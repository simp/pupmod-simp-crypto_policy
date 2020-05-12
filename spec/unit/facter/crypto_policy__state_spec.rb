# frozen_string_literal: true

require 'spec_helper'

describe 'crypto_policy__state' do
  before :each do
    Facter.clear

    # Mock out Facter method called when evaluating confine for :kernel
    # expect(Facter::Core::Execution).to receive(:exec).with('uname -s').and_return('Linux')
    expect(Facter.fact(:kernel)).to receive(:value).and_return('Linux')

    # Ensure that something sane is returned when finding the command
    expect(Facter::Util::Resolution).to receive(:which).with('update-crypto-policies').and_return('update-crypto-policies')
  end

  context 'with a functional update-crypto-policies command' do
    before :each do
      expect(Facter::Core::Execution).to receive(:execute).with('update-crypto-policies --no-reload --show', on_fail: false).and_return("DEFAULT\n")

      allow(Dir).to receive(:glob).with(anything).and_call_original
      expect(Dir).to receive(:glob).with('/usr/share/crypto-policies/*').and_return(
        [
          '/usr/share/crypto-policies/DEFAULT',
          '/usr/share/crypto-policies/LEGACY',
          '/usr/share/crypto-policies/foo',
        ],
      )

      allow(File).to receive(:directory?).with(anything).and_call_original
      expect(File).to receive(:directory?).with('/usr/share/crypto-policies/DEFAULT').and_return(true)
      expect(File).to receive(:directory?).with('/usr/share/crypto-policies/LEGACY').and_return(true)
      expect(File).to receive(:directory?).with('/usr/share/crypto-policies/foo').and_return(false)
    end

    context 'when applied' do
      before :each do
        expect(Facter::Core::Execution).to receive(:execute).with('update-crypto-policies --no-reload --is-applied', on_fail: false).and_return("The configured policy is applied\n")
      end

      it do
        expect(Facter.fact('crypto_policy__state').value).to include(
          {
            'global_policy' => 'DEFAULT',
            'global_policy_applied' => true,
            'global_policies_available' => ['DEFAULT', 'LEGACY']
          },
        )
      end
    end

    context 'when not applied' do
      before :each do
        expect(Facter::Core::Execution).to receive(:execute).with('update-crypto-policies --no-reload --is-applied', on_fail: false).and_return("The configured policy is NOT applied\n")
      end

      it do
        expect(Facter.fact('crypto_policy__state').value).to include(
          {
            'global_policy' => 'DEFAULT',
            'global_policy_applied' => false,
            'global_policies_available' => ['DEFAULT', 'LEGACY']
          },
        )
      end
    end
  end

  context 'with a non-functionsl update-crypto-policies command' do
    it 'returns a nil value' do
      expect(Facter::Core::Execution).to receive(:execute).with('update-crypto-policies --no-reload --show', on_fail: false).and_return(false)

      expect(Facter.fact('crypto_policy__state').value).to be_nil
    end
  end
end
