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
if [[ ${DEBUG:-false} == "true" ]]; then
    set -o xtrace
fi

trap "make fmt" EXIT

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
        elif [ ${attempt_counter} -eq ${max_attempts} ]; then
            echo "Max attempts reached"
            exit 1
        fi
        attempt_counter=$((attempt_counter + 1))
        sleep $((attempt_counter * 2))
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
        echo "$tags" | grep -Po '"name":.*?[^\\]",' | awk -F '"' 'NR==1{print $4}'
    fi
}

function _get_latest_ansible_role {
    curl -sfL "https://galaxy.ansible.com/api/v1/roles/?owner__username=${1%.*}&name=${1#*.}" | jq -r '.results[0].summary_fields.versions[0].name'
}

function _get_latest_ansible_collection {
    curl -sfL "https://galaxy.ansible.com/api/v3/collections/${1%.*}/${1#*.}/versions" | jq -r '.data[0].version'
}

function _get_latest_docker_tag {
    curl -sfL "https://registry.hub.docker.com/v2/repositories/$1/tags" | python -c 'import json,sys,re;versions=[obj["name"] for obj in json.load(sys.stdin)["results"] if re.match("^v?(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$",obj["name"])];print("\n".join(versions))' | uniq | sort -rn | head -n 1
}

function set_kubespray_img_version {
    local img_versions="$1"
    local image="$2"
    local kubespray_key="$3"

    sed -i "s/$image:.*/$image:$(echo "$img_versions" | grep "$kubespray_key" | awk '{ print $2}' | tr -d '"{}')/g" ./kubespray_images.tpl
}

function update_pip_pkg {
    local pkg="$1"
    local version="$2"

    while IFS= read -r playbook; do
        sed -i "s/$pkg==.*/$pkg==$version/g" "$playbook"
    done < <(grep -r "$pkg==" ./playbooks/ | awk -F ':' '{ print $1}')
}

# _vercmp() - Function that compares two versions
function _vercmp {
    local v1=$1
    local op=$2
    local v2=$3
    local result

    # sort the two numbers with sort's "-V" argument.  Based on if v2
    # swapped places with v1, we can determine ordering.
    result=$(echo -e "$v1\n$v2" | sort -V | head -1)

    case $op in
    "==")
        [ "$v1" = "$v2" ]
        return
        ;;
    ">")
        [ "$v1" != "$v2" ] && [ "$result" = "$v2" ]
        return
        ;;
    "<")
        [ "$v1" != "$v2" ] && [ "$result" = "$v1" ]
        return
        ;;
    ">=")
        [ "$result" = "$v2" ]
        return
        ;;
    "<=")
        [ "$result" = "$v1" ]
        return
        ;;
    *)
        echo "unrecognised op: $op"
        exit 1
        ;;
    esac
}

kubespray_version="$(get_version github_release kubernetes-sigs/kubespray)"
sed -i "s/kubespray_version:.*/kubespray_version: v$kubespray_version/g" ./playbooks/krd-vars.yml
sed -i "s/KRD_KUBESPRAY_VERSION                 |.*/KRD_KUBESPRAY_VERSION                 | v$kubespray_version                                        | Specifies the Kubespray version to be used during the upgrade process           |/g" README.md
sed -i "s/KRD_KUBESPRAY_VERSION:-.* \"\$(git describe --abbrev=0 --tags)\"/KRD_KUBESPRAY_VERSION:-v$kubespray_version}\" \"\$(git describe --abbrev=0 --tags)\"/g" ./ci/check.sh
sed -i "s/KRD_KUBESPRAY_VERSION:-.* \"\$(\$VAGRANT_CMD_SSH_INSTALLER \"cd \/opt\/kubespray; git describe --abbrev=0 --tags\")\"/KRD_KUBESPRAY_VERSION:-v$kubespray_version}\" \"\$(\$VAGRANT_CMD_SSH_INSTALLER \"cd \/opt\/kubespray; git describe --abbrev=0 --tags\")\"/g" ./ci/check.sh

