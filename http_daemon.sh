#!/bin/bash


set -u
shareddir=/home/ranger/mule/shared
logfile=$shareddir/log/mule_http_daemon.log
muledir=/home/ranger/mule/current
muledb=/home/ranger/mule/shared/db/mule.tcb
hostport=0.0.0.0:8980

log() {
	  echo "`date +'%F %T'`: $1 ($$)"
}

log "Start"

cd $muledir
/usr/local/bin/lua mule.lua -l $logfile -d $muledb -t $hostport

log "End"