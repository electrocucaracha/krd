#   Copyright 2020
#
#   Licensed under the Apache License, Version 2.0 (the "License"); you may
#   not use this file except in compliance with the License. You may obtain
#   a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#   WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#   License for the specific language governing permissions and limitations
#   under the License.
#

import time


def test_pmem_nodes_ready(host):
    cmd = host.run(
        "/usr/local/bin/kubectl get node -o jsonpath='{range .items[*]}{.metadata.name}{\",\"}{end}'"
    )

    assert cmd.rc == 0

    nodes = cmd.stdout[:-1].split(",")
    for node in nodes:
        cmd = host.run(
            f"/usr/local/bin/kubectl wait --for=condition=ready node/{node} --timeout=3m"
        )
        assert cmd.rc == 0
        assert "condition met" in cmd.stdout


def test_sriov_device_plugin_ready(host):
    cmd = host.run(
        "/usr/local/bin/kubectl rollout status"
        " daemonset/kube-sriov-device-plugin-amd64 -n kube-system"
    )

    assert cmd.rc == 0
    assert "successfully rolled out" in cmd.stdout


def test_allocatable_resources(host):
    host.run(
        "/usr/local/bin/kubectl wait --for=condition=ready node/molecule-control-plane --timeout=120s"
    )
    host.run(
        "/usr/local/bin/kubectl rollout status daemonset/kube-sriov-device-plugin-amd64 -n kube-system"
    )
    time.sleep(10)

    jsonpath = r"{range .items[*]}{.status.allocatable.redhat\.com/virtio_net_device}"
    cmd = host.run("/usr/local/bin/kubectl get nodes -o jsonpath='" + jsonpath + "'")

    assert cmd.rc == 0
    assert cmd.stdout == "1"


def test_capacity_resources(host):
    host.run(
        "/usr/local/bin/kubectl wait --for=condition=ready node/molecule-control-plane --timeout=120s"
    )
    host.run(
        "/usr/local/bin/kubectl rollout status daemonset/kube-sriov-device-plugin-amd64 -n kube-system"
    )
    time.sleep(10)

    jsonpath = r"{range .items[*]}{.status.capacity.redhat\.com/virtio_net_device}"
    cmd = host.run("/usr/local/bin/kubectl get nodes -o jsonpath='" + jsonpath + "'")

    assert cmd.rc == 0
    assert cmd.stdout == "1"
