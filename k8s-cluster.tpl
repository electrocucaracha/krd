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
kube_version: v1.21.5

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

# Local volume provisioner deployment
local_volume_provisioner_enabled: $KRD_LOCAL_VOLUME_PROVISIONER_ENABLED

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

# gVisor is an application kernel, written in Go, that implements a substantial portion of the Linux system call interface.
gvisor_enabled: $KRD_GVISOR_ENABLED

# The Mount propagation feature allows for sharing volumes mounted by
# a container to other containers in the same pod, or even to other
# pods on the same node
docker_mount_flags: shared

# Should be set to a cluster IP if using a custom cluster DNS
manual_dns_server: ""

# Flannel may be paired with several different backends.
# default - VXLAN is the recommended choice.
# host-gw is recommended for more experienced users who want the performance
# improvement and whose infrastructure support it (typically it can't be used in
# cloud environments).
# UDP is suggested for debugging only or for very old kernels that don't support VXLAN.
flannel_backend_type: $KRD_FLANNEL_BACKEND_TYPE

# Specify version of Docker to used (should be quoted string).
docker_version: "$KRD_DOCKER_VERSION"

# Specify version of ContainerD to used (should be quoted string).
containerd_version: "$KRD_CONTAINERD_VERSION"

# Override auto-detection of MTU by providing an explicit value if needed.
calico_mtu: 1500

# Enable nodelocal to make pods reach out to the dns (core-dns) caching agent
# running on the same node, thereby avoiding iptables DNAT rules and connection tracking.
enable_nodelocaldns: $KRD_ENABLE_NODELOCALDNS

# sets a threshold for the number of dots which must appear in a name before an
# initial absolute query will be made. The default for n is 1, meaning that if
# there are any dots in a name, the name will be tried first as an absolute name
# before any search list elements are appended to it.
ndots: $KRD_NDOTS

# configures how will be setup DNS for `hostNetwork: true` PODs and non-k8s containers.
resolvconf_mode: $KRD_RESOLVCONF_MODE

# The ipvs scheduler type when proxy mode is ipvs
# rr: Round Robin distributes jobs equally amongst the available real servers.
# lc: Least-Connection assigns more jobs to real servers with fewer active jobs.
# dh: Destination Hashing assigns jobs to servers through looking up a statically assigned hash table by their destination IP addresses.
# sh: Source Hashing assigns jobs to servers through looking up a statically assigned hash table by their source IP addresses.
# sed: Shortest Expected Delay assigns an incoming job to the server with the shortest expected delay.
# nq: Never Queue assigns an incoming job to an idle server if there is, instead of waiting for a fast one; if all the servers are busy, it adopts the Shortest Expected Delay policy to assign the job.
kube_proxy_scheduler: $KRD_KUBE_PROXY_SCHEDULER

kube_feature_gates:
  - EphemeralContainers=$KRD_EPHEMERAL_CONTAINERS_ENABLED # Ability to add ephemeral containers to running pods.

# configure arp_ignore and arp_announce to avoid answering ARP queries from kube-ipvs0 interface
# must be set to true for MetalLB to work
kube_proxy_strict_arp: $KRD_METALLB_ENABLED

# Enables MetalLB deployment
metallb_enabled: $KRD_METALLB_ENABLED

# Enables Kubernetes Auditing
kubernetes_audit: $KRD_KUBERNETES_AUDIT

# Enables Kubernetes Webhook Audit backend
kubernetes_audit_webhook: $KRD_KUBERNETES_AUDIT_WEBHOOK
audit_webhook_server_url: $KRD_AUDIT_WEBHOOK_SERVER_URL

# Maximum number of container log files that can be present for a container.
kubelet_logfiles_max_nr: $KRD_KUBELET_LOGFILES_MAX_NR

# Maximum size of the container log file before it is rotated
kubelet_logfiles_max_size: $KRD_KUBELET_LOGFILES_MAX_SIZE
