#!/bin/bash

. /etc/rc.d/init.d/functions

APP_ROOT=/home/ec2-user/applications/application/production/current
SHARED_ROOT=/home/ec2-user/applications/application/production/shared
DAEMON=/usr/local/bin/node
SERVER=$APP_ROOT/server.js

pidfile=$SHARED_ROOT/tmp/node.pid
logfile=$SHARED_ROOT/log/server.log
lockfile=$SHARED_ROOT/tmp/node.lock

do_start() {
  [ -x $DAEMON ] || exit 5
  [ -f $SERVER ] || exit 6
  echo -n $"Starting Node.js: "
  daemon "NODE_ENV=production $DAEMON $SERVER >> $logfile &"
  retval=$?
  pid=`ps -aefw | grep "$DAEMON $SERVER" | grep -v " grep " | awk '{print $2}'`
  echo "$pid" > $pidfile
  echo
  [ $retval -eq 0 ] && touch $lockfile && echo "$pid" > $pidfile
  return $retval
}

do_stop() {
  echo -n $"Stopping Node.js: "
  killproc -p $pidfile
  retval=$?
  echo
  [ $retval -eq 0 ] && rm -f $lockfile && rm -f $pidfile
  return $retval
}

case "$1" in
  start)
    do_start || exit 0
  ;;

  stop)
    do_stop || exit 0
  ;;

  restart)
    do_stop
    do_start
  ;;
  *)
    echo "Usage: $0 {start|stop|restart}"
    exit 2
  ;;
esac
