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

function get_version {
    local type="$1"
    local name="$2"
    local version=""
    local attempt_counter=0
    readonly max_attempts=5

    until [ "$version" ]; do
        version=$("_get_github_latest_$type" "$name")
        if [ "$version" ]; then
            break
        elif [ ${attempt_counter} -eq ${max_attempts} ];then
            echo "Max attempts reached"
            exit 1
        fi
        attempt_counter=$((attempt_counter+1))
        sleep $((attempt_counter*2))
    done

    echo "${version#v}"
}

function _get_github_latest_release {
    url_effective=$(curl -sL -o /dev/null -w '%{url_effective}' "https://github.com/$1/releases/latest")
    if [ "$url_effective" ]; then
        echo "${url_effective##*/}"
    fi
}

function _get_github_latest_tag {
    tags="$(curl -s "https://api.github.com/repos/$1/tags")"
    if [ "$tags" ]; then
        echo "$tags" | grep -Po '"name":.*?[^\\]",' | awk -F  "\"" 'NR==1{print $4}'
    fi
}

function update_pip_pkg {
    local pkg="$1"
    local version="$2"

    while IFS= read -r playbook; do
        sed -i "s/$pkg==.*/$pkg==$version/g" "$playbook"
    done < <(grep -r "$pkg==" ./playbooks/roles/ | awk -F ':' '{ print $1}')
}

kubespray_version="$(get_version release kubernetes-sigs/kubespray)"
sed -i "s/kubespray_version:.*/kubespray_version: v$kubespray_version/g" ./playbooks/krd-vars.yml
sed -i "s/KRD_KUBESPRAY_VERSION                 |.*/KRD_KUBESPRAY_VERSION                 | v$kubespray_version                                        | Specifies the Kubespray version to be used during the upgrade process           |/g" README.md
sed -i "s/KRD_KUBESPRAY_VERSION:-.* \"\$(git describe --abbrev=0 --tags)\"/KRD_KUBESPRAY_VERSION:-v$kubespray_version}\" \"\$(git describe --abbrev=0 --tags)\"/g" ./ci/check.sh
sed -i "s/KRD_KUBESPRAY_VERSION:-.* \"\$(\$VAGRANT_CMD_SSH_INSTALLER \"cd \/opt\/kubespray; git describe --abbrev=0 --tags\")\"/KRD_KUBESPRAY_VERSION:-v$kubespray_version}\" \"\$(\$VAGRANT_CMD_SSH_INSTALLER \"cd \/opt\/kubespray; git describe --abbrev=0 --tags\")\"/g" ./ci/check.sh

sed -i "s/istio_version:.*/istio_version: $(get_version release istio/istio)/g" ./playbooks/krd-vars.yml
sed -i "s/cfssl_version:.*/cfssl_version: $(get_version release cloudflare/cfssl)/g" ./playbooks/krd-vars.yml
sed -i "s/sonobuoy_version:.*/sonobuoy_version: $(get_version release vmware-tanzu/sonobuoy)/g" ./playbooks/krd-vars.yml

# Knative versions
sed -i "s/kn_version:.*/kn_version: v$(get_version tag knative/client)/g" ./playbooks/krd-vars.yml
sed -i "s/knative_serving_version:.*/knative_serving_version: v$(get_version tag knative/serving)/g" ./playbooks/krd-vars.yml
sed -i "s/knative_eventing_version:.*/knative_eventing_version: v$(get_version tag knative/eventing)/g" ./playbooks/krd-vars.yml
sed -i "s/net_kourier_version:.*/net_kourier_version: v$(get_version tag knative-sandbox/net-kourier)/g" ./playbooks/krd-vars.yml
sed -i "s/net_istio_version:.*/net_istio_version: v$(get_version tag knative-sandbox/net-istio)/g" ./playbooks/krd-vars.yml
sed -i "s/net_certmanager_version:.*/net_certmanager_version: v$(get_version tag knative-sandbox/net-certmanager)/g" ./playbooks/krd-vars.yml

