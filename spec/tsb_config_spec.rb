require_relative "../tsb_config"

RSpec.describe TsbConfig do
  context 'parsing the config' do
    before do
      @config = TsbConfig.new
    end

    it 'parses a direct field' do
      expect(@config.params['k8s_version']).to eq "1.25.9"
    end

    it 'parses a nested field' do
      expect(@config.params['tsb_repo']['username']).to eq "eitan-suez"
    end

    it 'identifies the cluster names' do
      expect(@config.clusters).to eq ["t1", "c1", "c2"]
    end

    it 'identifies the mp cluster name' do
      expect(@config.mp_cluster['name']).to eq "t1"
    end

    it 'identifies the cp cluster names' do
      expect(@config.cp_clusters).to eq ["c1", "c2"]
    end
  end
end
