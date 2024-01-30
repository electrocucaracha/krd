# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2021
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

DOCKER_CMD ?= $(shell which docker 2> /dev/null || which podman 2> /dev/null || echo docker)

.PHONY: lint
lint:
	sudo -E $(DOCKER_CMD) run --rm -v $$(pwd):/tmp/lint \
	-e RUN_LOCAL=true \
	-e LINTER_RULES_PATH=/ \
	-e VALIDATE_KUBERNETES_KUBEVAL=false \
	-e VALIDATE_NATURAL_LANGUAGE=false \
	-e KUBERNETES_KUBECONFORM_OPTIONS='-ignore-missing-schemas -ignore-filename-pattern custom-rules.yml' \
	github/super-linter
	tox -e lint

.PHONY: fmt
fmt:
	sudo -E $(DOCKER_CMD) run --rm -u "$$(id -u):$$(id -g)" \
	-v "$$(pwd):/mnt" -v /mnt/spec -v /mnt/playbooks/roles/pmem/files/ \
	-w /mnt mvdan/shfmt -l -w -i 4 -s .
	command -v yamlfmt > /dev/null || curl -s "https://i.jpillora.com/google/yamlfmt!!" | bash
	yamlfmt -dstar **/*.{yaml,yml}
