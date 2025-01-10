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

***********************************************
Benchmark results of Kubernetes network plugins
***********************************************

This document collects the results obtained from the execution of the
`kubernetes-iperf3 tool <https://github.com/Pharb/kubernetes-iperf3>`_
which measures the network bandwidth used by all nodes of a minimal
Kubernetes setup. 

Kubernetes Setup
################

The Linux distro used for all nodes is  *Ubuntu Bionic*. Hardware resources were
distributed in the following manner: 

+------------------+-------+--------+
| Hostname         | vCPUs | Memory |
+==================+=======+========+
| controller       | 1     | 4 GB   |
+------------------+-------+--------+
| worker01         | 1     | 4 GB   |
+------------------+-------+--------+
| worker02         | 1     | 4 GB   |
+------------------+-------+--------+

**Software versions**

+--------------+--------------------+
| Name         | Version            |
+==============+====================+
| Ubuntu       | Ubuntu 18.04.6 LTS |
+--------------+--------------------+
| Kernel       | 4.15.0-189-generic |
+--------------+--------------------+
| Kubernetes   | v1.24.6            |
+--------------+--------------------+
| Flannel      | v1.1.0             |
+--------------+--------------------+
| Calico       | v3.22.3            |
+--------------+--------------------+
| Cilium       | v1.12.1            |
+--------------+--------------------+

All the previous configuration uses VXLAN as overlay mode. This setup can be
achieved creating the following  *config/pdf.yml* file:

.. code-block:: yaml

    - name: controller
      os:
        name: ubuntu
        release: bionic
      networks:
        - name: public-net
          ip: "10.10.16.3"
      memory: 4096
      cpus: 1
      storage_controllers:
        - name: Virtual I/O Device SCSI controller
          type: virtio-scsi
          controller: VirtIO
      volumes:
        - name: sdb
          size: 25
          mount: /var/lib/docker/
          controller: Virtual I/O Device SCSI controller
          port: 1
          device: 0
      roles:
        - kube_control_plane
        - etcd
    - name: worker01
      os:
        name: ubuntu
        release: bionic
      networks:
        - name: public-net
          ip: "10.10.16.4"
      memory: 4096
      cpus: 1
      storage_controllers:
        - name: Virtual I/O Device SCSI controller
          type: virtio-scsi
          controller: VirtIO
      volumes:
        - name: sdb
          size: 25
          mount: /var/lib/docker/
          controller: Virtual I/O Device SCSI controller
          port: 1
          device: 0
      roles:
        - kube_node
    - name: worker02
      os:
        name: ubuntu
        release: bionic
      networks:
        - name: public-net
          ip: "10.10.16.5"
      memory: 4096
      cpus: 1
      storage_controllers:
        - name: Virtual I/O Device SCSI controller
          type: virtio-scsi
          controller: VirtIO
      volumes:
        - name: sdb
          size: 25
          mount: /var/lib/docker/
          controller: Virtual I/O Device SCSI controller
          port: 1
          device: 0
      roles:
        - kube_node

Once the Kubernetes cluster is provisioned by vagrant is possible to execute
the networking benchmark process. A new iperf log file will be created on the
user's home folder.

.. code-block:: bash

    ./krd_command.sh -a run_k8s_iperf

In order to get other results is necessary to reprovision the cluster with
the desired CNI.

.. code-block:: bash

    export KRD_FLANNEL_BACKEND_TYPE=vxlan
    export KRD_CILIUM_TUNNEL_MODE=vxlan
    export KRD_CALICO_VXLAN_MODE=Always
    for KRD_NETWORK_PLUGIN in calico cilium flannel; do
        export KRD_NETWORK_PLUGIN
        ./krd_command.sh -a uninstall_k8s -a install_k8s -a run_k8s_iperf
    done

Results
#######

+------------------------+---------------------------+----------------+----------------+----------------+
| Connection             | Measurement               | Flannel        | Calico         | Cilium         |
+========================+===========================+================+================+================+
| worker01 -> controller | Bitrate(sender)           | 4.18 Gbits/sec | 2.50 Gbits/sec | 4.09 Gbits/sec |
|                        +---------------------------+----------------+----------------+----------------+
|                        | Transfer(sender)          | 4.87 GBytes    | 2.91 GBytes    | 4.76 GBytes    |
|                        +---------------------------+----------------+----------------+----------------+
|                        | CPU Utilization(sender)   | 13.4%          | 43.0%          | 10.7%          |
|                        +---------------------------+----------------+----------------+----------------+
|                        | Bitrate(receiver)         | 4.18 Gbits/sec | 2.50 Gbits/sec | 4.08 Gbits/sec |
|                        +---------------------------+----------------+----------------+----------------+
|                        | Transfer(receiver)        | 4.86 GBytes    | 2.91 GBytes    | 4.75 GBytes    |
|                        +---------------------------+----------------+----------------+----------------+
|                        | CPU Utilization(receiver) | 70.3%          | 55.5%          | 63.9%          |
+------------------------+---------------------------+----------------+----------------+----------------+
| worker02 -> controller | Bitrate(sender)           | 4.20 Gbits/sec | 2.22 Gbits/sec | 3.72 Gbits/sec |
|                        +---------------------------+----------------+----------------+----------------+
|                        | Transfer(sender)          | 4.89 GBytes    | 2.59 GBytes    | 4.33 GBytes    |
|                        +---------------------------+----------------+----------------+----------------+
|                        | CPU Utilization(sender)   | 14.5%          | 31.5%          | 8.7%           |
|                        +---------------------------+----------------+----------------+----------------+
|                        | Bitrate(receiver)         | 4.19 Gbits/sec | 2.22 Gbits/sec | 3.72 Gbits/sec |
|                        +---------------------------+----------------+----------------+----------------+
|                        | Transfer(receiver)        | 4.88 GBytes    | 2.59 GBytes    | 4.33 GBytes    |
|                        +---------------------------+----------------+----------------+----------------+
|                        | CPU Utilization(receiver) | 70.9%          | 47.1%          | 59.1%          |
+------------------------+---------------------------+----------------+----------------+----------------+

This execution uses **kube-proxy** configured with *IPVS* mode.

.. note::
   EAST-WEST traffic goes from *worker01* and/or *worker02* to *controller*
