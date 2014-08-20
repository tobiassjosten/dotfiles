class utilities::elasticsearch {
  apt::source { 'elasticsearch':
    location    => 'http://packages.elasticsearch.org/elasticsearch/1.3/debian',
    release     => 'stable',
    repos       => 'main',
    include_src => false,
    require     => Apt::Key['elasticsearch'],
  }

  apt::key { 'elasticsearch':
    key        => 'D27D666CD88E42B4',
    key_source => 'http://packages.elasticsearch.org/GPG-KEY-elasticsearch',
  }

  package { 'elasticsearch':
    ensure  => latest,
    require => Apt::Source['spotify'],
  }
}
