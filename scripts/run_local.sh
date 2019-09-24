#!/bin/sh

set -eux

DYNAMO_CONTAINER="$(docker container ls --all --filter 'name=emergency-stop-dynamodb')"

if [ -z "$DYNAMO_CONTAINER" ] || echo "$DYNAMO_CONTAINER" | grep emergency-stop | grep Up; then
    echo "Container already running"
elif echo "$DYNAMO_CONTAINER" | grep Exited; then
    docker container rm "$(echo "$DYNAMO_CONTAINER" | grep emergency-stop | awk '{print $1}')"
else
    # Kick off a local DynamoDB, starting in detached mode.
    # Kill it with `docker container kill emergency-stop-dynamodb`
    docker run -d -p 8000:8000 --name emergency-stop-dynamodb amazon/dynamodb-local

    swift run BootstrapDatabaseTool
fi

ENVIRONMENT=local CREDENTIALS_FILENAME="$(dirname "${0}")/aws-dev.json" swift run Run --port 8081
