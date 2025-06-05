# frozen_string_literal: true

require 'spec_helper'
require 'facter'
require 'facter/crypto_policy_state'

describe :crypto_policy_state, type: :fact do
  subject(:fact) { Facter.fact(:crypto_policy_state) }

  on_supported_os.each do |os, os_facts|
    before :each do
      Facter.clear

      allow(Dir).to receive(:glob).and_call_original
    end

    context "on #{os}" do
      let(:facts) { os_facts }

      before :each do
        allow(Facter.fact(:kernel)).to receive(:value).and_return(facts[:kernel])
      end

      context 'with a functional update-crypto-policies command' do
        before :each do
          allow(Facter::Util::Resolution).to receive(:which)
            .with('update-crypto-policies')
            .and_return('/usr/bin/update-crypto-policies')
          allow(Facter::Core::Execution).to receive(:execute)
            .with(%(/usr/bin/update-crypto-policies --no-reload --show), on_fail: false)
            .and_return("DEFAULT\n")
          allow(Dir).to receive(:glob)
            .with(['/usr/share/crypto-policies/policies/*.pol', '/etc/crypto-policies/policies/*.pol'])
            .and_return(
              [
                '/usr/share/crypto-policies/policies/DEFAULT.pol',
                '/usr/share/crypto-policies/policies/LEGACY.pol',
                '/etc/crypto-policies/policies/DEFAULT.pol',
                '/etc/crypto-policies/policies/CUSTOM.pol',
              ],
            )
        end

        context 'when applied' do
          before :each do
            allow(Facter::Core::Execution).to receive(:execute)
              .with('/usr/bin/update-crypto-policies --no-reload --is-applied', on_fail: false)
              .and_return("The configured policy is applied\n")
          end

          it do
            expect(Facter.fact('crypto_policy_state').value).to include(
              {
                'global_policy'             => 'DEFAULT',
                'global_policy_applied'     => true,
                'global_policies_available' => ['DEFAULT', 'LEGACY', 'CUSTOM'],
              },
            )
          end

          context 'with sub-policies' do
            before :each do
              allow(Dir).to receive(:glob)
                .with(['/usr/share/crypto-policies/policies/modules/*.pmod', '/etc/crypto-policies/policies/modules/*.pmod'])
                .and_return(['/usr/share/crypto-policies/policies/modules/sub_policy.pmod'])
            end

            it 'returns the crypto policy state' do
              expect(fact.value).to include({ 'sub_policies_available' => ['sub_policy'] })
            end
          end
        end

        context 'when not applied' do
          before :each do
            allow(Facter::Core::Execution).to receive(:execute)
              .with('/usr/bin/update-crypto-policies --no-reload --is-applied', on_fail: false)
              .and_return("The configured policy is NOT applied\n")
          end

          it do
            expect(Facter.fact('crypto_policy_state').value).to include(
              {
                'global_policy'             => 'DEFAULT',
                'global_policy_applied'     => false,
                'global_policies_available' => ['DEFAULT', 'LEGACY', 'CUSTOM'],
              },
            )
          end
        end
      end

      context 'when update-crypto-policies is not available' do
        before :each do
          allow(Facter::Util::Resolution).to receive(:which).with('update-crypto-policies').and_return(nil)
        end

        it 'returns nil' do
          expect(fact.value).to be_nil
        end
      end
    end
  end

  context 'on a non-Linux host' do
    before :each do
      allow(Facter.fact(:kernel)).to receive(:value).and_return('windows')
    end

    it 'returns nil' do
      expect(fact.value).to be_nil
    end
  end
end
