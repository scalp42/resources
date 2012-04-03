#! /bin/bash

# US-East AMI: ami-349b495d

##
# Installation with auto tuning of filedescriptors with:
# - Git
# - Imagemagick
# - Monit
# - Nginx
# - PHP
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

if [ ! -n "$NGINX_VERSION" ]; then
  NGINX_VERSION="1.0.14"
fi

if [ ! -n "$PHP_VERSION" ]; then
  PHP_VERSION="5.4.0"
fi

if [ ! -n "$IMAGICK_VERSION" ]; then
  IMAGICK_VERSION="3.1.0RC1"
fi

if [ ! -n "$SYSTEM_FD_MAXSIZE" ]; then
  SYSTEM_FD_MAXSIZE=$(more /proc/sys/fs/file-max*)
fi

if [ ! -n "$SYSTEM_CORES" ]; then
  SYSTEM_CORES=$(cat /proc/cpuinfo | grep processor | wc -l)
fi

export LC_CTYPE="en_US.UTF-8"

function banner_echo {
  echo ""
  echo "##"
  echo "# $1"
  echo "##"
  echo ""
  sleep 3
}

cp -rf resources $SRC_PATH/resources

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

banner_echo "Installing php dependencies ..."
aptitude -y install build-essential libxml2-dev libcurl4-openssl-dev libmcrypt-dev libltdl-dev libevent-dev autoconf

banner_echo "Installing nginx dependencies ..."
aptitude -y install libpcre3-dev libssl-dev zlib1g-dev

banner_echo "Installing git ..."
aptitude -y install git-core

banner_echo "Installing monit dependencies ..."
aptitude -y install flex bison

banner_echo "Installing imagemagick ..."
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
# Nginx
##
banner_echo "Installing Nginx $NGINX_VERSION ..."

cd $SRC_PATH
wget http://nginx.org/download/nginx-$NGINX_VERSION.tar.gz -O $SRC_PATH/nginx-$NGINX_VERSION.tar.gz
tar -zxvf nginx-$NGINX_VERSION.tar.gz
cd nginx-$NGINX_VERSION
./configure --with-cpu-opt=amd64                             \
            --prefix=$PREFIX                                 \
            --user=www-data --group=www-data                 \
            --http-log-path=/var/log/nginx/access.log        \
            --error-log-path=/var/log/nginx/error.log        \
            --pid-path=/var/run/nginx.pid                    \
            --lock-path=/var/lock/nginx.lock                 \
            --http-client-body-temp-path=/var/tmp/nginx/body \
            --http-proxy-temp-path=/var/tmp/nginx/proxy      \
            --http-uwsgi-temp-path=/var/tmp/nginx/uwsgi      \
            --http-scgi-temp-path=/var/tmp/nginx/scgi        \
            --http-fastcgi-temp-path=/var/tmp/nginx/fastcgi  \
            --with-http_ssl_module                           \
            --with-http_gzip_static_module                   \
            --without-poll_module                            \
            --without-select_module                          \
            --without-http_charset_module                    \
            --without-http_empty_gif_module
make
make install
cd $SRC_PATH
rm -rf nginx-$NGINX_VERSION*

##
# Nginx directories
##
banner_echo "Setting up nginx directories ..."
mkdir -p $PREFIX/sites-available
mkdir -p $PREFIX/sites-enabled
mkdir -p /var/tmp/nginx
mkdir -p /var/tmp/nginx/body
mkdir -p /var/tmp/nginx/proxy
mkdir -p /var/tmp/nginx/uwsgi
mkdir -p /var/tmp/nginx/scgi
mkdir -p /var/tmp/nginx/fastcgi

##
# Nginx init and logrotate
##
banner_echo "Setting up nginx init and logrotate ..."
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
# PHP
##
banner_echo "Installing PHP $PHP_VERSION ..."
cd $SRC_PATH
wget http://www.php.net/get/php-$PHP_VERSION.tar.gz/from/this/mirror -O $SRC_PATH/php-$PHP_VERSION.tar.gz
tar -zxvf php-$PHP_VERSION.tar.gz
cd php-$PHP_VERSION
./configure --prefix=$PREFIX --with-libdir=/lib64 \
            --disable-debug --enable-inline-optimization \
            --enable-fpm \
            --with-openssl=/usr --with-openssl-dir=/usr \
            --with-curl=/usr --with-curlwrappers \
            --with-mcrypt --with-mhash \
            --enable-libxml --with-libxml-dir=/usr \
            --enable-mbstring --enable-mbregex \
            --enable-sockets \
            --with-zlib --with-zlib-dir=/usr \
            --enable-sysvsem --enable-sysvshm

make
make install
cd $SRC_PATH
rm -rf php-$PHP_VERSION*

##
# PHP directories
##
banner_echo "Setting up php-fpm init and logrotate ..."
mkdir -p /var/log/php-fpm
cp -f resources/init.d/php-fpm /etc/init.d/php-fpm
cp -f resources/logrotate/php-fpm /etc/logrotate.d/php-fpm
chmod +x /etc/init.d/php-fpm

