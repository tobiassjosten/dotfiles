class dotfiles::shell::bash {
  file { '.bashrc':
    path => '/home/tobias/.bashrc',
    ensure => file,
    source => 'puppet:///modules/dotfiles/shell/bashrc',
    owner  => 'tobias',
    group  => 'tobias',
  }

  file { '.bash_logout':
    path => '/home/tobias/.bash_logout',
    ensure => file,
    source => 'puppet:///modules/dotfiles/shell/bash_logout',
    owner  => 'tobias',
    group  => 'tobias',
  }

  file { '.bash_profile':
    path => '/home/tobias/.bash_profile',
    ensure => file,
    source => 'puppet:///modules/dotfiles/shell/bash_profile',
    owner  => 'tobias',
    group  => 'tobias',
  }

  file { '.bash':
    path => '/home/tobias/.bash',
    ensure => directory,
    owner  => 'tobias',
    group  => 'tobias',
  }

  file { '.bash/env':
    path => '/home/tobias/.bash/env',
    ensure => file,
    source => 'puppet:///modules/dotfiles/shell/bash/env',
    owner  => 'tobias',
    group  => 'tobias',
  }

  file { '.bash/interactive':
    path => '/home/tobias/.bash/interactive',
    ensure => file,
    source => 'puppet:///modules/dotfiles/shell/bash/interactive',
    owner  => 'tobias',
    group  => 'tobias',
  }

  file { '.bash/login':
    path => '/home/tobias/.bash/login',
    ensure => file,
    source => 'puppet:///modules/dotfiles/shell/bash/login',
    owner  => 'tobias',
    group  => 'tobias',
  }

  file { '.bash/logout':
    path => '/home/tobias/.bash/logout',
    ensure => file,
    source => 'puppet:///modules/dotfiles/shell/bash/logout',
    owner  => 'tobias',
    group  => 'tobias',
  }
}
