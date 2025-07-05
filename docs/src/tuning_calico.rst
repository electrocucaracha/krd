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
Tuning Kubernetes Calico CNI deployment
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
| Calico       | v3.23.3            |
+--------------+--------------------+

`Calico <https://projectcalico.docs.tigera.io/>`_ is an open-source networking
and network security solution for containers, virtual machines, and native
host-based workloads. Calico supports a wide range of platforms, including
Kubernetes, OpenShift, Mirantis Kubernetes Engine (MKE), OpenStack, and bare
metal environments.

Calico offers three routing modes:

**IP-in-IP**

IP-in-IP encapsulates traffic by placing one IP packet inside another. The outer
header contains the *host* source and destination IPs, while the inner header
includes the *pod* source and destination IPs.

**VXLAN (Virtual Extensible LAN)**

VXLAN adds more overhead per packet due to a larger header, but unless your
workloads are extremely network-intensive, the performance difference is usually
negligible. Unlike IP-in-IP, Calico’s VXLAN implementation does not use BGP
routing, while IP-in-IP relies on BGP to exchange routes between Calico nodes.

**Direct**

Direct mode sends packets directly from pods to their destinations without
encapsulation or decapsulation, resulting in the highest performance.

Backend Results
###############

+------------------------+-----------------------------+----------------+----------------+----------------+
| Connection             | Measurement                 | IP-in-IP       | VXLAN          | Direct         |
+========================+=============================+================+================+================+
| worker01 -> controller | Bitrate(sender)             | 4.28 Gbits/sec | 2.58 Gbits/sec | 16.1 Gbits/sec |
|                        +-----------------------------+----------------+----------------+----------------+
|                        | Transfer(sender)            | 4.99 GBytes    | 3.00 GBytes    | 18.7 GBytes    |
|                        +-----------------------------+----------------+----------------+----------------+
|                        | CPU Utilizatition(sender)   | 19.9%          | 64.9%          | 73.4%          |
|                        +-----------------------------+----------------+----------------+----------------+
|                        | Bitrate(receiver)           | 4.28 Gbits/sec | 2.57 Gbits/sec | 16.1 Gbits/sec |
|                        +-----------------------------+----------------+----------------+----------------+
|                        | Transfer(receiver)          | 4.98 GBytes    | 3.00 GBytes    | 18.7 GBytes    |
|                        +-----------------------------+----------------+----------------+----------------+
|                        | CPU Utilizatition(receiver) | 63.2%          | 54.5%          | 76.5%          |
+------------------------+-----------------------------+----------------+----------------+----------------+
| worker02 -> controller | Bitrate(sender)             | 4.82 Gbits/sec | 2.78 Gbits/sec | 15.4 Gbits/sec |
|                        +-----------------------------+----------------+----------------+----------------+
|                        | Transfer(sender)            | 5.62 GBytes    | 3.24 GBytes    | 17.9 GBytes    |
|                        +-----------------------------+----------------+----------------+----------------+
|                        | CPU Utilizatition(sender)   | 24.2%          | 66.0%          | 71.6%          |
|                        +-----------------------------+----------------+----------------+----------------+
|                        | Bitrate(receiver)           | 4.81 Gbits/sec | 2.78 Gbits/sec | 15.4 Gbits/sec |
|                        +-----------------------------+----------------+----------------+----------------+
|                        | Transfer(receiver)          | 5.61 GBytes    | 3.23 GBytes    | 17.9 GBytes    |
|                        +-----------------------------+----------------+----------------+----------------+
|                        | CPU Utilizatition(receiver) | 70.3%          | 58.3%          | 74.5%          |
+------------------------+-----------------------------+----------------+----------------+----------------+

***********************************************
Tuning Kubernetes using different Linux Distros
***********************************************

Each Linux distribution provides a kernel version optimized for different types
of workloads. The following results were obtained by running the previous
benchmark with various Linux distributions. All tests used *Direct* mode as the
Calico CNI backend in a Kubernetes v1.24.6 cluster.

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

Distro Results
##############

+------------+----------------+-------------+
| Hostname   | Bitrate        | Transfer    |
+============+================+=============+
| ubuntu16   | 16.1 Gbits/sec | 18.8 GBytes |
+------------+----------------+-------------+
| ubuntu18   | 16.9 Gbits/sec | 19.7 GBytes |
+------------+----------------+-------------+
| ubuntu20   | 15.5 Gbits/sec | 18.1 GBytes |
+------------+----------------+-------------+
| opensuse15 | 15.8 Gbits/sec | 18.3 GBytes |
+------------+----------------+-------------+
| centos7    | 15.5 Gbits/sec | 18.1 GBytes |
+------------+----------------+-------------+
