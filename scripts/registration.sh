#!/bin/sh

curl -XPOST -H "Content-Type: application/json" \
    -d "{\"Username\": \"$USER\", \"Timestamp\": \"$(date +%Y-%m-%dT%H:%M:%S%z)\", \"Hostname\": \"$(hostname)\", \"LoadtestToolName\": \"simple-curl\"}" \
http://localhost:8080/register
