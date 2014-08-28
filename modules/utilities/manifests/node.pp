class utilities::node {
  package { 'nodejs':
    ensure => latest,
  }

  package { 'npm':
    ensure => latest,
  }

  file { '/usr/local/bin/node':
    ensure  => 'link',
    target  => '/usr/bin/nodejs',
    require => Package['nodejs'],
  }
}