##
# PHP-FPM config
##
banner_echo "Generating tuned php-fpm config ..."
cat > $PREFIX/conf/php-fpm.conf << EOF
pid                         = /var/run/php-fpm.pid
error_log                   = /var/log/php-fpm/error.log
log_level                   = notice
emergency_restart_threshold = 16
emergency_restart_interval  = 0
process_control_timeout     = 0
daemonize                   = yes

[default]

rlimit_files                = $SYSTEM_FD_MAXSIZE
pm.max_children             = $(($SYSTEM_CORES * 4))
pm.max_requests             = $(($SYSTEM_FD_MAXSIZE / $SYSTEM_CORES / 4))
pm                          = static
listen                      = /var/run/php-fpm.sock
listen.allowed_clients      = 127.0.0.1
user                        = www-data
group                       = www-data
rlimit_core                 = $SYSTEM_FD_MAXSIZE
EOF

##
# PHP ini
##
banner_echo "Generating tuned example php.ini for php-$PHP_VERSION ..."
cat > $PREFIX/lib/php.ini << EOF
[hardware specific]
rlimit_files                   = $SYSTEM_FD_MAXSIZE
zlib.output_compression_level  = 4                  ; decrease if it eats too much cpu
output_buffering               = Off                ; on if compression eats too much cpu
zlib.output_compression        = On                 ; off if output_buffering is on

[PHP]
expose_php               = Off
short_open_tag           = Off
post_max_size            = 8M
ignore_user_abort        = Off
variables_order          = \"EGPCS\"
request_order            = \"GP\"
register_argc_argv       = Off
auto_globals_jit         = On
allow_url_fopen          = Off
allow_url_include        = Off
enable_dl                = Off
serialize_precision      = 100
implicit_flush           = Off
memory_limit             = 64M
enable_post_data_reading = 1 ; see http://se.php.net/manual/en/ini.core.php#ini.enable-post-data-reading

[cgi]
fastcgi.logging        = 1

[security]
disable_functions = \"system,exec,shell_exec,escapeshellcmd,popen,pcntl_exec\"
disable_classes   = \"\"

[upload]
file_uploads        = On
upload_tmp_dir      = \"/tmp/php\"
upload_max_filesize = 5M
max_file_uploads    = 10

[logging]
error_reporting        = E_ALL & ~E_DEPRECATED
error_log              = \"/var/log/php/error.log\"
display_errors         = Off
display_startup_errors = Off
log_errors             = Off
log_errors_max_len     = 1024
ignore_repeated_errors = Off
ignore_repeated_source = Off
report_memleaks        = Off
track_errors           = Off
html_errors            = Off

[timeout]
max_execution_time     = 0

[localization]
date.timezone   = Europe/Stockholm
default_charset = \"UTF-8\"

[extensions]
extension_dir = \"$PREFIX/lib/php/extensions/no-debug-non-zts-20100525\"
extension     = imagick.so
extension     = apc.so
;extension     = mongo.so
;extension     = xcache.so
;extension     = memcached.so
;extension     = newrelic.so

;[mongo]
;mongo.native_long      = false
;mongo.long_as_object   = false
;mongo.default_host     = 127.0.0.1
;mongo.default_port     = 27017
;mongo.auto_reconnect   = true
;mongo.allow_persistent = false
;mongo.chunk_size       = 262144
;mongo.cmd              = \"$\"
;mongo.utf8             = 1
;mongo.allow_empty_keys = false

;[newrelic]
;newrelic.appname                            = RobertBrewitz
;newrelic.enabled                            = 1
;newrelic.logfile                            = \"/var/log/newrelic/php_agent.log\"
;newrelic.loglevel                           = info
;newrelic.browser_monitoring.auto_instrument = 1
;newrelic.transaction_tracer.top100          = 1
;newrelic.framework                          = \"cakephp\"

;[session]
;session.save_handler             = memcached
;session.save_path                = 127.0.0.1:12345
;;
; http://se.php.net/manual/en/session.configuration.php#ini.session.upload-progress.enabled
;;
;session.upload_progress.enabled  = 
;session.upload_progress.cleanup  = 
;session.upload_progress.prefix   = 
;session.upload_progress.name     = 
;session.upload_progress.freq     = 
;session.upload_progress.min_freq = 
EOF

##
# ImageMagick PHP drivers
##
banner_echo "Installing php drivers for imagemagick ..."
cd $SRC_PATH
wget http://pecl.php.net/get/imagick-$IMAGICK_VERSION.tgz -O $SRC_PATH/imagick-$IMAGICK_VERSION.tar.gz
tar -zxvf imagick-$IMAGICK_VERSION.tar.gz
cd imagick-$IMAGICK_VERSION
phpize
./configure --prefix=$PREFIX
make
make install
cd $SRC_PATH
rm -rf imagick-$IMAGICK_VERSION*

##
# APC
##
banner_echo "Installing php drivers for imagemagick ..."
cd $SRC_PATH
wget http://pecl.php.net/get/APC-$APC_VERSION.tgz -O $SRC_PATH/APC-$APC_VERSION.tgz
tar -zxvf APC-$APC_VERSION.tgz
cd APC-$APC_VERSION
phpize
./configure --prefix=$PREFIX
make
make install
cd $SRC_PATH
rm -rf APC-$APC_VERSION*

##
# Cleanup
##
banner_echo "Cleaning up installation files ..."
cd $SRC_PATH
rm -rf resources

banner_echo "Done!"
