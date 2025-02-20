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
set -o pipefail
set -o nounset

source _commons.sh
if [[ $KRD_DEBUG == "true" ]]; then
    set -o xtrace
fi

# install_rundeck() - This function deploy a Rundeck instance
function install_rundeck {
    if rd version &>/dev/null; then
        return
    fi

    # shellcheck disable=SC1091
    source /etc/os-release || source /usr/lib/os-release
    case ${ID,,} in
    *suse) ;;

    ubuntu | debian)
        echo "deb https://rundeck.bintray.com/rundeck-deb /" | sudo tee -a /etc/apt/sources.list.d/rundeck.list
        curl 'https://bintray.com/user/downloadSubjectPublicKey?username=bintray' | sudo apt-key add -
        update_repos
        ;;
    rhel | centos | fedora)
        local java_version=1.8.0
        if ! command -v java; then
            _install_packages java-${java_version}-openjdk java-${java_version}-openjdk-devel
        fi
        sudo -E rpm -Uvh http://repo.rundeck.org/latest.rpm
        ;;
    esac
    _install_packages rundeck-cli rundeck

    sudo chown -R rundeck:rundeck /var/lib/rundeck/

    sudo service rundeckd start
    sleep 10
    while ! grep -q "Grails application running at" /var/log/rundeck/service.log; do
        sleep 5
    done
    sudo mkdir -p /home/rundeck/.ssh
    sudo cp "$HOME"/.ssh/id_rsa /home/rundeck/.ssh
    sudo chown -R rundeck:rundeck /home/rundeck/

    export RD_URL=http://localhost:4440
    export RD_USER=admin
    export RD_PASSWORD=admin
    echo "export RD_URL=$RD_URL" | sudo tee --append /etc/environment
    echo "export RD_USER=$RD_USER" | sudo tee --append /etc/environment
    echo "export RD_PASSWORD=$RD_PASSWORD" | sudo tee --append /etc/environment

    pushd "$KRD_FOLDER"/rundeck
    rd projects create --project krd --file krd.properties
    rd jobs load --project krd --file Deploy_Kubernetes.yaml --format yaml
    popd
}

# install_openstack() - Function that install OpenStack Controller services
function install_openstack {
    echo "Deploying openstack"
    local dest_folder=/opt

    KRD_HELM_VERSION=2 install_helm
    pkgs=""
    for pkg in git make jq nmap curl bc; do
        if ! command -v "$pkg"; then
            pkgs+=" $pkg"
        fi
    done
    if [ -n "$pkgs" ]; then
        curl -fsSL http://bit.ly/install_pkg | PKG=$pkgs bash
    fi

    kubectl create clusterrolebinding add-on-cluster-admin --clusterrole=cluster-admin --serviceaccount=kube-system:default
    # TODO: Improve how the roles are assigned to the nodes
    for label in openstack-control-plane=enabled openstack-compute-node=enable openstack-helm-node-class=primary openvswitch=enabled linuxbridge=enabled ceph-mon=enabled ceph-mgr=enabled ceph-mds=enabled; do
        kubectl label nodes "$label" --all --overwrite
    done

    if [[ ! -d "$dest_folder/openstack-helm-infra" ]]; then
        sudo -E git clone https://git.openstack.org/openstack/openstack-helm-infra "$dest_folder/openstack-helm-infra"
        sudo mkdir -p $dest_folder/openstack-helm-infra/tools/gate/devel/
        pushd $dest_folder/openstack-helm-infra/tools/gate/devel/
        sudo git checkout 70d93625e886a45c9afe2aa748228c39c5897e22 # 2020-01-21
        echo "proxy:" | sudo tee local-vars.yaml
        if [[ -n ${HTTP_PROXY} ]]; then
            echo "  http: $HTTP_PROXY" | sudo tee --append local-vars.yaml
        fi
        if [[ -n ${HTTPS_PROXY} ]]; then
            echo "  https: $HTTPS_PROXY" | sudo tee --append local-vars.yaml
        fi
        if [[ -n ${NO_PROXY} ]]; then
            echo "  noproxy: $NO_PROXY,.svc.cluster.local" | sudo tee --append local-vars.yaml
        fi
        popd
        sudo -H chown -R helm: "$dest_folder/openstack-helm-infra"
        pushd $dest_folder/openstack-helm-infra/
        sudo su helm -c "make helm-toolkit"
        sudo su helm -c "helm repo index /home/helm/.helm/repository/local/"
        sudo su helm -c "make all"
        popd
    fi

    if [[ ! -d "$dest_folder/openstack-helm" ]]; then
        sudo -E git clone https://git.openstack.org/openstack/openstack-helm "$dest_folder/openstack-helm"
        pushd $dest_folder/openstack-helm
        sudo git checkout 1258061410908f62c247b437fcb12d2e478ac42d # 2020-01-20
        sudo -H chown -R helm: "$dest_folder/openstack-helm"
        for script in $(find ./tools/deployment/multinode -name "??0-*.sh" | sort); do
            filename=$(basename -- "$script")
            echo "Executing $filename ..."
            sudo su helm -c "$script" | tee "$HOME/${filename%.*}.log"
        done
        popd
    fi
}

