#!/bin/bash

basedir=/home/trusteer/mule
shareddir=$basedir/shared

function log() {
  echo "`date --iso-8601=seconds` ($$) $*"
}

log "start"

for i in `seq 4 15`; do
  dir=`date --date="$i day ago" +'%y/%m/%d'`
  archive=`date --date="$i day ago" +'%y.%m.%d'`

  for j in $shareddir/queues/mule_processed  $shareddir/queues/ltmule_processed; do
    fulldir="$j/$dir"
    log "$j/$archive.tgz from $fulldir"
    if [[ -d $fulldir ]]; then
      tar zcf $j/$archive.tgz -C $j $dir --remove-files
    fi
  done

done

log "erasing old mule logs"
find $shareddir/ -name "mule.log-*" -mtime +30 -delete
find $shareddir/ -name "ltmule.log-*" -mtime +30 -delete

log "end"
