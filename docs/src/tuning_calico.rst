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

`Calico <https://projectcalico.docs.tigera.io/>`_  is an open source networking
and network security solution for containers, virtual machines, and native
host-based workloads. Calico supports a broad range of platforms including
Kubernetes, OpenShift, Mirantis Kubernetes Engine (MKE), OpenStack, and bare
metal services.

Calico supports three routing modes.

**IP-in-IP**

IP-in-IP is a simple form of encapsulation achieved by putting an IP packet
inside another. A transmitted packet contains an outer header with *host* source
and destination IPs and an inner header with *pod* source and destination IPs.

**VXLAN (Virtual Extensible LAN)**

VXLAN has a slightly higher per-packet overhead because the header is larger,
but unless you are running very network intensive workloads the difference is
not something you would typically notice. The other small difference between the
two types of encapsulation is that Calico’s VXLAN implementation does not use
BGP, whereas Calico’s IP in IP implementation uses BGP between Calico nodes.

**Direct**

Direct sends packets as if they came directly from the pod. Since there is no
encapsulation and de-capsulation overhead, direct is highly performant.

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

Every Linux distribution can provide a kernel version optimized for running
certain workloads. The following results were obtained running the previous
benchmark function with different Linux distributions. This setup is using
*Direct* as Calico CNI backend in a Kubernetes v1.24.6 cluster.

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
| opensuse42       | 1     | 4 GB   | openSUSE Leap 42.3 | 4.4.179-99-default          | containerd://1.5.8 |
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
