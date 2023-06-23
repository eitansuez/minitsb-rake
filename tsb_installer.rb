require 'yaml'
require 'fileutils'
require 'erb'
require 'open3'

require './logging.rb'
require './utils.rb'
require './certs.rb'

class TsbInstaller
  include Certs, Utils, Logging

  def initialize
    @config = YAML.load_file('config.yaml')
    @clusters = @config['clusters'].map { |c| c['name'] }
    @mp_cluster = @config['clusters'].find { |c| c['is_mp'] }
    @cp_clusters = @config['clusters'].select { |c| !c['is_mp'] }.map { |c| c['name'] }
  end

  attr_reader :config, :clusters, :mp_cluster, :cp_clusters

  def create_cluster
    log.info "create the host cluster"
    run_command %Q[k3d cluster create tsb-cluster \
      --image rancher/k3s:v#{@config['k8s_version']}-k3s1 \
      --k3s-arg "--disable=traefik,servicelb@server:0" \
      --no-lb \
      --registry-create my-cluster-registry:0.0.0.0:5000 \
      --wait]
  end

  def deploy_metallb
    log.info "deploy metallb"
    run_command "kubectl apply -f addons/metallb-0.12.1.yaml"
  end

  def configure_metallb
    log.info "configure metallb"
    ip_prefix = `docker network inspect k3d-tsb-cluster | jq -r ".[0].IPAM.Config[0].Gateway" | awk -F . '{ print $1 "." $2 }'`.strip

    template_file = File.read('addons/metallb-poolconfig.yaml')
    metallb_startip = "#{ip_prefix}.100.100"
    metallb_stopip = "#{ip_prefix}.100.200"
    template = ERB.new(template_file)
    Open3.capture2("kubectl apply -f -", stdin_data: template.result(binding))
  end

  def sync_images
    log.info "sync images"
    run_command "tctl install image-sync \
      --username #{@config['tsb_repo']['username']} \
      --apikey #{@config['tsb_repo']['apikey']} \
      --registry localhost:5000 \
      --accept-eula \
      --parallel"
  end

  def create_vclusters
    log.info "create vclusters"
    for cluster in @clusters
      run_command "vcluster create #{cluster}"
      `vcluster disconnect`
    end
  end

  def label_node_localities
    log.info "label cluster nodes with locality information (region/zone)"

    for cluster in @config['clusters']
      run_command "vcluster connect #{cluster['name']}"
      nodes = `(kubectl get node -ojsonpath='{.items[].metadata.name}')`.split("\n")
      for node in nodes
        run_command "kubectl label node #{node} topology.kubernetes.io/region=#{cluster['region']} --overwrite=true"
        run_command "kubectl label node #{node} topology.kubernetes.io/zone=#{cluster['zone']} --overwrite=true"
      end
    end
  end

  def patch_affinity
    Thread.new {
      wait_for "kubectl -n tsb get managementplane managementplane 2>/dev/null", "ManagementPlane object to exist"

      for tsb_component in ['apiServer', 'collector', 'frontEnvoy', 'iamServer', 'mpc', 'ngac', 'oap', 'webUI']
        run_command %Q[kubectl patch managementplane managementplane -n tsb --type=json \
          -p="[{'op': 'replace', 'path': '/spec/components/#{tsb_component}/kubeSpec/deployment/affinity/podAntiAffinity/requiredDuringSchedulingIgnoredDuringExecution/0/labelSelector/matchExpressions/0/key', 'value': 'platform.tsb.tetrate.io/demo-dummy'}]"]
      end
    }
  end

  def install_mp
    log.info "install management plane"

    run_command "vcluster connect #{@mp_cluster['name']}"

    patch_affinity

    run_command "tctl install demo \
      --cluster #{@mp_cluster['name']} \
      --registry my-cluster-registry:5000 \
      --admin-password admin"

    extract_mp_certs
    expose_tsb_gui
  end

  def extract_mp_certs
    log.info "extract mp certs"
    `kubectl get -n istio-system secret mp-certs -o jsonpath='{.data.ca\\.crt}' | base64 --decode > certs/mp-certs.pem`
    `kubectl get -n istio-system secret es-certs -o jsonpath='{.data.ca\\.crt}' | base64 --decode > certs/es-certs.pem`
    `kubectl get -n istio-system secret xcp-central-ca-bundle -o jsonpath='{.data.ca\\.crt}' | base64 --decode > certs/xcp-central-ca-certs.pem`
  end

  def expose_tsb_gui
    log.info "expose tsb gui"
    cluster_ctx="vcluster_#{@mp_cluster['name']}_vcluster-#{@mp_cluster['name']}_k3d-tsb-cluster"
  
    kubectl_fullpath=`which kubectl`.strip
  
    `sudo tee /etc/systemd/system/tsb-gui.service << EOF
    [Unit]
    Description=TSB GUI Exposure
  
    [Service]
    ExecStart=#{kubectl_fullpath} --kubeconfig #{Dir.home}/.kube/config --context #{cluster_ctx} port-forward -n tsb service/envoy 8443:8443 --address 0.0.0.0
    Restart=always
  
    [Install]
    WantedBy=multi-user.target
    EOF`
  
    run_command "sudo systemctl enable tsb-gui"
    run_command "sudo systemctl start tsb-gui"
  end
    
  def install_controlplanes
    log.info "install controlplanes"
    gen_cp_configs
    apply_cp_configs
  end

  def gen_cp_configs
    log.info "generate control plane configuration files"
    `tctl install manifest cluster-operators --registry my-cluster-registry:5000 > clusteroperators.yaml`

    for cluster in @cp_clusters
      `tctl install cluster-service-account --cluster #{cluster} > #{cluster}-service-account.jwk`

      `tctl install manifest control-plane-secrets \
        --cluster #{cluster} \
        --cluster-service-account="$(cat #{cluster}-service-account.jwk)" \
        --elastic-ca-certificate="$(cat certs/es-certs.pem)" \
        --management-plane-ca-certificate="$(cat certs/mp-certs.pem)" \
        --xcp-central-ca-bundle="$(cat certs/xcp-central-ca-certs.pem)" \
        > #{cluster}-controlplane-secrets.yaml`

      template_file = File.read('templates/controlplane.yaml')
      tsb_api_endpoint = `kubectl get svc -n tsb envoy --output jsonpath='{.status.loadBalancer.ingress[0].ip}'`
      template = ERB.new(template_file)
      File.write("#{cluster}-controlplane.yaml", template.result(binding))
    end
  end

  def apply_cp_configs
    log.info "apply control plane configurations"
    for cluster in @cp_clusters
      run_command "vcluster connect #{cluster}"
      run_command "kubectl apply -f clusteroperators.yaml"
      run_command "kubectl apply -f #{cluster}-controlplane-secrets.yaml"

      wait_for "kubectl get controlplanes.install.tetrate.io 2>/dev/null", "ControlPlane CRD definition"

      run_command "kubectl apply -f #{cluster}-controlplane.yaml"
    end
  end

  def deploy_scenario
    log.info "deploy scenario"
    FileUtils.cd('scenario') do
      run_command "./deploy.sh"
    end
  end

  def scenario_info
    log.info "scenario info"
    FileUtils.cd('scenario') do
      run_command "./info.sh"
    end

    public_ip = `curl -s ifconfig.me`
    puts "Management plane GUI can be accessed at: https://#{public_ip}:8443/"
  end

  def run
    create_cluster

    deploy_metallb
    configure_metallb

    sync_images

    create_vclusters
    label_node_localities

    make_certs @clusters
    install_certs @clusters

    install_mp
    install_controlplanes

    deploy_scenario
    scenario_info
  end

end