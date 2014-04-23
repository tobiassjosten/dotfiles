class utilities::spotify {
  apt::source { 'spotify':
    location    => 'http://repository.spotify.com',
    release     => 'stable',
    repos       => 'non-free',
    include_src => false,
  }

  apt::key { 'spotify':
    key        => '94558F59',
    key_server => 'keyserver.ubuntu.com',
  }

  package { 'spotify-client':
    ensure => latest,
    require  => [ Apt::Source['spotify'], Apt::Key['spotify'] ]
  }
}
