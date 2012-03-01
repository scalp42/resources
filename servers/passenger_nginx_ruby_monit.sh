#! /bin/bash

# ami-cc0e3cb8

##
# Installation with auto tuning of filedescriptors with:
# - Git
# - Imagemagick
# - Monit
# - Ruby
# - Bundler
# - Nginx with Passenger
##

##
# Copyright (c) 2012 Robert Brewitz
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

if [ ! -n "$MONIT_VERSION" ]; then
  MONIT_VERSION="5.3.2"
fi

if [ ! -n "$RUBY_VERSION" ]; then
  RUBY_VERSION="1.9.2-p290"
fi

if [ ! -n "$NGINX_VERSION" ]; then
  NGINX_VERSION="1.0.12"
fi

if [ ! -n "$PASSENGER_VERSION" ]; then
  PASSENGER_VERSION="3.0.11"
fi

if [ ! -n "$SYSTEM_FD_MAXSIZE" ]; then
  SYSTEM_FD_MAXSIZE=$(more /proc/sys/fs/file-max*)
fi

if [ ! -n "$SYSTEM_CORES" ]; then
  SYSTEM_CORES=$(cat /proc/cpuinfo | grep processor | wc -l)
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
# Resources
##
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

cat > /etc/default/locale << EOF
LANG="en_GB.UTF-8"
EOF

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
banner_echo "Installing Ruby $RUBY_VERSION dependencies ..."
aptitude -y install build-essential zlib1g-dev libxml2-dev libxslt-dev \
                    libffi-dev libyaml-dev \
                    libcurl4-openssl-dev libopenssl-ruby \
                    ncurses-dev libncurses-ruby \
                    libreadline-dev libreadline-ruby

banner_echo "Installing Nginx $NGINX_VERSION dependencies ..."
aptitude -y install libpcre3-dev libssl-dev # zlib1g-dev already required by Ruby

banner_echo "Installing Git..."
aptitude -y install git-core

banner_echo "Installing monit $MONIT_VERSION dependencies ..."
aptitude -y install flex bison

banner_echo "Installing Imagemagick and dependencies ..."
aptitude -y install libmagickwand-dev imagemagick

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
# Monit
##
banner_echo "Installing Monit $MONIT_VERSION ..."
cd $SRC_PATH
wget http://mmonit.com/monit/dist/monit-$MONIT_VERSION.tar.gz -O $SRC_PATH/monit-$MONIT_VERSION.tar.gz
tar -zxvf monit-$MONIT_VERSION.tar.gz
cd monit-$MONIT_VERSION
./configure --prefix=$PREFIX --enable-optimized
make
make install
cd $SRC_PATH
rm -rf monit-$MONIT_VERSION*

##
# Ruby
##
banner_echo "Installing Ruby $RUBY_VERSION ..."
cd $SRC_PATH
wget http://ftp.ruby-lang.org/pub/ruby/1.9/ruby-$RUBY_VERSION.tar.gz -O $SRC_PATH/ruby-$RUBY_VERSION.tar.gz
tar -zxvf ruby-$RUBY_VERSION.tar.gz
cd ruby-$RUBY_VERSION
./configure --prefix=$PREFIX --disable-install-doc --with-out-ext=tk,win32ole # --with-readline-dir=/lib --with-ncurses-dir=/lib
make
make install
cd $SRC_PATH
rm -rf ruby-$RUBY_VERSION*
gem install bundler --no-ri --no-rdoc

##
# Nginx
##
banner_echo "Installing Nginx $NGINX_VERSION with Passenger $PASSENGER_VERSION ..."

# Download
cd $SRC_PATH
wget http://rubyforge.org/frs/download.php/75548/passenger-$PASSENGER_VERSION.tar.gz -O $SRC_PATH/passenger-$PASSENGER_VERSION.tar.gz
wget http://nginx.org/download/nginx-$NGINX_VERSION.tar.gz -O $SRC_PATH/nginx-$NGINX_VERSION.tar.gz

# Passenger
cd $PREFIX
tar -zxvf $SRC_PATH/passenger-$PASSENGER_VERSION.tar.gz
mv $PREFIX/passenger-$PASSENGER_VERSION $PREFIX/passenger
cd $PREFIX/passenger
rake nginx RELEASE=yes

