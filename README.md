# Kubernetes Reference Deployment
[![Build Status](https://travis-ci.org/electrocucaracha/krd.png)](https://travis-ci.org/electrocucaracha/krd)

## Summary

This project offers a reference for deploying a Kubernetes cluster.
Its ansible playbooks allow to provision a deployment on Bare-metal
or Virtual Machines.

# Components

| Name           | Description                                   | Source                            | Status      |
|:--------------:|:----------------------------------------------|:----------------------------------|:-----------:|
| Kubernetes     | Base Kubernetes deployment                    | [kubespray][2]                    | Done        |
| ovn-kubernetes | Integrates Opensource Virtual Networking      | [configure-ovn-kubernetes.yml][3] | Tested      |
| Virtlet        | Allows to run VMs                             | [configure-virtlet.yml][4]        | Tested      |
| NFD            | Node feature discovery                        | [configure-nfd.yml][7]            | Tested      |
| Istio          | Service Mesh platform                         | [configure-istio.yml][8]          | Tested      |

## Deployment

The [installer](installer.sh) bash script contains the minimal
Ubuntu instructions required for running this project.

### Virtual Machines

This project uses [Vagrant tool][6] for provisioning Virtual Machines
automatically. The [setup](setup.sh) bash script contains the
Linux instructions to install dependencies and plugins required for
its usage. This script supports two Virtualization technologies
(Libvirt and VirtualBox).

    $ ./setup.sh -p libvirt

Once Vagrant is installed, it's possible to provision a cluster using
the following instructions:

    $ vagrant up && vagrant up installer

![Provisioning](docs/src/img/provisioning.png)

## License

Apache-2.0

[2]: https://github.com/kubernetes-sigs/kubespray
[3]: playbooks/configure-ovn-kubernetes.yml
[4]: playbooks/configure-virtlet.yml
[5]: playbooks/configure-multus.yml
[6]: https://www.vagrantup.com/
[8]: playbooks/configure-istio.yml
