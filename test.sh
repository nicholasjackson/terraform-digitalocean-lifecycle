#!/bin/bash

while true
do
  curl --silent $1 --stderr - | sed -n 's:.*<title>\(.*\)</title>.*:\1:p'
  sleep 1
done
