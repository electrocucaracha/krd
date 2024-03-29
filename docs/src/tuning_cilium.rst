.. Copyright 2022
   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at
        http://www.apache.org/licenses/LICENSE-2.0
   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.

***************************************
Tuning Kubernetes Cilium CNI deployment
***************************************

**Software versions**

+--------------+--------------------+
| Name         | Version            |
+==============+====================+
| Ubuntu       | Ubuntu 20.04.4 LTS |
+--------------+--------------------+
| Kernel       | 5.4.0-122-generic  |
+--------------+--------------------+
| Kubernetes   | v1.24.6            |
+--------------+--------------------+
| Cilium       | v1.12.1            |
+--------------+--------------------+

`Cilium <https://cilium.io/>`_ is an open source software for providing,
securing and observing network connectivity between container workloads - cloud
native, and fueled by the revolutionary Kernel technology eBPF. This document
compares results obtained with  *vxlan*, *disabled* and *geneve* tunnel modes.

**VXLAN (Virtual Extensible LAN)**

VXLAN is a network tunneling protocol that uses a VLAN-like encapsulation
technique to encapsulate OSI L2 Ethernet frames within L4 UDP datagrams. This
creates an illusion that containers on the same VXLAN are on the same L2
network.

.. image:: ./img/cilium_vxlan.png

**Native-Routing**

Cilium will delegate all packets which are not addressed to another local
endpoint to the routing subsystem of the Linux kernel. This means that the
packet will be routed as if a local process would have emitted the packet.

Cilium automatically enables IP forwarding in the Linux kernel when native
routing is configured.

**GENEVE (Generic Network Virtualization Encapsulation)**

Geneve is designed to support network virtualization use cases, where tunnels
are typically established to act as a backplane between the virtual switches
residing in hypervisors, physical switches, or middleboxes or other appliances.

The Geneve frame format consists of a compact tunnel header encapsulated in UDP
over either IPv4 or IPv6. A small fixed tunnel header provides control
information plus a base level of functionality and interoperability with a focus
on simplicity. This header is then followed by a set of variable options to
allow for future innovation. Finally, the payload consists of a protocol data
unit of the indicated type, such as an Ethernet frame.

Backend Results
###############

+------------------------+---------------------------+----------------+----------------+----------------+
| Connection             | Measurement               | Native-Routing | VXLAN          | GENEVE         |
+========================+===========================+================+================+================+
| worker01 -> controller | Bitrate(sender)           | 15.8 Gbits/sec | 3.93 Gbits/sec | 4.42 Gbits/sec |
|                        +---------------------------+----------------+----------------+----------------+
|                        | Transfer(sender)          | 18.4 GBytes    | 4.57 GBytes    | 5.15 GBytes    |
|                        +---------------------------+----------------+----------------+----------------+
|                        | CPU Utilization(sender)   | 61.5%          | 12.9%          | 14.4%          |
|                        +---------------------------+----------------+----------------+----------------+
|                        | Bitrate(receiver)         | 15.8 Gbits/sec | 3.92 Gbits/sec | 4.41 Gbits/sec |
|                        +---------------------------+----------------+----------------+----------------+
|                        | Transfer(receiver)        | 18.4 GBytes    | 4.57 GBytes    | 5.14 GBytes    |
|                        +---------------------------+----------------+----------------+----------------+
|                        | CPU Utilization(receiver) | 77.3%          | 67.2%          | 69.7%          |
+------------------------+---------------------------+----------------+----------------+----------------+
| worker02 -> controller | Bitrate(sender)           | 15.4 Gbits/sec | 3.93 Gbits/sec | 4.52 Gbits/sec |
|                        +---------------------------+----------------+----------------+----------------+
|                        | Transfer(sender)          | 17.9 GBytes    | 4.57 GBytes    | 5.27 GBytes    |
|                        +---------------------------+----------------+----------------+----------------+
|                        | CPU Utilization(sender)   | 67.2%          | 13.0%          | 14.3%          |
|                        +---------------------------+----------------+----------------+----------------+
|                        | Bitrate(receiver)         | 15.4 Gbits/sec | 3.93 Gbits/sec | 4.52 Gbits/sec |
|                        +---------------------------+----------------+----------------+----------------+
|                        | Transfer(receiver)        | 17.9 GBytes    | 4.57 GBytes    | 5.26 GBytes    |
|                        +---------------------------+----------------+----------------+----------------+
|                        | CPU Utilization(receiver) | 77.8%          | 66.4%          | 68.1%          |
+------------------------+---------------------------+----------------+----------------+----------------+

