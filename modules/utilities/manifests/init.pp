class utilities {
  include utilities::php
  include utilities::ruby

  package { 'zsh':
    ensure => latest,
  }

  exec { 'switch to zsh':
    command     => 'chsh -s $(which zsh) tobias',
    subscribe   => Package['zsh'],
    refreshonly => true,
  }

  package { 'vim-nox':
    ensure => latest,
  }

  package { 'htop':
    ensure => latest,
  }

  package { 'tree':
    ensure => latest,
  }

  package { 'tmux':
    ensure => latest,
  }
}
