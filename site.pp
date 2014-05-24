Exec { path => [ '/bin/', '/sbin/' , '/usr/bin/', '/usr/sbin/' ] }

include apt
include composer
include php

include utilities
include dotfiles
include dropbox
