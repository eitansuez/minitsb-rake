require 'yaml'

class TsbConfig

  def initialize(config_file = 'config.yaml')
    @params = YAML.load_file(config_file)

    scenario = @params['scenario']
    base_path = File.dirname(config_file)

    topology_file = "#{base_path}/scenarios/#{scenario}/topology.yaml"
    topology = YAML.load_file(topology_file)

    @params['clusters'] = topology['clusters']

    @clusters = @params['clusters'].map { |cluster| [cluster['name'], cluster] }.to_h
    @cluster_names = @params['clusters'].map { |c| c['name'] }

    @mp_cluster = @params['clusters'].find { |c| c['is_mp'] }
    @cp_clusters = @params['clusters'].select { |c| !c['is_mp'] }

    # default onboard_cluster to true if not specified
    @params['clusters'].each do |cluster|
      if !cluster.has_key?('onboard_cluster')
        cluster['onboard_cluster'] = true
      end
    end

  end

  attr_reader :params, :clusters, :cluster_names, :mp_cluster, :cp_clusters

end