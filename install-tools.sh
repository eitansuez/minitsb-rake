#!/bin/bash

k8s_version=$(yq .k8s_version config.yaml)
istio_version=$(yq .istio_version config.yaml)

# Colors
end="\033[0m"
greenb="\033[1;32m"

function print_info {
  echo -e "${greenb}${1}${end}"
}

print_info "Installing kubectl"
curl -Lo /tmp/kubectl "https://dl.k8s.io/release/v${k8s_version}/bin/linux/amd64/kubectl"
chmod +x /tmp/kubectl
sudo install /tmp/kubectl /usr/local/bin/kubectl
rm -f /tmp/kubectl

print_info "Installing k9s"
curl -Lo /tmp/k9s.tar.gz "https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_amd64.tar.gz"
tar xvfz /tmp/k9s.tar.gz -C /tmp
chmod +x /tmp/k9s
sudo install /tmp/k9s /usr/local/bin/k9s
rm -f /tmp/k9s*

print_info "Installing k3d"
latest_k3d_release=$(curl --silent https://api.github.com/repos/k3d-io/k3d/releases/latest | grep -i "tag_name" | awk -F '"' '{print $4}')
curl -Lo /tmp/k3d "https://github.com/k3d-io/k3d/releases/download/${latest_k3d_release}/k3d-linux-amd64"
chmod +x /tmp/k3d
sudo install /tmp/k3d /usr/local/bin/k3d
rm -f /tmp/k3d

print_info "Installing istioctl"
curl -Lo /tmp/istioctl.tar.gz "https://github.com/istio/istio/releases/download/${istio_version}/istioctl-${istio_version}-linux-amd64.tar.gz"
tar xvfz /tmp/istioctl.tar.gz -C /tmp
chmod +x /tmp/istioctl
sudo install /tmp/istioctl /usr/local/bin/istioctl
rm -f /tmp/istioctl*

print_info "Installing tctl"
curl -Lo /tmp/tctl "https://binaries.dl.tetrate.io/public/raw/versions/linux-amd64-1.6.2/tctl"
chmod +x /tmp/tctl
sudo install /tmp/tctl /usr/local/bin/tctl
rm -f /tmp/tctl

print_info "Installing vcluster"
curl -L -o vcluster "https://github.com/loft-sh/vcluster/releases/latest/download/vcluster-linux-amd64" && sudo install -c -m 0755 vcluster /usr/local/bin && rm -f vcluster

print_info "Installing step cli"
wget https://dl.smallstep.com/gh-release/cli/docs-cli-install/v0.23.4/step-cli_0.23.4_amd64.deb
sudo dpkg -i step-cli_0.23.4_amd64.deb
rm step-cli_0.23.4_amd64.deb

print_info "Enabling bash completion and add some alias"
cat >> ~/.bashrc <<'EOF'

#
set -o vi
export EDITOR=vim

source <(k3d completion bash)
source <(vcluster completion bash)

source <(kubectl completion bash)
alias k=kubectl
complete -F __start_kubectl k

source <(istioctl completion bash)

EOF
