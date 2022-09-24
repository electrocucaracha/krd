.. Copyright 2021,2022
   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at
        http://www.apache.org/licenses/LICENSE-2.0
   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.

****************************************
Tuning Kubernetes Flannel CNI deployment
****************************************

**Software versions**

+--------------+--------------------+
| Name         | Version            |
+==============+====================+
| Ubuntu       | Ubuntu 18.04.6 LTS |
+--------------+--------------------+
| Kernel       | 4.15.0-189-generic |
+--------------+--------------------+
| Kubernetes   | v1.23.7            |
+--------------+--------------------+
| Flannel      | v0.17.0            |
+--------------+--------------------+

`Flannel CNI <https://www.cni.dev/plugins/current/meta/flannel/>`_ is a simple
and easy way to configure a L3 network fabric designed for Kubernetes. It
supports different backend types for specific scenarios. This document compares
results obtained with  *vxlan* and *host-gw* backends.

**VXLAN (Virtual Extensible LAN)**

VXLAN is a network tunneling protocol that uses a VLAN-like encapsulation
technique to encapsulate OSI L2 Ethernet frames within L4 UDP datagrams. This 
creates an illusion that containers on the same VXLAN are on the same L2
network.

.. image:: ./img/flannel_vxlan.png

**Host Gateway**

Flannel configures each host node as a gateway and replies on routing table to
route the traffics between Pod network and host. Requires direct L2 connectivity
between hosts running Flannel daemon.

.. image:: ./img/flannel_host-gw.png

Backend Results
###############

+------------------------+--------------------+----------------+----------------+
| Connection             | Measurement        | host-gw        | VXLAN          |
+========================+====================+================+================+
| worker01 -> controller | Bitrate(sender)    | 25.1 Gbits/sec | 4.11 Gbits/sec |
|                        +--------------------+----------------+----------------+
|                        | Transfer(sender)   | 29.3 GBytes    | 4.78 GBytes    |
|                        +--------------------+----------------+----------------+
|                        | Bitrate(receiver)  | 25.1 Gbits/sec | 4.09 Gbits/sec |
|                        +--------------------+----------------+----------------+
|                        | Transfer(receiver) | 29.3 GBytes    | 4.78 GBytes    |
+------------------------+--------------------+----------------+----------------+
| worker02 -> controller | Bitrate(sender)    | 25.1 Gbits/sec | 4.19 Gbits/sec |
|                        +--------------------+----------------+----------------+
|                        | Transfer(sender)   | 29.2 GBytes    | 4.88 GBytes    |
|                        +--------------------+----------------+----------------+
|                        | Bitrate(receiver)  | 25.0 Gbits/sec | 4.18 Gbits/sec |
|                        +--------------------+----------------+----------------+
|                        | Transfer(receiver) | 29.2 GBytes    | 4.88 GBytes    |
+------------------------+--------------------+----------------+----------------+

***********************************************
Tuning Kubernetes using different Linux Distros
***********************************************

Every Linux distribution can provide a kernel version optimized for running
certain workloads. The following results were obtained running the previous
benchmark function with different Linux distributions. This setup is  using
*Host Gateway* as Flannel CNI backend in a Kubernetes v1.23.7 cluster.

Setup
#####

+------------------+-------+--------+--------------------+-----------------------------+-------------------+
| Hostname         | vCPUs | Memory | Distro             | Kernel                      | Container Runtime |
+==================+=======+========+====================+=============================+===================+
| controller       | 1     | 4 GB   | Ubuntu 18.04.6 LTS | 4.15.0-189-generic          | docker://20.10.11 |
+------------------+-------+--------+--------------------+-----------------------------+-------------------+
| ubuntu18         | 1     | 4 GB   | Ubuntu 18.04.6 LTS | 4.15.0-189-generic          | docker://20.10.11 |
+------------------+-------+--------+--------------------+-----------------------------+-------------------+
| ubuntu20         | 1     | 4 GB   | Ubuntu 20.04.4 LTS | 5.4.0-122-generic           | docker://20.10.11 |
+------------------+-------+--------+--------------------+-----------------------------+-------------------+
| opensuse42       | 1     | 4 GB   | openSUSE Leap 42.3 | 4.4.179-99-default          | docker://18.9.1   |
+------------------+-------+--------+--------------------+-----------------------------+-------------------+

Distro Results
##############

+------------+----------------+-------------+
| Hostname   | Bitrate        | Transfer    |
+============+================+=============+
| ubuntu18   | 20.0 Gbits/sec | 23.3 GBytes |
+------------+----------------+-------------+
| ubuntu20   | 17.9 Gbits/sec | 15.3 GBytes |
+------------+----------------+-------------+
| opensuse42 | 20.0 Gbits/sec | 23.3 GBytes |
+------------+----------------+-------------+
