# frozen_string_literal: true

require 'spec_helper'

describe 'crypto_policy' do
  on_supported_os.each do |os, os_facts|
    context 'with required facts' do
      let(:fips_enabled) { false }
      let(:facts) do
        os_facts.merge(
          simplib__crypto_policy_state: {
            'global_policies_available' => ['DEFAULT', 'FIPS', 'LEGACY', 'FUTURE', 'NONE']
          },
          fips_enabled: fips_enabled,
        )
      end

      context "on #{os}" do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to create_class('crypto_policy') }
        it { is_expected.to create_class('crypto_policy::update') }
        it { is_expected.to create_class('crypto_policy::install').that_comes_before('Class[crypto_policy::update]') }
        it { is_expected.not_to create_file('/etc/crypto-policies/config') }

        context 'when not managing the installation' do
          let(:params) { { manage_installation: false } }

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to create_class('crypto_policy::update') }
          it { is_expected.not_to create_class('crypto_policy::install') }
        end

        context 'with ensure set to DEFAULT' do
          let(:params) do
            {
              ensure: 'DEFAULT',
            }
          end

          it { is_expected.to compile.with_all_deps }

          it {
            is_expected.to create_file('/etc/crypto-policies/config').with_content(
              <<~CONTENT,
                # This file managed by Puppet using crypto_policy
                #
                DEFAULT
              CONTENT
            ).that_notifies('Class[crypto_policy::update]')
          }

          it { is_expected.to create_exec('update global crypto policy') }
        end

        context 'with the system in FIPS mode' do
          let(:fips_enabled) { true }

          it {
            is_expected.to create_file('/etc/crypto-policies/config').with_content(
              <<~CONTENT,
                # This file managed by Puppet using crypto_policy
                #
                FIPS
              CONTENT
            ).that_notifies('Class[crypto_policy::update]')
          }

          it { is_expected.to create_exec('update global crypto policy') }

          context 'with forced override' do
            let(:fips_enabled) { true }

            let(:params) do
              {
                ensure: 'DEFAULT',
                force_fips_override: true
              }
            end

            it {
              is_expected.to create_file('/etc/crypto-policies/config').with_content(
                <<~CONTENT,
                  # This file managed by Puppet using crypto_policy
                  #
                  DEFAULT
                CONTENT
              ).that_notifies('Class[crypto_policy::update]')
            }
          end
        end
      end
    end

    context "on #{os} without required facts" do
      let(:facts) { os_facts.reject { |k, _v| k == :simplib__crypto_policy_state } }
      let(:params) { { ensure: 'DEFAULT' } }

      it { is_expected.to compile.with_all_deps }
    end
  end
end
