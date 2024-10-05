# Virtlet

It is a Kubernetes runtime server which allows you to run VM
workloads, based on QCOW2 images.

The following figure provides a general view of Virtlet architecture:

![Virtlet architecture](../../../docs/src/img/virtlet.png)

Virtlet consists of the following components:

- Virtlet manager which implements CRI interface for virtualization
  and image handling.
- libvirt instance.
- vmwrapper which is responsible for setting up the environment for
  emulator.
- the emulator, currently qemu with KVM support (with a possibility
  to disable KVM).

> Note: The [multus-cni fix](https://github.com/Mirantis/virtlet/commit/c1880f37149547931832c0e77d5d853b164f150e)
> has not been added in this release yet.
