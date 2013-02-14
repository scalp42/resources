# Server installation

## System update, build essentials, monit, git, nginx and production configured NodeJS with NPM

    sudo yum update -y
    sudo yum install -y git.x86_64 monit.x86_64 nginx.x86_64 gcc-c++ make.x86_64
    cd /usr/local
    sudo wget http://nodejs.org/dist/v0.8.14/node-v0.8.14.tar.gz
    sudo tar zxvf node-v0.8.14.tar.gz
    cd node-v0.8.14
    sudo ./configure --dest-cpu=x64 --dest-os=linux --without-etw --without-dtrace --without-waf
    sudo make
    sudo make install

## Autostart nginx and monit

    sudo chkconfig nginx on
    sudo chkconfig monit on

## Sites enabled folder

    sudo mkdir -p /etc/nginx/sites-enabled
