# @summary Helper class for triggering a run of update-crypto-policies
#
# This is deliberately not kept private in case other classes need to trigger
# an update but do not wish to include full management
#
# The update runs when this class is refreshed. It also runs without a refresh
# when the `crypto_policy_state` fact reports that the configured policy is not
# applied, so an update that failed or was skipped in an earlier run (for
# example, because `crypto_policy::install` failed after
# `/etc/crypto-policies/config` had been written) is retried in a later run.
#
# @param command
#   The path to the command to be executed
#
# @author https://github.com/simp/pupmod-simp-crypto_policy/graphs/contributors
#
class crypto_policy::update (
  Stdlib::Absolutepath $command = "/usr/bin/update-crypto-policies --set ${crypto_policy::_ensure}", # lint:ignore:variable_scope
) {
  if $facts['crypto_policy_state'] and $crypto_policy::_ensure {
    # `global_policy_applied` is false when /etc/crypto-policies/config is
    # newer than, or differs from, the policy the back-ends were last
    # generated from. An unknown state keeps the refresh-only behavior.
    $_refreshonly = $facts['crypto_policy_state']['global_policy_applied'] != false

    exec { 'update global crypto policy':
      command     => $command,
      refreshonly => $_refreshonly,
    }
  }
  else {
    warning("${module_name}: crypto_policy_state fact not found, updating not enabled")
  }
}