# Image versions
kubespray_url="https://raw.githubusercontent.com/kubernetes-sigs/kubespray/v$kubespray_version/roles/download/defaults/main.yml"
if _vercmp "$kubespray_version" '>=' '2.25.0'; then
    kubespray_url="https://raw.githubusercontent.com/kubernetes-sigs/kubespray/v$kubespray_version/roles/kubespray-defaults/defaults/main/download.yml"
fi
kubespray_defaults=$(curl -sfL "$kubespray_url" | grep -e "^[a-zA-Z].*_version: " -e "^[a-zA-Z].*image_tag: ")
set_kubespray_img_version "$kubespray_defaults" "k8s-dns-node-cache" "nodelocaldns_version"
set_kubespray_img_version "$kubespray_defaults" "controller" "ingress_nginx_version"
set_kubespray_img_version "$kubespray_defaults" "local-volume-provisioner" "local_volume_provisioner_version"
for img in cainjector controller webhook; do
    set_kubespray_img_version "$kubespray_defaults" "cert-manager-$img" "cert_manager_version"
done

sed -i "s/kpt_version:.*/kpt_version: $(get_version github_release kptdev/kpt)/g" ./playbooks/krd-vars.yml
sed -i "s/istio_version:.*/istio_version: $(get_version github_release istio/istio)/g" ./playbooks/krd-vars.yml
sed -i "s/cfssl_version:.*/cfssl_version: $(get_version github_release cloudflare/cfssl)/g" ./playbooks/krd-vars.yml
sed -i "s/sonobuoy_version:.*/sonobuoy_version: $(get_version github_release vmware-tanzu/sonobuoy)/g" ./playbooks/krd-vars.yml

# Knative versions
sed -i "s/kn_version:.*/kn_version: $(get_version github_release knative/client)/g" ./playbooks/krd-vars.yml
sed -i "s/knative_serving_version:.*/knative_serving_version: $(get_version github_release knative/serving)/g" ./playbooks/krd-vars.yml
sed -i "s/knative_eventing_version:.*/knative_eventing_version: v$(get_version github_tag knative/eventing)/g" ./playbooks/krd-vars.yml
sed -i "s/net_kourier_version:.*/net_kourier_version: $(get_version github_release knative-sandbox/net-kourier)/g" ./playbooks/krd-vars.yml
sed -i "s/net_istio_version:.*/net_istio_version: v$(get_version github_release knative-sandbox/net-istio)/g" ./playbooks/krd-vars.yml
sed -i "s/net_certmanager_version:.*/net_certmanager_version: v$(get_version github_release knative-sandbox/net-certmanager)/g" ./playbooks/krd-vars.yml

sed -i "s/octant_version:.*/octant_version: $(get_version github_release vmware-tanzu/octant)/g" ./playbooks/krd-vars.yml
sed -i "s/kube-ovn_version:.*/kube-ovn_version: v$(get_version github_release kubeovn/kube-ovn)/g" ./playbooks/krd-vars.yml
sed -i "s/prometheus-operator_version:.*/prometheus-operator_version: v$(get_version github_tag prometheus-operator/prometheus-operator)/g" ./playbooks/krd-vars.yml
sed -i "s/kubevirt_version:.*/kubevirt_version: v$(get_version github_release kubevirt/kubevirt)/g" ./playbooks/krd-vars.yml
sed -i "s/containerized_data_importer_version:.*/containerized_data_importer_version: v$(get_version github_release kubevirt/containerized-data-importer)/g" ./playbooks/krd-vars.yml
sed -i "s/virtink_version:.*/virtink_version: v$(get_version github_release smartxworks/virtink)/g" ./playbooks/krd-vars.yml
sed -i "s/kubesphere_version:.*/kubesphere_version: v$(get_version github_release kubesphere/kubesphere)/g" ./playbooks/krd-vars.yml
sed -i "s/metallb_version:.*/metallb_version: v$(get_version github_tag metallb/metallb)/g" ./playbooks/krd-vars.yml
sed -i "s/argocd_version:.*/argocd_version: v$(get_version github_tag argoproj/argo-cd)/g" ./playbooks/krd-vars.yml
sed -i "s/tekton_version:.*/tekton_version: v$(get_version github_tag tektoncd/operator)/g" ./playbooks/krd-vars.yml
sed -i "s/kubevirt_tekton_tasks_version:.*/kubevirt_tekton_tasks_version: v$(get_version github_tag kubevirt/kubevirt-tekton-tasks)/g" ./playbooks/krd-vars.yml

