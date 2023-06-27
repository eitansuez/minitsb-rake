require 'open3'
require 'erb'
require 'logger'
require 'colorize'

require_relative 'tsb_config'

Config = TsbConfig.new

Log ||= Logger.new(STDOUT, level: Logger::INFO, formatter: proc {|severity, datetime, progname, msg|
  color = if severity == "DEBUG"
      :white
    elsif severity == "INFO"
      :green
    elsif severity == "WARN"
      :yellow
    elsif severity == "ERROR"
      :red
    else
      :light_blue
    end
  sprintf("%s: %s\n", datetime.strftime('%Y-%m-%d %H:%M:%S'), msg.colorize(color: color, mode: :bold))
})


task :default => :deploy_scenario

desc "Create host k3d cluster"
task :create_cluster do
  output, status = Open3.capture2("k3d cluster get tsb-cluster 2>/dev/null")
  if status.success?
    Log.warn "K3d host cluster already exists, skipping."
    next
  end

  Log.info("Creating host k3d cluster..")

  sh %Q[k3d cluster create tsb-cluster \
    --image rancher/k3s:v#{Config.params['k8s_version']}-k3s1 \
    --k3s-arg "--disable=traefik,servicelb@server:0" \
    --no-lb \
    --registry-create my-cluster-registry:0.0.0.0:5000 \
    --wait]
end

desc "Deploy metallb to host cluster and configure the address pool"
task :deploy_metallb => :create_cluster do
  output, status = Open3.capture2("kubectl --context k3d-tsb-cluster get ns metallb-system 2>/dev/null")
  if status.success?
    Log.warn "Metallb seems to already be deployed, skipping."
    next
  end

  Log.info("Deploying metallb..")

  sh "kubectl --context k3d-tsb-cluster apply -f addons/metallb-0.12.1.yaml"

  ip_prefix = `docker network inspect k3d-tsb-cluster | jq -r ".[0].IPAM.Config[0].Gateway" | awk -F . '{ print $1 "." $2 }'`.strip

  template_file = File.read('addons/metallb-poolconfig.yaml')
  metallb_startip = "#{ip_prefix}.100.100"
  metallb_stopip = "#{ip_prefix}.100.200"
  template = ERB.new(template_file)
  Open3.capture2("kubectl --context k3d-tsb-cluster apply -f -", stdin_data: template.result(binding))
end

desc "Synchronize TSB container images to local registry"
task :sync_images => :create_cluster do
  Log.info("Sync'ing images..")

  sh "tctl install image-sync \
    --username #{Config.params['tsb_repo']['username']} \
    --apikey #{Config.params['tsb_repo']['apikey']} \
    --registry localhost:5000 \
    --accept-eula \
    --parallel"
end

directory 'certs'

file 'certs/root-cert.pem' => ["certs"] do
  cd('certs') do
    sh %Q[step certificate create "Root CA" root-cert.pem root-cert.key \
      --profile root-ca \
      --kty RSA \
      --size 4096 \
      --not-after 87360h \
      --insecure --no-password]
  end
end

Config.params['clusters'].each do |cluster_entry|
  cluster = cluster_entry['name']

  directory "certs/#{cluster}"
  file "certs/#{cluster}/ca-cert.pem" => ['certs/root-cert.pem', "certs/#{cluster}"] do
    cd("certs/#{cluster}") do
      sh %Q[step certificate create "Istio intermediate certificate for #{cluster}" ca-cert.pem ca-key.pem \
        --profile intermediate-ca \
        --kty RSA \
        --size 4096 \
        --san istiod.istio-system.svc \
        --not-after 17520h \
        --ca ../root-cert.pem --ca-key ../root-cert.key \
        --insecure --no-password]

      sh "cat ca-cert.pem ../root-cert.pem > cert-chain.pem"
    end
  end

  task "create_#{cluster}_vcluster" => :create_cluster do
    output, status = Open3.capture2("vcluster list | grep vcluster-#{cluster}")
    if status.success?
      Log.warn "vcluster #{cluster} already exists, skipping."
      next
    end

    sh "vcluster create #{cluster}"
    sh "vcluster disconnect"
  end

  multitask "install_#{cluster}_cert" => ["certs/#{cluster}/ca-cert.pem", "create_#{cluster}_vcluster"] do
    context_name = k8s_context_name(cluster)

    output, status = Open3.capture2("kubectl --context #{context_name} get secret -n istio-system cacerts 2>/dev/null")
    if status.success?
      Log.warn "cacerts secret already exists in cluster #{cluster}, skipping."
      next
    end

    Log.info "Installing cacerts on #{cluster}.."

    sh "kubectl --context #{context_name} create ns istio-system"
    cd("certs/#{cluster}") do
      sh "kubectl --context #{context_name} create secret generic cacerts -n istio-system \
        --from-file=ca-cert.pem \
        --from-file=ca-key.pem \
        --from-file=../root-cert.pem \
        --from-file=cert-chain.pem"
    end
  end

  task "label_#{cluster}_locality" => "create_#{cluster}_vcluster" do
    Log.info "Labeling nodes for #{cluster} with region and zone information.."
    context_name = k8s_context_name(cluster)
    nodes = `kubectl --context #{context_name} get node -ojsonpath='{.items[].metadata.name}'`.split("\n")
    for node in nodes
      sh "kubectl --context #{context_name} label node #{node} topology.kubernetes.io/region=#{cluster_entry['region']} --overwrite=true"
      sh "kubectl --context #{context_name} label node #{node} topology.kubernetes.io/zone=#{cluster_entry['zone']} --overwrite=true"
    end
  end

