class dotfiles::shell::common {
  file { '.shell':
    path => '/home/tobias/.shell',
    ensure => directory,
    owner  => 'tobias',
    group  => 'tobias',
  }

  file { '.shell/env':
    path => '/home/tobias/.shell/env',
    ensure => file,
    source => 'puppet:///modules/dotfiles/shell/shell/env',
    owner  => 'tobias',
    group  => 'tobias',
  }

  file { '.shell/env_functions':
    path => '/home/tobias/.shell/env_functions',
    ensure => file,
    source => 'puppet:///modules/dotfiles/shell/shell/env_functions',
    owner  => 'tobias',
    group  => 'tobias',
  }

  file { '.shell/interactive':
    path => '/home/tobias/.shell/interactive',
    ensure => file,
    source => 'puppet:///modules/dotfiles/shell/shell/interactive',
    owner  => 'tobias',
    group  => 'tobias',
  }

  file { '.shell/login':
    path => '/home/tobias/.shell/login',
    ensure => file,
    source => 'puppet:///modules/dotfiles/shell/shell/login',
    owner  => 'tobias',
    group  => 'tobias',
  }

  file { '.shell/logout':
    path => '/home/tobias/.shell/logout',
    ensure => file,
    source => 'puppet:///modules/dotfiles/shell/shell/logout',
    owner  => 'tobias',
    group  => 'tobias',
  }
}
