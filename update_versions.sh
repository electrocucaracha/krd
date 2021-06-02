#!/bin/bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2021
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

set -o errexit
set -o pipefail
if [[ "${KRD_DEBUG:-false}" == "true" ]]; then
    set -o xtrace
fi

function get_github_latest_release {
    version=""
    attempt_counter=0
    max_attempts=5

    until [ "$version" ]; do
        url_effective=$(curl -sL -o /dev/null -w '%{url_effective}' "https://github.com/$1/releases/latest")
        if [ "$url_effective" ]; then
            version="${url_effective##*/}"
            break
        elif [ ${attempt_counter} -eq ${max_attempts} ];then
            echo "Max attempts reached"
            exit 1
        fi
        attempt_counter=$((attempt_counter+1))
        sleep 2
    done
    echo "${version#v}"
}

function get_github_latest_tag {
    version=""
    attempt_counter=0
    max_attempts=5

    until [ "$version" ]; do
        tags="$(curl -s "https://api.github.com/repos/$1/tags")"
        if [ "$tags" ]; then
            version="$(echo "$tags" | grep -Po '"name":.*?[^\\]",' | awk -F  "\"" 'NR==1{print $4}')"
            break
        elif [ ${attempt_counter} -eq ${max_attempts} ];then
            echo "Max attempts reached"
            exit 1
        fi
        attempt_counter=$((attempt_counter+1))
        sleep 2
    done

    echo "${version#*v}"
}

kubespray_version="$(get_github_latest_release kubernetes-sigs/kubespray)"
sed -i "s/kubespray_version:.*/kubespray_version: v$kubespray_version/g" ./playbooks/krd-vars.yml
sed -i "s/KRD_KUBESPRAY_VERSION                 |.*/KRD_KUBESPRAY_VERSION                 | v$kubespray_version                                        | Specifies the Kubespray version to be used during the upgrade process           |/g" README.md
sed -i "s/KRD_KUBESPRAY_VERSION:-.* \"\$(git describe --abbrev=0 --tags)\"/KRD_KUBESPRAY_VERSION:-v$kubespray_version}\" \"\$(git describe --abbrev=0 --tags)\"/g" check.sh
sed -i "s/KRD_KUBESPRAY_VERSION:-.* \"\$(\$VAGRANT_CMD_SSH_INSTALLER \"cd \/opt\/kubespray; git describe --abbrev=0 --tags\")\"/KRD_KUBESPRAY_VERSION:-v$kubespray_version}\" \"\$(\$VAGRANT_CMD_SSH_INSTALLER \"cd \/opt\/kubespray; git describe --abbrev=0 --tags\")\"/g" check.sh

sed -i "s/istio_version:.*/istio_version: $(get_github_latest_release istio/istio)/g" ./playbooks/krd-vars.yml
sed -i "s/knative_version:.*/knative_version: v$(get_github_latest_tag knative/serving)/g" ./playbooks/krd-vars.yml
sed -i "s/octant_version:.*/octant_version: $(get_github_latest_release vmware-tanzu/octant)/g" ./playbooks/krd-vars.yml
sed -i "s/rook_version:.*/rook_version: v$(get_github_latest_release rook/rook)/g" ./playbooks/krd-vars.yml
sed -i "s/kube-ovn_version:.*/kube-ovn_version: v$(get_github_latest_release kubeovn/kube-ovn)/g" ./playbooks/krd-vars.yml
sed -i "s/prometheus-operator_version:.*/prometheus-operator_version: v$(get_github_latest_tag prometheus-operator/prometheus-operator)/g" ./playbooks/krd-vars.yml
sed -i "s/kubevirt_version:.*/kubevirt_version: v$(get_github_latest_release kubevirt/kubevirt)/g" ./playbooks/krd-vars.yml
sed -i "s/kubesphere_version:.*/kubesphere_version: v$(get_github_latest_release kubesphere/kubesphere)/g" ./playbooks/krd-vars.yml
sed -i "s/metallb_version:.*/metallb_version: v$(get_github_latest_release metallb/metallb)/g" ./playbooks/krd-vars.yml

cat << EOT > galaxy-requirements.yml
---
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2018
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

roles:
  - name: geerlingguy.docker
    version: $(get_github_latest_tag geerlingguy/ansible-role-docker)
  - name: geerlingguy.repo-epel
    version: $(get_github_latest_tag geerlingguy/ansible-role-repo-epel)
  - name: andrewrothstein.gcc-toolbox
    version: v$(get_github_latest_tag andrewrothstein/ansible-gcc-toolbox)
  - name: andrewrothstein.kind
    version: v$(get_github_latest_tag andrewrothstein/ansible-kind)
  - name: andrewrothstein.kubectl
    version: v$(get_github_latest_tag andrewrothstein/ansible-kubectl)

collections:
  - name: community.kubernetes
    version: ">=0.10.0"
EOT
