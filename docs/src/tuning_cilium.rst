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

Overview
========

`Cilium <https://cilium.io/>`_ is an open-source networking, observability, and security
solution for container workloads. It uses eBPF, a Linux kernel technology, to enable
high-performance networking with rich visibility and control.

This document compares performance metrics across three tunnel modes supported by Cilium:

- vxlan
- disabled (native routing)
- geneve

Software Versions
=================

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

Tunnel Modes
============

VXLAN (Virtual Extensible LAN)
------------------------------

VXLAN is a tunneling protocol that encapsulates OSI Layer 2 Ethernet frames
into Layer 4 UDP packets. It creates the illusion that containers on different
hosts are on the same Layer 2 network.

.. image:: ./img/cilium_vxlan.png

Native Routing
--------------

With tunnel mode disabled, Cilium routes non-local packets using the standard
Linux routing subsystem. It behaves as though a local process emitted the packet.

- Cilium automatically enables IP forwarding when native routing is used.

GENEVE (Generic Network Virtualization Encapsulation)
------------------------------------------------------

Geneve is a modern, extensible tunneling protocol for network virtualization.
It encapsulates Ethernet frames in UDP packets and supports customizable metadata
via optional headers.

Performance Results (Tunnel Modes)
==================================

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

Kube-Proxy Replacement: Probe Mode
==================================

Cilium partially replaces kube-proxy functionality in Kubernetes clusters.

Once the Cilium agent starts, it probes the kernel for required eBPF capabilities.
If some are unavailable, Cilium disables specific eBPF features and relies on kube-proxy
for fallback service handling.

***********************************************
Tuning Kubernetes using different Linux Distros
***********************************************

Each Linux distribution ships with a kernel version optimized for specific workloads.
This section benchmarks native routing performance with different distros using the
same hardware and Cilium setup.

.. note::
   Cilium requires Linux kernel version **4.9.17** or later.

Setup
=====

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
==============

+------------+----------------+-------------+
| Hostname   | Bitrate        | Transfer    |
+============+================+=============+
| ubuntu18   | 17.1 Gbits/sec | 19.9 GBytes |
+------------+----------------+-------------+
| ubuntu20   | 15.1 Gbits/sec | 17.6 GBytes |
+------------+----------------+-------------+
| opensuse15 | 16.9 Gbits/sec | 19.7 GBytes |
+------------+----------------+-------------+
