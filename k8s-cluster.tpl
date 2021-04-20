---
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2018
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

# Kubernetes configuration dirs and system namespace.
# Those are where all the additional config stuff goes
# kubernetes normally puts in /srv/kubernetes.
# This puts them in a sane location and namespace.
# Editing those values will almost surely break something.
system_namespace: kube-system

# Logging directory (sysvinit systems)
kube_log_dir: "/var/log/kubernetes"

kube_api_anonymous_auth: true

# Users to create for basic auth in Kubernetes API via HTTP
# Optionally add groups for user
kube_api_pwd: "secret"
kube_users:
  kube:
    pass: "{{ kube_api_pwd }}"
    role: admin
    groups:
      - system:masters

# It is possible to activate / deactivate selected authentication methods (basic auth, static token auth)
kube_basic_auth: false
kube_token_auth: false

# Choose network plugin (calico, contiv, weave or flannel)
# Can also be set to 'cloud', which lets the cloud provider setup appropriate routing
kube_network_plugin: $KRD_NETWORK_PLUGIN

# Make a copy of kubeconfig on the host that runs Ansible in GITDIR/artifacts
kubeconfig_localhost: true

# Change this to use another Kubernetes version, e.g. a current beta release
kube_version: v1.19.9

# Kube-proxy proxyMode configuration.
# NOTE: Ipvs is based on netfilter hook function, but uses hash table as the underlying data structure and
# works in the kernel space
# https://kubernetes.io/docs/concepts/services-networking/service/#proxy-mode-ipvs
kube_proxy_mode: $KRD_KUBE_PROXY_MODE

# Download container images only once then push to cluster nodes in batches
download_run_once: $KRD_DOWNLOAD_RUN_ONCE

# Where the binaries will be downloaded.
# Note: ensure that you've enough disk space (about 1G)
local_release_dir: "/tmp/releases"

# Helm deployment
helm_enabled: false

# Enable MountPropagation gate feature
local_volumes_enabled: true
local_volume_provisioner_enabled: true

# Makes the installer node a delegate for pushing images while running
# the deployment with ansible. This maybe the case if cluster nodes
# cannot access each over via ssh or you want to use local docker
# images as a cache for multiple clusters.
download_localhost: $KRD_DOWNLOAD_LOCALHOST

# Enable Multus
kube_network_plugin_multus: $KRD_MULTUS_ENABLED

# Download kubectl onto the host that runs Ansible in {{ bin_dir }}
kubectl_localhost: false

# Settings for containerized control plane (etcd/kubelet/secrets)
etcd_deployment_type: $KUBESPRAY_ETCD_KUBELET_DEPLOYMENT_TYPE

# Controls which platform to deploy kubelet on. Available options are host, rkt, and docker.
kubelet_deployment_type: $KUBESPRAY_ETCD_KUBELET_DEPLOYMENT_TYPE

# Container for runtime
container_manager: $KRD_CONTAINER_RUNTIME

# Rook requires a FlexVolume plugin directory to integrate with K8s for performing storage operations
kubelet_flexvolumes_plugins_dir: /usr/libexec/kubernetes/kubelet-plugins/volume/exec

# Dashboard
dashboard_enabled: $KRD_DASHBOARD_ENABLED
dashboard_skip_login: true

# Cert manager deployment
cert_manager_enabled: $KRD_CERT_MANAGER_ENABLED

# Nginx ingress controller deployment
ingress_nginx_enabled: $KRD_INGRESS_NGINX_ENABLED

# Kata Containers is an OCI runtime, where containers are run inside lightweight VMs
kata_containers_enabled: $KRD_KATA_CONTAINERS_ENABLED

# crun is a container runtime which has lower footprint, better performance and cgroup2 support
crun_enabled: $KRD_CRUN_ENABLED

# The Mount propagation feature allows for sharing volumes mounted by
# a container to other containers in the same pod, or even to other
# pods on the same node
docker_mount_flags: shared

# Should be set to a cluster IP if using a custom cluster DNS
manual_dns_server: ""
