class dotfiles {
  include dotfiles::shell
  include dotfiles::vim

  vcsrepo { '/home/tobias/.oh-my-zsh':
    ensure => present,
    provider => git,
    source => 'git://github.com/robbyrussell/oh-my-zsh.git',
    user => 'tobias'
  }

  file { '/home/tobias/.gitconfig':
    ensure => file,
    source => 'puppet:///modules/dotfiles/gitconfig',
    owner  => 'tobias',
    group  => 'tobias',
  }

  file { '/home/tobias/.htoprc':
    ensure => file,
    source => 'puppet:///modules/dotfiles/htoprc',
    owner  => 'tobias',
    group  => 'tobias',
  }

  file { '/home/tobias/.ssh':
    ensure => link,
    target => '/home/tobias/Dropbox/ssh',
    force  => true,
  }

  file { '.tmux.conf':
    path   => '/home/tobias/.tmux.conf',
    ensure => file,
    source => 'puppet:///modules/dotfiles/tmux.conf',
    owner  => 'tobias',
    group  => 'tobias',
  }

  file { '.xmodmaprc':
    path   => '/home/tobias/.xmodmaprc',
    ensure => file,
    source => 'puppet:///modules/dotfiles/xmodmaprc',
    owner  => 'tobias',
    group  => 'tobias',
  }
}
