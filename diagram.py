#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.

import os.path

import diagrams
import diagrams.k8s.infra as k8s_infra
import yaml
from diagrams.generic.os import Centos, Suse, Ubuntu

with diagrams.Diagram(filename="krd", direction="BT"):
    try:
        config_nodes = yaml.load(open(r"config/default.yml"), Loader=yaml.FullLoader)
        if os.path.isfile("config/pdf.yml"):
            config_nodes = yaml.load(open(r"config/pdf.yml"), Loader=yaml.FullLoader)
    except IOError:
        print("File not accessible")

    nodes = []
    for node in config_nodes:
        ips = ""
        for net in node["networks"]:
            ips += net["ip"] + "\n"
        with diagrams.Cluster(
            f'{node["name"]} ({node["cpus"]} vCPUs, {node["memory"]} KB)\n{ips[:-1]}'
        ):
            if node["os"]["name"] == "ubuntu":
                nodes.append(Ubuntu())
            elif node["os"]["name"] == "centos":
                nodes.append(Centos())
            elif node["os"]["name"] == "opensuse":
                nodes.append(Suse())
            with diagrams.Cluster("Kubernetes Roles"):
                roles = []
                if "kube-master" in node["roles"]:
                    roles.append(k8s_infra.Master())
                if "etcd" in node["roles"]:
                    roles.append(k8s_infra.ETCD())
                if "kube-node" in node["roles"]:
                    roles.append(k8s_infra.Node())

    installer = Ubuntu("installer\n10.10.16.2")
    installer >> nodes
