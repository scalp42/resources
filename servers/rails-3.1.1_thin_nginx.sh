#! /bin/bash

##
# Installation with auto tuning of filedescriptors with:
# - Monit
# - Nginx
# - Git
# - Node
# - NPM
# - CoffeeScript
# - Ruby
# - Rails
# - Bundler
# - Thin
# - Basic application in a capistrano'ish structure
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
  MONIT_VERSION="5.2.5"
fi

if [ ! -n "$NGINX_VERSION" ]; then
  NGINX_VERSION="1.0.4"
fi

if [ ! -n "$NODE_VERSION"]; then
  NODE_VERSION="v0.4.12"
fi

if [ ! -n "$RUBY_VERSION" ]; then
  RUBY_VERSION="1.9.2-p290"
fi

if [ ! -n "$RAILS_VERSION" ]; then
  RAILS_VERSION="3.1.1"
fi

system_fd_maxsize=$(more /proc/sys/fs/file-max*)
system_cores=$(cat /proc/cpuinfo | grep processor | wc -l)

function banner_echo {
  echo ""
  echo "##"
  echo "# $1"
  echo "##"
  echo ""
  sleep 2
}

cp -rf resources $SRC_PATH/resources

##
# System updates
##

banner_echo "Updating sources ..."

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

banner_echo "... done!"
banner_echo "Updating system ..."
apt-get -y update
banner_echo "... done!"
banner_echo "Upgrading system ..."
apt-get -y upgrade
banner_echo "... done!"
banner_echo "Updating locales ..."
locale-gen
banner_echo "... done!"

##
# Dependencies
##

banner_echo "Installing dependencies ..."

aptitude -y install build-essential libpcre3-dev zlib1g-dev git-core flex bison libssl-dev sqlite3 libsqlite3-dev libffi-dev libyaml-dev

# libyaml-dev
# libffi-dev
# libyaml libffi openssl
# --disable-tk, --without-x11
# --with-out-ext=x11,tk,tcl

banner_echo "... done!"

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

banner_echo "... done!"

##
# Monit
##

banner_echo "Installing Monit ..."

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

banner_echo "... done!"

##
# Nginx
##

banner_echo "Installing Nginx ..."

# Download and install
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
            --http-fastcgi-temp-path=/var/tmp/nginx/fastcgi   \
            --with-http_gzip_static_module                    \
            --without-poll_module                             \
            --without-select_module                           \
            #--without-http                                   \
            #--without-http_access_module                     \
            --without-http_autoindex_module                   \
            --without-http_browser_module                     \
            --without-http_charset_module                     \
            --without-http_empty_gif_module                   \
            #--without-http_fastcgi_module                    \
            #--without-http_gzip_module                       \
            --without-http_limit_zone_module                  \
            --without-http_map_module                         \
            #--without-http_memcached_module                  \
            #--without-http_proxy_module                      \
            #--without-http_referer_module                    \
            #--without-http_rewrite_module                    \
            --without-http_split_clients_module               \
            --without-http_ssi_module                         \
            #--without-http_upstream_ip_hash_module           \
            --without-http_uwsgi_module

make
make install
cd $SRC_PATH
rm -rf nginx-$NGINX_VERSION*

# Directories and init
mkdir -p $PREFIX/sites-available
mkdir -p $PREFIX/sites-enabled
mkdir -p /var/tmp/nginx
mkdir -p /var/tmp/nginx/body
mkdir -p /var/tmp/nginx/proxy
mkdir -p /var/tmp/nginx/fastcgi
cp -f resources/init.d/nginx /etc/init.d/nginx
chmod +x /etc/init.d/nginx
cp -f resources/logrotate/nginx /etc/logrotate.d/nginx

# Configuration
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
  
  log_format            gzip '[$status @ $time_local <$bytes_sent:$gzip_ratio>] $request from $http_referer by $http_user_agent';
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

banner_echo "... done!"

##
# Ruby
##

banner_echo "Installing Ruby, Rails, Thin and Bundler ..."

# Download and install
cd $SRC_PATH
wget http://ftp.ruby-lang.org/pub/ruby/1.9/ruby-$RUBY_VERSION.tar.gz -O $SRC_PATH/ruby-$RUBY_VERSION.tar.gz
tar -zxvf ruby-$RUBY_VERSION.tar.gz
cd ruby-$RUBY_VERSION
./configure --prefix=$PREFIX --disable-install-doc
make
make install

# Cleanup
cd $SRC_PATH
rm -rf ruby-$RUBY_VERSION*

# Directories
mkdir -p /var/log/thin

# Gems
gem update --system
gem install bundler thin --no-ri --no-rdoc
gem install rails -v $RAILS_VERSION --no-ri --no-rdoc

# Configuration
cat > $PREFIX/conf/thin.yml << EOF
daemonize: true
socket: /tmp/thin.sock
pid: /var/run/thin.pid
log: /var/log/thin/thin.log
servers: $system_cores
max_conns: $(($system_fd_maxsize / $system_cores))
max_persistent_conns: 512
timeout: 30
chdir: /data/www/cloudsalot/production/current
environment: production
EOF

