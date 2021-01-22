# @summary Configure the system crypto policy settings
#
# @param ensure
#   The system crypto policy that you wish to enforce
#
#   * Will be checked against `$facts['simplib__crypto_policy_state']['global_policies_available']` for validity
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
  Optional[String] $ensure              = simplib::lookup('simp_options::fips', { 'default_value' => pick($facts['fips_enabled'], false) }) ? { true => 'FIPS', default => undef },
  Boolean          $validate_policy     = true,
  Boolean          $force_fips_override = false,
  Boolean          $manage_installation = true
) {
  simplib::assert_metadata($module_name)

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

  if $_ensure {
    unless $facts["${module_name}__state"] and ($_ensure in $facts["${module_name}__state"]['global_policies_available']) {
      $_available_policies = join($facts['simplib__crypto_policy_state']['global_policies_available'],"', '")

      fail("${module_name}:ensure must be one of '${_available_policies}'")
    }

    $_crypto_config = @("CRYPTO_CONFIG")
      # This file managed by Puppet using ${module_name}
      #
      $_ensure
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
