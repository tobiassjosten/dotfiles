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

  package { 'php5-mysql':
    ensure => latest,
  }

  package { 'php5-sqlite':
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

  php::pecl::module { 'mongo':
    service_autorestart => false,
    use_package         => 'no',
  }

  file { 'mongo.ini':
    path    => '/etc/php5/mods-available/mongo.ini',
    source  => 'puppet:///modules/utilities/php/mongo.ini',
    require => Php::Pecl::Module['mongo'],
  }

  exec { 'php5enmod mongo':
    require => File['mongo.ini'],
  }

  vcsrepo { 'boris-loader':
    path     => '/home/tobias/.boris-loader',
    ensure   => present,
    provider => git,
    source   => 'git://github.com/tobiassjosten/boris-loader.git',
  }

  file { '.borisrc':
    path   => '/home/tobias/.borisrc',
    source => 'puppet:///modules/utilities/php/borisrc',
  }
}
