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


def test_sriov_cni_ready(host):
    cmd = host.run(
        "/usr/local/bin/kubectl rollout status"
        " daemonset/kube-sriov-cni-ds-amd64 -n kube-system"
    )

    assert cmd.rc == 0
    assert "successfully rolled out" in cmd.stdout


def test_sriov_bin_copied(host):
    cmd = host.run("/usr/bin/docker exec molecule-control-plane ls /opt/cni/bin/")

    assert cmd.rc == 0
    assert "sriov" in cmd.stdout


def test_sriov_net_created(host):
    cmd = host.run(
        "/usr/local/bin/kubectl get net-attach-def"
        " sriov-net -n kube-system --no-headers"
    )

    assert cmd.rc == 0
    assert "sriov-net" in cmd.stdout
