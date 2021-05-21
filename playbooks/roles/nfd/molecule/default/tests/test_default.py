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


def test_get_nfd_ready_nodes(host):
    assert host.run(
        "/usr/local/bin/kubectl rollout status"
        " deployment/nfd-master"
        " --namespace node-feature-discovery"
        " --timeout=3m"
    ).succeeded
    assert host.run(
        "/usr/local/bin/kubectl rollout status"
        " daemonset/nfd-worker"
        " --namespace node-feature-discovery"
        " --timeout=3m"
    ).succeeded
    assert (
        host.run(
            "/usr/local/bin/kubectl get deployment"
            " --namespace node-feature-discovery"
            " -o jsonpath='{.items[0].status."
            "readyReplicas}'"
        ).stdout
        == "1"  # noqa: W503
    )
    assert (
        host.run(
            "/usr/local/bin/kubectl get daemonset"
            " --namespace node-feature-discovery"
            " -o jsonpath='{.items[0].status."
            "numberReady}'"
        ).stdout
        == "1"  # noqa: W503
    )
