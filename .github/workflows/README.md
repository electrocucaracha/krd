# Available workflows

| Workflow file                                  | Description                                                                  | Run event                    |
| :--------------------------------------------- | ---------------------------------------------------------------------------- | ---------------------------- |
| [diagram](./diagram.yml)                       | Generates the codebase diagram used by the main README.md file               | on new commit/push on master |
| [distros](./distros.yml)                       | Updates the Vagrant box versions for Distro list supported file              | scheduled/manual trigger     |
| [linter](./linter.yml)                         | Counts Line of Codes, verifies broken links in docs and runs linter tools    | on new commit/push on master |
| [on-demand_ci](./on-demand_ci.yml)             | Runs BDD and integration tests for different container runtimes and projects | on new commit/push on master |
| [on-demand_corner](./on-demand_corner.yml)     | Runs integration tests for corner cases (kong, rook, HAProxy, kubewarden)    | on new commit/push on master |
| [on-demand_molecule](./on-demand_molecule.yml) | Runs unit tests for Ansible roles                                            | on new commit/push on master |
| [on-demand_multus](./on-demand_multus.yml)     | Deploys a basic cluster on a Virtual environment with Multus CNI enabled     | on new commit/push on master |
| [on-demand_virtlet](./on-demand_virtlet.yml)   | Verifies that CRIproxy and Virtlet services works                            | on new commit/push on master |
| [rebase](./rebase.yml)                         | Helps to rebase changes of the Pull request                                  | manual trigger               |
| [scheduled_ci](./scheduled_ci.yml)             | Verifies Kubernetes Dashboard operation                                      | scheduled/manual trigger     |
| [scheduled_distros](./scheduled_distros.yml)   | Validation in all the Linux distros supported (CNI and CRI combinations)     | scheduled/manual trigger     |
| [spell](./spell.yml)                           | Verifies spelling errors on documentation                                    | on new commit/push on master |
| [triage](./triage.yml)                         | Applies labels on new Pull requests opened                                   | on new commit/push on master |
| [update](./update.yml)                         | Updates python and galaxy requirements files and word list in the dict.      | scheduled/manual trigger     |

## Available labels

| Label name    | Description                                        |
| :------------ | -------------------------------------------------- |
| documentation | Changes on documentation files                     |
| test          | Changes on script files located in `tests/` folder |
| ci            | Changes on GitHub files                            |
| all-in-one    | Changes on `aio.sh` script file                    |
| addons        | Changes on Ansible roles files                     |
