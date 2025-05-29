# frozen_string_literal: true

require 'spec_helper'

describe 'crypto_policy' do
  on_supported_os.each do |os, os_facts|
    context 'with required facts' do
      let(:fips_enabled) { false }
      let(:facts) do
        os_facts.merge(
          crypto_policy_state: {
            'global_policies_available' => ['DEFAULT', 'FIPS', 'LEGACY', 'FUTURE', 'NONE'],
            'sub_policies_available'    => ['AD-SUPPORT', 'ECDHE-ONLY', 'NO-CAMELLIA', 'NO-SHA1', 'OSPP']
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

        context 'with ensure set to DEFAULT:NO-SHA1:OSPP' do
          let(:params) do
            {
              ensure: 'DEFAULT:NO-SHA1:OSPP',
            }
          end

          it { is_expected.to compile.with_all_deps }

          it {
            is_expected.to create_file('/etc/crypto-policies/config').with_content(
              <<~CONTENT,
                # This file managed by Puppet using crypto_policy
                #
                DEFAULT:NO-SHA1:OSPP
              CONTENT
            ).that_notifies('Class[crypto_policy::update]')
          }

          it { is_expected.to create_exec('update global crypto policy') }
        end

        context 'with ensure set to DEFAULT:NO-SHA1' do
          let(:params) do
            {
              ensure: 'DEFAULT:NO-SHA1',
            }
          end

          it { is_expected.to compile.with_all_deps }

          it {
            is_expected.to create_file('/etc/crypto-policies/config').with_content(
              <<~CONTENT,
                # This file managed by Puppet using crypto_policy
                #
                DEFAULT:NO-SHA1
              CONTENT
            ).that_notifies('Class[crypto_policy::update]')
          }

          it { is_expected.to create_exec('update global crypto policy') }
        end

        context 'with ensure set to non-existent global policy' do
          let(:params) do
            {
              ensure: 'FAKE',
            }
          end

          it { is_expected.not_to compile }
        end

        context 'with ensure set to non-existent subpolicy' do
          let(:params) do
            {
              ensure: 'DEFAULT:FAKE',
            }
          end

          it { is_expected.not_to compile }
        end

        context 'with ensure set to real and non-existent subpolicy' do
          let(:params) do
            {
              ensure: 'DEFAULT:NO-SHA1:FAKE',
            }
          end

          it { is_expected.not_to compile }
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
      let(:facts) { os_facts.reject { |k, _v| k == :crypto_policy_state } }
      let(:params) { { ensure: 'DEFAULT' } }

      it { is_expected.to compile.with_all_deps }
    end
  end
end
