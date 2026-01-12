# @summary Allows for management of crypto policy subpolicies. The content will not
#   have any validation performed on it, so the user is responsible for ensuring
#   the content is valid.
# @param subpolicy_name
#   The name of the new subpolicy
# @param content
#   The content of the new subpolicy
# @param ensure
#   Whether the subpolicy should (true) exist or not (false / absent)
define crypto_policy::subpolicy (
  Optional[String]                          $content = undef,
  String                                    $subpolicy_name = $name,
  Variant[Boolean,Enum['absent','present']] $ensure = true,
) {
  $_ensure = $ensure ? {
    'absent'  => false,
    'present' => true,
    default   => $ensure,
  }

  if $_ensure {
    if content == undef {
      fail("${module_name}::subpolicy ${subpolicy_name}: 'content' parameter must be provided when 'ensure' is true")
    }

    file { '/usr/share/crypto-policies/policies/modules':
      ensure  => directory,
      mode    => '0755',
      owner   => 'root',
      group   => 'root',
      require => Class["${module_name}::install"],
    }
    file { "/usr/share/crypto-policies/policies/modules/${subpolicy_name}.pmod":
      ensure  => file,
      content => $content,
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      require => File['/usr/share/crypto-policies/policies/modules'],
      before  => Class["${module_name}::update"],
    }
  } else {
    file { "/usr/share/crypto-policies/policies/modules/${subpolicy_name}.pmod":
      ensure => absent,
    }
  }
}
