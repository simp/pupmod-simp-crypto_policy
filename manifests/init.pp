# @summary Configure the system crypto policy settings
#
# @param ensure
#   The system crypto policy and subpolicies that you wish to enforce
#
#   * Will be checked against `$facts['crypto_policy_state']['global_policies_available']`
#     and `$facts['crypto_policy_state']['sub_policies_available']`for validity
#
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
  Optional[String] $ensure              = pick($facts['fips_enabled'], false) ? { true => 'FIPS', default => undef },
  Boolean          $validate_policy     = true,
  Boolean          $force_fips_override = false,
  Boolean          $manage_installation = true
) {
  include crypto_policy::update

  if $manage_installation {
    include crypto_policy::install

    Class["${module_name}::install"] -> Class["${module_name}::update"]
  }

  # FIPS systems should always switch to FIPS mode
  if $facts['fips_enabled'] {
    if $force_fips_override {
      $_ensure = $ensure
    }
    else {
      $_ensure = 'FIPS'
    }
  }
  else {
    $_ensure = $ensure
  }

  $global_policies_available = $facts.dig('crypto_policy_state', 'global_policies_available')
  $sub_policies_available = $facts.dig('crypto_policy_state', 'sub_policies_available')

  if $_ensure and $global_policies_available and $sub_policies_available {
    $_policy_components = $_ensure.split(':')
    $_global_policy = $_policy_components[0]
    $_sub_policies = $_policy_components.delete($_policy_components[0])
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

    $_crypto_config = @("CRYPTO_CONFIG")
      # This file managed by Puppet using ${module_name}
      #
      ${_ensure}
      | CRYPTO_CONFIG

    file { '/etc/crypto-policies/config':
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => $_crypto_config,
      notify  => Class["${module_name}::update"]
    }
  }
}
