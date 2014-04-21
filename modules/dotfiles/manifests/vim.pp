class dotfiles::vim {
  file { '/home/tobias/.vimrc':
    ensure => file,
    source => 'puppet:///modules/dotfiles/vimrc',
    owner  => 'tobias',
    group  => 'tobias',
  }

  file { '/home/tobias/.vim':
    ensure => directory,
    owner  => 'tobias',
    group  => 'tobias',
  }

  file { '/home/tobias/.vim/bundle':
    ensure => directory,
    owner  => 'tobias',
    group  => 'tobias',
  }

  vcsrepo { '/home/tobias/.vim/bundle/vundle':
    ensure   => present,
    provider => git,
    source   => 'git://github.com/gmarik/vundle.git',
    user     => 'tobias',
  }

  #exec { 'update vim plugins':
  #  command     => 'vim +PluginInstall +qall',
  #  subscribe   => File['/home/tobias/.vimrc'],
  #  refreshonly => true,
  #  user        => 'tobias',
  #}

  file { '/home/tobias/.vim/ultisnips':
    ensure => directory,
    owner  => 'tobias',
    group  => 'tobias',
  }

  file { '/home/tobias/.vim/ultisnips/php.snippets':
    ensure => file,
    source => 'puppet:///modules/dotfiles/vim/ultisnips/php.snippets',
    owner  => 'tobias',
    group  => 'tobias',
  }

  package { 'vim-ctrlp python-dev':
    name   => 'python-dev',
    ensure => installed,
  }

  #exec { 'install ctrlp':
  #  command     => 'install_linux.sh',
  #  path        => '/home/tobias/.vim/bundle/ctrlp-cmatcher',
  #  subscribe   => Package['vim-ctrlp python-dev'],
  #  refreshonly => true,
  #  user        => 'tobias',
  #}
}
