# MongoDB servers

## Synchronize time with NTP

ntp is installed and running by default on Amazon Linux. For whatever reason it is not.

    sudo yum install -y ntp
    sudo chkconfig ntpd on
    sudo service ntp start

## Basic replica-set /etc/mongod.conf

    logpath=/log/mongod.log
    logappend=true
    fork=true
    dbpath=/data
    replSet=replicaSet1

Add the arbiter to a replica-set with:

    rs.add("<host:port>", true);

or

    rs.addArb("<host:port>");
