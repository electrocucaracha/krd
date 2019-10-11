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

This document explains the different components of the KRD project
and how they can configured to modify its default behaviour.

Vagranfile
##########

This file describes how the Virtual Machines are going to be
configured and the scripts and arguments used during their
provisioning process. This file uses *elastic/ubuntu-16.04-x86_64*
vagrant box for VirtualBox and Libvirt providers.

config/
#######

This folder contains the POD Descriptor File (PDF) which is used
by Vagrant during the provisioning process. The *samples* folder
contains examples for some setups (All-in-One, Mini, NoHA, HA, etc.)
that can be used.

This list contains the valid entries used by Vagrant to define the
virtual resources used by Vagrant during the creation of the Virtual
Machines:

    * name - Hostname assigned to the VM. (String value)
    * os - Operating system of the VM. (String value, Options
      supported: opensuse/centos/ubuntu/clearlinux)
    * networks - List of private networks. This list doesn't include
      the management network.

      * name - Libvirt name assigned to the network. (String value)
      * ip - The static IP address assigned to the VM. (String value)
    * memory - The amount of memory RAM. (KB - Integer value)
    * cpus - Number of CPUs. (Integer value)
    * volumes - List of volumes to be formatted and mounted to the VM.

      * name - Disk name. (String value)
      * size - Size of the volume. (GB - Integer value)
      * mount - Mount point. (String value)
    * roles - Ansible group which this VM belongs. (String value)
    * qat_dev - Virtual Functions list of Intel QuickAssist (QAT)
      Technology devices attached to the VM. (List of String values)
    * sriov_dev - Virtual Functions list of Single Root I/O
      Virtualization (SR-IOV) devices attached to the VM. (List of
      String values)
    * numa_nodes - List of Non-Uniform Memory Access (NUMA) nodes
      created for this VM. *Note:* Total memory for NUMA nodes must be
      equal to RAM size.

      * cpus - Range of CPUs used by a given node. (String value)
      * memory - The amount of memory used by a given node. (KB -
        Integer value)
    * pmem - Specify the Persistent Memory (PMEM) device(s) to be
      created and attached to the VM. These devices are configured in
      App Direct Mode. *Note:* This feature was introduced in QEMU
      2.6.0.

      * size - Memory size. This value may affect the currentMemory
        libvirt tag. (G - String value)
      * slots - Total amount of normal RAM and vNVDIMM devices.
        (Integer value)
      * max_size - Total size of normal RAM and vNVDIMM devices. (G -
        String value)
      * vNVDIMMs - List of virtual Non-Volatile Dual In-line Memory
        Modules.

        * mem_id - Memory identifier. (String value)
        * id - Identifier. (String value)
        * share - Controls the visibility of guest writes. (String
          value, Options supported: on/off)
        * path - Host path. (String value)
        * size - Size of vNVDIMM device. (G - String value)

config/default.yml
******************

If there is no *pdf.yml* file present in *config* folder, Vagrant will
use the information specified in the **config/default.yml**. The following
diagram displays how the services are installed in the nodes using the 
default configuration.

.. image:: ./img/default_pdf.png

docs/
#####

This folder contains documentation files using reStructuredText
(RST) syntax. It's possible to generate documentation in  *html*
format using `python tox module <https://tox.readthedocs.io/en/latest/>`_
. Once this is installed, it's possible to build html files using
this following command:

.. code-block:: bash

    tox -e docs

After its execution, the **docs/build** subfolder will contain
subfolders and html files that can be opened from any web browser.

galaxy-requirements.yml
#######################

This file contains third party Ansible roles. Only those tasks which
are not related with the main installation process has been placed in
this file.

krd_command.sh
##############

Main bash script that triggers the installation of configuration
functions for provisioning KRD components on external nodes. This
script uses some arguments for the additional installation of
components. For more information about its usage:

.. code-block:: bash

    ./krd_command.sh -h

inventory/
##########

This folder contains the Ansible host inventory file. The
**inventory/host.ini** file, which is used during the execution of 
Ansible playbooks, is autogenerated by Vagrant using the values
specified in the *config/pdf.yml* file (or *config/default.yml*).

k8s-cluster.yml
***************

A preferred practice in Ansible is to not store variables in the
main inventory file. The default configuration variables required for 
`Kubespray <https://github.com/kubernetes-sigs/kubespray>`_ are
stored in this file.

Some **KRD_** environment variables might affect the values of this
file.

node.sh
#######

This bash script is executed in every node after this has been
provisioned. The script provides the possibility to partition and
mount external volumes.

playbooks/
##########

This folder contains a set of Ansible playbooks and roles which
performs the tasks required for configuring services and Kubernetes
Device plugins.

playbooks/krd-vars.yml
************************

This file centralizes the version numbers and source URLs used for
different components offered by the KRD. Bumping a version requires
extensive testing to ensure compatibility.

tests/
######

This folder contains the health check scripts that guarantees the
proper installation/configuration of Kubernetes AddOns.  In order to
enable it, it's necessary to provide a *true* value for
**KRD_ENABLE_TESTS** environment variable.