end

desc "Generate istio cacerts"
multitask :make_certs => Config.clusters.map { |cluster| "certs/#{cluster}/ca-cert.pem" }

desc "Install istio cacerts as secrets in each vcluster"
task :install_certs => Config.clusters.map { |cluster| "install_#{cluster}_cert" }

desc "Create vclusters"
task :create_vclusters => Config.clusters.map { |cluster| "create_#{cluster}_vcluster" }

desc "Label cluster nodes with region and zone information"
task :label_node_localities => Config.clusters.map { |cluster| "label_#{cluster}_locality" }

desc "Install the TSB management plane"
multitask :install_mp => ["install_#{Config.mp_cluster['name']}_cert", "label_#{Config.mp_cluster['name']}_locality", :deploy_metallb, :sync_images] do
  mp_context = k8s_context_name(Config.mp_cluster['name'])

  output, status = Open3.capture2("kubectl --context #{mp_context} get -n tsb managementplane managementplane 2>/dev/null")
  if status.success?
    Log.warn "managementplane appears to be installed, skipping."
    next
  end

  sh "vcluster connect #{Config.mp_cluster['name']}"

  patch_affinity

  sh "tctl install demo \
    --cluster #{Config.mp_cluster['name']} \
    --registry my-cluster-registry:5000 \
    --admin-password admin"

  expose_tsb_gui

  sh "vcluster disconnect"
end

file 'certs/mp-certs.pem' => ["certs", :install_mp] do
  mp_context = k8s_context_name(Config.mp_cluster['name'])
  sh "kubectl --context #{mp_context} get -n istio-system secret mp-certs -o jsonpath='{.data.ca\\.crt}' | base64 --decode > certs/mp-certs.pem"
end

file 'certs/es-certs.pem' => ["certs", :install_mp] do
  mp_context = k8s_context_name(Config.mp_cluster['name'])
  sh "kubectl --context #{mp_context} get -n istio-system secret es-certs -o jsonpath='{.data.ca\\.crt}' | base64 --decode > certs/es-certs.pem"
end

file 'certs/xcp-central-ca-certs.pem' => ["certs", :install_mp] do
  mp_context = k8s_context_name(Config.mp_cluster['name'])
  sh "kubectl --context #{mp_context} get -n istio-system secret xcp-central-ca-bundle -o jsonpath='{.data.ca\\.crt}' | base64 --decode > certs/xcp-central-ca-certs.pem"
end

directory 'generated-artifacts'

file 'generated-artifacts/clusteroperators.yaml' => ['generated-artifacts'] do
  cd('generated-artifacts') do
    `tctl install manifest cluster-operators --registry my-cluster-registry:5000 > clusteroperators.yaml`
  end
end

