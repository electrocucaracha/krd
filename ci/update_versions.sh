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
if [[ "${DEBUG:-false}" == "true" ]]; then
    set -o xtrace
fi

function get_version {
    local type="$1"
    local name="$2"
    local version=""
    local attempt_counter=0
    readonly max_attempts=5

    until [ "$version" ]; do
        version=$("_get_latest_$type" "$name")
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

function _get_latest_github_release {
    url_effective=$(curl -sL -o /dev/null -w '%{url_effective}' "https://github.com/$1/releases/latest")
    if [ "$url_effective" ]; then
        echo "${url_effective##*/}"
    fi
}

function _get_latest_github_tag {
    tags="$(curl -s "https://api.github.com/repos/$1/tags")"
    if [ "$tags" ]; then
        echo "$tags" | grep -Po '"name":.*?[^\\]",' | awk -F  "\"" 'NR==1{print $4}'
    fi
}

function _get_latest_ansible_role {
    curl -sfL "https://galaxy.ansible.com/api/v1/roles/?owner__username=${1%.*}&name=${1#*.}" | jq -r '.results[0].summary_fields.versions[0].name'
}

function _get_latest_ansible_collection {
    curl -sfL "https://galaxy.ansible.com/api/v2/collections/${1%.*}/${1#*.}/versions" | jq -r '.results[0].version'
}

function _get_latest_docker_tag {
    curl -sfL "https://registry.hub.docker.com/v1/repositories/$1/tags" | python -c 'import json,sys;versions=[obj["name"][1:] for obj in json.load(sys.stdin) if obj["name"][0] == "v"];print("\n".join(versions))' | sed 's/-.*//g' | uniq | sort -rn | head -n 1
}

function update_pip_pkg {
    local pkg="$1"
    local version="$2"

    while IFS= read -r playbook; do
        sed -i "s/$pkg==.*/$pkg==$version/g" "$playbook"
    done < <(grep -r "$pkg==" ./playbooks/roles/ | awk -F ':' '{ print $1}')
}

kubespray_version="$(get_version github_release kubernetes-sigs/kubespray)"
sed -i "s/kubespray_version:.*/kubespray_version: v$kubespray_version/g" ./playbooks/krd-vars.yml
sed -i "s/KRD_KUBESPRAY_VERSION                 |.*/KRD_KUBESPRAY_VERSION                 | v$kubespray_version                                        | Specifies the Kubespray version to be used during the upgrade process           |/g" README.md
sed -i "s/KRD_KUBESPRAY_VERSION:-.* \"\$(git describe --abbrev=0 --tags)\"/KRD_KUBESPRAY_VERSION:-v$kubespray_version}\" \"\$(git describe --abbrev=0 --tags)\"/g" ./ci/check.sh
sed -i "s/KRD_KUBESPRAY_VERSION:-.* \"\$(\$VAGRANT_CMD_SSH_INSTALLER \"cd \/opt\/kubespray; git describe --abbrev=0 --tags\")\"/KRD_KUBESPRAY_VERSION:-v$kubespray_version}\" \"\$(\$VAGRANT_CMD_SSH_INSTALLER \"cd \/opt\/kubespray; git describe --abbrev=0 --tags\")\"/g" ./ci/check.sh

sed -i "s/istio_version:.*/istio_version: $(get_version github_release istio/istio)/g" ./playbooks/krd-vars.yml
sed -i "s/cfssl_version:.*/cfssl_version: $(get_version github_release cloudflare/cfssl)/g" ./playbooks/krd-vars.yml
sed -i "s/sonobuoy_version:.*/sonobuoy_version: $(get_version github_release vmware-tanzu/sonobuoy)/g" ./playbooks/krd-vars.yml

# Knative versions
sed -i "s/kn_version:.*/kn_version: $(get_version github_release knative/client)/g" ./playbooks/krd-vars.yml
sed -i "s/knative_serving_version:.*/knative_serving_version: $(get_version github_release knative/serving)/g" ./playbooks/krd-vars.yml
sed -i "s/knative_eventing_version:.*/knative_eventing_version: v$(get_version github_tag knative/eventing)/g" ./playbooks/krd-vars.yml
sed -i "s/net_kourier_version:.*/net_kourier_version: $(get_version github_release knative-sandbox/net-kourier)/g" ./playbooks/krd-vars.yml
sed -i "s/net_istio_version:.*/net_istio_version: v$(get_version github_tag knative-sandbox/net-istio)/g" ./playbooks/krd-vars.yml
sed -i "s/net_certmanager_version:.*/net_certmanager_version: v$(get_version github_tag knative-sandbox/net-certmanager)/g" ./playbooks/krd-vars.yml

sed -i "s/octant_version:.*/octant_version: $(get_version github_release vmware-tanzu/octant)/g" ./playbooks/krd-vars.yml
sed -i "s/kube-ovn_version:.*/kube-ovn_version: v$(get_version github_release kubeovn/kube-ovn)/g" ./playbooks/krd-vars.yml
sed -i "s/prometheus-operator_version:.*/prometheus-operator_version: v$(get_version github_tag prometheus-operator/prometheus-operator)/g" ./playbooks/krd-vars.yml
sed -i "s/kubevirt_version:.*/kubevirt_version: v$(get_version github_release kubevirt/kubevirt)/g" ./playbooks/krd-vars.yml
sed -i "s/kubesphere_version:.*/kubesphere_version: v$(get_version github_release kubesphere/kubesphere)/g" ./playbooks/krd-vars.yml
sed -i "s/metallb_version:.*/metallb_version: v$(get_version github_tag metallb/metallb)/g" ./playbooks/krd-vars.yml

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
    version: $(get_version ansible_role geerlingguy.docker)
  - name: geerlingguy.repo-epel
    version: $(get_version ansible_role geerlingguy.repo-epel)
  - name: geerlingguy.pip
    version: $(get_version ansible_role geerlingguy.pip)
  - name: andrewrothstein.gcc-toolbox
    version: v$(get_version ansible_role andrewrothstein.gcc-toolbox)
  - name: andrewrothstein.kind
    version: v$(get_version ansible_role andrewrothstein.kind)
  - name: andrewrothstein.kubectl
    version: v$(get_version ansible_role andrewrothstein.kubectl)

collections:
  - name: community.kubernetes
    version: $(get_version ansible_collection community.kubernetes)
EOT

# Udpate Playbook default versions
# NOTE: There is no images released for minor versions https://hub.docker.com/r/nfvpe/sriov-cni/tags
#sed -i "s/sriov_cni_version:.*/sriov_cni_version: v$(get_version github_tag k8snetworkplumbingwg/sriov-cni)/g" ./playbooks/roles/sriov_cni/defaults/main.yml
sed -i "s/criproxy_version:.*/criproxy_version: $(get_version github_tag Mirantis/criproxy)/g" ./playbooks/roles/criproxy/defaults/main.yml
sed -i "s/pmem_version:.*/pmem_version: v$(get_version github_tag intel/pmem-csi)/g" ./playbooks/roles/pmem/defaults/main.yml
sed -i "s/driver_registrar_version:.*/driver_registrar_version: v$(get_version github_tag kubernetes-csi/node-driver-registrar)/g" ./playbooks/roles/pmem/defaults/main.yml
sed -i "s/csi_provisioner_version:.*/csi_provisioner_version: v$(get_version github_tag kubernetes-csi/external-provisioner)/g" ./playbooks/roles/pmem/defaults/main.yml
sed -i "s/cfssl_version:.*/cfssl_version: $(get_version github_tag cloudflare/cfssl)/g" ./playbooks/roles/pmem/defaults/main.yml
sed -i "s/virtlet_version:.*/virtlet_version: $(get_version github_tag Mirantis/virtlet)/g" ./playbooks/roles/virtlet/defaults/main.yml
sed -i "s/sriov_plugin_version:.*/sriov_plugin_version: v$(get_version docker_tag nfvpe/sriov-device-plugin)/g" ./playbooks/roles/sriov_plugin/defaults/main.yml
sed -i "s/nfd_version:.*/nfd_version: v$(get_version github_release kubernetes-sigs/node-feature-discovery)/g" ./playbooks/roles/nfd/defaults/main.yml

# Update Kubernetes Collection dependencies
update_pip_pkg "kubernetes" "$(get_version github_release kubernetes-client/python)"
update_pip_pkg "openshift" "$(get_version github_release openshift/openshift-restclient-python)"

# Update Kubespray Default variables
sed -i "s/{KRD_CONTAINERD_VERSION:-.*/{KRD_CONTAINERD_VERSION:-$(get_version github_release containerd/containerd)}/g" ./defaults.env
sed -i "s/{KRD_CERT_MANAGER_VERSION:-.*/{KRD_CERT_MANAGER_VERSION:-v$(get_version github_release jetstack/cert-manager)}/g" ./defaults.env

# Update Checkov
wget -q -O ./resources/checkov-job.yaml https://raw.githubusercontent.com/bridgecrewio/checkov/master/kubernetes/checkov-job.yaml

# Update Metrics server
sed -i "s|image.tag=.*|image.tag=v$(get_version docker_tag rancher/metrics-server),args[0]='--kubelet-insecure-tls',args[1]='--kubelet-preferred-address-types=InternalIP'\" _install_chart metrics-server metrics-server/metrics-server default|g" _chart_installers.sh

# Update Rook test resources
wget -q -O ./tests/resources/rook/toolbox.yaml https://raw.githubusercontent.com/rook/rook/master/deploy/examples/toolbox.yaml
wget -q -O ./tests/resources/rook/cluster-test.yaml https://raw.githubusercontent.com/rook/rook/master/deploy/examples/cluster-test.yaml
