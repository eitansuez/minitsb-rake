require 'yaml'

class TsbConfig

  def initialize
    @params = YAML.load_file('config.yaml')

    @clusters = @params['clusters'].map { |c| c['name'] }
    @mp_cluster = @params['clusters'].find { |c| c['is_mp'] }
    @cp_clusters = @params['clusters'].select { |c| !c['is_mp'] }.map { |c| c['name'] }
  end

  attr_reader :params, :clusters, :mp_cluster, :cp_clusters

end