# powerdns::authoritative
class powerdns::authoritative (
  $package_ensure = $powerdns::params::default_package_ensure,
  Optional[Array[String]] $install_packages = $powerdns::install_packages,
) inherits powerdns {
  # install the powerdns package
  package { $powerdns::params::authoritative_package:
    ensure => $package_ensure,
  }

  stdlib::ensure_packages($install_packages)

  # install the right backend
  case $powerdns::backend {
    'mysql': {
      include powerdns::backends::mysql
    }
    'bind': {
      include powerdns::backends::bind
    }
    'postgresql': {
      include powerdns::backends::postgresql
    }
    'ldap': {
      include powerdns::backends::ldap
    }
    'sqlite': {
      include powerdns::backends::sqlite
    }
    default: {
      fail("${powerdns::backend} is not supported. We only support 'mysql', 'bind', 'postgresql', 'ldap' and 'sqlite' at the moment.")
    }
  }

  if $facts['os']['family'] == 'RedHat' {
    file { '/etc/pdns/pdns.conf':
      ensure  => file,
      owner   => 'pdns',
      group   => 'pdns',
      require => Package[$powerdns::params::authoritative_package],
    }
  }

  service { 'pdns':
    ensure  => running,
    name    => $powerdns::params::authoritative_service,
    enable  => true,
    require => Package[$powerdns::params::authoritative_package],
  }
}
