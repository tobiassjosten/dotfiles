class utilities::golang {
  apt::ppa { 'ppa:duh/golang': }

  package { 'golang':
    ensure  => latest,
    require => Apt::Ppa['ppa:duh/golang']
  }
}