# Nginx
cd $SRC_PATH
tar -zxvf nginx-$NGINX_VERSION.tar.gz
cd nginx-$NGINX_VERSION
./configure --with-cpu-opt=amd64                              \
            --prefix=$PREFIX                                  \
            --user=www-data --group=www-data                  \
            --http-log-path=/var/log/nginx/access.log         \
            --error-log-path=/var/log/nginx/error.log         \
            --pid-path=/var/run/nginx.pid                     \
            --lock-path=/var/lock/nginx.lock                  \
            --http-client-body-temp-path=/var/tmp/nginx/body  \
            --http-proxy-temp-path=/var/tmp/nginx/proxy       \
            --with-http_ssl_module                            \
            --with-http_gzip_static_module                    \
            --without-poll_module                             \
            --without-select_module                           \
            --without-http_charset_module                     \
            --without-http_empty_gif_module                   \
            --without-http_fastcgi_module                     \
            --add-module=$PREFIX/passenger/ext/nginx
make
make install
cd $SRC_PATH
rm -rf nginx-$NGINX_VERSION*
rm -rf passenger-$PASSENGER_VERSION*

##
# Nginx directories
##
banner_echo "Setting up nginx directories ..."
mkdir -p $PREFIX/sites-available
mkdir -p $PREFIX/sites-enabled
mkdir -p /var/tmp/nginx
mkdir -p /var/tmp/nginx/body
mkdir -p /var/tmp/nginx/proxy

##
# Nginx init and logrotate
##
banner_echo "Setting up nginx init and logrotate scripts ..."
cp -f resources/init.d/nginx /etc/init.d/nginx
chmod +x /etc/init.d/nginx
cp -f resources/logrotate/nginx /etc/logrotate.d/nginx

##
# Tuning nginx configuration
##
banner_echo "Tuning nginx configuration ..."
cat > $PREFIX/conf/nginx.conf << EOF
user www-data www-data;
pid /var/run/nginx.pid;
worker_processes $SYSTEM_CORES;
worker_rlimit_nofile $(($SYSTEM_FD_MAXSIZE / 2));

events {
  use epoll;
  epoll_events $(($SYSTEM_FD_MAXSIZE / 2));
  worker_connections $(($SYSTEM_FD_MAXSIZE / $SYSTEM_CORES / 2));
}

http {
  sendfile          off;
  tcp_nodelay       off;
  tcp_nopush        off;
  keepalive_timeout 65;
  
  passenger_root $PREFIX/passenger;
  passenger_ruby $PREFIX/bin/ruby;
  passenger_max_pool_size $(($SYSTEM_CORES * 4));
  
  server_tokens              off;
  default_type               text/html;
  include                    $PREFIX/conf/mime.types;
  
  open_file_cache            max=4096 inactive=20s;
  open_file_cache_valid      30s;
  open_file_cache_min_uses   2;
  open_file_cache_errors     off;
  variables_hash_bucket_size 256;
  variables_hash_max_size    2048;
  
  log_format            gzip '[\$status @ \$time_local <\$bytes_sent:\$gzip_ratio>] \$request from \$http_referer by \$http_user_agent';
  access_log            /var/log/nginx/access.log gzip buffer=32k;
  error_log             /var/log/nginx/error.log crit;
  
  gzip              on;
  gzip_vary         on;
  gzip_static       on;
  gzip_comp_level   1;
  gzip_min_length   0;
  gzip_http_version 1.1;
  gzip_proxied      any;
  gzip_disable      "MSIE [1-6].(?!.*SV1)";
  gzip_buffers      16 8k;
  gzip_types        text/plain text/css application/json application/x-javascript text/xml application/xml application/xml+rss text/javascript image/bmp;
  
  include $PREFIX/sites-enabled/*;
}
EOF

##
# Tuning example application configuration
##
banner_echo "Example nginx configuration ..."
cat > $PREFIX/sites-available/site.conf.example << EOF
server {
  listen                     80;
  server_name                localhost;
  root                       /data/www/application/production/current/public;
  passenger_enabled          on;
  passenger_use_global_queue on;
  rails_env                  production;
}
EOF

##
# Cleanup
##
banner_echo "Cleaning up installation files ..."
cd $SRC_PATH
rm -rf resources

banner_echo "... installation completed!"