Config.cp_clusters.each do |cluster|

  directory "generated-artifacts/#{cluster}"
  file "generated-artifacts/#{cluster}/service-account.jwk" => ["generated-artifacts/#{cluster}"] do
    cd("generated-artifacts/#{cluster}") do
      `tctl install cluster-service-account --cluster #{cluster} > service-account.jwk`
    end
  end

  file "generated-artifacts/#{cluster}/controlplane-secrets.yaml" => ["generated-artifacts/#{cluster}/service-account.jwk", "certs/es-certs.pem", "certs/mp-certs.pem", "certs/xcp-central-ca-certs.pem"] do
    `tctl install manifest control-plane-secrets \
      --cluster #{cluster} \
      --cluster-service-account="$(cat generated-artifacts/#{cluster}/service-account.jwk)" \
      --elastic-ca-certificate="$(cat certs/es-certs.pem)" \
      --management-plane-ca-certificate="$(cat certs/mp-certs.pem)" \
      --xcp-central-ca-bundle="$(cat certs/xcp-central-ca-certs.pem)" \
      > generated-artifacts/#{cluster}/controlplane-secrets.yaml`
  end

  file "generated-artifacts/#{cluster}/controlplane.yaml" => ["generated-artifacts/#{cluster}"] do
    template_file = File.read('templates/controlplane.yaml')
    mp_context = k8s_context_name(Config.mp_cluster['name'])
    tsb_api_endpoint = `kubectl --context #{mp_context} get svc -n tsb envoy --output jsonpath='{.status.loadBalancer.ingress[0].ip}'`
    template = ERB.new(template_file)
    File.write("generated-artifacts/#{cluster}/controlplane.yaml", template.result(binding))
  end

  task "install_cp_#{cluster}" => [:install_mp, "install_#{cluster}_cert", "label_#{cluster}_locality", 'generated-artifacts/clusteroperators.yaml', "generated-artifacts/#{cluster}/controlplane-secrets.yaml", "generated-artifacts/#{cluster}/controlplane.yaml"] do
    cp_context = k8s_context_name(cluster)

    output, status = Open3.capture2("kubectl --context #{cp_context} get -n istio-system controlplane controlplane 2>/dev/null")
    if status.success?
      Log.warn "Controlplane appears to be installed on cluster #{cluster}, skipping."
      next
    end

    Log.info("Installing control plane on #{cluster}..")

    sh "kubectl --context #{cp_context} apply -f generated-artifacts/clusteroperators.yaml"
    sh "kubectl --context #{cp_context} apply -f generated-artifacts/#{cluster}/controlplane-secrets.yaml"
    wait_for "kubectl --context #{cp_context} get controlplanes.install.tetrate.io 2>/dev/null", "ControlPlane CRD definition"
    sh "kubectl --context #{cp_context} apply -f generated-artifacts/#{cluster}/controlplane.yaml"
  end
end

desc "Install the TSB control planes"
task :install_controlplanes => Config.cp_clusters.map { |cluster| "install_cp_#{cluster}" }

desc "Deploy and print TSB scenario"
task :deploy_scenario => :install_controlplanes do
  Log.info "Deploying scenario.."

  cd('scenario') do
    sh "./deploy.sh"
    sh "./info.sh"
  end
  public_ip = `curl -s ifconfig.me`
  puts "Management plane GUI can be accessed at: https://#{public_ip}:8443/"
  Log.info("..provisioning complete.")
end




def k8s_context_name(vcluster_name)
  "vcluster_#{vcluster_name}_vcluster-#{vcluster_name}_k3d-tsb-cluster"
end

def patch_affinity
  Thread.new {
    wait_for "kubectl -n tsb get managementplane managementplane 2>/dev/null", "ManagementPlane object to exist"

    for tsb_component in ['apiServer', 'collector', 'frontEnvoy', 'iamServer', 'mpc', 'ngac', 'oap', 'webUI']
      sh %Q[kubectl patch managementplane managementplane -n tsb --type=json \
        -p="[{'op': 'replace', 'path': '/spec/components/#{tsb_component}/kubeSpec/deployment/affinity/podAntiAffinity/requiredDuringSchedulingIgnoredDuringExecution/0/labelSelector/matchExpressions/0/key', 'value': 'platform.tsb.tetrate.io/demo-dummy'}]"]
    end
  }
end

def expose_tsb_gui
  cluster_ctx=k8s_context_name(Config.mp_cluster['name'])

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

  sh "sudo systemctl enable tsb-gui"
  sh "sudo systemctl start tsb-gui"
end

def wait_for(command, msg=nil)
  if msg
    Log.info "waiting for #{msg}"
  end

  output, status = Open3.capture2(command)
  until status.success?
    sleep 1
    print "."
    output, status = Open3.capture2(command)
  end

  Log.info "condition passed"
end
