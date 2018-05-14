# Kubernetes Reference Deployment

This project pretends to create a Kubernetes reference deployment in
a distributed setup environment. It uses [kubespray][1] tool to make
the base deployment and installs [ovn-kubernetes][2]

## Requirements

  * [Vagrant][3]
  * [VirtualBox][4] or [Libvirt][5]

## Execution

    $ git clone http://github.com/electrocucaracha/vagrant-k8s
    $ cd vagrant-k8s
    $ ./setup.sh -p libvirt
    $ vagrant up

## License

Apache-2.0

[1]: https://github.com/kubernetes-incubator/kubespray
[2]: https://github.com/openvswitch/ovn-kubernetes
[3]: https://www.vagrantup.com/downloads.html
[4]: https://www.virtualbox.org/wiki/Downloads
[5]: http://libvirt.org/downloads.html
