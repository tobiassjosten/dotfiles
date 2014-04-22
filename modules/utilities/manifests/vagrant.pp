class utilities::vagrant {
  wget::fetch { 'vagrant.deb':
    source      => 'https://dl.bintray.com/mitchellh/vagrant/vagrant_1.5.4_x86_64.deb',
    destination => '/tmp/vagrant.deb',
    timeout     => 0,
    verbose     => false,
  }

  package { 'vagrant.deb':
    provider => dpkg,
    ensure   => latest,
    source   => '/tmp/vagrant.deb',
    require  => Wget::Fetch['vagrant.deb']
  }
}
