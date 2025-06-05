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

      it 'has a valid crypto_policy_state fact' do
        crypto_policy_state = pfact_on(host, 'crypto_policy_state')

        expect(crypto_policy_state).not_to be_empty
        expect(crypto_policy_state['global_policy']).to eq default_policy
        expect(crypto_policy_state['global_policy_applied']).to eq true
        expect(crypto_policy_state['global_policies_available']).to include('DEFAULT', 'EMPTY', 'FIPS', 'FUTURE', 'LEGACY')
        expect(crypto_policy_state['sub_policies_available']).not_to be_empty
        expect(crypto_policy_state['sub_policies_available']).to be_an(Array)
      end
    end

    context 'when setting the config to a global policy' do
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
          crypto_policy_state = pfact_on(host, 'crypto_policy_state')

          expect(crypto_policy_state).not_to be_empty
          expect(crypto_policy_state['global_policy']).to eq 'FIPS'
          expect(crypto_policy_state['global_policy_applied']).to eq true
        end
      else
        it 'has the global policy set to LEGACY' do
          crypto_policy_state = pfact_on(host, 'crypto_policy_state')

          expect(crypto_policy_state).not_to be_empty
          expect(crypto_policy_state['global_policy']).to eq hieradata['crypto_policy::ensure']
          expect(crypto_policy_state['global_policy_applied']).to eq true
        end
      end
    end

    context 'with custom subpolicy' do

      # Create a custom subpolicy
      on(host, "cp /usr/share/crypto-policies/policies/modules/NO-SHA1.pmod /etc/crypto-policies/policies/modules/TEST.pmod")

      # Using puppet_apply as a helper
      it 'works without error' do
        apply_manifest_on(host, manifest, catch_failures: true)
      end

      it 'is idempotent' do
        apply_manifest_on(host, manifest, { catch_changes: true })
      end

      it 'has a valid crypto_policy_state fact' do
        crypto_policy_state = pfact_on(host, 'crypto_policy_state')

        expect(crypto_policy_state).not_to be_empty
        expect(crypto_policy_state['sub_policies_available']).to be_an(Array)
        expect(crypto_policy_state['sub_policies_available']).to include('TEST')
      end
    end

    context 'when setting the config with a subpolicy' do
      let(:hieradata) do
        {
          'crypto_policy::ensure' => 'DEFAULT:NO-SHA1',
          'force_fips_override'   => true
        }
      end

      it 'works without error' do
        set_hieradata_on(host, hieradata)
        apply_manifest_on(host, manifest, catch_failures: true)
      end

      it 'is idempotent' do
        apply_manifest_on(host, manifest, { catch_changes: true })
      end

      it 'has the global policy set to DEFAULT:NO-SHA1' do
        crypto_policy_state = pfact_on(host, 'crypto_policy_state')

        expect(crypto_policy_state).not_to be_empty
        expect(crypto_policy_state['global_policy']).to eq hieradata['crypto_policy::ensure']
        expect(crypto_policy_state['global_policy_applied']).to eq true
      end
    end
  end
end
