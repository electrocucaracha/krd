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

*****************
Tuning Kube-proxy
*****************

Overview
========

`kube-proxy <https://kubernetes.io/docs/reference/command-line-tools-reference/kube-proxy/>`_
is a Kubernetes network component that reflects Services as defined in the API on
each node. It handles:

- TCP, UDP, and SCTP stream forwarding
- Round-robin load balancing across backend Pods

kube-proxy supports several proxying modes:

- ``userspace`` (legacy)
- ``iptables`` (default, fast)
- ``ipvs`` (load-balancer capable)
- ``kernelspace`` (Windows only)

This document compares the performance of the `iptables` and `ipvs` modes.

Proxy Modes
===========

iptables
--------

``iptables`` is a userspace utility for managing firewall rules using the Linux
kernel's Netfilter framework. It filters packets by matching them to rules organized
in tables and chains.

- Applies to IPv4
- Uses rule chains for decision making
- Part of the traditional Linux networking stack

Other related tools:

- ``ip6tables`` for IPv6
- ``arptables`` for ARP
- ``ebtables`` for Ethernet frames

IPVS (IP Virtual Server)
------------------------

``ipvs`` implements transport-layer load balancing. It’s built on top of Netfilter
but uses a **hash table** instead of chain-based processing, making it more scalable
under high load.

Key characteristics:

- Acts as an L4 load balancer
- More efficient than iptables under high concurrency
- May bypass some iptables hooks, which can cause compatibility issues

Supported scheduling algorithms in **Kubespray**:

- **Round Robin** – evenly distributes connections
- **Least Connection** – favors backends with fewer active sessions
- **Destination Hashing** – uses destination IP to select a backend
- **Source Hashing** – uses source IP to select a backend
- **Shortest Expected Delay** – selects the server with the best estimated delay
- **Never Queue** – assigns only to idle servers; falls back to shortest delay

Cluster Setup
=============

+------------------+-------+--------+--------------------+--------------------+-------------------+--------------+------------------+
| Hostname         | vCPUs | Memory | Distro             | Kernel             | Container Runtime | IPVS version | iptables version |
+==================+=======+========+====================+====================+===================+==============+==================+
| controller01     | 1     | 4 GB   | Ubuntu 18.04.7 LTS | 4.15.0-142-generic | docker://19.3.14  | v1.2.1       | v1.6.1           |
+------------------+-------+--------+--------------------+--------------------+-------------------+--------------+------------------+
| controller02     | 1     | 4 GB   | Ubuntu 18.04.7 LTS | 4.15.0-142-generic | docker://19.3.14  | v1.2.1       | v1.6.1           |
+------------------+-------+--------+--------------------+--------------------+-------------------+--------------+------------------+
| controller03     | 1     | 4 GB   | Ubuntu 18.04.7 LTS | 4.15.0-142-generic | docker://19.3.14  | v1.2.1       | v1.6.1           |
+------------------+-------+--------+--------------------+--------------------+-------------------+--------------+------------------+
| controller04     | 1     | 4 GB   | Ubuntu 18.04.7 LTS | 4.15.0-142-generic | docker://19.3.14  | v1.2.1       | v1.6.1           |
+------------------+-------+--------+--------------------+--------------------+-------------------+--------------+------------------+
| controller05     | 1     | 4 GB   | Ubuntu 18.04.7 LTS | 4.15.0-142-generic | docker://19.3.14  | v1.2.1       | v1.6.1           |
+------------------+-------+--------+--------------------+--------------------+-------------------+--------------+------------------+
| worker           | 1     | 4 GB   | Ubuntu 18.04.7 LTS | 4.15.0-142-generic | docker://19.3.14  | v1.2.1       | v1.6.1           |
+------------------+-------+--------+--------------------+--------------------+-------------------+--------------+------------------+

Performance: iptables vs IPVS
=============================

+-----------------------+------------+-------------+
| Measurement           | iptables   | IPVS        |
+=======================+============+=============+
| HTTP Request duration | 317.92µs   | 299.57µs    |
+-----------------------+------------+-------------+
| HTTP Request waiting  | 256.04µs   | 246.08µs    |
+-----------------------+------------+-------------+
| HTTP Requests per sec | 3575.62904 | 3632.013667 |
+-----------------------+------------+-------------+

.. note::

   These results were gathered using the `k6`_ tool. A single virtual user sent HTTP
   requests to 100 NGINX web servers over 1 minute. Values shown represent the 95th
   percentile latency and throughput.

IPVS Scheduling Benchmark
==========================

+-------------------------+----------+---------+---------------+
| Method                  | Duration | Waiting | Requests      |
+=========================+==========+=========+===============+
| Round Robin             | 53.84ms  | 12.82µs | 4206.677073/s |
+-------------------------+----------+---------+---------------+
| Least-Connection        | 49.51ms  | 12.23µs | 4478.541861/s |
+-------------------------+----------+---------+---------------+
| Destination Hashing     | 51.38ms  | 13.23µs | 4362.282114/s |
+-------------------------+----------+---------+---------------+
| Source Hashing          | 44.04ms  | 12µs    | 4731.799579/s |
+-------------------------+----------+---------+---------------+
| Shortest Expected Delay | 46.91ms  | 11.27µs | 4782.159376/s |
+-------------------------+----------+---------+---------------+
| Never Queue             | 50.81ms  | 12.21µs | 4331.884239/s |
+-------------------------+----------+---------+---------------+

.. note::

   These benchmarks were generated using the `k6`_ tool with 500 virtual users making HTTP
   requests (without reusing connections) to 10 NGINX servers. Each NGINX instance simulated
   a 1-second response time. Values shown represent the 90th percentile.

.. _k6: https://k6.io/