touch $PREFIX/sites-available/cloudsalot
echo "upstream thin {" >> $PREFIX/sites-available/cloudsalot
for i in `seq 1 $system_cores`;
do
  echo "  server unix:/var/run/thin.$(($i-1)).sock;" >> $PREFIX/sites-available/cloudsalot
done
echo "}" >> $PREFIX/sites-available/cloudsalot
echo "" >> $PREFIX/sites-available/cloudsalot
echo "server {" >> $PREFIX/sites-available/cloudsalot
echo "  listen      80;" >> $PREFIX/sites-available/cloudsalot
echo "  server_name localhost;" >> $PREFIX/sites-available/cloudsalot
echo "  root        /data/www/cloudsalot/production/current/public;" >> $PREFIX/sites-available/cloudsalot
echo "  " >> $PREFIX/sites-available/cloudsalot
echo "  location / {" >> $PREFIX/sites-available/cloudsalot
echo "    proxy_set_header X-Real-IP \$remote_addr;" >> $PREFIX/sites-available/cloudsalot
echo "    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;" >> $PREFIX/sites-available/cloudsalot
echo "    proxy_set_header Host \$http_host;" >> $PREFIX/sites-available/cloudsalot
echo "    proxy_redirect   off;" >> $PREFIX/sites-available/cloudsalot
echo "    " >> $PREFIX/sites-available/cloudsalot
echo "    if (-f \$request_filename/index.html) {" >> $PREFIX/sites-available/cloudsalot
echo "      rewrite (.*) \$1/index.html break;" >> $PREFIX/sites-available/cloudsalot
echo "    }" >> $PREFIX/sites-available/cloudsalot
echo "    " >> $PREFIX/sites-available/cloudsalot
echo "    if (-f \$request_filename.html) {" >> $PREFIX/sites-available/cloudsalot
echo "      rewrite (.*) \$1.html break;" >> $PREFIX/sites-available/cloudsalot
echo "    }" >> $PREFIX/sites-available/cloudsalot
echo "    " >> $PREFIX/sites-available/cloudsalot
echo "    if (!-f \$request_filename) {" >> $PREFIX/sites-available/cloudsalot
echo "      proxy_pass http://thin;" >> $PREFIX/sites-available/cloudsalot
echo "      break;" >> $PREFIX/sites-available/cloudsalot
echo "    }" >> $PREFIX/sites-available/cloudsalot
echo "    " >> $PREFIX/sites-available/cloudsalot
echo "    error_page 500 502 503 504 /50x.html;" >> $PREFIX/sites-available/cloudsalot
echo "    " >> $PREFIX/sites-available/cloudsalot
echo "    location = /50x.html {" >> $PREFIX/sites-available/cloudsalot
echo "      root html;" >> $PREFIX/sites-available/cloudsalot
echo "    }" >> $PREFIX/sites-available/cloudsalot
echo "  }" >> $PREFIX/sites-available/cloudsalot
echo "}" >> $PREFIX/sites-available/cloudsalot

banner_echo "... done!"

##
# Node
##

banner_echo "Installing Node, NPM and coffee-script ..."

cd $SRC_PATH
git clone git://github.com/joyent/node.git
cd /usr/local/src/node
git checkout $NODE_VERSION
./configure --prefix=$PREFIX --dest-cpu=x64
make -j2
make install
cd $SRC_PATH
rm -rf node
curl http://npmjs.org/install.sh | clean=no sh
npm install -g coffee-script

banner_echo "... done!"

##
# Data directories
##

banner_echo "Setting up directories and example website ..."

# Directories
mkdir -p /data/db
mkdir -p /data/www
mkdir -p /data/www/cloudsalot/production

# Permissions
chown -R ubuntu:ubuntu /data/www
chmod 775 /data/www

# Symlinks
ln -s /data/www /www
ln -s /data/www /var/www

# Rails application
cd /data/www/cloudsalot/production
rails new current
cd /data/www/cloudsalot/production/current
RAILS_ENV=production bundle exec rake assets:precompile
cd $SRC_PATH
ln -s $PREFIX/sites-available/cloudsalot $PREFIX/sites-enabled/cloudsalot

# Cleanup
cd $SRC_PATH
rm -rf resources

banner_echo "... done!"

banner_echo "Installation completed, starting servers ..."

thin -C /usr/local/conf/thin.yml start
/etc/init.d/nginx start

banner_echo "Done"
echo ""
echo "##"
echo "# Precompile assets in production"
echo "# preferably add as a callback in capistrano after deploy"
echo "##"
echo ""
echo "RAILS_ENV=#{rails_env} bundle exec rake assets:precompile"
echo ""
echo "##"
echo "# Start Thin"
echo "##"
echo ""
echo "sudo thin -C /usr/local/conf/thin.yml start"
echo "sudo thin -C /usr/local/conf/thin.yml stop"
echo ""
echo "##"
echo "# Start Nginx"
echo "##"
echo ""
echo "sudo /etc/init.d/nginx start"
echo "sudo /etc/init.d/nginx stop"
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
echo "15:  thin -C /usr/local/conf/thin.yml start"
echo "16:  /etc/init.d/nginx start"
echo "17:  "
echo "18:  exit 0"
