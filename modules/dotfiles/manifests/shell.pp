class dotfiles::shell {
  include dotfiles::shell::common
  include dotfiles::shell::bash
  include dotfiles::shell::sh
  include dotfiles::shell::zsh

  file { '.profile':
    path => '/home/tobias/.profile',
    ensure => file,
    source => 'puppet:///modules/dotfiles/shell/profile',
    owner  => 'tobias',
    group  => 'tobias',
  }
}
