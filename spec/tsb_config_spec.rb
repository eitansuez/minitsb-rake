require_relative "../tsb_config"

RSpec.describe TsbConfig do
  context 'parsing the config' do
    before do
      @config = TsbConfig.new('spec/config-test.yaml')
    end

    it 'parses a direct field' do
      expect(@config.params['k8s_version']).to eq "1.27.6"
    end

    it 'parses a nested field' do
      expect(@config.params['tsb_repo']['username']).to eq "john-jones"
    end

    it 'identifies the cluster names' do
      expect(@config.cluster_names).to eq ["t1", "c1", "c2", "c3"]
    end

    it 'identifies the mp cluster name' do
      expect(@config.mp_cluster['name']).to eq "t1"
    end

    it 'identifies the cp cluster names' do
      expect(@config.cp_clusters.map { |c| c['name'] }).to eq ["c1", "c2", "c3"]
    end

    it 'defaults to onboarding control plane clusters unless explicitly set to false' do
      expect(@config.clusters['c1']['onboard_cluster']).to be true
      expect(@config.clusters['c2']['onboard_cluster']).to be false
      expect(@config.clusters['c3']['onboard_cluster']).to be true
    end
  end
end
