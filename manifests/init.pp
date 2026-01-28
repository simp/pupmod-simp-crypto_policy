# @summary Configure the system crypto policy settings
#
# @param ensure
#   The global system crypto policy to enforce (DEFAULT, FIPS, etc). You may specify subpolicies here,
#   however, it is recommended to use the `subpolicies` parameter for clarity or specify your own
#   in `custom_subpolicies`.
#
#   * Will be checked against `$facts['crypto_policy_state']['global_policies_available']`
#     and `$facts['crypto_policy_state']['sub_policies_available']`for validity
#
# @param subpolicies
#   An array of subpolicy names to apply in addition to the main policy specified
#   in the `ensure` parameter. These will be in addition to any custom_subpolicies specified.
#
# @param custom_subpolicies
#   A hash of custom subpolicy names to content that will be created in
#   `/usr/share/crypto-policies/policies/modules/` prior to applying the
#   selected policy. This allows users to create and apply their own
#   subpolicies.
# @example Using custom subpolicies in hiera
#   crypto_policy::custom_subpolicies:
#     MY_CUSTOM_SUBPOLICY:
#       content: |
#         # This is my custom subpolicy
#         algorithm = MY_CUSTOM_ALGO
#         key_size = 4096
#       ensure: present
# @param validate_policy
#   Disables validation of the `$ensure` parameter prior to application
#
# @param force_fips_override
#   Set this to indicate that you wish to force the system into the mode
#   specified by `$ensure` even if the system is in FIPS mode
#
#   * WARNING: This may break all crypto on your system
#
# @param manage_installation
#   Enables management of the system installation via the `crypto_policy::install` class
#
# @author https://github.com/simp/pupmod-simp-crypto_policy/graphs/contributors
#
class crypto_policy (
  String        $ensure              = $facts['fips_enabled'] ? {
    true    => 'FIPS',
    default => ($facts.dig('crypto_policy_state','global_policy') ? {
        undef   => 'DEFAULT',
        default => $facts.dig('crypto_policy_state','global_policy'),
    })
  },
  Array[String] $subpolicies         = [],
  Hash          $custom_subpolicies  = {},
  Boolean       $validate_policy     = true,
  Boolean       $force_fips_override = false,
  Boolean       $manage_installation = true
) {
  if $manage_installation {
    include crypto_policy::install
  }

  # Ensure the directory we will be putting subpolicies into exists
  unless $custom_subpolicies.empty {
    file { '/usr/share/crypto-policies/policies/modules':
      ensure => directory,
      mode   => '0755',
      owner  => 'root',
      group  => 'root',
    }
  }

  $_policy_components = $ensure.split(':')
  $_global_policy = $_policy_components[0]
  # Remove any custom_subpolicy entries we don't want to enforce
  $_enforced_sub_policies = $custom_subpolicies.filter |$subpolicy_name, $subpolicy_params| {
    $ensure_val = $subpolicy_params.get('ensure', true)
    $ensure_val != 'absent' and $ensure_val != false
  }

  # Collect all sub policies specified in the ensure parameter plus those in the subpolicies parameter and managed in custom_subpolicies
  $_sub_policies = unique($_policy_components.delete($_policy_components[0]) + $subpolicies + $_enforced_sub_policies.keys)

  $_collected_subpolicies = $_sub_policies ? {
    []      => '',
    default => ":${_sub_policies.join(':')}",
  }

  # FIPS systems should always switch to FIPS mode
  if $facts['fips_enabled'] {
    if $force_fips_override {
      $_ensure = "${_global_policy}${_collected_subpolicies}"
    }
    else {
      $_ensure = 'FIPS'
    }
  }
  else {
    $_ensure = "${_global_policy}${_collected_subpolicies}"
  }

  $global_policies_available = $facts.dig('crypto_policy_state', 'global_policies_available')
  # Add any custom subpolicies to the available sub policies in case they haven't been picked up by facter yet
  $existing_sub_policies = $facts.dig('crypto_policy_state', 'sub_policies_available')

  if $existing_sub_policies == '' or $existing_sub_policies == undef {
    $existing_sub_policies_clean = []
  } else {
    $existing_sub_policies_clean = $existing_sub_policies
  }

  $sub_policies_available = unique(
    $existing_sub_policies_clean + $custom_subpolicies.keys
  )

  if $_ensure and $global_policies_available and $sub_policies_available {
    unless $_global_policy in $global_policies_available {
      $_available_policies = join($global_policies_available,"', '")

      if $ensure == $_ensure {
        $ensure_message = $ensure
      } else {
        $ensure_message = "${ensure}, overridden to ${_ensure}"
      }

      fail("${module_name}::ensure (${ensure_message}) must be one of '${_available_policies}'")
    }

    unless $_sub_policies.empty or ($_sub_policies - $sub_policies_available).empty {
      $_available_sub_policies = join($sub_policies_available, "', '")
      # Any sub policies not available to use will be displayed back to the user
      $_unknown_sub_policies = join(($_sub_policies - $sub_policies_available), "', '")
      fail("${module_name}::ensure unknown sub_policies (${$_unknown_sub_policies}) must be one of '${_available_sub_policies}'")
    }

    class { 'crypto_policy::update':
      command => "/usr/bin/update-crypto-policies --set ${_ensure}",
    }

    $custom_subpolicies.each |$subpolicy_name, $subpolicy_params| {
      crypto_policy::subpolicy { $subpolicy_name:
        ensure  => $subpolicy_params.get('ensure', true),
        content => $subpolicy_params['content'],
        before  => Class["${module_name}::update"],
      }
    }

    if $manage_installation {
      Class["${module_name}::install"] -> Class["${module_name}::update"]
    }

    # We Removed the "Managed by Puppet" content to accomodate el 10 os flavors
    $_crypto_config = @("CRYPTO_CONFIG")
      ${_ensure}
      | CRYPTO_CONFIG

    # This code will now fire off an 'update-crypto-policies --set $crypto-policy::_enable' if the file has changed
    # There is a bug in the 'update-crytpo-policies' binary in el10 that causes it to not apply the policy specified
    # in /etc/crypto-policies/config, so you are forced to use the --set command to apply it appropriately.
    file { '/etc/crypto-policies/config':
      owner                   => 'root',
      group                   => 'root',
      mode                    => '0644',
      # The update-crypto-policy command will reset the context every run, causing flapping without this parameter
      selinux_ignore_defaults => true,
      content                 => $_crypto_config,
      notify                  => Class["${module_name}::update"],
    }
  }
}
