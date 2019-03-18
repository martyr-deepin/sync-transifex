#!/bin/sh
set -ex
docker run --rm \
    -e TX_USER=$TX_USER \
    -e TX_PASSWORD=$TX_PASSWORD \
    -e GITHUB_USER=$GITHUB_USER \
    -e GITHUB_PASSWORD=$GITHUB_PASSWORD \
    -e GITHUB_EMAIL=$GITHUB_EMAIL \
    -e GITHUB_TOKEN=$GITHUB_TOKEN \
    hub.deepin.io/deepin/sync-transifex:$IMAGE_TAG $@
