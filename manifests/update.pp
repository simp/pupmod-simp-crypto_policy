# @summary Helper class for triggering a run of update-crypto-policies
#
# This is deliberately not kept private in case other classes need to trigger
# an update but do not wish to include full management
#
# @param command
#   The path to the command to be executed
#
# @author https://github.com/simp/pupmod-simp-crypto_policy/graphs/contributors
#
class crypto_policy::update (
  Stdlib::Absolutepath $command = '/usr/bin/update-crypto-policies'
) {
  if $facts['crypto_policy_state'] {
    exec { 'update global crypto policy':
      command     => $command,
      refreshonly => true
    }
  }
  else {
    warning("${module_name}: crypto_policy_state fact not found, updating not enabled")
  }
}
