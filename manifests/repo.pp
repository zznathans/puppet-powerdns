# powerdns::repo
class powerdns::repo inherits powerdns {
  # The repositories of PowerDNS use a version such as '40' for version 4.0
  # and 41 for version 4.1.
  $authoritative_short_version = regsubst($powerdns::authoritative_version, /^(\d)\.(\d)$/, '\\1\\2', 'G')
  $recursor_short_version = regsubst($powerdns::recursor_version, /^(\d)\.(\d)$/, '\\1\\2', 'G')

  case $facts['os']['family'] {
    'RedHat': {
      unless $powerdns::custom_epel {
        include epel
      }

      Yumrepo['powerdns'] -> Package <| title == $powerdns::params::authoritative_package |>
      Yumrepo['powerdns-recursor'] -> Package <| title == $powerdns::params::recursor_package |>

      if versioncmp($facts['os']['release']['major'], '7') <= 0 {
        stdlib::ensure_packages('yum-plugin-priorities')

        Package['yum-plugin-priorities']
        -> Yumrepo['powerdns']
      }

      if versioncmp($facts['os']['release']['major'], '8') >= 0 {
        if ($facts['os']['name'] == 'Rocky') {
          $mirrorlist = "https://mirrors.rockylinux.org/mirrorlist?arch=\$basearch&repo=PowerTools-\$releasever"
          $gpgkey = 'file:///etc/pki/rpm-gpg/RPM-GPG-KEY-rockyofficial'
        } else {
          $mirrorlist = "http://mirrorlist.centos.org/?release=\$releasever&arch=\$basearch&repo=PowerTools&infra=\$infra"
          $gpgkey = 'file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial'
        }

        if ($facts['os']['release']['major'] < 8) {
          yumrepo { 'powertools':
            ensure     => 'present',
            descr      => 'PowerTools',
            mirrorlist => $mirrorlist,
            enabled    => 'true',
            gpgkey     => $gpgkey,
            gpgcheck   => 'true',
          }
        } else {
          # Install CRB instead of PowerTools
          package { 'dnf-plugins-core':
            ensure => installed,
          }

          exec { 'enable-crb-repo':
            command => '/usr/bin/dnf config-manager --set-enabled crb',
            path    => ['/bin', '/usr/bin'],
            unless  => '/usr/bin/dnf repolist enabled | grep -q crb',
            require => Package['dnf-plugins-core'],
          }
        }
      }

      yumrepo { 'powerdns':
        name        => 'powerdns',
        descr       => "PowerDNS repository for PowerDNS Authoritative - version ${powerdns::authoritative_version}",
        baseurl     => "http://repo.powerdns.com/centos/\$basearch/\$releasever/auth-${authoritative_short_version}",
        gpgkey      => 'https://repo.powerdns.com/FD380FBB-pub.asc',
        gpgcheck    => 1,
        enabled     => 1,
        priority    => 90,
        includepkgs => 'pdns*',
      }

      yumrepo { 'powerdns-recursor':
        name        => 'powerdns-recursor',
        descr       => "PowerDNS repository for PowerDNS Recursor - version ${powerdns::recursor_version}",
        baseurl     => "http://repo.powerdns.com/centos/\$basearch/\$releasever/rec-${recursor_short_version}",
        gpgkey      => 'https://repo.powerdns.com/FD380FBB-pub.asc',
        gpgcheck    => 1,
        enabled     => 1,
        priority    => 90,
        includepkgs => 'pdns*',
      }
    }

    'Debian': {
      include apt

      $os = downcase($facts['os']['name'])

      apt::key { 'powerdns':
        ensure => present,
        id     => '9FAAA5577E8FCF62093D036C1B0C6205FD380FBB',
        source => 'https://repo.powerdns.com/FD380FBB-pub.asc',
      }

      apt::source { 'powerdns':
        ensure       => present,
        location     => "http://repo.powerdns.com/${os}",
        repos        => 'main',
        release      => "${facts['os']['distro']['codename']}-auth-${authoritative_short_version}",
        architecture => 'amd64',
        require      => Apt::Key['powerdns'],
      }

      apt::source { 'powerdns-recursor':
        ensure       => present,
        location     => "http://repo.powerdns.com/${os}",
        repos        => 'main',
        release      => "${facts['os']['distro']['codename']}-rec-${recursor_short_version}",
        architecture => 'amd64',
        require      => Apt::Source['powerdns'],
      }

      apt::pin { 'powerdns':
        priority => 600,
        packages => 'pdns-*',
        origin   => 'repo.powerdns.com',
        require  => Apt::Source['powerdns-recursor'],
      }

      Apt::Pin['powerdns'] -> Package <| title == $powerdns::params::authoritative_package |>
      Apt::Pin['powerdns'] -> Package <| title == $powerdns::params::recursor_package |>
    }

    'FreeBSD','Archlinux': {
      # Use the official pkg repository
    }

    default: {
      fail("${facts['os']['family']} is not supported yet.")
    }
  }
}
