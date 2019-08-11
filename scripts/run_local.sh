#!/bin/sh

set -eux

if docker container ls --filter 'name=emergency-stop-dynamodb' | grep -q 'emergency-stop'; then
    echo "Container already running"
else
    # Kick off a local DynamoDB, starting in detached mode.
    # Kill it with `docker container kill emergency-stop-dynamodb`
    docker run -d -p 8000:8000 --name emergency-stop-dynamodb amazon/dynamodb-local
fi

ENVIRONMENT=local CREDENTIALS_FILENAME="$(basename "${0}")/aws-dev.json" swift run Run
