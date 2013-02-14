# MongoDB, Raid10, RVM, Ruby-1.9.3-p194

Currently testing setups on Amazon Linux, documenting progress and findings here.

## Raid10

Make sure you check the EBS device names before attempting this.

### Install tools

    sudo yum install -y mdadm.x86_64 xfsprogs.x86_64

### Format XFS filesystem for disks

    sudo mkfs.xfs /dev/xvdf1 -f
    sudo mkfs.xfs /dev/xvdf2 -f
    sudo mkfs.xfs /dev/xvdf3 -f
    sudo mkfs.xfs /dev/xvdf4 -f
    sudo mkfs.xfs /dev/xvdf5 -f
    sudo mkfs.xfs /dev/xvdf6 -f

### Create and persist raid10 array

    sudo mdadm --create /dev/md0 --level=10 --chunk=256 --raid-devices=6 /dev/xvdf1 /dev/xvdf2 /dev/xvdf3 /dev/xvdf4 /dev/xvdf5 /dev/xvdf6
    echo 'DEVICE /dev/xvdf1 /dev/xvdf2 /dev/xvdf3 /dev/xvdf4 /dev/xvdf5 /dev/xvdf6' | sudo tee -a /etc/mdadm.conf
    sudo mdadm --detail --scan | sudo tee -a /etc/mdadm.conf

### Tune EBS volumes

    sudo blockdev --setra 128 /dev/md0
    sudo blockdev --setra 128 /dev/xvdf1
    sudo blockdev --setra 128 /dev/xvdf2
    sudo blockdev --setra 128 /dev/xvdf3
    sudo blockdev --setra 128 /dev/xvdf4
    sudo blockdev --setra 128 /dev/xvdf5
    sudo blockdev --setra 128 /dev/xvdf6

### Zeroing out our RAID

    sudo dd if=/dev/zero of=/dev/md0 bs=512 count=1

### Physical device designation

    sudo pvcreate /dev/md0

### volume group for md0 device

    sudo vgcreate vg0 /dev/md0

### Partition device for mongodb

    sudo lvcreate -l 90%vg -n data vg0
    sudo lvcreate -l 5%vg -n log vg0
    sudo lvcreate -l 5%vg -n journal vg0

### Format partitions

    sudo mkfs.xfs /dev/vg0/data -f
    sudo mkfs.xfs /dev/vg0/log -f
    sudo mkfs.xfs /dev/vg0/journal -f

### Create MongoDB directories

    sudo mkdir /data
    sudo mkdir /log
    sudo mkdir /journal

### Add partitions to fstab

    echo '/dev/vg0/data /data xfs defaults,auto,noatime,noexec 0 0' | sudo tee -a /etc/fstab
    echo '/dev/vg0/log /log xfs defaults,auto,noatime,noexec 0 0' | sudo tee -a /etc/fstab
    echo '/dev/vg0/journal /journal xfs defaults,auto,noatime,noexec 0 0' | sudo tee -a /etc/fstab

### Mount directories and symlink journal to data

    sudo mount /data
    sudo mount /log
    sudo mount /journal
    sudo ln -s /journal /data/journal

## Install MongoDB

### Add 10gen repository to yum

    echo "[10gen]
    name=10gen Repository
    baseurl=http://downloads-distro.mongodb.org/repo/redhat/os/x86_64
    gpgcheck=0" | sudo tee -a /etc/yum.repos.d/10gen.repo

### Install MongoDB server and sysstat

    sudo yum -y install mongo-10gen-server
    sudo yum -y install sysstat

### Set mongod as owner for MongoDB directories

    sudo chown mongod:mongod /data
    sudo chown mongod:mongod /log
    sudo chown mongod:mongod /journal

### Important configuration options

/etc/mongod.conf

    ...
    logpath=/log/mongod.log
    logappend=true
    fork=true
    dbpath=/data
    ...

### Auto start mongod

    sudo chkconfig mongod on

### Start/Stop mongod

    sudo service mongod start
    sudo service mongod stop

### Format and remount when launching instance from AMI with raid10 configuration

I am not sure this is needed, needs more research; But better safe than sorry.

    sudo unlink /data/journal
    sudo umount /data
    sudo umount /log
    sudo umount /journal
    sudo mkfs.xfs /dev/vg0/data -f
    sudo mkfs.xfs /dev/vg0/log -f
    sudo mkfs.xfs /dev/vg0/journal -f
    sudo mount /data
    sudo mount /log
    sudo mount /journal
    sudo ln -s /journal /data/journal
    sudo chown mongod:mongod /data
    sudo chown mongod:mongod /log
    sudo chown mongod:mongod /journal

## Install RVM

### Dependencies

    sudo yum install -y gcc-c++ patch readline readline-devel zlib zlib-devel libyaml-devel libffi-devel openssl-devel make bzip2 autoconf automake libtool bison iconv-devel

### RVM and ruby-1.9.3-p194

Need RVM installed as sudo to make it accessible in the unicorn startup script.

    curl -L https://get.rvm.io | sudo bash -s stable
    sudo reboot # might be needed
    sudo rvm install ruby-1.9.3-p194

## Install Node

    sudo yum localinstall --nogpgcheck http://nodejs.tchol.org/repocfg/amzn1/nodejs-stable-release.noarch.rpm
    sudo yum install -y nodejs-compat-symlinks npm