# install_harbor() - Function that installs Harbor Cloud Native registry project
function install_harbor {
    install_helm

    if ! helm repo list | grep -e harbor; then
        helm repo add harbor https://helm.goharbor.io
    fi
    if ! helm ls -qA | grep -q harbor; then
        helm upgrade --install harbor harbor/harbor \
            --wait
    fi
}

# install_octant() - Function that installs Octant which is a tool for developers to understand how applications run on a Kubernetes cluster
function install_octant {
    octant_version=$(_get_version octant)
    local filename="octant_${octant_version}_Linux-64bit"

    if command -v octant; then
        return
    fi

    pushd "$(mktemp -d)"
    # shellcheck disable=SC1091
    source /etc/os-release || source /usr/lib/os-release
    case ${ID,,} in
    ubuntu | debian)
        curl -Lo "$filename.deb" "https://github.com/vmware-tanzu/octant/releases/download/v$octant_version/$filename.deb"
        sudo dpkg -i "$filename.deb"
        ;;
    rhel | centos | fedora)
        curl -Lo "$filename.rpm" "https://github.com/vmware-tanzu/octant/releases/download/v$octant_version/$filename.rpm"
        sudo rpm -i "$filename.rpm"
        ;;
    esac
    rm "$filename".*
    popd
}

# install_kubelive() - Function that installs Kubelive tool
function install_kubelive {
    if command -v kubelive; then
        return
    fi

    if ! command -v npm; then
        curl -sL https://deb.nodesource.com/setup_6.x | sudo -E bash -
        _install_packages nodejs

        # Update NPM to latest version
        npm config set registry http://registry.npmjs.org/
        if [[ ${HTTP_PROXY+x} == "x" ]]; then
            npm config set proxy "$HTTP_PROXY"
        fi
        if [[ ${HTTPS_PROXY+x} == "x" ]]; then
            npm config set https-proxy "$HTTPS_PROXY"
        fi
        sudo npm install -g npm
    fi

    sudo npm install -g kubelive
}

# TODO: This function needs to be implemented as Ansible playbooks
# install_cockpit() - Function that installs Cockpit tool
function install_cockpit {
    if systemctl is-active --quiet cockpit; then
        return
    fi

    _install_packages cockpit
    if command -v firewall-cmd && systemctl is-active --quiet firewalld; then
        sudo firewall-cmd --permanent --add-service="cockpit" --zone=trusted
        sudo firewall-cmd --set-default-zone=trusted
        sudo firewall-cmd --reload
    fi
    sudo systemctl start cockpit
    sudo systemctl enable cockpit
}

# run_cnf_conformance - Installs and runs CNF Conformance binary
function run_cnf_conformance {
    local cnf_conformance_dir="/opt/cnf-conformance"
    local version="v0.6.0"

    install_helm

    if [ ! -d "$cnf_conformance_dir" ]; then
        sudo git clone --depth 1 https://github.com/cncf/cnf-conformance "$cnf_conformance_dir" -b "$version"
        pushd "$cnf_conformance_dir/cnfs"
        sudo git clone --depth 1 https://github.com/cncf/cnf-testbed/
        popd
        sudo chown -R "$USER" "$cnf_conformance_dir"
    fi

    # Install cnf_conformance binary
    pushd "$cnf_conformance_dir"
    if ! command -v cnf-conformance; then
        if [ "$KRD_CNF_CONFORMANCE_INSTALL_METHOD" == "source" ]; then
            if ! command -v crystal; then
                curl -fsSL http://bit.ly/install_pkg | PKG="crystal-lang" bash
            fi
            shards install
            crystal build src/cnf-conformance.cr --release --static
        else
            curl -sL -o cnf-conformance "https://github.com/cncf/cnf-conformance/releases/download/${version}/cnf-conformance"
            chmod +x cnf-conformance
        fi
        sudo cp cnf-conformance /usr/local/bin/cnf-conformance
    fi

    cnf-conformance setup
    while IFS= read -r -d '' file; do
        cnf-conformance cnf_setup cnf-config="$file"
    done < <(find ./example-cnfs -name cnf-conformance.yml -print0)
    popd
}

