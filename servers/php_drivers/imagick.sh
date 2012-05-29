#! /bin/bash

##
# Installs IMagick PHP drivers
##

if [ ! -n "$PREFIX" ]; then
  PREFIX="/usr/local"
fi

if [ ! -n "$SRC_PATH" ]; then
  SRC_PATH="$PREFIX/src"
fi

if [ ! -n "$IMAGICK_VERSION" ]; then
  VERSION="3.0.1"
fi

# Dependencies
aptitude -y install autoconf

# Source folder
cd $SRC_PATH
wget http://pecl.php.net/get/imagick-$VERSION.tgz -O $SRC_PATH/imagick-$VERSION.tar.gz

# Untar
tar -zxvf imagick-$VERSION.tar.gz
cd imagick-$VERSION
phpize
./configure --enable-xcache
make
make install
cd $SRC_PATH
rm -rf imagick-$VERSION*
echo "##"
echo "# Don't forget to add extension=imagick.so to your php.ini file in /usr/local/lib/php.ini"
echo "##"
