class utilities {
  include utilities::docker
  include utilities::elasticsearch
  include utilities::golang
  include utilities::node
  include utilities::php
  include utilities::ruby
  include utilities::spotify
  include utilities::vagrant
  include utilities::virtualbox

  package { 'ansible':
    ensure => latest,
  }

  package { 'apache2':
    ensure => latest,
  }

  package { 'autossh':
    ensure => latest,
  }

  package { 'beanstalkd':
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

  package { 'ghc':
    ensure => latest,
  }

  package { 'gimp':
    ensure => latest,
  }

  package { 'libappindicator1':
    ensure => latest,
  }

  package { 'libreadline-dev':
    ensure => latest,
  }

  package { 'mercurial':
    ensure => latest,
  }

  package { 'mysql-server-5.6':
    ensure => latest,
  }

  package { 'ngrok-client':
    ensure => latest,
  }

  package { 'postgresql':
    ensure => latest,
  }

  package { 'postgresql-client-common':
    ensure => latest,
  }

  package { 'postgresql-contrib':
    ensure => latest,
  }

  package { 'sqlite3':
    ensure => latest,
  }

  package { 'tf5':
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

  package { 'libapache2-mod-php5':
    ensure => latest,
  }

  package { 'mysql-client-core-5.6':
    ensure => latest,
  }

  package { 'retext':
    ensure  => latest,
  }

  package { 'tig':
    ensure => latest,
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