Kube-Proxy Replacement: *Probe*

Kube-proxy is running in the Kubernetes cluster where Cilium partially replaces
and optimizes kube-proxy functionality. Once the Cilium agent is up and running,
it probes the underlying kernel for the availability of needed eBPF kernel
features and, if not present, disables a subset of the functionality in eBPF by
relying on kube-proxy to complement the remaining Kubernetes service handling.

***********************************************
Tuning Kubernetes using different Linux Distros
***********************************************

Every Linux distribution can provide a kernel version optimized for running
certain workloads. The following results were obtained running the previous
benchmark function with different Linux distributions. This setup is using
*Native-Routing* as Cilium CNI backend in a Kubernetes v1.24.6 cluster.

Setup
#####

+------------------+-------+--------+--------------------+-----------------------------+--------------------+
| Hostname         | vCPUs | Memory | Distro             | Kernel                      | Container Runtime  |
+==================+=======+========+====================+=============================+====================+
| ubuntu16         | 1     | 4 GB   | Ubuntu 16.04.7 LTS | 4.4.0-210-generic           | containerd://1.5.8 |
+------------------+-------+--------+--------------------+-----------------------------+--------------------+
| ubuntu18         | 1     | 4 GB   | Ubuntu 18.04.6 LTS | 4.15.0-189-generic          | containerd://1.5.8 |
+------------------+-------+--------+--------------------+-----------------------------+--------------------+
| ubuntu20         | 1     | 4 GB   | Ubuntu 20.04.4 LTS | 5.4.0-122-generic           | containerd://1.5.8 |
+------------------+-------+--------+--------------------+-----------------------------+--------------------+
| opensuse15       | 1     | 4 GB   | openSUSE Leap 15.4 | 5.14.21-150400.22-default   | containerd://1.5.8 |
+------------------+-------+--------+--------------------+-----------------------------+--------------------+
| fedora34         | 1     | 4 GB   | Fedora 34          | 5.11.12-300.fc34.x86_64     | containerd://1.5.8 |
+------------------+-------+--------+--------------------+-----------------------------+--------------------+
| fedora35         | 1     | 4 GB   | Fedora Linux 35    | 5.14.10-300.fc35.x86_64     | containerd://1.5.8 |
+------------------+-------+--------+--------------------+-----------------------------+--------------------+
| centos7          | 1     | 4 GB   | CentOS Linux 7     | 3.10.0-1160.71.1.el7.x86_64 | containerd://1.5.8 |
+------------------+-------+--------+--------------------+-----------------------------+--------------------+
| centos8          | 1     | 4 GB   | CentOS Linux 8     | 4.18.0-348.7.1.el8_5.x86_64 | containerd://1.5.8 |
+------------------+-------+--------+--------------------+-----------------------------+--------------------+

.. note::
    Cilium requires +4.9.17 kernel version

Distro Results
##############

+------------+----------------+-------------+
| Hostname   | Bitrate        | Transfer    |
+============+================+=============+
| ubuntu18   | 17.1 Gbits/sec | 19.9 GBytes |
+------------+----------------+-------------+
| ubuntu20   | 15.1 Gbits/sec | 17.6 GBytes |
+------------+----------------+-------------+
| opensuse15 | 16.9 Gbits/sec | 19.7 GBytes |
+------------+----------------+-------------+
