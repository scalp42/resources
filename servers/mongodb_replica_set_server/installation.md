# MongoDB

Instructions to setup and install MongoDB server(s) with 6 volume Raid10 storage configuration.

Arbiters (http://docs.mongodb.org/manual/reference/glossary/#term-arbiter) does not require raid10 nor any additional ebs volumes, also they should be run on a micro instance.

## Add 10gen repository

    echo "[10gen]
    name=10gen Repository
    baseurl=http://downloads-distro.mongodb.org/repo/redhat/os/x86_64
    gpgcheck=0" | sudo tee -a /etc/yum.repos.d/10gen.repo

### Install packages

    sudo yum install -y mdadm.x86_64 xfsprogs.x86_64 mongo-10gen-server.x86_64 sysstat.x86_64
    
### Set filedescriptor limits for mongod

    # /etc/security/limits.conf
    mongod soft nofile 65536
    mongod hard nofile 65536

### Create and attach EBS drives

Create six EBS volumes and name them xvdf1, xvdf2, xvdf3, xvdf4, xvdf5 and xvdf6.

More information here: http://docs.amazonwebservices.com/AWSEC2/latest/UserGuide/ebs-creating-volume.html

### Format EBS volumes

When the devices are attached to the server format the disks as XFS filesystems

    sudo mkfs.xfs /dev/xvdf1 -f
    sudo mkfs.xfs /dev/xvdf2 -f
    sudo mkfs.xfs /dev/xvdf3 -f
    sudo mkfs.xfs /dev/xvdf4 -f
    sudo mkfs.xfs /dev/xvdf5 -f
    sudo mkfs.xfs /dev/xvdf6 -f

### Raid10

Create a new Raid10 array and add the EBS volumes to it, also persist the Raid10 array.

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

### Zeroing out our Raid10

    sudo dd if=/dev/zero of=/dev/md0 bs=512 count=1

### Physical device designation

    sudo pvcreate /dev/md0

### Create a volume group

    sudo vgcreate vg0 /dev/md0

### Partition volume group

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

### Set mongod as owner for MongoDB directories

    sudo chown mongod:mongod /data
    sudo chown mongod:mongod /log
    sudo chown mongod:mongod /journal

### Auto start mongod

    sudo chkconfig mongod on

### Start/Stop mongod

    sudo service mongod start
    sudo service mongod stop
