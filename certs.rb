require 'fileutils'

module Certs

  def make_certs(clusters)
    log.info "make istio certificates"
    for cluster in clusters
      make_intermediate_cert cluster
    end
  end

  def install_certs(clusters)
    log.info "install istio cacerts"
    for cluster in clusters
      context_name = k8s_context_name(cluster)
      puts `kubectl --context #{context_name} create ns istio-system`
      FileUtils.cd("certs/#{cluster}") do
        puts `kubectl --context #{context_name} create secret generic cacerts -n istio-system \
          --from-file=ca-cert.pem \
          --from-file=ca-key.pem \
          --from-file=../root-cert.pem \
          --from-file=cert-chain.pem`
      end
    end
  end

  private

  def make_root_cert
    if File.exist? 'certs/root-cert.pem'
      log.warn 'skipping, root cert already exists'
      return
    end

    certs_dir = 'certs'
    FileUtils.mkdir(certs_dir) unless File.exist?(certs_dir)

    FileUtils.cd(certs_dir) do
      `step certificate create "Root CA" root-cert.pem root-cert.key \
        --profile root-ca \
        --kty RSA \
        --size 4096 \
        --not-after 87360h \
        --insecure --no-password`
    end
  end

  def make_intermediate_cert(cluster)
    make_root_cert
    if File.exist? "certs/#{cluster}/ca-cert.pem"
      log.warn "skipping, ca cert for cluster #{cluster} already exists"
      return
    end

    cert_dir = "certs/#{cluster}"
    FileUtils.mkdir(cert_dir) unless File.exist?(cert_dir)

    FileUtils.cd(cert_dir) do
      `step certificate create "Istio intermediate certificate for ${cluster}" ca-cert.pem ca-key.pem \
        --profile intermediate-ca \
        --kty RSA \
        --size 4096 \
        --san istiod.istio-system.svc \
        --not-after 17520h \
        --ca ../root-cert.pem --ca-key ../root-cert.key \
        --insecure --no-password`

      `cat ca-cert.pem ../root-cert.pem > cert-chain.pem`
    end
  end

end