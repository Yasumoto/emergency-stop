#!/bin/sh

# Create a container for running Emergency Stop

docker build --tag=emergency-stop --file=./web.Dockerfile --build-arg env=docker .
