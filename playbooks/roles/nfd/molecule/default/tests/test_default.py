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
    for resource in ["deployment/nfd-master", "daemonset/nfd-worker"]:
        assert host.run(
            f"/usr/local/bin/kubectl rollout status {resource}"
            " --namespace node-feature-discovery"
            " --timeout=3m"
        ).succeeded
    for item in [
        {"type": "deployment", "metric": "readyReplicas"},
        {"type": "daemonset", "metric": "numberReady"},
    ]:
        assert (
            host.run(
                f"/usr/local/bin/kubectl get {item['type']}"
                " --namespace node-feature-discovery"
                " -o jsonpath='{.items[0].status.{item['metric']}}'"
            ).stdout
            == "1"  # noqa: W503
        )
