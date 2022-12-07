[ssh_connection]
pipelining=True
ansible_ssh_common_args = -o ControlMaster=auto -o ControlPersist=30m -o ConnectionAttempts=100
retries=2
[defaults]
forks = 20
strategy_plugins = plugins/mitogen/ansible_mitogen/plugins/strategy

host_key_checking=False
gathering = smart
fact_caching = jsonfile
fact_caching_connection = /tmp
stdout_callback = skippy
library = ./library:../library
callbacks_enabled = profile_tasks
jinja2_extensions = jinja2.ext.do
