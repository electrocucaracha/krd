# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2018
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

FROM python:2.7

ARG HTTP_PROXY=${HTTP_PROXY}
ARG HTTPS_PROXY=${HTTPS_PROXY}

ENV http_proxy $HTTP_PROXY
ENV https_proxy $HTTPS_PROXY

EXPOSE 8080

RUN mkdir -p /{tmp,etc}/generic_sim

WORKDIR /opt/generic_sim/

COPY . .
RUN pip install --no-cache-dir -r requirements.txt

CMD [ "python", "generic_sim.py" ]
