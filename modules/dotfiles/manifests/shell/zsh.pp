class dotfiles::shell::zsh {
  file { '.zshenv':
    path => '/home/tobias/.zshenv',
    ensure => file,
    source => 'puppet:///modules/dotfiles/shell/zshenv',
    owner  => 'tobias',
    group  => 'tobias',
  }

  file { '.zshrc':
    path => '/home/tobias/.zshrc',
    ensure => file,
    source => 'puppet:///modules/dotfiles/shell/zshrc',
    owner  => 'tobias',
    group  => 'tobias',
  }

  file { '.zsh':
    path => '/home/tobias/.zsh',
    ensure => directory,
    owner  => 'tobias',
    group  => 'tobias',
  }

  file { '.zsh/env':
    path => '/home/tobias/.zsh/env',
    ensure => file,
    source => 'puppet:///modules/dotfiles/shell/zsh/env',
    owner  => 'tobias',
    group  => 'tobias',
  }

  file { '.zsh/interactive':
    path => '/home/tobias/.zsh/interactive',
    ensure => file,
    source => 'puppet:///modules/dotfiles/shell/zsh/interactive',
    owner  => 'tobias',
    group  => 'tobias',
  }

  file { '.zsh/login':
    path => '/home/tobias/.zsh/login',
    ensure => file,
    source => 'puppet:///modules/dotfiles/shell/zsh/login',
    owner  => 'tobias',
    group  => 'tobias',
  }

  file { '.zsh/logout':
    path => '/home/tobias/.zsh/logout',
    ensure => file,
    source => 'puppet:///modules/dotfiles/shell/zsh/logout',
    owner  => 'tobias',
    group  => 'tobias',
  }
}
