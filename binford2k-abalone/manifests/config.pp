class abalone::config {
  # pull these into local scope so we can use them in templates
  $port                    = $abalone::port
  $bind                    = $abalone::bind
  $method                  = $abalone::method
  $logfile                 = $abalone::logfile
  $ssh_host                = $abalone::ssh_host
  $ssh_cert                = $abalone::ssh_cert
  $ssh_port                = $abalone::ssh_port
  $ssh_user                = $abalone::ssh_user
  $command                 = $abalone::command
  $params                  = $abalone::params
  $server_service_provider = $abalone::params::server_service_provider


  File {
    owner  => 'root',
    group  => 'root',
    mode   => '0644',
  }

  file { $logfile:
    ensure => file,
  }

  file { '/etc/abalone':
    ensure  => directory,
  }

  file { '/etc/abalone/config.yaml':
    ensure  => file,
    content => template('abalone/config.yaml.erb'),
  }

  case $::server_service_provider {
    'systemd': {
      file { "/usr/lib/systemd/system/abalone.service":
        ensure  => file,
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        content => file('abalone/abalone.service'),
        before  => Service['abalone'],
      }
    }
    'upstart': {
      file { "/etc/init/abalone.conf":
        ensure  => file,
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        content => file('abalone/abalone.conf'),
        before  => Service['abalone'],
      }
    }
    default: {
      fail("Unsupported service provider ${::server_service_provider}. ${::operatingsystem} is not supported.")
    }

  }
}
