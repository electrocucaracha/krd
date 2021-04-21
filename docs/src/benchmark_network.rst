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

***********************************************
Benchmark results of Kubernetes network plugins
***********************************************

This document collects the results obtained from the execution of the
`kubernetes-iperf3 tool <https://github.com/Pharb/kubernetes-iperf3>`_
which measures the network bandwidth used by all nodes of a minimal
Kubernetes setup. 

Kubernetes setup
################

The Linux distro used for all nodes is  *Ubuntu Focal*. Hardware resources were
distributed in the following manner: 

+------------------+-------+--------+
| Hostname         | vCPUs | Memory |
+==================+=======+========+
| controller       | 2     | 4 GB   |
+------------------+-------+--------+
| worker01         | 2     | 8 GB   |
+------------------+-------+--------+

**Software versions**

+--------------+--------------------+
| Name         | Version            |
+==============+====================+
| Ubuntu       | Ubuntu 20.04.2 LTS |
+--------------+--------------------+
| Kernel       | 5.4.0-70-generic   |
+--------------+--------------------+
| Kubernetes   | v1.19.9            |
+--------------+--------------------+
| Flannel      | v0.13.0            |
+--------------+--------------------+
| Calico       | v3.16.9            |
+--------------+--------------------+

This setup can be achieved creating the following  *config/pdf.yml* file:

.. code-block:: yaml

    - name: controller
      os:
        name: ubuntu
        release: focal
      networks:
        - name: public-net
          ip: "10.10.16.3"
      memory: 4096
      cpus: 2
      volumes:
        - name: sdb
          size: 25
          mount: /var/lib/docker/
      roles:
        - kube-master
        - etcd
    - name: worker01
      os:
        name: ubuntu
        release: focal
      networks:
        - name: public-net
          ip: "10.10.16.4"
      memory: 8192
      cpus: 2
      volumes:
        - name: sdb
          size: 25
          mount: /var/lib/docker/
      roles:
        - kube-node

Once the Kubernetes cluster is provisioned by vagrant is possible to execute
the networking benchmark process. A new iperf log file will be created on the
user's home folder.

.. code-block:: bash

    ./krd_command.sh -a run_internal_k6

In order to get other results is necessary to reprovision the cluster with
the desired CNI.

.. code-block:: bash

    for KRD_NETWORK_PLUGIN in calico cilium flannel; do
        export KRD_NETWORK_PLUGIN
        ./krd_command.sh -a uninstall_k8s -a install_k8s -a run_internal_k6
    done

Results
#######

+-------------+----------------+----------------+----------------+
| Measurement | Flannel        | Calico         | Cilium         |
+=============+================+================+================+
| Bitrate     | 5.18 Gbits/sec | 5.09 Gbits/sec | 4.37 Gbits/sec |
+-------------+----------------+----------------+----------------+
| Transfer    | 6.03 GBytes    | 5.68 GBytes    | 5.09 GBytes    |
+-------------+----------------+----------------+----------------+

This execution uses **kube-proxy** configured with *iptables* mode which
allows flexible sequences of rules to be attached to various hooks in the
kernel’s packet processing pipeline but in counterpart the number of rules can
grow roughly in proportion to the cluster size.

.. note::
   EAST-WEST traffic goes from *worker01* to *controller*
