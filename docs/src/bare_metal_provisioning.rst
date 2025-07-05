.. Copyright 2018
   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at
        http://www.apache.org/licenses/LICENSE-2.0
   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.

***********************
Bare-Metal Provisioning
***********************

The Kubernetes Reference Deployment (KRD) is designed to run on both
Virtual Machines and Bare-Metal servers. The *aio.sh* script contains
the bash instructions needed to provision an All-in-One Kubernetes
cluster on a Bare-Metal server. This document outlines the required
hardware and software, and explains the key phases of *aio.sh*.

Hardware Requirements
#####################

+------------------+--------+
| Component        | Value  |
+==================+========+
| CPU (amd64/arm64)| 2      |
+------------------+--------+
| Memory           | 7.5GB  |
+------------------+--------+
| Hard Disk        | ~50GB  |
+------------------+--------+

Software Requirements
#####################

- Ubuntu Server 16.04 LTS or later

aio.sh
######

The *aio.sh* script automates the process of deploying an All-in-One
Kubernetes cluster.

To start the provisioning process, run:

.. code-block:: bash

    curl -fsSL http://bit.ly/KRDaio | KRD_ACTIONS_LIST="install_k8s,install_cockpit" bash

The script performs the following phases:

1. Server validation
2. Dependency installation
3. Configuration
4. Deployment of KRD services

**Server validation**

The script first checks that the user account running KRD has
passwordless sudo privileges and that the server’s IP address is
included in the NO_PROXY environment variable.

**Installation of dependencies**

KRD requires the `git` command-line tool to fetch its source code.
It also executes *node.sh*, which installs additional management
tools required for the deployment.

**Configuration**

Ansible uses an inventory file to define the systems it will manage.
For an All-in-One deployment, the *aio.sh* script creates a local
inventory file that points Ansible tasks to `localhost`:

.. code-block:: bash

    cat <<EOL > inventory/hosts.ini
    [all]
    localhost

    [kube_control_plane]
    localhost

    [kube_node]
    localhost

    [etcd]
    localhost

    [k8s-cluster:children]
    kube_node
    kube_control_plane
    EOL

Since Ansible uses SSH for executing tasks, the following instructions
generate and register SSH keys to enable passwordless authentication:

.. code-block:: bash

    # echo -e "\n\n\n" | ssh-keygen -t rsa -N ""
    # cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
    # chmod og-wx ~/.ssh/authorized_keys

**Deploying KRD services**

Once configuration is complete, the KRD provisioning process can be
started by running the *krd_command.sh* script. Logs are saved to
*krd_${krd_action}.log* for future reference.

.. code-block:: bash

    # ./krd_command.sh -a "$krd_action" | tee "krd_${krd_action}.log"

.. image:: ./img/installer_workflow.png
