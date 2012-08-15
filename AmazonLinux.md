# MongoDB, Raid10, RVM, Ruby-1.9.3-p125

Currently testing setups on Amazon Linux, documenting progress and findings here.

## Install tools

    yum install mdadm.x86_64
    yum install xfsprogs.x86_64

## Format XFS filesystem for disks

    sudo mkfs.xfs /dev/xvdf1 -f
    sudo mkfs.xfs /dev/xvdf2 -f
    sudo mkfs.xfs /dev/xvdf3 -f
    sudo mkfs.xfs /dev/xvdf4 -f

## Create and persist raid10 array

    sudo mdadm --create /dev/md0 --level=10 --chunk=256 --raid-devices=4 /dev/xvdf1 /dev/xvdf2 /dev/xvdf3 /dev/xvdf4
    echo 'DEVICE /dev/xvdf1 /dev/xvdf2 /dev/xvdf3 /dev/xvdf4' | sudo tee -a /etc/mdadm.conf
    sudo mdadm --detail --scan | sudo tee -a /etc/mdadm.conf

## Tune EBS volumes

    sudo blockdev --setra 128 /dev/md0
    sudo blockdev --setra 128 /dev/xvdf1
    sudo blockdev --setra 128 /dev/xvdf2
    sudo blockdev --setra 128 /dev/xvdf3
    sudo blockdev --setra 128 /dev/xvdf4

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

## Install MongoDB server and sysstat

    sudo yum -y install mongo-10gen-server
    sudo yum -y install sysstat

## Set mongod as owner for MongoDB directories

    sudo chown mongod:mongod /data
    sudo chown mongod:mongod /log
    sudo chown mongod:mongod /journal

## Important configuration options

/etc/mongod.conf

    ...
    logpath=/log/mongod.log
    logappend=true
    fork=true
    dbpath=/data
    ...

## Install RVM

### Dependencies

    sudo yum install -y gcc-c++ patch readline readline-devel zlib zlib-devel libyaml-devel libffi-devel openssl-devel make bzip2 autoconf automake libtool bison iconv-devel

### RVM and ruby-1.9.3-p125

    curl -L https://get.rvm.io | bash -s stable
    rvm install ruby-1.9.3-p125
