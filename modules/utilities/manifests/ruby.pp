class utilities::ruby {
  package { 'ruby':
    ensure => latest,
  }

  package { 'rbenv':
    ensure => latest,
  }
}
