# @summary Manage the installation of the crypto policy package(s)
#
# @param packages
#   The list of packages to manage for this capability
#
# @param package_ensure
#   The 'ensure' parameter for `$packages`
#
# @author https://github.com/simp/pupmod-simp-crypto_policy/graphs/contributors
#
class crypto_policy::install (
  Array[String[1]] $packages       = ['crypto-policies'],
  String[1]        $package_ensure = simplib::lookup('simp_options::package_ensure', { 'default_value' => 'installed' })
) {
  assert_private()

  package { $packages: ensure => $package_ensure }
}
