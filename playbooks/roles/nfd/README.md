# Node Feature Discovery

Node Feature Discovery (NFD) is a Kubernetes add-on that detects and
advertises hardware and software capabilities of a platform that can,
in turn, be used to facilitate intelligent scheduling of a workload.

This is a SIG-node subproject, hosted under the Kubernetes SIGs
[organization in GitHub][1]. The project was established in 2016 as a
Kubernetes Incubator project and migrated to Kubernetes SIGs in 2018.

In a standard deployment, Kubernetes reveals very few details about
the underlying platform to the user. This may be a good strategy for
general data center use, but, in many cases a workload behavior or its
performance, may improve by leveraging the platform (hardware and/or
software) features. Node Feature Discovery detects these features and
advertises them through a Kubernetes concept called node labels which,
in turn, can be used to control workload placement in a Kubernetes
cluster. NFD runs as a separate container on each individual node of
the cluster, discovers capabilities of the node, and finally,
publishes these as node labels using the Kubernetes API.

NFD only handles non-allocatable features, that is, unlimited
capabilities that do not require any accounting and are available to
all workloads. Allocatable resources that require accounting,
initialization and other special handling (such as Intel® QuickAssist
Technology, GPUs, and FPGAs) are presented as Kubernetes Extended
Resources and handled by device plugins. They are out of the scope of
NFD.

[1]: https://github.com/kubernetes-sigs/node-feature-discovery
