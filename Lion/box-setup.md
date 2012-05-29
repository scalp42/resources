Download Xcode 3/4 Installer from App Store and run the installer from the applications directory.

## Homebrew

``
  /usr/bin/ruby -e "$(curl -fsSL https://raw.github.com/gist/323731)"
``

## Git

``
  brew install git
``

## Ruby and Rails

``
  bash < <(curl -sk https://rvm.beginrescueend.com/install/rvm)
  rvm install ruby-1.9.2-p290
  rvm 1.9.2 --default
  gem install rails
``

## Node.js and coffee-script

``
  brew install node
  curl http://npmjs.org/install.sh | sh
  npm install -g coffee-script
``

## PHP
For more infromation about homebrew php installer check https://github.com/mxcl/homebrew/tree/master/Library/Formula or google for more information

``
  brew tap josegonzalez/php
``
``
  brew install josegonzalez/php/php54 --with-fpm --with-mysql --with-intl --with-readline
``

## Other

``
  brew install mongodb
``
