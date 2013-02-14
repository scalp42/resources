# Configuration

## Nginx

One process per available core (2 on large instance)

## Unicorn

One process per available core (2 on large instance)

## File descriptor limits

### Get file descriptors available for instance

    more /proc/sys/fs/file-max*

### Set limits in /etc/security/limits.conf

Set it to 65000 or if less, to max available FD's

    * soft nofile 65000
    * hard nofile 65000
