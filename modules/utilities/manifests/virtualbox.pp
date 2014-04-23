#VBoxManage openmedium dvd /home/vmuser/VBoxGuestAdditions.iso
#VBoxManage storageattach "Ubuntu Server" --storagectl "IDE Controller"  --port 0 --device 1 --type dvddrive --medium  /home/vmuser/VBoxGuestAdditions.iso

class utilities::virtualbox {
  package { 'virtualbox': ensure => latest }

  # Needed for NFS sharing.
  package { 'nfs-kernel-server': ensure => installed }

  # Needed for VirtualBox GuestAdditions.
  package { 'linux-headers-generic': ensure => installed }
  package { 'build-essential': ensure       => installed }
  package { 'dkms': ensure                  => installed }

  package { 'virtualbox-guest-additions-iso':
    ensure  => latest,
    require => [ Package['linux-headers-generic'], Package['build-essential'], Package['dkms'] ],
  }

  package { 'virtualbox-guest-utils':
    ensure  => latest,
    require => [ Package['linux-headers-generic'], Package['build-essential'], Package['dkms'] ],
  }

  package { 'virtualbox-guest-dkms':
    ensure  => latest,
    require => [ Package['linux-headers-generic'], Package['build-essential'], Package['dkms'] ],
  }

  package { 'virtualbox-guest-x11':
    ensure  => latest,
    require => [ Package['linux-headers-generic'], Package['build-essential'], Package['dkms'] ],
  }
}
