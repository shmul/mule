#!/bin/bash

basedir=/home/trusteer/mule
shareddir=$basedir/shared
processed=$shareddir/queues/mule_processed


function log() {
  echo "`date --iso-8601=seconds` ($$) $*"
}

log "start"

for i in `seq 4 15`; do
  dir=`date --date="$i day ago" +'%y/%m/%d'`
  archive=`date --date="$i day ago" +'%y.%m.%d'`
  fulldir="$processed/$dir"
  log "$processed/$archive.tgz from $fulldir"
  if [[ -d $fulldir ]]; then
    tar zcf $processed/$archive.tgz -C $processed $dir --remove-files
  fi
done

log "erasing old mule logs"
find $shareddir/ -name "mule.log-*" -mtime +30 -delete

log "end"