sed -i "s/octant_version:.*/octant_version: $(get_version release vmware-tanzu/octant)/g" ./playbooks/krd-vars.yml
sed -i "s/kube-ovn_version:.*/kube-ovn_version: v$(get_version release kubeovn/kube-ovn)/g" ./playbooks/krd-vars.yml
sed -i "s/prometheus-operator_version:.*/prometheus-operator_version: v$(get_version tag prometheus-operator/prometheus-operator)/g" ./playbooks/krd-vars.yml
sed -i "s/kubevirt_version:.*/kubevirt_version: v$(get_version release kubevirt/kubevirt)/g" ./playbooks/krd-vars.yml
sed -i "s/kubesphere_version:.*/kubesphere_version: v$(get_version release kubesphere/kubesphere)/g" ./playbooks/krd-vars.yml
sed -i "s/metallb_version:.*/metallb_version: v$(get_version tag metallb/metallb)/g" ./playbooks/krd-vars.yml

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
    version: $(get_version tag geerlingguy/ansible-role-docker)
  - name: geerlingguy.repo-epel
    version: $(get_version tag geerlingguy/ansible-role-repo-epel)
  - name: geerlingguy.pip
    version: $(get_version tag geerlingguy/ansible-role-pip)
  - name: andrewrothstein.gcc-toolbox
    version: v$(get_version tag andrewrothstein/ansible-gcc-toolbox)
  - name: andrewrothstein.kind
    version: v$(get_version tag andrewrothstein/ansible-kind)
  - name: andrewrothstein.kubectl
    version: v$(get_version tag andrewrothstein/ansible-kubectl)

collections:
  - name: community.kubernetes
    version: 1.2.1
EOT

# Udpate Playbook default versions
# NOTE: There is no images released for minor versions https://hub.docker.com/r/nfvpe/sriov-cni/tags
#sed -i "s/sriov_cni_version:.*/sriov_cni_version: v$(get_version tag k8snetworkplumbingwg/sriov-cni)/g" ./playbooks/roles/sriov_cni/defaults/main.yml
sed -i "s/criproxy_version:.*/criproxy_version: $(get_version tag Mirantis/criproxy)/g" ./playbooks/roles/criproxy/defaults/main.yml
sed -i "s/pmem_version:.*/pmem_version: v$(get_version tag intel/pmem-csi)/g" ./playbooks/roles/pmem/defaults/main.yml
sed -i "s/driver_registrar_version:.*/driver_registrar_version: v$(get_version tag kubernetes-csi/node-driver-registrar)/g" ./playbooks/roles/pmem/defaults/main.yml
sed -i "s/csi_provisioner_version:.*/csi_provisioner_version: v$(get_version tag kubernetes-csi/external-provisioner)/g" ./playbooks/roles/pmem/defaults/main.yml
sed -i "s/cfssl_version:.*/cfssl_version: $(get_version tag cloudflare/cfssl)/g" ./playbooks/roles/pmem/defaults/main.yml
sed -i "s/virtlet_version:.*/virtlet_version: $(get_version tag Mirantis/virtlet)/g" ./playbooks/roles/virtlet/defaults/main.yml
sed -i "s/sriov_plugin_version:.*/sriov_plugin_version: v$(get_version release k8snetworkplumbingwg/sriov-network-device-plugin)/g" ./playbooks/roles/sriov_plugin/defaults/main.yml
sed -i "s/nfd_version:.*/nfd_version: v$(get_version release kubernetes-sigs/node-feature-discovery)/g" ./playbooks/roles/nfd/defaults/main.yml

# Update Kubernetes Collection dependencies
update_pip_pkg "kubernetes" "$(get_version release kubernetes-client/python)"
update_pip_pkg "openshift" "$(get_version release openshift/openshift-restclient-python)"
