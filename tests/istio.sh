#!/bin/bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2018
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

set -o errexit
set -o nounset
set -o pipefail

# shellcheck source=tests/_functions.sh
source _functions.sh

istio_version=$(grep "istio_version:" "$TEST_FOLDER/../playbooks/krd-vars.yml" | awk -F ': ' '{print $2}')

kubectl apply -f "https://raw.githubusercontent.com/istio/istio/$istio_version/samples/bookinfo/platform/kube/bookinfo.yaml"
kubectl apply -f "https://raw.githubusercontent.com/istio/istio/$istio_version/samples/bookinfo/networking/bookinfo-gateway.yaml"

for deployment in details-v1 productpage-v1 ratings-v1 reviews-v1 reviews-v2 reviews-v3; do
    wait_deployment $deployment
done
INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
INGRESS_HOST=$(kubectl get po -l istio=ingressgateway -n istio-system -o 'jsonpath={.items[0].status.hostIP}')
curl -o /dev/null -s -w "%{http_code}\n" "http://$INGRESS_HOST:$INGRESS_PORT/productpage"
