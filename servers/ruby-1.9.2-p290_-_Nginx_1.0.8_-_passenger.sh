#! /bin/bash

##
# Installation with auto tuning of filedescriptors with:
# - Ruby
# - Nginx
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

if [ ! -n "$NGINX_VERSION" ]; then
  NGINX_VERSION="1.0.8"
fi

if [ ! -n "$RUBY_VERSION" ]; then
  RUBY_VERSION="1.9.2-p290"
fi

system_fd_maxsize=$(more /proc/sys/fs/file-max*)
system_cores=$(cat /proc/cpuinfo | grep processor | wc -l)

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

##
# System upgrade
##
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
banner_echo "Installing Ruby $RUBY_VERSION and passenger dependencies ..."
aptitude -y install build-essential zlib1g-dev libffi-dev libyaml-dev libcurl4-openssl-dev libopenssl-ruby

banner_echo "Installing Nginx dependencies ..."
aptitude -y install libpcre3-dev libssl-dev # zlib1g-dev already required by Ruby

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
# Nginx
##
banner_echo "Installing Nginx ..."
cd $SRC_PATH
wget http://nginx.org/download/nginx-$NGINX_VERSION.tar.gz -O $SRC_PATH/nginx-$NGINX_VERSION.tar.gz
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
            --without-http_fastcgi_module
make
make install
cd $SRC_PATH
rm -rf nginx-$NGINX_VERSION*

##
# Nginx directories
##
banner_echo "Settings up nginx directories ..."
mkdir -p $PREFIX/sites-available
mkdir -p $PREFIX/sites-enabled
mkdir -p /var/tmp/nginx
mkdir -p /var/tmp/nginx/body
mkdir -p /var/tmp/nginx/proxy

##
# Nginx init and logrotate
##
banner_echo "Setting up nginx init and logrotate scripts"
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
worker_processes $system_cores;
worker_rlimit_nofile $system_fd_maxsize;

events {
  use epoll;
  epoll_events $system_fd_maxsize;
  worker_connections $(($system_fd_maxsize / $system_cores));
}

http {
  sendfile          off;
  tcp_nodelay       off;
  tcp_nopush        off;
  keepalive_timeout 60;
  
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
  error_log             /var/log/nginx/error.log crit buffer=32k;
  
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
# Ruby
##
banner_echo "Installing Ruby $RUBY_VERSION ..."
cd $SRC_PATH
wget http://ftp.ruby-lang.org/pub/ruby/1.9/ruby-$RUBY_VERSION.tar.gz -O $SRC_PATH/ruby-$RUBY_VERSION.tar.gz
tar -zxvf ruby-$RUBY_VERSION.tar.gz
cd ruby-$RUBY_VERSION
./configure --prefix=$PREFIX --disable-install-doc --disable-pthread --with-out-ext=tk,win32ole
make
make install
cd $SRC_PATH
rm -rf ruby-$RUBY_VERSION*

banner_echo "... done!"
