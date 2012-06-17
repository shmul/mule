#!/bin/sh
#
# mule     Startup script for mule
#
# chkconfig:   - 64 36
# description: Startup script for mule
# processname: lua
# config:      /etc/sysconfig/mule
# pidfile:     /var/run/mule/mule.pid

# Source function library
. /etc/rc.d/init.d/functions

prog="mule.lua"
stop_password="nomoremule"
mule_port=8980
luaexec=/usr/bin/lua
shareddir=/home/ranger/mule/shared
currentdir=/home/ranger/mule/current
#export FCGI_CHILDREN FCGI_MAX_REQUESTS

RETVAL=0

start() {
  echo -n $"Starting $prog: "
  echo
  cd $currentdir
  $luaexec $currentdir/mule.lua -l $shareddir/mule_http_daemon.log -d $shareddir/db/mule.tcb -t 0.0.0.0:$mule_port -x $stop_password &
  RETVAL=$?
  if [ $RETVAL -eq 0 ]
  then
      echo_success
  else
      echo_failure
  fi
  echo
  return $RETVAL
}

stop() {

  for i in 1 2 3; do
      echo -n $"Stopping $prog. Attempt $i"
      curl http://localhost:$mule_port/stop?password=$stop_password
      sleep 4
      curl http://localhost:$mule_port
      if [ $?==7 ]; then
          echo "\nsuccessfully stopped"
          return 0
      fi
  done

  echo_failure
  return 1
}

case "$1" in
  start)
    start
    ;;
  stop)
    stop
    ;;
  restart)
    stop
    start
    ;;
  *)
    echo $"Usage: $0 {start|stop|restart}"
    RETVAL=1
esac

exit $RETVAL
