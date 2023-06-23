require "./tsb_installer.rb"

RSpec.describe TsbInstaller do
  context 'parsing the config' do
    before do
      @installer = TsbInstaller.new
    end

    it 'parses a direct field' do
      expect(@installer.config['k8s_version']).to eq "1.25.9"
    end

    it 'parses a nested field' do
      expect(@installer.config['tsb_repo']['username']).to eq "eitan-suez"
    end

    it 'identifies the cluster names' do
      expect(@installer.clusters).to eq ["t1", "c1", "c2"]
    end

    it 'identifies the mp cluster name' do
      expect(@installer.mp_cluster['name']).to eq "t1"
    end

    it 'identifies the cp cluster names' do
      expect(@installer.cp_clusters).to eq ["c1", "c2"]
    end
  end
end
