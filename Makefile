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
	-e VALIDATE_PYTHON_PYLINT=false \
	-e PYTHON_FLAKE8_CONFIG_FILE=tox.ini \
	-e VALIDATE_PYTHON_MYPY=false \
	github/super-linter
	tox -e lint
