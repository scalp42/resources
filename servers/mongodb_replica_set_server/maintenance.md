# MongoDB server maintainance

Documentation and instructions on how to manage MongoDB servers.

## Replica Sets

### Initializing and reconfiguring replica set

In mongo console do the following, members are the replica-set server IPs & Ports.

    cfg = {
      "_id" : "replicaSet1",
      "version" : 1,
      "members" : [
        {
          "_id" : 0,
          "host" : "<ip:port>"
        },
        {
          "_id" : 1,
          "host" : "<ip:port>"
        },
        {
          "_id" : 2,
          "host" : "<ip:port>"
        }
      ]
    }
    
    # To initialize
    rs.initiate(cfg);
    
    # To reconfigure
    rs.reconfig(cfg);

### Adding member to replica set

    rs.add("<host:port>", false);

### Adding a node to replica set

    rs.add("<host:port>", true);

or

    rs.addArb("<host:port>");

### Initializing replica set

    rs.initiate(cfg)

### Removing node from replica set

    rs.remove("<host:port>");

## Backups

### Snapshotting raid10

    1) Step down if primary
    2) Stop communication with replica set
    3) Snapshot instances
    4) Start communication with replica set

### Restoring from snapshot

    1) Create instance
    2) Create disks from snapshots
    3) Introduce to replica set
