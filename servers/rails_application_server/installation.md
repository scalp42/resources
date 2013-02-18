# Application Server

## Update

    sudo yum update -y

## RVM/Ruby dependencies

    sudo yum install -y gcc-c++ patch readline readline-devel zlib zlib-devel libyaml-devel libffi-devel openssl-devel make bzip2 autoconf automake libtool bison iconv-devel libxml2-devel.x86_64 libxslt-devel.x86_64

## Dependencies if the application uses curl

    sudo yum install libcurl-devel.x86_64 libcurl-devel.x86_64

## Nginx and git

    sudo yum install -y git-core nginx

## RVM/Ruby installation

    curl -L https://get.rvm.io | sudo bash -s stable
    source /etc/profile.d/rvm.sh
    sudo su
    rvm install ruby-1.9.3-p194

## Autostart nginx and monit

    sudo chkconfig nginx on
    sudo chkconfig monit on

## Sites enabled folder

    sudo mkdir -p /etc/nginx/sites-enabled
