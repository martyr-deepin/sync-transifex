#!/bin/bash -ex
docker run --rm -it \
	-e SSH_AUTH_SOCK=$SSH_AUTH_SOCK \
	-e TX_USER=$TX_USER \
	-e TX_PASSWORD=$TX_PASSWORD \
	-e PROJECT=$PROJECT \
	-v $SSH_AUTH_SOCK:$SSH_AUTH_SOCK \
	hub.deepin.io/deepin/sync-transifex:$IMAGE_TAG bash -e sync_po.sh $ACTION
