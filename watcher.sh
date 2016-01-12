#!/bin/bash

while true; do printf "%s %3s %3s\n" `date +"%H:%M:%S"` `find ~/mule/shared/queues/ltmule_incoming/   | wc -l` `tail -50 ~/mule/shared/logs/ltmule.log | grep -c accepting` ; sleep 2;done
