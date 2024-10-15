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

    for node in cmd.stdout[:-1].split(","):
        cmd = host.run(
            f"/usr/local/bin/kubectl wait --for=condition=ready node/{node} --timeout=1m"
        )
        assert cmd.rc == 0
        assert "condition met" in cmd.stdout


def _wait_resource_ready(host, resource):
    cmd = host.run(
        f"/usr/local/bin/kubectl rollout status {resource} -n pmem-csi --timeout=1m"
    )

    assert cmd.rc == 0
    assert "successfully rolled out" in cmd.stdout


def test_pmem_device_plugin_ready(host):
    _wait_resource_ready(host, "daemonset/pmem-csi-intel-com-node")


def test_pmem_deployment_ready(host):
    _wait_resource_ready(host, "deployment/pmem-csi-intel-com-controller")


def test_get_pmem_node_annotation(host):
    host.run(
        "/usr/local/bin/kubectl wait --for=condition=ready node/molecule-control-plane --timeout=1m"
    )
    host.run(
        "/usr/local/bin/kubectl rollout status daemonset/pmem-csi-intel-com-node -n pmem-csi --timeout=1m"
    )
    host.run(
        "/usr/local/bin/kubectl rollout status statefulset/pmem-csi-intel-com-controller -n pmem-csi --timeout=1m"
    )
    time.sleep(10)

    jsonpath = (
        r"{range .items[*]}{.metadata.annotations.csi\.volume\.kubernetes\.io/nodeid}"
    )
    cmd = host.run("/usr/local/bin/kubectl get nodes -o jsonpath='" + jsonpath + "'")

    assert "pmem-csi.intel.com" in cmd.stdout
