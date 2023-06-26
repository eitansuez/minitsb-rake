require_relative 'tsb_installer'

Installer = TsbInstaller.new

task :default => :deploy_scenario

desc "Create host k3d cluster"
task :create_cluster do
  Installer.create_cluster
end

desc "Deploy metallb to host cluster and configure the address pool"
task :deploy_metallb => :create_cluster do
  Installer.instance_exec do
    deploy_metallb
    configure_metallb
  end
end

desc "Synchronize tsb container images to local registry"
task :sync_images => :create_cluster do
  Installer.sync_images
end

desc "Create vclusters for TSB topology"
task :create_vclusters => :create_cluster do
  Installer.create_vclusters
end

desc "Label cluster nodes with region and zone information"
task :label_node_localities => :create_vclusters do
  Installer.label_node_localities
end

desc "Generate istio cacerts"
task :make_certs do
  Installer.make_the_certs
end

desc "Install istio cacerts as secrets in each vcluster"
multitask :install_certs => [:make_certs, :create_vclusters] do
  Installer.install_the_certs
end

desc "Install the TSB management plane"
task :install_mp => [:install_certs, :deploy_metallb, :sync_images] do
  Installer.install_mp
end

desc "Install the TSB control planes"
task :install_controlplanes => :install_mp do
  Installer.install_controlplanes
end

desc "Deploy and print TSB scenario"
task :deploy_scenario => :install_controlplanes do
  Installer.instance_exec do
    deploy_scenario
    scenario_info
  end
end