# install_ovn_metrics_dashboard() - Enables a Grafana dashboard
function install_ovn_metrics_dashboard {
    kube_ovn_version=$(_get_version kube-ovn)
    prometheus_operator_version=$(_get_version prometheus-operator)

    KRD_HELM_VERSION=2 install_helm

    if ! helm ls | grep -e metrics-dashboard; then
        helm install stable/grafana --name metrics-dashboard -f ./helm/kube-ovn/grafana.yml
    fi
    kubectl apply -f "https://raw.githubusercontent.com/coreos/prometheus-operator/${prometheus_operator_version}/bundle.yaml"
    if ! kubectl get namespaces 2>/dev/null | grep monitoring; then
        kubectl create namespace monitoring
    fi
    for resource in cni-monitor controller-monitor pinger-monitor; do
        kubectl apply -f "https://raw.githubusercontent.com/alauda/kube-ovn/${kube_ovn_version}/dist/monitoring/${resource}.yaml"
    done
}

# install_nsm() - Installs Network Service Mesh
function install_nsm {
    KRD_HELM_VERSION=2 install_helm

    # Add helm chart release repositories
    if ! helm repo list | grep -e nsm; then
        helm repo add nsm https://helm.nsm.dev/
        helm repo update
    fi

    # Install the nsm chart
    if ! helm ls | grep -e nsm; then
        helm install nsm/nsm --name nsm
    fi

    for daemonset in $(kubectl get daemonset | grep nsm | awk '{print $1}'); do
        echo "Waiting for $daemonset to successfully rolled out"
        if ! kubectl rollout status "daemonset/$daemonset" --timeout=5m >/dev/null; then
            echo "The $daemonset daemonset has not started properly"
            exit 1
        fi
    done
}

# install_velero() - Installs Velero solution
function install_velero {
    install_helm

    # Add helm chart release repositories
    if ! helm repo list | grep -e vmware-tanzu; then
        helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts
        helm repo update
    fi

    # Install the nsm chart
    if ! helm ls -qA | grep -q velero; then
        helm upgrade --install velero vmware-tanzu/velero \
            --wait
    fi
}

