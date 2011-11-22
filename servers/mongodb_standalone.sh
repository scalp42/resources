#! /bin/bash

##
# Installation with auto tuning of filedescriptors with:
# - SpiderMonkey patch
# - Replacing XULrunner
# - MongoDB 2.0.1
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

if [ ! -n "$SYSTEM_FD_MAXSIZE" ]; then
  SYSTEM_FD_MAXSIZE=$(more /proc/sys/fs/file-max*)
fi

function banner_echo {
  echo ""
  echo "##"
  echo "# $1"
  echo "##"
  echo ""
  sleep 3
}

# Copy resources to SRC_PATH
mkdir -p $SRC_PATH
cp -rf resources $SRC_PATH/resources

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
* soft nofile $SYSTEM_FD_MAXSIZE
* hard nofile $SYSTEM_FD_MAXSIZE
EOF
sed -i s/\#define\\t__FD_SETSIZE\\t\\t1024/\#define\\t__FD_SETSIZE\\t\\t$SYSTEM_FD_MAXSIZE/g /usr/include/bits/typesizes.h
sed -i s/\#define\\s__FD_SETSIZE\\t1024/\#define\\t__FD_SETSIZE\\t$SYSTEM_FD_MAXSIZE/g /usr/include/linux/posix_types.h

##
# MongoDB prequisits
##
banner_echo "Fixing MongoDB dependencies ..."
cd $SRC_PATH
aptitude -y remove xulrunner-1.9.2-dev xulrunner-1.9.2
wget ftp://ftp.mozilla.org/pub/mozilla.org/js/js-1.7.0.tar.gz -O $SRC_PATH/js-1.7.0.tar.gz
tar zxvf js-1.7.0.tar.gz
cd js/src
export CFLAGS="-DJS_C_STRINGS_ARE_UTF8"
make -f Makefile.ref
JS_DIST=$PREFIX make -f Makefile.ref export
cd $SRC_PATH
rm -rf js*

##
# MongoDB
# 
# Pulling from my own repository with master at r2.0.1 due to bash and git problems
##
banner_echo "Installing MongoDB ..."
cd $SRC_PATH
git clone git://github.com/RobertBrewitz/mongo.git
cd mongo
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
chown -R ubuntu:ubuntu /data/db
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
echo "14:  sudo /etc/init.d/mongodb start"
echo "17:  "
echo "18:  exit 0"
echo ""
echo "##"
echo "# Create MongoDB admin"
echo "##"
echo "$ mongo"
echo "> use admin"
echo "> db.addUser(\"admin\", \"admin_password\")"
echo ""
echo "##"
echo "# Create database and user with read+write"
echo "##"
echo ""
echo "$ mongo"
echo "> use project_name"
echo "> db.addUser(\"user\", \"user_password\")"
echo ""
echo "##"
echo "# Create database and user with read only"
echo "##"
echo ""
echo "$ mongo"
echo "> use project_name"
echo "> db.addUser(\"user\", \"user_password\", true)"