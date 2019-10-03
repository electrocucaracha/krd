# SR-IOV Network Device Plugin

The Single Root I/O Virtualization (SR-IOV) technology provides the
ability to partition a single physical PCI resource device into
virtual PCI functions (VFs) which can then be injected into a VM
and/or Kubernetes pod. In the case of network VFs, SR-IOV improves
north-south network performance by allowing traffic to bypass the
host machine’s network stack.

The SR-IOV network device plugin discovers and registers available
SR-IOV capable VFs in host machine to Kubernetes API as extended
resources. Pods that require one or more SR-IOV VFs will request for
these VFs in their specification. Kubelet takes care of resource
allocation and accounting of all VFs that registered with the SR-IOV
network device plugin.

This role deploys the SR-IOV Network Device Plugin in Kubernetes.
