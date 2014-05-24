class utilities::php {
  package { 'php5-cli':
    ensure => latest,
  }

  package { 'php5-dev':
    ensure => latest,
  }

  package { 'php5-curl':
    ensure => latest,
  }

  package { 'php5-intl':
    ensure => latest,
  }

  package { 'php5-memcached':
    ensure => latest,
  }

  php::pecl::module { 'stats':
    service_autorestart => false,
    use_package         => 'no',
  }

  file { 'stats.ini':
    path    => '/etc/php5/mods-available/stats.ini',
    source  => 'puppet:///modules/utilities/php/stats.ini',
    require => Php::Pecl::Module['stats'],
  }

  exec { 'php5enmod stats':
    require => File['stats.ini'],
  }
}
