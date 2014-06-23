class utilities::docker {
  package { 'docker.io':
    ensure => latest,
  }

  file { '/usr/local/bin/docker':
    ensure  => 'link',
    target  => '/usr/bin/docker.io',
    require => Package['docker.io'],
  }
}
