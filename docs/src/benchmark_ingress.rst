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

***************************************************
Benchmark results of Kubernetes Ingress Controllers
***************************************************

This document presents the results obtained from running the `k6`_ tool,
which performs load testing and measures performance on different `Kubernetes
Ingress Controllers <https://kubernetes.io/docs/concepts/services-networking/ingress-controllers/>`_.

Kubernetes setup
################

All nodes ran *Ubuntu Bionic*. Hardware resources were allocated as follows:

+------------------+-------+--------+
| Hostname         | vCPUs | Memory |
+==================+=======+========+
| controller       | 2     | 4 GB   |
+------------------+-------+--------+
| worker01         | 2     | 8 GB   |
+------------------+-------+--------+
| worker02         | 2     | 8 GB   |
+------------------+-------+--------+

**Software versions**

+--------------+--------------------+
| Name         | Version            |
+==============+====================+
| Ubuntu       | Ubuntu 18.04.5 LTS |
+--------------+--------------------+
| Kernel       | 4.15.0-143-generic |
+--------------+--------------------+
| Kubernetes   | v1.19.9            |
+--------------+--------------------+
| Docker       | 19.3.14            |
+--------------+--------------------+
| MetalLB      | v0.9.6             |
+--------------+--------------------+
| NGINX        | v0.41.2            |
+--------------+--------------------+
| HAProxy      | v1.6.0             |
+--------------+--------------------+
| Kong         | 1.2.0              |
+--------------+--------------------+

This setup can be reproduced by creating the following *config/pdf.yml* file:

.. code-block:: yaml

    - name: controller
      os:
        name: ubuntu
        release: bionic
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
        - kube_control_plane
        - etcd
    - name: worker01
      os:
        name: ubuntu
        release: bionic
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
        - kube_node
    - name: worker02
      os:
        name: ubuntu
        release: bionic
      networks:
        - name: public-net
          ip: "10.10.16.5"
      memory: 8192
      cpus: 2
      volumes:
        - name: sdb
          size: 25
          mount: /var/lib/docker/
      roles:
        - kube_node

After provisioning the Kubernetes cluster with Vagrant, you can execute the networking
benchmark process. A new k6 log file will be created in the user's home directory.

.. code-block:: bash

    ./krd_command.sh -a run_external_k6

Results
#######

+-----------------------+-------------+-------------+-------------+
| Measurement           | NGINX       | HAProxy     | Kong        |
+=======================+=============+=============+=============+
| HTTP Request duration | 304.82ms    | 221.16ms    | 220.22ms    |
+-----------------------+-------------+-------------+-------------+
| HTTP Request waiting  | 254.79ms    | 179.71ms    | 173.89ms    |
+-----------------------+-------------+-------------+-------------+
| HTTP Requests per sec | 2007.039003 | 2620.277269 | 2662.725828 |
+-----------------------+-------------+-------------+-------------+

.. note::

   These results were obtained by running the `k6`_ tool with
   500 virtual users connecting to 10 NGINX web servers over a 1-minute period. The
   reported values represent the 95th percentile of the collected data.

.. _k6: https://k6.io/
