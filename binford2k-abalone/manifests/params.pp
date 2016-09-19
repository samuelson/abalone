class abalone::params {
  $port      = '9090'
  $bind      = '0.0.0.0'
  $method    = 'login'
  $logfile   = '/var/log/abalone'
  $ssh_host  = undef
  $ssh_cert  = undef
  $ssh_port  = undef
  $ssh_user  = undef
  $command   = undef
  $params    = undef

  case $::operatingsystem {
    'Ubuntu': {
      if versioncmp($::operatingsystemmajrelease, '14.10') > 0 {
        $server_service_provider = 'systemd'
      } else {
        $server_service_provider = 'upstart'
      }
    }
		'RedHat','CentOS': {
    	$server_service_provider = 'systemd'
		}
    default: {
      $server_service_provider = undef
    }
  }
}
