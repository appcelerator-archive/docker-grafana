#!/bin/bash

ready=1
for service in $DEPENDENCIES
do
  status=$(curl --max-time 3 -s http://$CONSUL/v1/health/checks/$service)
  if [[ $status =~ ^.*\"Status\":\"passing\" ]]; then
    echo $service" is ready"
  else
    echo $service" is not yet ready"
    ready=0
  fi
done
if [ "$ready" == "0" ]; then
  echo "Dependencies are not still ready: Send SIGTERM (15) signal"
  kill SIGTERM $(pidof node)
fi