class dotfiles::shell::sh {
  file { '.sh':
    path => '/home/tobias/.sh',
    ensure => directory,
    owner  => 'tobias',
    group  => 'tobias',
  }

  file { '.sh/env':
    path => '/home/tobias/.sh/env',
    ensure => file,
    source => 'puppet:///modules/dotfiles/shell/sh/env',
    owner  => 'tobias',
    group  => 'tobias',
  }

  file { '.sh/interactive':
    path => '/home/tobias/.sh/interactive',
    ensure => file,
    source => 'puppet:///modules/dotfiles/shell/sh/interactive',
    owner  => 'tobias',
    group  => 'tobias',
  }

  file { '.sh/login':
    path => '/home/tobias/.sh/login',
    ensure => file,
    source => 'puppet:///modules/dotfiles/shell/sh/login',
    owner  => 'tobias',
    group  => 'tobias',
  }
}