# TODO: Use resources folder to reduce KubeSphere installation instructions
# install_kubesphere() - Installs KubeSphere services
function install_kubesphere {
    kubesphere_version=$(_get_version kubesphere)

    kubectl apply -f "https://github.com/kubesphere/ks-installer/releases/download/$kubesphere_version/kubesphere-installer.yaml"
    kubectl rollout status deployment/ks-installer -n kubesphere-system --timeout=5m
    # editorconfig-checker-disable
    cat <<EOF | kubectl apply -f -
---
apiVersion: installer.kubesphere.io/v1alpha1
kind: ClusterConfiguration
metadata:
  name: ks-installer
  namespace: kubesphere-system
  labels:
    version: $kubesphere_version
spec:
  persistence:
    storageClass: ""        # If there is not a default StorageClass in your cluster, you need to specify an existing StorageClass here.
  authentication:
    jwtSecret: ""           # Keep the jwtSecret consistent with the host cluster. Retrive the jwtSecret by executing "kubectl -n kubesphere-system get cm kubesphere-config -o yaml | grep -v "apiVersion" | grep jwtSecret" on the host cluster.
  etcd:
    monitoring: false       # Whether to enable etcd monitoring dashboard installation. You have to create a secret for etcd before you enable it.
    endpointIps: localhost  # etcd cluster EndpointIps, it can be a bunch of IPs here.
    port: 2379              # etcd port
    tlsEnable: true
  common:
    mysqlVolumeSize: 20Gi # MySQL PVC size.
    minioVolumeSize: 20Gi # Minio PVC size.
    etcdVolumeSize: 20Gi  # etcd PVC size.
    openldapVolumeSize: 2Gi   # openldap PVC size.
    redisVolumSize: 2Gi # Redis PVC size.
    es:   # Storage backend for logging, events and auditing.
      # elasticsearchMasterReplicas: 1   # total number of master nodes, it's not allowed to use even number
      # elasticsearchDataReplicas: 1     # total number of data nodes.
      elasticsearchMasterVolumeSize: 4Gi   # Volume size of Elasticsearch master nodes.
      elasticsearchDataVolumeSize: 20Gi    # Volume size of Elasticsearch data nodes.
      logMaxAge: 7                     # Log retention time in built-in Elasticsearch, it is 7 days by default.
      elkPrefix: logstash              # The string making up index names. The index name will be formatted as ks-<elk_prefix>-log.
  console:
    enableMultiLogin: true  # enable/disable multiple sing on, it allows an account can be used by different users at the same time.
    port: 30880
  alerting:                # (CPU: 0.3 Core, Memory: 300 MiB) Whether to install KubeSphere alerting system. It enables Users to customize alerting policies to send messages to receivers in time with different time intervals and alerting levels to choose from.
    enabled: false
  auditing:                # Whether to install KubeSphere audit log system. It provides a security-relevant chronological set of records，recording the sequence of activities happened in platform, initiated by different tenants.
    enabled: false
  devops:                  # (CPU: 0.47 Core, Memory: 8.6 G) Whether to install KubeSphere DevOps System. It provides out-of-box CI/CD system based on Jenkins, and automated workflow tools including Source-to-Image & Binary-to-Image.
    enabled: $KRD_KUBESPHERE_DEVOPS_ENABLED
    jenkinsMemoryLim: 2Gi      # Jenkins memory limit.
    jenkinsMemoryReq: 1500Mi   # Jenkins memory request.
    jenkinsVolumeSize: 8Gi     # Jenkins volume size.
    jenkinsJavaOpts_Xms: 512m  # The following three fields are JVM parameters.
    jenkinsJavaOpts_Xmx: 512m
    jenkinsJavaOpts_MaxRAM: 2g
  events:                  # Whether to install KubeSphere events system. It provides a graphical web console for Kubernetes Events exporting, filtering and alerting in multi-tenant Kubernetes clusters.
    enabled: false
    ruler:
      enabled: true
      replicas: 2
  logging:                 # (CPU: 57 m, Memory: 2.76 G) Whether to install KubeSphere logging system. Flexible logging functions are provided for log query, collection and management in a unified console. Additional log collectors can be added, such as Elasticsearch, Kafka and Fluentd.
    enabled: false
    logsidecarReplicas: 2
  metrics_server:                    # (CPU: 56 m, Memory: 44.35 MiB) Whether to install metrics-server. IT enables HPA (Horizontal Pod Autoscaler).
    enabled: $KRD_KUBESPHERE_METRICS_SERVER_ENABLED
  monitoring:
    # prometheusReplicas: 1            # Prometheus replicas are responsible for monitoring different segments of data source and provide high availability as well.
    prometheusMemoryRequest: 400Mi   # Prometheus request memory.
    prometheusVolumeSize: 20Gi       # Prometheus PVC size.
    # alertmanagerReplicas: 1          # AlertManager Replicas.
  multicluster:
    clusterRole: none  # host | member | none  # You can install a solo cluster, or specify it as the role of host or member cluster.
  networkpolicy:       # Network policies allow network isolation within the same cluster, which means firewalls can be set up between certain instances (Pods).
    # Make sure that the CNI network plugin used by the cluster supports NetworkPolicy. There are a number of CNI network plugins that support NetworkPolicy, including Calico, Cilium, Kube-router, Romana and Weave Net.
    enabled: false
  notification:        # Email Notification support for the legacy alerting system, should be enabled/disabled together with the above alerting option.
    enabled: false
  openpitrix:          # (2 Core, 3.6 G) Whether to install KubeSphere Application Store. It provides an application store for Helm-based applications, and offer application lifecycle management.
    enabled: false
  servicemesh:         # (0.3 Core, 300 MiB) Whether to install KubeSphere Service Mesh (Istio-based). It provides fine-grained traffic management, observability and tracing, and offer visualization for traffic topology.
    enabled: $KRD_KUBESPHERE_SERVICEMESH_ENABLED
EOF
    # editorconfig-checker-enable
    for namespace in "" -controls -monitoring -devops; do
        if kubectl get "namespace/kubesphere$namespace-system" --no-headers -o custom-columns=name:.metadata.name; then
            for deployment in $(kubectl get deployments --no-headers -o custom-columns=name:.metadata.name -n "kubesphere$namespace-system"); do
                kubectl rollout status "deployment/$deployment" -n "kubesphere$namespace-system" --timeout=5m
            done
        fi
    done
    echo "Track deployment process with: "
    echo "  kubectl logs -n kubesphere-system $(kubectl get pod -n kubesphere-system -l app=ks-install -o jsonpath='{.items[0].metadata.name}') -f"
    echo "KubeSphere web console: http://$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}'):30880/login"
    echo "KubeSphere 'admin' user with 'P@88w0rd' password"
}
