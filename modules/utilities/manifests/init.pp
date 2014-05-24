class utilities {
  include utilities::node
  include utilities::php
  include utilities::ruby
  include utilities::spotify
  include utilities::vagrant
  include utilities::virtualbox

  package { 'ansible':
    ensure => latest,
  }

  package { 'default-jre':
    ensure => latest,
  }

  package { 'exuberant-ctags':
    ensure => latest,
  }

  package { 'fabric':
    ensure => latest,
  }

  package { 'gimp':
    ensure => latest,
  }

  package { 'libappindicator1':
    ensure => latest,
  }

  package { 'tshark':
    ensure => latest,
  }

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

  package { 'mysql-client-core-5.6':
    ensure => latest,
  }

  package { 'retext':
    ensure  => latest,
  }

  package { 'tree':
    ensure => latest,
  }

  package { 'tmux':
    ensure => latest,
  }

  package { 'vlc':
    ensure => latest,
  }

  package { 'whois':
    ensure => latest,
  }
}
