class utilities::vagrant {
  wget::fetch { 'vagrant.deb':
    source      => 'https://dl.bintray.com/mitchellh/vagrant/vagrant_1.6.3_x86_64.deb',
    destination => '/tmp/vagrant-1.6.3.deb',
    timeout     => 0,
    verbose     => false,
  }

  package { 'vagrant.deb':
    provider => dpkg,
    ensure   => latest,
    source   => '/tmp/vagrant-1.6.3.deb',
    require  => Wget::Fetch['vagrant.deb']
  }
}
