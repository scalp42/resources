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

if [ ! -n "$MONIT_VERSION" ]; then
  MONIT_VERSION="5.3"
fi

if [ ! -n "$NGINX_VERSION" ]; then
  NGINX_VERSION="1.0.8"
fi

if [ ! -n "$RUBY_VERSION" ]; then
  RUBY_VERSION="1.9.2-p290"
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
banner_echo "Installing Ruby $RUBY_VERSION dependencies ..."
aptitude -y install build-essential zlib1g-dev libxml2-dev libxslt-dev \
                    libffi-dev libyaml-dev \
                    libcurl4-openssl-dev libopenssl-ruby \
                    ncurses-dev libncurses-ruby \
                    libreadline-dev libreadline-ruby

banner_echo "Installing Git..."
aptitude -y install git-core

banner_echo "Installing Nginx $NGINX_VERSION dependencies ..."
aptitude -y install libpcre3-dev libssl-dev # zlib1g-dev already required by Ruby

banner_echo "Installing Node v0.6.2 dependencies ..."
aptitude -y install pkg-config

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

# Download and install
cd $SRC_PATH
wget http://mmonit.com/monit/dist/monit-$MONIT_VERSION.tar.gz -O $SRC_PATH/monit-$MONIT_VERSION.tar.gz
tar -zxvf monit-$MONIT_VERSION.tar.gz
cd monit-$MONIT_VERSION
./configure --prefix=$PREFIX
make
make install
cd $SRC_PATH
rm -rf monit-$MONIT_VERSION*

##
# Nginx
##
banner_echo "Installing Nginx $NGINX_VERSION ..."
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
worker_rlimit_nofile $SYSTEM_FD_MAXSIZE;

