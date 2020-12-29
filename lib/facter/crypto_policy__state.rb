# frozen_string_literal: true

# Provides the state of the configured crypto policies
#
# @see update-crypto-policy(8)
#
# @return [Hash]
#
# @example Output Hash
#
#   {
#     'global_policy'           => 'POLICY_NAME',
#     'global_policy_applied'   => BOOLEAN,
#     'global_policies_available' => ['POLICY_ONE', 'POLICY_TWO']
#   }
#
Facter.add('crypto_policy__state') do
  confine kernel: 'Linux'

  crypto_policy_cmd = Facter::Util::Resolution.which('update-crypto-policies')
  confine { crypto_policy_cmd }

  setcode do
    system_state = nil

    output = Facter::Core::Execution.execute(%(#{crypto_policy_cmd} --no-reload --show), on_fail: false)
    output = output.strip if output

    if output && !output.empty?
      system_state = {}

      system_state['global_policy'] = output.strip

      output = Facter::Core::Execution.execute(%(#{crypto_policy_cmd} --no-reload --is-applied), on_fail: false)

      system_state['global_policy_applied'] = !Array(output).grep(%r{is applied}).empty? if output

      system_state['global_policies_available'] = Dir.glob('/usr/share/crypto-policies/policies/*.pol').map { |x| File.basename(x, '.pol') }
    end

    system_state
  end
end
