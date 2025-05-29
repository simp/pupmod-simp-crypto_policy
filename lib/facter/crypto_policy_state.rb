# frozen_string_literal: true

# @summary Provides the state of the configured crypto policies
#
# @see update-crypto-policy(8)
#
# @return [Hash]
#
# @example Output Hash
#
#   {
#     'global_policy'             => 'POLICY_NAME',
#     'global_policy_applied'     => BOOLEAN,
#     'global_policies_available' => ['POLICY_ONE', 'POLICY_TWO']
#     'sub_policies_available'    => ['SUB_POLICY_ONE', 'SUB_POLICY_TWO']
#   }
#
Facter.add('crypto_policy_state') do
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

      # This is everything past EL8.0
      global_policies = Dir.glob(['/usr/share/crypto-policies/policies/*.pol', '/etc/crypto-policies/policies/*.pol'])

      # Need available subpolicies to support users setting them
      sub_policies = Dir.glob(['/usr/share/crypto-policies/policies/modules/*.pmod', '/etc/crypto-policies/policies/modules/*.pmod'])

      # Fallback for 8.0
      if global_policies.empty?
        global_policies = Dir.glob('/usr/share/crypto-policies/*').select { |x| File.directory?(x) }
      end

      system_state['global_policies_available'] = global_policies.map { |x| File.basename(x, '.pol') }.uniq
      system_state['sub_policies_available'] = sub_policies.map {|x| File.basename(x, '.pmod') }.uniq
    end

    system_state
  end
end
