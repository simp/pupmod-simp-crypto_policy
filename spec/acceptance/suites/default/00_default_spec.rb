require 'spec_helper_acceptance'

test_name 'crypto_policy class'

describe 'crypto_policy class' do
  let(:manifest) {
    <<-EOS
      include 'crypto_policy'
    EOS
  }

  hosts.each do |host|
    context 'with defaults' do

      # Using puppet_apply as a helper
      it 'should work with no errors' do
         apply_manifest_on(host, manifest, :catch_failures => true)
      end

      it 'should be idempotent' do
        apply_manifest_on(host, manifest, {:catch_changes => true})
      end
    end
  end
end
