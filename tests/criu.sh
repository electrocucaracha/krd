#!/bin/bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c)
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

set -o pipefail
set -o xtrace
set -o errexit
set -o nounset

# TODO: Get two criu hostnames

ssh -o StrictHostKeyChecking=no minion01 sudo docker rm worker
ssh -o StrictHostKeyChecking=no minion02 sudo docker rm worker

scp -o StrictHostKeyChecking=no init.py minion01:/vagrant/tests/init.py
ssh -o StrictHostKeyChecking=no -t minion01 sudo docker run -d --rm --name worker -v /vagrant/tests/:/usr/src/worker -w /usr/src/worker python:3 python init.py
sleep 10
ssh -o StrictHostKeyChecking=no -t minion01 sudo docker checkpoint create worker worker_checkpoint
CONTAINER_ID=$(ssh -o StrictHostKeyChecking=no minion01 sudo docker inspect --format="{{.Id}}" worker)
ssh -o StrictHostKeyChecking=no minion01 sudo tar cvzf /tmp/worker_checkpoint.tar.gz -C "/var/lib/docker/containers/$CONTAINER_ID/checkpoints" .

scp -o StrictHostKeyChecking=no minion01:/tmp/worker_checkpoint.tar.gz /tmp/worker_checkpoint.tar.gz
scp -o StrictHostKeyChecking=no /tmp/worker_checkpoint.tar.gz minion02:/tmp/worker_checkpoint.tar.gz
rm /tmp/worker_checkpoint.tar.gz

ssh -o StrictHostKeyChecking=no minion02 sudo docker create --name worker python
ssh -o StrictHostKeyChecking=no minion02 sudo mkdir -p "/var/lib/docker/containers/$CONTAINER_ID/checkpoints"; sudo tar -C "/var/lib/docker/containers/$CONTAINER_ID/checkpoints" -xvf /tmp/worker_checkpoint.tar.gz
ssh -o StrictHostKeyChecking=no minion02 sudo docker start --checkpoint worker_checkpoint worker
