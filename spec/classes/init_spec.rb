require 'spec_helper'

describe 'crypto_policy' do
  on_supported_os.each do |os, os_facts|
    let(:facts) do
      os_facts
    end

    context "on #{os}" do
      it { is_expected.to compile.with_all_deps }
      it { is_expected.to create_class('crypto_policy') }
    end
  end
end
