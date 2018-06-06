# Kubernetes Reference Deployment

## Summary

This project offers a reference for deployment a Kubernetes cluster
that satisfies the requirements of [ONAP multicloud/k8s plugin][1]. Its
ansible playbooks allow to provision a deployment on Bare-metal or
Virtual Machines.

![Diagram](docs/src/img/diagram.png)

# Components

| Name           | Description                                   | Source                            | Status |
|:--------------:|:----------------------------------------------|:----------------------------------|:------:|
| Kubernetes     | Base Kubernetes deployment                    | [kubespray][2]                    | Done   |
| OVN            | Opensource Virtual Networking for OpenvSwitch | [configure-ovn.yml][3]            | Done   |
| ovn-kubernetes | Integrates Opensource Virtual Networking      | [configure-ovn-kubernetes.yml][4] | Done   |
| Virtlet        | Allows to run VMs                             | [virtlet][5]                      |        |
| CRI Proxy      | Makes possible to run several CRIs            | [virtlet][5]                      |        |
| Multus         | Provides Multiple Network support in a pod    | [multus-cni][7]                   |        |

## Deployment

### Virtual Machines

    $ git clone http://github.com/electrocucaracha/vagrant-k8s
    $ cd vagrant-k8s
    $ ./setup.sh -p libvirt
    $ vagrant up
    $ vagrant up installer

## License

Apache-2.0

[1]: https://git.onap.org/multicloud/k8s
[2]: https://github.com/kubernetes-incubator/kubespray
[3]: playbooks/configure-ovn.yml
[4]: playbooks/configure-ovn-kubernetes.yml
[5]: https://github.com/Mirantis/virtlet
[6]: https://github.com/Mirantis/criproxy
[7]: https://github.com/intel/multus-cni