# editorconfig-checker-disable
cat <<EOT >galaxy-requirements.yml
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
  - name: andrewrothstein.gcc-toolbox
    version: v$(get_version ansible_role andrewrothstein.gcc-toolbox)
  - name: andrewrothstein.kind
    version: v$(get_version ansible_role andrewrothstein.kind)
  - name: andrewrothstein.kubectl
    version: v$(get_version ansible_role andrewrothstein.kubectl)

collections:
  - name: kubernetes.core
    version: $(get_version ansible_collection kubernetes.core)
  - name: community.docker
    version: $(get_version ansible_collection community.docker)
  - name: ansible.posix
    version: $(get_version ansible_collection ansible.posix)
  - name: community.general
    version: $(get_version ansible_collection community.general)
EOT
# editorconfig-checker-enable

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

# Update Kubespray Default variables
sed -i "s/{KRD_CERT_MANAGER_VERSION:-.*/{KRD_CERT_MANAGER_VERSION:-v$(get_version github_release jetstack/cert-manager)}/g" ./defaults.env

# Update Checkov
wget -q -O ./resources/checkov-job.yaml https://raw.githubusercontent.com/bridgecrewio/checkov/master/kubernetes/checkov-job.yaml

# Update Metrics server
sed -i "s|image.tag=.*|image.tag=v$(get_version docker_tag rancher/metrics-server),args[0]='--kubelet-insecure-tls',args[1]='--kubelet-preferred-address-types=InternalIP'\" _install_chart metrics-server metrics-server/metrics-server default|g" _chart_installers.sh

# Update Rook test resources
rook_version=$(get_version github_tag rook/rook)
wget -q -O ./tests/resources/rook/cluster-test.yaml "https://raw.githubusercontent.com/rook/rook/refs/tags/v$rook_version/deploy/examples/cluster-test.yaml"
sed -i 's|dataDirHostPath: .*|dataDirHostPath: /var/lib/csi-block|g' ./tests/resources/rook/cluster-test.yaml
wget -q -O ./resources/storageclass.yml "https://raw.githubusercontent.com/rook/rook/refs/tags/v$rook_version/deploy/examples/csi/rbd/storageclass.yaml"

# Update K8sGPT resources
k8sgpt_version=$(get_version github_release k8sgpt-ai/k8sgpt)
sed -i "s/version: .*/version: v$k8sgpt_version/g" resources/k8sgpt-localai.yml
sed -i "s/version: .*/version: v$k8sgpt_version/g" resources/k8sgpt-ollama.yml

# Update GitHub Action commit hashes
gh_actions=$(grep -r "uses: [a-zA-Z\-]*/[\_a-z\-]*@" .github/ | sed 's/@.*//' | awk -F ': ' '{ print $3 }' | sort -u)
for action in $gh_actions; do
    commit_hash=$(git ls-remote "https://github.com/$action" | grep 'refs/tags/[v]\?[0-9][0-9\.]*$' | sed 's|refs/tags/[vV]\?[\.]\?||g' | sort -u -k2 -V | tail -1 | awk '{ printf "%s # %s\n",$1,$2 }')
    # shellcheck disable=SC2267
    grep -ElRZ "uses: $action@" .github/ | xargs -0 -l sed -i -e "s|uses: $action@.*|uses: $action@$commit_hash|g"
done
