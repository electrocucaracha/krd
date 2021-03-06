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

`kube-proxy <https://kubernetes.io/docs/reference/command-line-tools-reference/kube-proxy/>`_
reflects services as defined in the Kubernetes API on each node and can do
simple TCP, UDP, and SCTP stream forwarding or round robin TCP, UDP, and SCTP
forwarding across a set of backends. It can be used in different modes:
*userspace* (older) or *iptables* (faster) or *ipvs* or *kernelspace* (windows).
This document compares results obtained with  *iptables* and *ipvs* proxy modes.

**iptables**

iptables is a user-space utility program that allows a system administrator to
configure the IP packet filter rules of the Linux kernel firewall, implemented
as different Netfilter modules. The filters are organized in different tables,
which contain chains of rules for how to treat network traffic packets.
Different kernel modules and programs are currently used for different
protocols; iptables applies to IPv4, ip6tables to IPv6, arptables to ARP, and
ebtables to Ethernet frames. 

**IPVS (IP Virtual Server)**

IPVS running on a host acts as L4 load balancer at the front of a real servers.
It is built on top of netfilter and utilizes hash table instead of chain,
therefore it can redirect TCP/UDP based services to the real servers. One
potential downside is that packets that are handled by IPVS take a very
different path through the iptables filter hooks than packets under normal
circumstances. If you plan to use it with other programs that use iptables then
you will need to research whether they will behave as expected together.

IPVS provides different algorithms for allocating TCP connections and UDP
datagrams to real servers. Scheduling algorithms are implemented as
kernel modules. *Kubespray* supports the following methods:

- Round Robin: distributes jobs equally amongst the available real servers.
- Least-Connection: assigns more jobs to real servers with fewer active jobs.
- Destination Hashing: assigns jobs to servers through looking up a statically
  assigned hash table by their destination IP addresses.
- Source Hashing: assigns jobs to servers through looking up a statically
  assigned hash table by their source IP addresses.
- Shortest Expected Delay: assigns an incoming job to the server with the
  shortest expected delay. The expected delay that the job will experience is
  (Ci + 1) / Ui if sent to the ith server, in which Ci is the number of jobs on
  the ith server and Ui is the fixed service rate (weight) of the ith server.
- Never Queue: assigns an incoming job to an idle server if there is, instead of
  waiting for a fast one; if all the servers are busy, it adopts the Shortest
  Expected Delay policy to assign the job.

Setup
#####

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

iptables vs IPVS
################

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

   The following results were obtained running `k6`_ tool using
   1 virtual user connecting to 100 NGINX webservers during 1 minute. These are
   the 95 percentile value of the results collected by the tool.

IPVS scheduling methods
#######################

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

   The following results were obtained running `k6`_ tool using
   500 virtual user connecting (no reusing connections) to 10 NGINX webservers
   (simulating 1 sec slow responses) during 1 minute. These are the 90
   percentile value of the results collected by the tool.

.. _k6: https://k6.io/