events {
  use epoll;
  epoll_events $SYSTEM_FD_MAXSIZE;
  worker_connections $(($SYSTEM_FD_MAXSIZE / $SYSTEM_CORES));
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
# CoffeScript
##

banner_echo "Installing Node v0.6.2, Node Package Manager and CoffeScript ..."
cd $SRC_PATH
wget http://nodejs.org/dist/node-v0.6.2.tar.gz -O $SRC_PATH/node-v0.6.2.tar.gz
tar xzvf node-v0.6.2.tar.gz
cd $SRC_PATH/node-v0.6.2
./configure --prefix=$PREFIX --dest-cpu=x64
make
make install
cd $SRC_PATH
rm -rf node-*
curl http://npmjs.org/install.sh | sh
npm install -g coffee-script

##
# Ruby
##
banner_echo "Installing Ruby $RUBY_VERSION ..."
cd $SRC_PATH
wget http://ftp.ruby-lang.org/pub/ruby/1.9/ruby-$RUBY_VERSION.tar.gz -O $SRC_PATH/ruby-$RUBY_VERSION.tar.gz
tar -zxvf ruby-$RUBY_VERSION.tar.gz
cd ruby-$RUBY_VERSION
./configure --prefix=$PREFIX --disable-install-doc --disable-pthread --with-out-ext=tk,win32ole # --with-readline-dir=/lib --with-ncurses-dir=/lib
make
make install
cd $SRC_PATH
rm -rf ruby-$RUBY_VERSION*
gem install bundler --no-ri --no-rdoc

##
# Tuned thin configuration
##
mkdir -p /var/log/thin
banner_echo "Tuning thin configuration ..."
cat > $PREFIX/conf/thin.yml.example << EOF
daemonize: true
socket: /tmp/thin.sock
pid: /var/run/thin.pid
log: /var/log/thin/thin.log
servers: $SYSTEM_CORES
max_conns: $(($SYSTEM_FD_MAXSIZE / $SYSTEM_CORES))
max_persistent_conns: 512
timeout: 60
chdir: /data/www/application/production/current
environment: production
EOF

##
# Tuning example application configuration
##
banner_echo "Tuning example nginx site configuration, including maintenance catcher \$document_root/system/maintenance.html ..."
touch $PREFIX/sites-available/site.conf.example
echo "upstream thin {" >> $PREFIX/sites-available/site.conf.example
for i in `seq 1 $SYSTEM_CORES`;
do
  echo "  server unix:/tmp/thin.$(($i-1)).sock;" >> $PREFIX/sites-available/site.conf.example
done
echo "}" >> $PREFIX/sites-available/site.conf.example
echo "" >> $PREFIX/sites-available/site.conf.example
echo "server {" >> $PREFIX/sites-available/site.conf.example
echo "  listen      80;" >> $PREFIX/sites-available/site.conf.example
echo "  server_name localhost;" >> $PREFIX/sites-available/site.conf.example
echo "  root        /data/www/application/production/current/public;" >> $PREFIX/sites-available/site.conf.example
echo "  " >> $PREFIX/sites-available/site.conf.example
echo "  location / {" >> $PREFIX/sites-available/site.conf.example
echo "    proxy_set_header X-Real-IP \$remote_addr;" >> $PREFIX/sites-available/site.conf.example
echo "    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;" >> $PREFIX/sites-available/site.conf.example
echo "    proxy_set_header Host \$http_host;" >> $PREFIX/sites-available/site.conf.example
echo "    proxy_redirect   off;" >> $PREFIX/sites-available/site.conf.example
echo "    " >> $PREFIX/sites-available/site.conf.example
echo "    if (-f \$document_root/system/maintenance.html) {" >> $PREFIX/sites-available/site.conf.example
echo "      rewrite ^(.*)$ /system/maintenance.html break;" >> $PREFIX/sites-available/site.conf.example
echo "    }" >> $PREFIX/sites-available/site.conf.example
echo "    " >> $PREFIX/sites-available/site.conf.example
echo "    if (-f \$request_filename) {" >> $PREFIX/sites-available/site.conf.example
echo "      break;" >> $PREFIX/sites-available/site.conf.example
echo "    }" >> $PREFIX/sites-available/site.conf.example
echo "    " >> $PREFIX/sites-available/site.conf.example
echo "    if (-f \$request_filename/index.html) {" >> $PREFIX/sites-available/site.conf.example
echo "      rewrite (.*) \$1/index.html break;" >> $PREFIX/sites-available/site.conf.example
echo "    }" >> $PREFIX/sites-available/site.conf.example
echo "    " >> $PREFIX/sites-available/site.conf.example
echo "    if (-f \$request_filename.html) {" >> $PREFIX/sites-available/site.conf.example
echo "      rewrite (.*) \$1.html break;" >> $PREFIX/sites-available/site.conf.example
echo "    }" >> $PREFIX/sites-available/site.conf.example
echo "    " >> $PREFIX/sites-available/site.conf.example
echo "    if (!-f \$request_filename) {" >> $PREFIX/sites-available/site.conf.example
echo "      proxy_pass http://thin;" >> $PREFIX/sites-available/site.conf.example
echo "      break;" >> $PREFIX/sites-available/site.conf.example
echo "    }" >> $PREFIX/sites-available/site.conf.example
echo "    " >> $PREFIX/sites-available/site.conf.example
echo "    error_page 500 502 503 504 /50x.html;" >> $PREFIX/sites-available/site.conf.example
echo "    " >> $PREFIX/sites-available/site.conf.example
echo "    location = /50x.html {" >> $PREFIX/sites-available/site.conf.example
echo "      root html;" >> $PREFIX/sites-available/site.conf.example
echo "    }" >> $PREFIX/sites-available/site.conf.example
echo "  }" >> $PREFIX/sites-available/site.conf.example
echo "}" >> $PREFIX/sites-available/site.conf.example

##
# Cleanup
##
banner_echo "Cleaning up installation files ..."
cd $SRC_PATH
rm -rf resources

banner_echo "... installation completed!"