# frozen_string_literal: true

require 'spec_helper_acceptance'

test_name 'crypto_policy class'

describe 'crypto_policy class' do
  let(:manifest) do
    <<~MANIFEST
      include 'crypto_policy'
    MANIFEST
  end

  hosts.each do |host|
    if pfact_on(host, 'fips_enabled')
      let(:default_policy) { 'FIPS' }
    else
      let(:default_policy) { 'DEFAULT' }
    end

    context 'with defaults' do
      # Using puppet_apply as a helper
      it 'works without error' do
        apply_manifest_on(host, manifest, catch_failures: true)
      end

      it 'is idempotent' do
        apply_manifest_on(host, manifest, { catch_changes: true })
      end

      it 'has a valid crypto_policy__state fact' do
        crypto_policy_state = pfact_on(host, 'crypto_policy__state')

        expect(crypto_policy_state).not_to be_empty
        expect(crypto_policy_state['global_policy']).to eq default_policy
        expect(crypto_policy_state['global_policy_applied']).to eq true
        expect(crypto_policy_state['global_policies_available']).to include('DEFAULT', 'EMPTY', 'FIPS', 'FUTURE', 'LEGACY')
      end
    end

    context 'when setting the config' do
      let(:hieradata) do
        {
          'crypto_policy::ensure' => 'LEGACY'
        }
      end

      it 'works without error' do
        set_hieradata_on(host, hieradata)
        apply_manifest_on(host, manifest, catch_failures: true)
      end

      it 'is idempotent' do
        apply_manifest_on(host, manifest, { catch_changes: true })
      end

      if pfact_on(host, 'fips_enabled')
        it 'has the global policy set to FIPS' do
          crypto_policy_state = pfact_on(host, 'crypto_policy__state')

          expect(crypto_policy_state).not_to be_empty
          expect(crypto_policy_state['global_policy']).to eq 'FIPS'
          expect(crypto_policy_state['global_policy_applied']).to eq true
        end
      else
        it 'has the global policy set to LEGACY' do
          crypto_policy_state = pfact_on(host, 'crypto_policy__state')

          expect(crypto_policy_state).not_to be_empty
          expect(crypto_policy_state['global_policy']).to eq hieradata['crypto_policy::ensure']
          expect(crypto_policy_state['global_policy_applied']).to eq true
        end
      end
    end
  end
end
