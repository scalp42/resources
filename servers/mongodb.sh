#! /bin/bash

##
# Installation with auto tuning of filedescriptors with:
# - Git
# - Imagemagick
# - Monit
# - Nginx
# - Node, NPM and CoffeeScript
# - Ruby
# - Bundler
##

##
# Copyright (c) 2011 Robert Brewitz
# 
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
# 
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
##

if [ ! -n "$PREFIX" ]; then
  PREFIX="/usr/local"
fi

if [ ! -n "$SRC_PATH" ]; then
  SRC_PATH="$PREFIX/src"
fi

if [ ! -n "$MONGODB_VERSION" ]; then
  MONGODB_VERSION="r2.0.1"
fi

function banner_echo {
  echo ""
  echo "##"
  echo "# $1"
  echo "##"
  echo ""
  sleep 3
}

##
# System settings and updates
##
banner_echo "Updating locales ..."
locale-gen
LC_CTYPE="en_GB.UTF-8"
LC_ALL="en_GB.UTF-8"
LANGUAGE="en_GB.UTF-8"
LANG="en_GB.UTF-8"

banner_echo "Updating sources and upgrading system ..."
cat > /etc/apt/sources.list << EOF
## main & restricted repositories
deb http://us.archive.ubuntu.com/ubuntu/ lucid main restricted
deb-src http://us.archive.ubuntu.com/ubuntu/ lucid main restricted

deb http://security.ubuntu.com/ubuntu lucid-security main restricted
deb-src http://security.ubuntu.com/ubuntu lucid-security main restricted

## universe repositories
deb http://us.archive.ubuntu.com/ubuntu/ lucid universe
deb-src http://us.archive.ubuntu.com/ubuntu/ lucid universe
deb http://us.archive.ubuntu.com/ubuntu/ lucid-updates universe
deb-src http://us.archive.ubuntu.com/ubuntu/ lucid-updates universe

deb http://security.ubuntu.com/ubuntu lucid-security universe
deb-src http://security.ubuntu.com/ubuntu lucid-security universe
EOF

apt-get -y update
apt-get -y upgrade

##
# Dependencies
##
banner_echo "Installing MongoDB dependencies ..."
aptitude -y build-dep firefox
aptitude -y install mercurial libasound2-dev libcurl4-openssl-dev libnotify-dev libxt-dev libiw-dev mesa-common-dev autoconf2.13 yasm
aptitude -y install tcsh git-core scons g++ libpcre++-dev libboost-dev libreadline-dev xulrunner-1.9.2-dev install libboost-program-options-dev libboost-thread-dev libboost-filesystem-dev libboost-date-time-dev

##
# Filedescriptors
##
banner_echo "Tuning filedescriptors ..."
cat > /etc/security/limits.conf << EOF
* soft nofile $system_fd_maxsize
* hard nofile $system_fd_maxsize
EOF
sed -i s/\#define\\t__FD_SETSIZE\\t\\t1024/\#define\\t__FD_SETSIZE\\t\\t$system_fd_maxsize/g /usr/include/bits/typesizes.h
sed -i s/\#define\\s__FD_SETSIZE\\t1024/\#define\\t__FD_SETSIZE\\t$system_fd_maxsize/g /usr/include/linux/posix_types.h

##
# MongoDB
##
banner_echo "Installing MongoDB ..."
cd $SRC_PATH
git clone git://github.com/mongodb/mongo.git
cd mongo
git checkout $MONGO_VERSION
scons all
scons --prefix=$PREFIX install
cd $SRC_PATH
rm -rf mongo

banner_echo "Setting up mongodb init and logrotate scripts ..."
cp -f resources/init.d/mongodb /etc/init.d/mongodb
chmod +x /etc/init.d/mongodb
cp -f resources/logrotate/mongodb /etc/logrotate.d/mongodb

banner_echo "Generating single server mongodb config ..."
cat > /usr/local/conf/mongodb.conf << EOF
dbpath="/data/db"
fork=true
bind_ip=127.0.0.1
port=27017
logappend=true
journal=true
nohttpinterface=true
EOF

##
# Directories and permission
##
banner_echo "Setting up directories ..."
mkdir -p /var/log/mongodb
mkdir -p /data/db
chown -R mongodb:mongodb /data/db
chmod 775 /data/db

##
# Cleanup
##
banner_echo "Cleaning up installation files ..."
cd $SRC_PATH
rm -rf resources

banner_echo "Done"
echo "##"
echo "# Start/Stop MongoDB"
echo "##"
echo ""
echo "sudo /etc/init.d/mongodb start"
echo "sudo /etc/init.d/mongodb stop"
echo ""
echo "##"
echo "# Start services on server startup"
echo "##"
echo ""
echo "Add all service start commands before 'exit 0' in '/etc/rc.local' as such:"
echo " 1:  !/bin/sh -e"
echo " 2:  "
echo " 3:  rc.local"
echo " 4:  "
echo " 5:  This script is executed at the end of each multiuser runlevel."
echo " 6:  Make sure that the script will \"exit 0\" on success or any other"
echo " 7:  value on error."
echo " 8:  "
echo " 9:  In order to enable or disable this script just change the execution"
echo "10:  bits."
echo "11:  "
echo "12:  By default this script does nothing."
echo "13:  "
echo "14:  /etc/init.d/mongodb start"
echo "17:  "
echo "18:  exit 0"
