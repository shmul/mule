#!/bin/bash


set -u
shareddir=/home/ranger/mule/shared
logfile=$shareddir/log/mule_http_daemon.log
muledir=/home/ranger/mule/current
muledb=/home/ranger/mule/shared/db/mule.tcb
hostport=0.0.0.0:8980
luaexec=/usr/bin/lua

log() {
	  echo "`date +'%F %T'`: $1 ($$)"
}

log "Start"

cd $muledir
$luaexec mule.lua -l $logfile -d $muledb -t $hostport -x nomoremule

log "End"
