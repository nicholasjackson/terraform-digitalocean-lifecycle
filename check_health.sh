#!/bin/bash

fail_count=1

while true
do
  response=$(curl --write-out %{http_code} --silent --output /dev/null $1)

  if [ $response -eq 200 ] ; then
    echo "$(date -u) Server available"
    exit 0
  else
    if [ $fail_count -eq 11 ]; then
      echo "$(date -u) Server unavailable"
      exit 2
    else
      echo "$(date -u) Attempt ${fail_count}/10: Server not yet available"
      sleep 3
      fail_count=$[$fail_count +1]
    fi
  fi
done
