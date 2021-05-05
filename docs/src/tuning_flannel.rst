.. Copyright 2021
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

+-------------+----------------+----------------+
| Measurement | VXLAN          | host-gw        |
+=============+================+================+
| Bitrate     | 5.33 Gbits/sec | 11.8 Gbits/sec |
+-------------+----------------+----------------+
| Transfer    | 6.20 GBytes    | 13.7 GBytes    |
+-------------+----------------+----------------+

***********************************************
Tuning Kubernetes using different Linux Distros
***********************************************

Every Linux distribution can provide a kernel version optimized for running
certain workloads. The following results were obtained running the previous
benchmark function with different Linux distributions. This setup is  using
*Host Gateway* as Flannel CNI backend in a Kubernetes v1.19.9 cluster.

Setup
#####

+------------------+-------+--------+--------------------+--------------------+-------------------+
| Hostname         | vCPUs | Memory | Distro             | Kernel             | Container Runtime |
+==================+=======+========+====================+====================+===================+
| controller       | 1     | 4 GB   | Ubuntu 18.04.7 LTS | 4.15.0-142-generic | docker://20.10.6  |
+------------------+-------+--------+--------------------+--------------------+-------------------+
| ubuntu16         | 1     | 8 GB   | Ubuntu 16.04.7 LTS | 4.4.0-210-generic  | docker://20.10.6  |
+------------------+-------+--------+--------------------+--------------------+-------------------+
| ubuntu18         | 1     | 8 GB   | Ubuntu 18.04.7 LTS | 4.15.0-142-generic | docker://20.10.6  |
+------------------+-------+--------+--------------------+--------------------+-------------------+
| ubuntu20         | 1     | 8 GB   | Ubuntu 20.04.7 LTS | 5.4.0-72-generic   | docker://20.10.6  |
+------------------+-------+--------+--------------------+--------------------+-------------------+
| opensuse42       | 1     | 8 GB   | openSUSE Leap 42.3 | 4.4.179-99-default | docker://18.9.1   |
+------------------+-------+--------+--------------------+--------------------+-------------------+

Distro Results
##############

+------------+----------------+-------------+
| Hostname   | Bitrate        | Transfer    |
+============+================+=============+
| opensuse42 | 19.4 Gbits/sec | 22.6 GBytes |
+------------+----------------+-------------+
| ubuntu16   | 22.1 Gbits/sec | 25.7 GBytes |
+------------+----------------+-------------+
| ubuntu18   | 25.4 Gbits/sec | 29.6 GBytes |
+------------+----------------+-------------+
| ubuntu20   | 18.1 Gbits/sec | 21.1 GBytes |
+------------+----------------+-------------+
