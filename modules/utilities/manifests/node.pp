class utilities::node {
  package { 'nodejs':
    ensure => latest,
  }

  package { 'npm':
    ensure => latest,
  }
}
