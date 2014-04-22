class utilities::php {
  package { 'php5':
    ensure => latest,
  }

  package { 'php5-cli':
    ensure => latest,
  }

  package { 'php5-curl':
    ensure => latest,
  }

  package { 'php5-intl':
    ensure => latest,
  }
}
