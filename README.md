# Kubernetes Reference Deployment
[![Build Status](https://travis-ci.org/electrocucaracha/krd.png)](https://travis-ci.org/electrocucaracha/krd)

## Summary

This project offers a reference for deploying a Kubernetes cluster.
Its ansible playbooks allow to provision a deployment on Bare-metal
or Virtual Machines.

# Components

| Name           | Description                                    | Source                            | Status      |
|:--------------:|:-----------------------------------------------|:----------------------------------|:-----------:|
| Kubernetes     | Base Kubernetes deployment                     | [kubespray][1]                    | Done        |
| Virtlet        | Allows to run VMs                              | [configure-virtlet.yml][3]        | Tested      |
| Multus         | Provides Multiple Network support in a pod     |                                   | Tested      |
| NFD            | Node feature discovery                         | [nfd role][4]                     | Tested      |
| Istio          | Service Mesh platform                          |                                   | Tested      |
| PMEM           | Persistent Memory CSI                          | [pmem role][6]                    | Implemented |
| QAT            | QuickAssist Technology Plugin                  | [qat_plugin role][8]              | Implemented |
| SR-IOV         | Single Root Input/Output Virtualization Plugin | [sriov_plugin role][9]            | Implemented |

## Deployment

The [installer](installer.sh) bash script contains the minimal
Ubuntu instructions required for running this project.

### Virtual Machines

This project uses [Vagrant tool][5] for provisioning Virtual Machines
automatically. The *setup.sh* script of the
[bootstrap-vagrant project][7] contains the Linux instructions to
install dependencies and plugins required for its usage. This script
supports two Virtualization technologies (Libvirt and VirtualBox).

    $ curl -fsSL https://raw.githubusercontent.com/electrocucaracha/bootstrap-vagrant/master/setup.sh | PROVIDER=libvirt bash

Once Vagrant is installed, it's possible to provision a cluster using
the following instructions:

    $ vagrant up && vagrant up installer

![Provisioning](docs/src/img/provisioning.png)

## Install KRD actions

The [KRD command script](krd_command.sh) provides an easy way to
install complementary Kubernetes projects to an existing cluster.
Those projects are grouped in KRD actions and it's possible to get
the current list of current supported actions executing the following
instruction:

    $ ./krd_command.sh -h

The actions which require the execution of a distributed commands were
implemented through the **install_k8s_addons** KRD action. This action
uses the *KRD_ADDONS* environment variable to specify the Ansible
playbook to be executed.

    $ KRD_ADDONS=nfd ./krd_command.sh -a install_k8s_addons

*Note:* Some KRD AddOns have a corresponding validation script in the
[tests](tests) folder.

## Day-2 Operations

The functions defined in this project covers the life-cycle of a
Kubernetes cluster. In other words, its possible to add more nodes,
upgrade the existing deployment or remove the services.  The following
instruction shows how to upgrade the existing Kubernetes cluster to
*v1.15.3* using the Kubespray version *v2.11.0*:

    $ KRD_KUBE_VERSION=v1.15.3 KRD_KUBESPRAY_VERSION=v2.11.0 ./krd_command.sh -a upgrade_k8s

### Environment variables

| Name                   | Default     | Description                                                           |
|:-----------------------|:------------|:----------------------------------------------------------------------|
| KRD_DEBUG              | false       | Enables verbose execution                                             |
| KRD_KUBE_VERSION       |             | Specifies the Kubernetes version to be upgraded                       |
| KRD_KUBESPRAY_VERSION  |             | Specifies the Kubespray version to be used during the upgrade process |
| KRD_ENABLE_TESTS       |             | Enables the functional tests during the deployment process            |
| KRD_HELM_CHART         |             | Specifies the Helm chart to be installed                              |
| KRD_FOLDER             | /opt/krd    | KRD source code destination folder                                    |
| KRD_ACTIONS            | install_k8s | KRD actions to be installed during the All-in-One execution           |
| KRD_CONTAINER_RUNTIME  | docker      | Specifies the Container Runtime to be used for deploying kubernetes   |
| KRD_NETWORK_PLUGIN     | flannel     | Choose network plugin (calico, canal, cilium, contiv, flannel weave)  |

## License

Apache-2.0

[1]: https://github.com/kubernetes-sigs/kubespray
[3]: playbooks/configure-virtlet.yml
[4]: playbooks/roles/nfd
[5]: https://www.vagrantup.com/
[6]: playbooks/roles/pmem
[7]: https://github.com/electrocucaracha/bootstrap-vagrant
[8]: playbooks/roles/qat_plugin
[9]: playbooks/roles/sriov_plugin
