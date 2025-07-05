.. Copyright 2019
   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at
        http://www.apache.org/licenses/LICENSE-2.0
   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.

********************
Project Architecture
********************

This document describes the components of the KRD project
and how they can be configured to modify its default behavior.

Vagranfile
##########

This file defines the configuration of the Virtual Machines (VMs),
including the scripts and arguments used during provisioning.
It uses the *elastic/ubuntu-16.04-x86_64* Vagrant box with support
for both VirtualBox and Libvirt providers.

config/
#######

This directory contains the POD Descriptor File (PDF) used by Vagrant
during provisioning. The *samples* folder provides examples for
different setups (All-in-One, Mini, NoHA, HA, etc.).

Below is a list of valid entries for defining virtual resources in Vagrant:

    * **name**: Hostname assigned to the VM. *(String)*
    * **os**: Operating system of the VM. *(String; supported options: opensuse, centos, ubuntu)*
    * **networks**: List of private networks (excluding the management network).

      * **name**: Libvirt-assigned network name. *(String)*
      * **ip**: Static IP address assigned to the VM. *(String)*
    * **memory**: RAM size in KB. *(Integer)*
    * **cpus**: Number of CPUs. *(Integer)*
    * **volumes**: List of volumes to format and mount on the VM.

      * **name**: Disk name. *(String)*
      * **size**: Volume size in GB. *(Integer)*
      * **mount**: Mount point. *(String)*
    * **roles**: Ansible group this VM belongs to. *(String)*
    * **qat_dev**: List of Intel QuickAssist (QAT) virtual functions attached to the VM. *(List of strings)*
    * **sriov_dev**: List of SR-IOV virtual functions attached to the VM. *(List of strings)*
    * **numa_nodes**: List of NUMA nodes for the VM. *Note*: Total NUMA memory must match the VM's RAM.

      * **cpus**: CPU range for the node. *(String)*
      * **memory**: Memory assigned to the node in KB. *(Integer)*
    * **pmem**: Persistent Memory (PMEM) devices to create and attach to the VM (App Direct Mode; requires QEMU 2.6.0+).

      * **size**: Memory size; may affect the `currentMemory` libvirt tag. *(String, in GB)*
      * **slots**: Total count of normal RAM and vNVDIMM devices. *(Integer)*
      * **max_size**: Combined RAM and vNVDIMM size. *(String, in GB)*
      * **vNVDIMMs**: List of virtual Non-Volatile Dual In-line Memory Modules:

        * **mem_id**: Memory identifier. *(String)*
        * **id**: Device identifier. *(String)*
        * **share**: Guest write visibility control; options: `on`/`off`. *(String)*
        * **path**: Host path. *(String)*
        * **size**: vNVDIMM size. *(String, in GB)*

config/default.yml
******************

If no *pdf.yml* file exists in the *config* directory, Vagrant falls back to **config/default.yml**.
The following diagram shows service installation on nodes using the default configuration:

.. image:: ./img/default_pdf.png

docs/
#####

This folder contains documentation in reStructuredText (RST) format.
You can generate HTML documentation using the `tox` module. After installing tox, run:

.. code-block:: bash

    tox -e docs

Generated HTML files will appear in the **docs/build** subfolder and can be opened with any web browser.

galaxy-requirements.yml
#######################

Contains third-party Ansible roles. Only tasks unrelated to the core installation process are defined here.

krd_command.sh
##############

Main Bash script to install and configure KRD components on external nodes.
For usage details, run:

.. code-block:: bash

    ./krd_command.sh -h

inventory/
##########

This folder holds the Ansible inventory file. The **inventory/host.ini** file,
generated automatically by Vagrant from *config/pdf.yml* or *config/default.yml*,
is used during Ansible playbook execution.

k8s_cluster.yml
***************

In line with best practices, variables are not stored in the main inventory file.
This file contains the default configuration variables required for
`Kubespray <https://github.com/kubernetes-sigs/kubespray>`_.

Some **KRD_** environment variables may override values in this file.

node.sh
#######

A Bash script executed on each node after provisioning, allowing partitioning
and mounting of external volumes.

playbooks/
##########

Contains Ansible playbooks and roles for configuring services and Kubernetes device plugins.

playbooks/krd-vars.yml
************************

Centralizes version numbers and source URLs for KRD components.
Updating versions requires thorough testing for compatibility.

tests/
######

Includes health check scripts to validate proper installation and configuration
of Kubernetes add-ons. To enable tests, set the **KRD_ENABLE_TESTS** environment
variable to *true*.
