#!/bin/bash
# SPDX-license-identifier: Apache-2.0

set -o errexit
set -o nounset
set -o pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
export TEST_KUBESPRAY_FOLDER="$test_dir/kubespray"
mkdir -p "$test_dir/system"

cat >"$test_dir/system/ansible-playbook" <<'EOF'
#!/bin/bash
echo 'ansible [core 2.21.4]'
EOF
chmod +x "$test_dir/system/ansible-playbook"
export PATH="$test_dir/system:$PATH"

function check_environment {
    bash -c '
        source <(sed \
            "s|^export kubespray_folder=/opt/kubespray$|export kubespray_folder=\$TEST_KUBESPRAY_FOLDER|" \
            _commons.sh)
        test "$(command -v ansible-playbook)" = "$1"
        test "$(ansible-playbook --version)" = "$2"
    ' bash "$1" "$2"
}

check_environment "$test_dir/system/ansible-playbook" 'ansible [core 2.21.4]'

mkdir -p "$TEST_KUBESPRAY_FOLDER/.venv/bin"
cat >"$TEST_KUBESPRAY_FOLDER/.venv/bin/activate" <<'EOF'
export VIRTUAL_ENV="$TEST_KUBESPRAY_FOLDER/.venv"
export PATH="$VIRTUAL_ENV/bin:$PATH"
EOF
cat >"$TEST_KUBESPRAY_FOLDER/.venv/bin/ansible-playbook" <<'EOF'
#!/bin/bash
echo 'ansible [core 2.19.0]'
EOF
chmod +x "$TEST_KUBESPRAY_FOLDER/.venv/bin/ansible-playbook"

check_environment "$TEST_KUBESPRAY_FOLDER/.venv/bin/ansible-playbook" 'ansible [core 2.19.0]'
echo "Ansible environment checks passed"
