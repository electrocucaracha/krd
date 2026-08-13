<!-- Markdownlint-disable MD024 -->

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [23.1.0] - 2026-08-12

### Added

- Enabled users and maintainers to track project developments more effectively by providing a comprehensive history of recent changes through the addition of version 23.0.5 release notes in the changelog. [5df35777](https://github.com/electrocucaracha/krd/commit/5df357776d80eab2ef8916199527bbd517c4ac4a)

## [23.0.5] - 2026-08-11

### Changed

- Updated the changelog to accurately reflect recent releases and improvements, including Kubespray version updates, YAML manifest formatting enhancements, and documentation standardization, without introducing any breaking changes. [38ea7da0](https://github.com/electrocucaracha/krd/commit/38ea7da0973c7dc9afa142401a8a234839edf5e9)

## [23.0.4] - 2026-08-11

### Fixed

- Simplified kubespray version replacement in check.sh to reduce maintenance overhead and risk of breakage due to syntax changes without affecting resulting version update behavior. [e34d963f](https://github.com/electrocucaracha/krd/commit/e34d963fb6eee3497c692bfed133d4a3c95c8cad)

## [23.0.3] - 2026-08-11

### Fixed

- Updated the default kubespray version to v2.31.0, ensuring compatibility with newer Kubernetes versions and incorporating upstream improvements that resolve potential issues with outdated bug fixes and features. [da8abc29](https://github.com/electrocucaracha/krd/commit/da8abc290bf59d0d05c57a180cc93d94c2d76c72)

## [23.0.2] - 2026-08-11

### Changed

- Stabilized the formatting of ServiceAccount and ClusterRoleBinding blocks in generated YAML manifests to consistently use two spaces per level for improved readability and alignment with YAML best practices without introducing any functional changes. [c69c47ff](https://github.com/electrocucaracha/krd/commit/c69c47ff85e739a2f070aaef5572f4de7b25704c)

## [23.0.1] - 2026-08-11

### Fixed

- Stabilized the Vagrantfile's free memory output to standard error, preventing diagnostic information from interfering with scripts that expect clean stdout and ensuring compatibility with automation tools. [26f48405](https://github.com/electrocucaracha/krd/commit/26f48405ba8371d7fb9b1f63362986e88992df5b)

## [23.0.0] - 2026-08-11

### Removed

- Simplified the test environment list in tox.ini by removing an extraneous comma that could cause parsing inconsistencies in some versions of tox, without affecting the functionality of test execution. [a2b7bfea](https://github.com/electrocucaracha/krd/commit/a2b7bfeaf8b08d1d694c7e6423d09d9b9d563bdd)

## [22.0.1] - 2026-08-11

### Changed

- Simplified tool name references throughout the changelog to consistently match official terminology and improve readability for users referencing these tools in their workflows. [8b19affe](https://github.com/electrocucaracha/krd/commit/8b19affe50fa9187f057c7ce266aedfc7966f708)

## [22.0.0] - 2026-08-11

### Removed

- Eliminated unnecessary workflow steps by removing criproxy from the test matrix in the CI workflow. [8967ff24](https://github.com/electrocucaracha/krd/commit/8967ff245a25624bcf1c6a0310c70ac70baead13)

## [21.2.2] - 2026-08-11

### Changed

- Updated molecule test environments to use the generic/ubuntu2204 Vagrant box by default and provisioned an internal Ubuntu package mirror using nginx and apt-mirror to support local package caching and reduce external bandwidth usage during CI runs. [4cd58bc3](https://github.com/electrocucaracha/krd/commit/4cd58bc3e1155010c1c21dbe5d5e6627468fe75e)

## [21.2.1] - 2026-08-11

### Fixed

- Resolved unexpected failures and inaccurate error messages in the pmem task's molecule prepare step by correcting the variable name used in the failed_when condition to accurately evaluate the intended result. [7b76fbf4](https://github.com/electrocucaracha/krd/commit/7b76fbf44de1653a0575de0863721c4472336b1e)

## [21.2.0] - 2026-08-11

### Added

- Enabled systematic documentation of project updates through the introduction of a comprehensive changelog following the Keep a Changelog format and adhering to Semantic Versioning. [9e0c6404](https://github.com/electrocucaracha/krd/commit/9e0c6404a81f77c158ac98962daa9cfc1ecd7757)

## [21.1.0] - 2026-07-02

### Added

- BREAKING: Enabled support for Ubuntu Noble runners by updating pipeline runs and RBAC configuration to streamline deployment and enhance security and flexibility for GitHub Actions integration with KubeVirt. [1b2c8e84](https://github.com/electrocucaracha/krd/commit/1b2c8e84d41cfc4cb3698fada688bad103952a6c)

## [21.0.0] - 2026-07-02

### Removed

- Simplified runner provisioning by eliminating redundant configuration elements and clarifying the setup flow. [733d1c99](https://github.com/electrocucaracha/krd/commit/733d1c99849c5a999660384c17c2f224822a6777)

## [20.4.0] - 2026-07-02

### Added

- Enabled flexible and reliable dynamic storage provisioning for users by allowing volume expansion and deferring binding until a pod is scheduled. [4d53618f](https://github.com/electrocucaracha/krd/commit/4d53618f835e1065418e23a61d76939a3308f921)

## [20.3.2] - 2026-07-02

### Fixed

- Resolved compatibility issues by downgrading default containerd version to 2.2.3 which restores stability for users relying on the default environment configuration without introducing any breaking behavior or API changes. [261a6737](https://github.com/electrocucaracha/krd/commit/261a6737ba1a2b935f7bb1299eb07a186e2f44d3)

## [20.3.1] - 2026-07-01

### Changed

- Updated GitHub Actions runners to ubuntu-24.04 for improved performance and compatibility with the latest available environment. [8148c7d3](https://github.com/electrocucaracha/krd/commit/8148c7d32d23d8724d0defd0468eeefe003c8710)

## [20.3.0] - 2026-07-01

### Added

- Enabled rapid, repeatable environment resets for testing and CI purposes through automation of full environment recreation in Kubernetes, including volume cleanup, cluster installation, deployment of key components, provisioning of a golden image pipeline, and self-hosted GitHub Actions runner configuration. [87d82c49](https://github.com/electrocucaracha/krd/commit/87d82c49b1b3205dd8aabe0a5f9cfb82b2a7de19)

## [20.2.1] - 2026-07-01

### Changed

- Upgraded dependencies to their latest versions, including GitHub Actions, Kubespray, containerd, Ansible Galaxy roles and collections, Kubernetes Python package, k8sgpt, litellm, ubuntu-runner, and other resource images, thereby improving reliability, security, and maintainability without introducing breaking changes. [94ea4256](https://github.com/electrocucaracha/krd/commit/94ea4256939bf55746e6727ec624dcee08507eb1)

## [20.2.0] - 2026-06-10

### Added

- BREAKING: Enabled pinned actions in the version update script to allow certain GitHub Actions to remain at specific versions while others are updated automatically, preventing breaking changes from automatic updates unless explicitly removed from a new `pinned_actions` array. [2fc3cfff](https://github.com/electrocucaracha/krd/commit/2fc3cfff2f5f4d8f8198d0cb7ae75e85d11f734a)

## [20.1.7] - 2026-04-25

### Changed

- Standardized GitHub Actions workflows across lint, spellcheck, and update jobs to ensure consistent behavior while preserving repository-specific configurations. [493e278e](https://github.com/electrocucaracha/krd/commit/493e278ef9a0515b39588a0beceb875f523dd16c)

## [20.1.6] - 2026-04-25

### Changed

- Updated dictionary definitions in the spellchecker bot's wordlist to remove MKE and add Ons, potentially requiring users with custom dictionaries relying on these words to update their configurations. [aef4179e](https://github.com/electrocucaracha/krd/commit/aef4179ebb0580b105c06c016dcab6116c26be48)

## [20.1.5] - 2026-04-25

### Changed

- Upgraded galaxy requirements and krd versions to newer dependencies including Go 1.24.0 and super-linter 8.6.0, which may necessitate migration steps for users running older versions. [92262b3c](https://github.com/electrocucaracha/krd/commit/92262b3c14a95ea3ee750b5c21490b53b3d5d128)

## [20.1.4] - 2026-04-25

### Changed

- Upgraded galaxy requirements and krd versions files to newer versions affecting various dependencies and configurations which may require migration steps or breaking changes depending on the specific configuration. [10e74743](https://github.com/electrocucaracha/krd/commit/10e74743c339c8046038551c2486f312d91c0965)

## [20.1.3] - 2026-03-20

### Changed

- Upgraded galaxy requirements and krd versions files to newer versions without introducing any breaking behavior or requiring migration efforts from developers. [c6426728](https://github.com/electrocucaracha/krd/commit/c642672814b8f513d04846b28a9ed4d02b3e133b)

## [20.1.2] - 2026-03-20

### Changed

- Upgraded galaxy requirements and krd versions to ensure compatibility with latest dependencies, requiring users who rely on these tools to migrate to the new versions. [9fe327b1](https://github.com/electrocucaracha/krd/commit/9fe327b1a54338def793e9bfe71a2d84fa84090e)

## [20.1.1] - 2026-03-20

### Changed

- Upgraded dependencies to ensure compatibility with newer software releases and maintain a stable development environment. [5a7aefd6](https://github.com/electrocucaracha/krd/commit/5a7aefd61eec0dabbc2bba3057c3b4ed28fa0fee)

## [20.1.0] - 2026-03-15

### Added

- Enabled workflows to modify pull requests by granting actions/labeler the necessary permissions without requiring any additional migration steps. [befa7799](https://github.com/electrocucaracha/krd/commit/befa7799640fc8a454878660e47bb288c1ce7f9a)

## [20.0.0] - 2026-03-15

### Removed

- Simplified the _installers.sh script by removing an unnecessary for loop and directly applying the grafana.yaml file, resulting in no observable impact on developers or operators. [4a61bce4](https://github.com/electrocucaracha/krd/commit/4a61bce477485ed98b76e7da1cc4b33d654b2237)

## [19.4.7] - 2026-03-15

### Changed

- Improved codespell linting by introducing a `.codespellrc` configuration to ignore specific words and updating GitHub Actions workflow for linter checks to remove unnecessary permissions and modify label creation. [00f5a3ef](https://github.com/electrocucaracha/krd/commit/00f5a3ef2921ba3f72fae82fced982f58cf2f603)

## [19.4.6] - 2026-02-27

### Changed

- Upgraded galaxy requirements and KRD versions files to include Python 3.9, Ansible Core 2.20.2, and Kubernetes 35.0.0, requiring users who rely on these dependencies to migrate their deployments for compatibility. [f939211b](https://github.com/electrocucaracha/krd/commit/f939211be839552865ff59f8f670ac24797d0b55)

## [19.4.5] - 2026-02-27

### Changed

- Updated galaxy requirements and krd versions files to reflect newer software versions: kpt 1.0.0-beta.61, istio 1.29.0, argocd 3.3.1, and others, potentially requiring updates or migrations in user configurations. [b054ca5d](https://github.com/electrocucaracha/krd/commit/b054ca5defa792ffb558e8d8000c8f6dc8fce1c9)

## [19.4.4] - 2026-02-27

### Changed

- Upgraded galaxy requirements and krd versions files to reflect newer dependencies including super-linter 8.5.0 and ai-inference 2.0.6. [a22b147d](https://github.com/electrocucaracha/krd/commit/a22b147da04070559b6b997ddb897cc1dcda9992)

## [19.4.3] - 2026-02-27

### Changed

- Upgraded galaxy requirements and KRD versions files to newer dependencies including Go 1.20.0, actions/ai-inference 2.0.7, and Kubernetes v1.21.1, requiring users to update their configurations accordingly. [3925d75e](https://github.com/electrocucaracha/krd/commit/3925d75e8e0993062d92d1fe5958043c0b320f0b)

## [19.4.2] - 2026-02-27

### Changed

- Updated galaxy requirements to utilize newer versions of dependencies including krd serving net and cert manager, potentially necessitating manual configuration updates from affected users. [2ce0d2d6](https://github.com/electrocucaracha/krd/commit/2ce0d2d67de36d93eff5a56a67a4f9b93b818201)

## [19.4.1] - 2026-01-31

### Fixed

- The automated verification process for latest Vagrant Boxes is now stabilized by updating the distro update schedule to run daily at 2am instead of 1am without introducing any breaking behavior and no migration steps are required. [1a899c04](https://github.com/electrocucaracha/krd/commit/1a899c0488bf059675acb020e8cef6629ceb55fc)

## [19.4.0] - 2026-01-23

### Added

- Enabled automated monitoring of system performance through the addition of kube-prometheus-stack, which provides visualization tools for administrators via Grafana dashboards and Prometheus rules. [932328da](https://github.com/electrocucaracha/krd/commit/932328daed33b75a4c28639dadd0caef893b312e)

## [19.3.4] - 2026-01-23

### Changed

- Updated galaxy requirements and krd versions files to ensure compatibility with latest dependencies and workflows. [62bb0e7f](https://github.com/electrocucaracha/krd/commit/62bb0e7fe119dcc9ca3052858ce61071f3e89579)

## [19.3.3] - 2026-01-23

### Changed

- Upgraded galaxy requirements and krd versions files to newer versions including Ansible-lint 26.1.0, jsonschema 4.26.0, ruamel-yaml 0.19.1, and filelock 3.20.2 potentially requiring users to update dependencies or modify configurations. [59ff041c](https://github.com/electrocucaracha/krd/commit/59ff041cae4fdca07915cf76228d2d2d12f2cd9e)

## [19.3.2] - 2026-01-08

### Fixed

- The GitHub Actions linter workflow has been stabilized to resolve issues detected by the zizmor linter without introducing any breaking changes or requiring migration steps. [75940e98](https://github.com/electrocucaracha/krd/commit/75940e98932716ac7615e173ae78cab45fc67898)

## [19.3.1] - 2026-01-08

### Fixed

- The linter zizimor issues were resolved by updating dependencies in GitHub Actions workflows to newer versions, specifically sh-checker from 0.9.0 to 0.10.0 and misspell from 1.27.0 to 1.27.0, which affects the on-demand_ci.yml and spell.yml workflows with no migration steps required due to backward compatibility. [940b3519](https://github.com/electrocucaracha/krd/commit/940b35198d4201b0a7467f6b90b8a1b22c05f517)

## [19.3.0] - 2026-01-08

### Added

- Enabled automated analysis of linter failures using machine learning models in GitHub Actions workflow, introducing no breaking behavior and requiring no migration steps, resulting in improved diagnostic capabilities for software build and runtime failures. [9aa18edb](https://github.com/electrocucaracha/krd/commit/9aa18edb8c0620e5bb08b3572d2005a659643513)

## [19.2.1] - 2026-01-08

### Fixed

- Optimized test execution times for kubevirt tests by reducing memory requests from 64M to 256M and changing the container disk image without introducing breaking behavior or requiring migration steps. [39b3868e](https://github.com/electrocucaracha/krd/commit/39b3868e0613bf5c8aafc5506e40601bbddfa0db)

## [19.2.0] - 2026-01-08

### Added

- The network interface multiqueue setting has been enabled and the default network interface model changed to virtio with a bridge in Kubevirt runner settings to improve performance. [1de1c48a](https://github.com/electrocucaracha/krd/commit/1de1c48a4d6bd144d1feaf4041c7d726ef304688)

## [19.1.0] - 2026-01-08

### Added

- Enabled emulation for kubevirt configurations by setting useEmulation to true and updating feature gates where necessary without introducing breaking behavior or requiring migration steps. [98625e5a](https://github.com/electrocucaracha/krd/commit/98625e5a2fa0c552d0a4ca39b58b677a00eb6dc3)

## [19.0.0] - 2026-01-02

### Removed

- The spellchecker bot has hardened its internal wordlist by removing 15 words including CRI, criproxy, datasets, KVM, QCOW, qemu, runtimes, and VMs potentially affecting users who rely on these specific terms being recognized. [e7cc1295](https://github.com/electrocucaracha/krd/commit/e7cc1295b70008bbe3b0fddf26b147b7c77cd734)

## [18.2.1] - 2025-12-30

### Fixed

- The GitHub Actions workflow for super-linter validation has been stabilized to run successfully with the latest super-linter version by updating permissions and checkout behavior. [9a9151d6](https://github.com/electrocucaracha/krd/commit/9a9151d682af9d1bc9890d3abfde4a0df9284437)

## [18.2.0] - 2025-12-30

### Added

- Enabled support for running tests on Ubuntu 2404 in Vagrant environments by adding the corresponding box to the pipeline. [c77185ca](https://github.com/electrocucaracha/krd/commit/c77185ca7e9ef492bf5b40d169b0c7fc371a30d0)

## [18.1.1] - 2025-12-30

### Fixed

- Resolved tests to capture and report status even on encountering errors by enabling the get_status function to run in such scenarios without introducing any breaking behavior or API changes requiring test script adjustments. [9d07c3d4](https://github.com/electrocucaracha/krd/commit/9d07c3d4e539cab37edd769906d90a8f24fed79b)

## [18.1.0] - 2025-12-30

### Added

- Improved failure messages now provide more detailed system information in case of errors to aid users in troubleshooting issues with their Vagrant setup without affecting API or CLI contracts and introducing any security risks. [dcab606c](https://github.com/electrocucaracha/krd/commit/dcab606c556eba931f948d47c10d94e99c4b2255)

## [18.0.0] - 2025-12-30

### Removed

- Dropped support for running VM workloads in Kubernetes via Virtlet, requiring users to update configurations and install alternative solutions. [a92e33eb](https://github.com/electrocucaracha/krd/commit/a92e33eb665cce2ca9d53fb857d6f58e84478170)

## [17.0.1] - 2025-12-27

### Fixed

- Resolved linting issues by updating linter configuration to exclude certain checks, which may break existing linting behavior for users requiring no migration steps or API/CLI contract updates. [9aa5ebd4](https://github.com/electrocucaracha/krd/commit/9aa5ebd45f05423b28c329aba3b1a489984b0246)

## [17.0.0] - 2025-12-27

### Removed

- Eliminated the ability for users to manually trigger an automatic rebase of their pull request changes by removing the archive rebase action from GitHub workflows. [7c7c376f](https://github.com/electrocucaracha/krd/commit/7c7c376f4e7cace1e2fb10d6fb08713e5e54fdff)

## [16.1.3] - 2025-12-27

### Changed

- Updated versions of dependencies including GitHub Actions, Docker tags, and Kubernetes components were harmonized to ensure compatibility and the latest features are available. [357a82de](https://github.com/electrocucaracha/krd/commit/357a82de25ff029a4e52ce924dc3602cf4d2ab98)

## [16.1.2] - 2025-12-26

### Fixed

- Storage provisioning for runners has been optimized to default to the topolvm-provisioner class, replacing the previous hardcoded value and requiring no migration steps from users. [4eec3fd1](https://github.com/electrocucaracha/krd/commit/4eec3fd170ef1dfb04db5bd9683adf79ae6a724d)

## [16.1.1] - 2025-12-23

### Fixed

- Resolved the Tekton operator installation issue by updating its link in the install script to point to `infra.tekton.dev` instead of `storage.googleapis.com`, requiring users to verify their setup after updating if they had previously installed it. [5cb0b25b](https://github.com/electrocucaracha/krd/commit/5cb0b25ba3782ee1734bda03d19bb7b15256e488)

## [16.1.0] - 2025-12-23

### Added

- Introduced automatic installation of the CSI Snapshotter using an external snapshotter, which is now fetched from GitHub releases and will be automatically updated in the CI pipeline. [5a338d39](https://github.com/electrocucaracha/krd/commit/5a338d391918c0cfc32ff92d089a366167226c7d)

## [16.0.2] - 2025-12-23

### Changed

- Upgraded Kubernetes version to v1.33.7 in various configuration files, affecting the cluster's behavior and possibly requiring migration steps for users running older versions. [f48bc916](https://github.com/electrocucaracha/krd/commit/f48bc91606604adb44564d1b7880d3123d9e75ef)

## [16.0.1] - 2025-12-23

### Fixed

- Stabilized multinode tests by allocating two CPUs per public-net pod to mitigate potential resource bottlenecks and improve overall performance in these environments. [b1e9e804](https://github.com/electrocucaracha/krd/commit/b1e9e804dd995bb7750a07fa4848643abec95492)

## [16.0.0] - 2025-12-23

### Removed

- The typo in the _untested_installers.sh script has been corrected without any observable impact on behavior, API contract, security, config schema, or migration requirements. [7ad8c963](https://github.com/electrocucaracha/krd/commit/7ad8c9634755dfeb5bbb7b572fa6d8d03d309530)

## [15.0.2] - 2025-12-23

### Changed

- Modernized galaxy requirements and KRD versions files to align with newer dependencies and configurations used in the deployment process, requiring migration steps for existing deployments to maintain compatibility. [3e4bd36a](https://github.com/electrocucaracha/krd/commit/3e4bd36a23a03419fd92eaaaab78e6cd4947ce3c)

## [15.0.1] - 2025-12-11

### Changed

- Upgraded galaxy requirements and krd versions to ensure compatibility with latest dependencies and workflows impacting multiple users. [9cc76249](https://github.com/electrocucaracha/krd/commit/9cc7624967739cc0def2340b3ddfd5ee92f0f2df)

## [15.0.0] - 2025-12-11

### Removed

- Simplified the spell checker's wordlist by removing datasets and runtime from its list of recognized words, which may affect users relying on these terms being flagged by the spell checker. [5d8440fe](https://github.com/electrocucaracha/krd/commit/5d8440fe96388c8edfaf4754bdad21d7e8cff44a)

## [14.0.2] - 2025-11-19

### Changed

- Updated test requirements to pin molecule module version to 25.1.0 potentially requiring users who rely on it for testing to update their dependencies accordingly. [7e0b04be](https://github.com/electrocucaracha/krd/commit/7e0b04be9f9774b9331b796417299f889f6fcbf8)

## [14.0.1] - 2025-11-19

### Changed

- Credentials are now persisted for subsequent jobs in the update CI workflow. [0accbdf2](https://github.com/electrocucaracha/krd/commit/0accbdf24c1f6de90375feb0136b6e35ad111e9d)

## [14.0.0] - 2025-10-09

### Removed

- Eliminated reliance on cache CI task for Vagrant boxes builds which may now take longer to complete without the ability to reuse cached box files. [b7e49471](https://github.com/electrocucaracha/krd/commit/b7e49471debe2ffad23adafbe34192794c292ca8)

## [13.3.2] - 2025-10-09

### Changed

- Updated the Ubuntu runner pipeline to utilize VirtualBox 7.2 instead of version 7.1, requiring users to ensure their existing environments and VirtualBox installations are updated accordingly. [8f2f67a8](https://github.com/electrocucaracha/krd/commit/8f2f67a89ae0ac217a43216e6aaa9e76510050ec)

## [13.3.1] - 2025-10-08

### Changed

- The local box repository now uses a custom URL for the generic/ubuntu2204 box, pointing to a specific node's metadata.json file instead of the default provider. [329fb81c](https://github.com/electrocucaracha/krd/commit/329fb81cfa460c3f318ddd283bdcc774b15a3684)

## [13.3.0] - 2025-09-14

### Added

- Enabled GitHub actions to utilize updated wordlists that include new terms such as "datasets" and "runtime", potentially requiring users to update their workflows. [fea9845e](https://github.com/electrocucaracha/krd/commit/fea9845ef7256de3439b290dbc6e284c9e95268d)

## [13.2.0] - 2025-09-14

### Added

- Enabled trivy severity filtering allowing users to specify which vulnerability severities are checked during scans impacting the trivy.yaml configuration file where users can now define which severities to include CRITICAL and HIGH by default. [261fb2af](https://github.com/electrocucaracha/krd/commit/261fb2af1fed18412e1754b3be9d2a618acf08ca)

## [13.1.0] - 2025-09-14

### Added

- Enabled GitHub Actions workflows to adhere to security policies by persisting credentials only within individual actions rather than across multiple steps. [b4f569da](https://github.com/electrocucaracha/krd/commit/b4f569dadb450039a513bba2f82403b74be6d15b)

## [13.0.5] - 2025-09-14

### Changed

- Upgraded Kubernetes to version v1.32.8, requiring no migration steps but potentially necessitating updates to environment variables or config files if customized. [cbf2c5a8](https://github.com/electrocucaracha/krd/commit/cbf2c5a88c77bc0f38b639c186f134fe5cbc9b33)

## [13.0.4] - 2025-09-04

### Changed

- Updated the LLM Lite image in the litellm.yml file to utilize a newer version, main-v1.76.2-nightly, from its GitHub repository without introducing any breaking behavior or security concerns. [329ba194](https://github.com/electrocucaracha/krd/commit/329ba194c634b4427552c303524df5baf68ba94d)

## [13.0.3] - 2025-09-04

### Changed

- Upgraded galaxy requirements and krd versions to ensure compatibility with the latest dependencies and tools, requiring users who rely on these roles and versions for their infrastructure setup to adjust configuration files accordingly. [984a5c12](https://github.com/electrocucaracha/krd/commit/984a5c12898efe0b32451f77e4ac5bf9326773ab)

## [13.0.2] - 2025-09-04

### Changed

- Updated galaxy requirements and krd versions files to reflect new dependencies, requiring users who rely on these dependencies for their pipelines and galaxy configurations to update their environments accordingly. [423421e5](https://github.com/electrocucaracha/krd/commit/423421e59715b435b36248cf0522b90163c761e1)

## [13.0.1] - 2025-09-04

### Changed

- Updated Kubespray and Kubernetes versions to v2.28.1 and 1.32.5 respectively in galaxy-requirements.yml, krd-vars.yml, and other files with no impact on API or CLI contracts and no migration steps required. [1a1793f6](https://github.com/electrocucaracha/krd/commit/1a1793f64950411f34d845eaf9756d75731ee90a)

## [13.0.0] - 2025-08-12

### Removed

- Eliminated outdated dictionary definitions for datasets and runtime from the spellchecker bot to prevent potential functionality issues if these terms are referenced elsewhere in the system. [fe1e68e3](https://github.com/electrocucaracha/krd/commit/fe1e68e38173ed9d8f16566980018ed0362fe408)

## [12.0.1] - 2025-08-12

### Changed

- Upgraded galaxy requirements and krd versions files to newer dependencies, including kubernetes.core 6.1.0 and community.docker 4.7.0, potentially requiring migration steps for users depending on the specific version upgrades. [39441963](https://github.com/electrocucaracha/krd/commit/39441963a558656e61ae83684a800b89083a3735)

## [12.0.0] - 2025-08-11

### Removed

- Eliminated outdated external links from the documentation to improve readability without altering breaking behavior or requiring migration efforts. [167421ca](https://github.com/electrocucaracha/krd/commit/167421ca568feaf721fe061604d27a083729de1e)

## [11.2.0] - 2025-08-11

### Added

- Enabled automatic default branch setting for super-linter in GitHub workflows based on the current branch name if unspecified, affecting users who configure linter jobs without requiring manual intervention to migrate existing setups and introducing no breaking behavior or API changes. [d67291d1](https://github.com/electrocucaracha/krd/commit/d67291d1f61c96c9caf3bc473ae954807d746601)

## [11.1.7] - 2025-07-28

### Changed

- Updated versions of multiple dependencies including Knative, ArgoCD, Tekton, and Kubernetes components to ensure compatibility and reflect latest releases affecting users who must update their configurations accordingly due to minor version bumps that may impact future workflows. [08f42a3b](https://github.com/electrocucaracha/krd/commit/08f42a3b9c1b016ec4887121219ec875c26820a4)

## [11.1.6] - 2025-07-27

### Changed

- Optimized kagent deployment versions to be controlled and managed centrally, ensuring consistent and up-to-date installations across environments. [f7db95c6](https://github.com/electrocucaracha/krd/commit/f7db95c65b536500631b1e93b3619d9fbd4e9ca0)

## [11.1.5] - 2025-07-27

### Changed

- Modernized the kagent ollama agent configuration to improve performance and functionality by modifying its name, model settings, system messages, tool server settings, resource requests, and adding new environment variables and config schema options for streamable HTTP transport. [db63aa79](https://github.com/electrocucaracha/krd/commit/db63aa7916cd4495f0a8372b17340a7ebd14d080)

## [11.1.4] - 2025-07-27

### Changed

- Kagent now uses CNPG for its database, replacing the previous setup. [ccd1b795](https://github.com/electrocucaracha/krd/commit/ccd1b7951813ed6288cd0337d9fca362b1dd17b2)

## [11.1.3] - 2025-07-27

### Changed

- Simplified kagent setup instructions to remove agent-specific configurations and apply generic approaches for kagent resources. [e1091478](https://github.com/electrocucaracha/krd/commit/e1091478e430609cc4bc0e11252a848bd01f546f)

## [11.1.2] - 2025-07-22

### Changed

- Updated Knative serving configurations to reference version v1.19.0, requiring users to update their deployments and settings accordingly without introducing breaking behavior or API changes. [2af5b590](https://github.com/electrocucaracha/krd/commit/2af5b590796bfb34ccba899e4aef1f3b4ce4e8df)

## [11.1.1] - 2025-07-22

### Changed

- Updated image tag references in Kubespray to require a prefix for certain images, affecting how image versions are set and used in playbooks and templates, requiring migration steps to ensure compatibility with newer versions of Kubespray. [6e9e4114](https://github.com/electrocucaracha/krd/commit/6e9e41145901b94116d6d205e22b1b96bb661e78)

## [11.1.0] - 2025-07-22

### Added

- The wordlist used for spell checking has been updated to include new terms, specifically "datasets" and "runtime", which may affect the accuracy of spell checks in certain contexts. [a7c4ef45](https://github.com/electrocucaracha/krd/commit/a7c4ef4549e5fbf524a7432f0b15ca8f42654360)

## [11.0.5] - 2025-07-22

### Changed

- The environment variables KRD_ANSIBLE_DEBUG and PKG_DEBUG now default to false, simplifying the execution process by reducing verbosity. [d528bb43](https://github.com/electrocucaracha/krd/commit/d528bb439a8d879304288c98193c73d2f1af4a1b)

## [11.0.4] - 2025-07-22

### Changed

- Modernized the CI process by updating several dependencies to their latest versions including Go, super-linter, pyspelling-any, kubernetes, and cert-manager which may require users who rely on these dependencies for their Kubernetes environments to review and adapt their configurations accordingly. [0be57358](https://github.com/electrocucaracha/krd/commit/0be57358816abe36abbf71d176075612d707f6d7)

## [11.0.3] - 2025-07-07

### Changed

- Updated the identation format value in the Makefile from 2 spaces to 4 spaces, which may affect users who have customized their own formatting settings and may require adjustments to maintain consistent formatting. [6444f82f](https://github.com/electrocucaracha/krd/commit/6444f82f9ea4d6321c2adf3a2beffd702f53c92b)

## [11.0.2] - 2025-07-05

### Changed

- The spellchecker bot now correctly identifies and suggests corrections for words in text due to updated dictionary definitions that resolve case sensitivity issues. [1ace4ef5](https://github.com/electrocucaracha/krd/commit/1ace4ef5cc64273bfc7b6dcadcc6d28b53414980)

## [11.0.1] - 2025-07-05

### Changed

- Simplified documentation for the Kubernetes Reference Deployment (KRD) project to improve readability and clarity in architecture documentation, provisioning scripts, and benchmarking results without introducing any breaking behavior or migration requirements. [4b8d11cc](https://github.com/electrocucaracha/krd/commit/4b8d11cc72d57aa596b89e3e11d785ee929a04d2)

## [11.0.0] - 2025-06-28

### Removed

- Simplified kyverno installation by eliminating unnecessary dependency on Gatekeeper. [fde2f94a](https://github.com/electrocucaracha/krd/commit/fde2f94a25a0e4c82105bdf6ec2079285f7f5b32)

## [10.1.0] - 2025-06-26

### Added

- Improved spell-checking accuracy for project tools by updating the wordlist to include Agentic, kagent, KRM, and aio terms. [f0ebb186](https://github.com/electrocucaracha/krd/commit/f0ebb186f761bec7e84f35728e7da298ccc6bc83)

## [10.0.4] - 2025-06-26

### Changed

- Updated documentation now clearly explains the POD Descriptor File (PDF) concept and custom cluster definitions for deploying Kubernetes clusters on bare-metal or virtual machines using Ansible, while also listing supported Linux distributions and included components with a focus on extensibility and configurability. [ca335091](https://github.com/electrocucaracha/krd/commit/ca335091b9c1771be7d0cd274c21c1d5bba0e7a0)

## [10.0.3] - 2025-06-26

### Changed

- Updated links in the README.md file to point to their correct locations ensuring users have access to accurate information for Kubernetes-related topics and resolving a minor issue that could lead to confusion when following provided resources. [7cd181ed](https://github.com/electrocucaracha/krd/commit/7cd181ed98566d6119d857afff03ce311246cb74)

## [10.0.2] - 2025-06-26

### Changed

- The Kubernetes version is now correctly retrieved and stored in cluster configuration files regardless of the presence of the KRD_KUBE_VERSION variable or a cluster configuration file. [2b1b7a8e](https://github.com/electrocucaracha/krd/commit/2b1b7a8e57aaa21422038d3d1e04d584d0acc13e)

## [10.0.1] - 2025-06-26

### Changed

- Upgraded Kubernetes to version 1.32.5, impacting default cluster configurations and assertions in CI checks that rely on this version, potentially necessitating updates to dependent code or configurations referencing the previous version. [5ec505df](https://github.com/electrocucaracha/krd/commit/5ec505df9da23060173f5514eed8e4ec6cd0fa48)

## [10.0.0] - 2025-06-26

### Removed

- Simplified the script for installing chart installers to adhere to best practices and improve code quality without affecting API or CLI contract. [4b68d942](https://github.com/electrocucaracha/krd/commit/4b68d942fe813b59788f848ad5ff7e04da0391b3)

## [9.0.2] - 2025-06-26

### Changed

- Updated Kubespray to version v2.28.0, adjusting default versions of Kubernetes and Cert-Manager to 1.31.4 and 1.17.2 respectively in various configuration files and scripts. [698c7cac](https://github.com/electrocucaracha/krd/commit/698c7cac93c68c264fc951058f091d99ccbebe14)

## [9.0.1] - 2025-04-30

### Changed

- Enabled support for Agentic AI KRM platform by adding kagent service and its dependencies to the supported scenarios in README.md. [f0b26b21](https://github.com/electrocucaracha/krd/commit/f0b26b21aa136dd5da0771471182f5de7411b659)

## [9.0.0] - 2025-04-28

### Removed

- Eliminated the automatic deletion of the CDI namespace during KubeVirt uninstallation, requiring users who have CDI installed to manually delete the cdi namespace after uninstalling. [deab1bce](https://github.com/electrocucaracha/krd/commit/deab1bce57d7ae8162faf099053e478ce1a6aee3)

## [8.1.1] - 2025-04-28

### Changed

- Improved functionality is now available within Kubernetes clusters thanks to the introduction of OpenAI support. [c68941d8](https://github.com/electrocucaracha/krd/commit/c68941d83dd82ed832b0d3049ec406b145aa0579)

## [8.1.0] - 2025-04-28

### Added

- Introduced new Ollama models for continued use, requiring users to update their existing configurations to utilize the new model names and API bases in the Litellm configuration file with updated API base URLs at http://ollama-svr01:11434. [24d49ec4](https://github.com/electrocucaracha/krd/commit/24d49ec4f7200f2903ddab5e3d4d864f9dfa9498)

## [8.0.3] - 2025-04-28

### Changed

- Optimized user flexibility by enabling override of all-in-one IP address in Ansible inventory for host-installer mode, impacting installer node provisioning and deployment. [fbe741c7](https://github.com/electrocucaracha/krd/commit/fbe741c761b7e04a6ccdd8325a789b847725025e)

## [8.0.2] - 2025-04-25

### Changed

- Enabled debugging for workflows by defaulting KRD_DEBUG to ACTIONS_RUNNER_DEBUG, which in turn defaults to ACTIONS_STEP_DEBUG if set, otherwise falling back to false. [76806102](https://github.com/electrocucaracha/krd/commit/7680610203e689a7a43e6ab24df744c6297636da)

## [8.0.1] - 2025-04-25

### Changed

- Simplified the management of KRD_DEBUG by making it implicitly set to false by default without introducing any breaking behavior or migration requirements. [4cc994d3](https://github.com/electrocucaracha/krd/commit/4cc994d3d34fb81408781d002a60e8b7aa759f38)

## [8.0.0] - 2025-04-25

### Removed

- Eliminated support for self-hosted installations of the actions-runner-controller to simplify maintenance and reduce complexity. [569fb4d2](https://github.com/electrocucaracha/krd/commit/569fb4d2b5e01acaf516978a760dec3b7973ec70)

## [7.6.0] - 2025-04-24

### Added

- Enabled comprehensive cleanup during Longhorn uninstallation by deleting the Longhorn settings confirmation flag and system namespace. [9253343f](https://github.com/electrocucaracha/krd/commit/9253343f7a2d24728fb546147cf48ef904a79f08)

## [7.5.1] - 2025-04-24

### Changed

- Optimized test VM memory requirements by reducing the requested amount from 128Mi to 64M for default network setups thereby potentially improving test execution speed without introducing any breaking behavior or API changes. [aee73b37](https://github.com/electrocucaracha/krd/commit/aee73b37245cda3bef1bcec3546551f8d2f99b30)

## [7.5.0] - 2025-04-24

### Added

- Enabled local network access for LiteLLM by default, allowing Firefox and Chrome to connect without requiring system settings changes, improving usability for users accessing LiteLLM from these browsers. [6189409d](https://github.com/electrocucaracha/krd/commit/6189409d69796a3b0dde4bd784d0a3849fa0c5a0)

## [7.4.1] - 2025-04-24

### Changed

- Hardened KubeVirt Runner to allow for increased virtual machine density by enabling memory overcommit and reducing the default memory request from 16G to 8G, with guest memory allocation set to 16G. [e8cb75f0](https://github.com/electrocucaracha/krd/commit/e8cb75f07dbc54ecea5beff0aef41493f6d607f3)

## [7.4.0] - 2025-04-24

### Added

- Enabled customization of KubeVirt CPU allocation ratio configuration through environment variable injection, supporting users who require tailored CPU settings without affecting existing installations. [8a8b667d](https://github.com/electrocucaracha/krd/commit/8a8b667d95c04468c4be034a1dc83a335a283440)

## [7.3.1] - 2025-04-24

### Changed

- Simplified virtlink tests by automating setup through a sample VirtualMachine resource in YAML format, reducing test complexity and enabling easier testing. [39c3ad28](https://github.com/electrocucaracha/krd/commit/39c3ad2830de2041b42528892f3f7edecabd13eb)

## [7.3.0] - 2025-04-24

### Added

- Enabled increased inotify resources to prevent failures on fsnotify watcher when running `kubectl logs`, particularly benefiting users relying on Rook Ceph functionality. [5076bd7e](https://github.com/electrocucaracha/krd/commit/5076bd7e1ab600f54f0b34b5984682945c76eaa2)

## [7.2.1] - 2025-04-24

### Changed

- Modernized dependencies to improve compatibility and security for users, with no breaking behavior or migration requirements necessary. [ebcf7670](https://github.com/electrocucaracha/krd/commit/ebcf767090c96174b8122e0b487b89abf494d121)

## [7.2.0] - 2025-04-23

### Added

- Enabled tracking of rstcheck warnings in documentation by introducing a configuration file that sets the report level to WARNING. [88811d1b](https://github.com/electrocucaracha/krd/commit/88811d1b52842fcebb22544272e241e054640f03)

## [7.1.1] - 2025-04-23

### Changed

- Updated editorconfig linting to reference the new configuration file name, which now affects linter workflows including GitHub Actions and Makefile tasks. [b919b639](https://github.com/electrocucaracha/krd/commit/b919b639483b0bd5fbae2db0888167c6a03b1060)

## [7.1.0] - 2025-04-23

### Added

- Enabled access to large language models through the LiteLLM service, which is now accessible via an API at port 4000 and can be accessed through a Kubernetes ingress. [5340bc89](https://github.com/electrocucaracha/krd/commit/5340bc890350834c585c1b13e3adefef7aff8ce7)

## [7.0.10] - 2025-04-19

### Changed

- Enabled support for PostgreSQL clusters by introducing CloudNativePG into the existing infrastructure and updating related documentation and deployment processes. [0f03650b](https://github.com/electrocucaracha/krd/commit/0f03650b422626bdbec8fe0875a33bde5046bf25)

## [7.0.9] - 2025-04-16

### Changed

- Optimized K8sGPT resources to resolve compatibility issues and introduced a test case for verifying functionality. [cc98ba3f](https://github.com/electrocucaracha/krd/commit/cc98ba3f4cdfe838863d692c6f7f29d8e2ca56bc)

## [7.0.8] - 2025-04-09

### Changed

- Updated the GitHub Actions workflow to utilize the super-linter/super-linter repository, ensuring the project leverages the latest version of the super-linter tool without requiring any migration steps and maintaining an unchanged API contract. [835c76ed](https://github.com/electrocucaracha/krd/commit/835c76ed29f2509594790bee56dade17cde5948d)

## [7.0.7] - 2025-04-03

### Changed

- Stabilized retrieval of galaxy collection versions by updating the endpoint from v2 to v3, requiring dependent scripts to adjust their calls accordingly. [9b701550](https://github.com/electrocucaracha/krd/commit/9b70155085c9d76a47d40d38ca358c4b523af7cf)

## [7.0.6] - 2025-03-13

### Changed

- Updated galaxy requirements and krd versions files to ensure compatibility with the latest Istio, Knative, and Kubernetes software releases affecting users who rely on these dependencies for their galaxy configurations. [fe5f26b2](https://github.com/electrocucaracha/krd/commit/fe5f26b2739cb6d6caadd824867beefae5890b83)

## [7.0.5] - 2025-03-13

### Changed

- Modernized Galaxy requirements to align with latest Ansible role versions for Kubernetes, Docker, POSIX, and General collections, ensuring compatibility with current dependencies without requiring any breaking changes or migration steps. [cda9c527](https://github.com/electrocucaracha/krd/commit/cda9c5270b09148f8b727d7c64b0e08b8242c61b)

## [7.0.4] - 2025-03-13

### Changed

- Upgraded galaxy requirements and krd versions files to reflect new version numbers for various dependencies, requiring users to migrate tasks relying on these dependencies to the new versions. [8ff25137](https://github.com/electrocucaracha/krd/commit/8ff251370c55a975515e98b050276b3f38c2540c)

## [7.0.3] - 2025-03-13

### Changed

- Updated galaxy requirements and krd versions files to newer versions, requiring users with existing setups to migrate their configurations accordingly. [5fb7837f](https://github.com/electrocucaracha/krd/commit/5fb7837fa78afb40118dc63f7a9cbaed98d1fbd6)

## [7.0.2] - 2025-02-20

### Changed

- Upgraded dependencies and configurations for various packages including Istio, Sonobuoy, and Prometheus Operator, affecting test requirements and cluster settings. [d164a189](https://github.com/electrocucaracha/krd/commit/d164a189849e5a04e275cce65d4cf1034a6c9828)

## [7.0.1] - 2025-02-20

### Changed

- Updated galaxy requirements to specific release numbers for several collections: kubernetes.core was set to 5.0.0, community.docker to 4.3.0, ansible.posix to 2.0.0, and community.general to 10.2.0. [42677625](https://github.com/electrocucaracha/krd/commit/42677625e9c6566178196f176a11eb5cc3823b44)

## [7.0.0] - 2025-02-14

### Removed

- Eliminated outdated dictionary terms from the spellchecker bot's wordlist to improve accuracy and efficiency, potentially requiring users to retrain their models if previously reliant on these specific terms. [cef7bdb8](https://github.com/electrocucaracha/krd/commit/cef7bdb88d7382c5bab5cf05ee0354a4c6b0eef9)

## [6.1.6] - 2025-02-14

### Changed

- Updated galaxy requirements and krd versions files to reflect latest dependencies versions, requiring users who rely on these dependencies to migrate to the new versions. [c25db738](https://github.com/electrocucaracha/krd/commit/c25db73873793171e5a92f81d3325fa4f944b038)

## [6.1.5] - 2025-02-14

### Changed

- Updated galaxy requirements to enforce stricter versioning for role dependencies in galaxy-requirements.yml, requiring users to migrate to the latest versions of kubernetes.core (5.0.0), community.docker (4.3.0), ansible.posix (2.0.0), and community.general (10.2.0). [1faf382b](https://github.com/electrocucaracha/krd/commit/1faf382b212d6993d843c17c772467f9fabaf99c)

## [6.1.4] - 2025-02-14

### Changed

- Updated version requirements for several Ansible collections to ensure compatibility and functionality by replacing generic "Max attempts reached" messages with specific versions affecting the configuration of impacted collections including kubernetes.core, community.docker, ansible.posix, and community.general. [12ca521f](https://github.com/electrocucaracha/krd/commit/12ca521ff86f7e771757be42896a6387a0a933ea)

## [6.1.3] - 2025-02-14

### Changed

- Modernized galaxy requirements and krd versions files to ensure compatibility with newer software releases and address potential security vulnerabilities by upgrading dependencies including Python 5.4.0, Go 5.3.0, and various other package version upgrades. [06efa57b](https://github.com/electrocucaracha/krd/commit/06efa57b8eead4ebb9772c7c7ff265a4c5b2753d)

## [6.1.2] - 2025-02-11

### Changed

- Updated labeler rules now require new syntax using "changed-files" with glob patterns to specify files, replacing previous wildcard-based configurations that may need adjustments in existing workflows or scripts. [a7c145f9](https://github.com/electrocucaracha/krd/commit/a7c145f983e862bade1da479aadfaa4b942f329b)

## [6.1.1] - 2025-02-05

### Changed

- Optimized Kata containers integration tests are no longer executed in the on-demand CI workflow due to deployment issues affecting testing for Kata-enabled runtimes. [d8ae9926](https://github.com/electrocucaracha/krd/commit/d8ae99262ac67596fdb26207536a9a375cffa557)

## [6.1.0] - 2025-02-05

### Added

- Kubevirt runners now enable cpu host-passthrough by default, allowing for more flexible resource allocation. [dc120ab0](https://github.com/electrocucaracha/krd/commit/dc120ab0808285b2fee722943338cce4220182d6)

## [6.0.0] - 2025-02-05

### Removed

- Simplified the VBox logging during Vagrant up actions to reduce unnecessary log retrieval from VirtualBox VMs without introducing any breaking behavior and maintaining compatibility with existing workflows. [a59085c1](https://github.com/electrocucaracha/krd/commit/a59085c1c3473d38bfb9b9e9fc696899517434f8)

## [5.0.2] - 2025-02-05

### Changed

- Increased the timeout for Longhorn tests to 5 minutes from the default of 1 minute, allowing persistent volume claim binding and potentially requiring adjustments to test scripts that relied on the previous duration. [0f0c33f3](https://github.com/electrocucaracha/krd/commit/0f0c33f39af2369ccace568d79d9de5d66a18f79)

## [5.0.1] - 2025-02-05

### Changed

- Enabled support for multiple container runtimes in on-demand CI jobs through the addition of gvisor and youki runtime options to configuration settings. [1fcaff6c](https://github.com/electrocucaracha/krd/commit/1fcaff6ce6863e1f89c9b14ab7ae4508d4b25e61)

## [5.0.0] - 2025-02-05

### Removed

- Failed virtual machine instances are now automatically deleted by the succeeded-vmis-garbage-collector cron job, which was created to replace the existing one with the same name and targets failed VMIs instead of succeeded ones. [4e61660a](https://github.com/electrocucaracha/krd/commit/4e61660a1eeb4052a3f5860d0aa44df7aac985cb)

## [4.4.0] - 2025-02-04

### Added

- Enabled secure execution of GitHub Actions workflows by authenticating with a repository-specific secret token instead of personal access tokens. [17e308e6](https://github.com/electrocucaracha/krd/commit/17e308e6442034c9e23cf8c102a7268c4da344e2)

## [4.3.6] - 2025-02-01

### Changed

- Optimized integration testing workflows to execute multiple test sets separately in on-demand CI environments. [81f2bbdc](https://github.com/electrocucaracha/krd/commit/81f2bbdcfe96d097c77b540e6ef3dbf2b3f3ae0a)

## [4.3.5] - 2025-01-24

### Changed

- CRI-O's tests now run without Kata containers enabled due to compatibility issues that have been temporarily addressed by disabling this configuration in on-demand CI workflows. [8df12521](https://github.com/electrocucaracha/krd/commit/8df1252134f20880854029bcbc7b148ca735d1b2)

## [4.3.4] - 2025-01-24

### Changed

- Optimized the ephemeral runner garbage collector's frequency to run every hour instead of every 15 minutes as previously configured by the arc-cleanup YAML file schedule and may require manual intervention for existing jobs relying on the previous frequency. [0962192a](https://github.com/electrocucaracha/krd/commit/0962192acf8708e4d9fb106a5f869cbea187bf17)

## [4.3.3] - 2025-01-24

### Changed

- Optimized runtime classes integration tests to dynamically create deployments for each available runtimeclass, reducing repetition and improving flexibility. [e5cb69db](https://github.com/electrocucaracha/krd/commit/e5cb69db387d555d235845fab9127f09b96a8104)

## [4.3.2] - 2025-01-24

### Changed

- CI workflows now support testing Youki-enabled environments alongside other runtimes like crio and containerd without requiring any migration steps for existing workflows. [b1505176](https://github.com/electrocucaracha/krd/commit/b15051768685323363cbda888d199b54ef6dc7f6)

## [4.3.1] - 2025-01-24

### Changed

- Istio integration tests were updated to accurately test sidecar injection requests by changing the assertion to look for a specific log message indicating successful sidecar injection. [8a3f05c9](https://github.com/electrocucaracha/krd/commit/8a3f05c9b09d0d2c7bb37d87727990c338da19da)

## [4.3.0] - 2025-01-24

### Added

- Disabled gvisor by default in CRI-O runtime manager for users relying on this feature, breaking compatibility with gvisor for CRI-O deployments in Kubernetes 1.24 and later versions. [8042b745](https://github.com/electrocucaracha/krd/commit/8042b745b2add8ae62e436793a3efed5cb4abaec)

## [4.2.0] - 2025-01-24

### Added

- Introduced support for easy integration of Fluent logging agent into the deployment process through an automated installation script. [54f207cc](https://github.com/electrocucaracha/krd/commit/54f207cc21b11f81f5677190d4efc1862ca604b5)

## [4.1.1] - 2025-01-23

### Changed

- Simplified the setup process for the kubevirt runner by reducing the number of Vagrant boxes to only the generic/ubuntu2204 box, which may require users to manually add other required boxes if needed. [aeb8907e](https://github.com/electrocucaracha/krd/commit/aeb8907edf6134a399e34521660c503a7f1004ef)

## [4.1.0] - 2025-01-23

### Added

- Enabled automatic image version updates for kubevirt runner deployments by switching to an always pull policy. [9a5a69b0](https://github.com/electrocucaracha/krd/commit/9a5a69b091914a95aefa7bd1931262bbe8ddd7df)

## [4.0.1] - 2025-01-21

### Changed

- Updated the list of supported Linux distributions to include Debian Bullseye and Rocky 9 while removing support for Ubuntu Bionic and OpenSUSE Leap, potentially requiring users to adjust their configurations or migration scripts. [9d428cda](https://github.com/electrocucaracha/krd/commit/9d428cda73e8162142c6177c4fa93838fc09094f)

## [4.0.0] - 2025-01-17

### Removed

- Eliminated support for Ubuntu Bionic distro, requiring users to migrate their setups to Ubuntu Focal instead. [94575275](https://github.com/electrocucaracha/krd/commit/94575275ec26f375b499b26e99ab333fdec42ca0)

## [3.1.2] - 2025-01-17

### Changed

- Updated the Ubuntu version in Scheduled CI to 22.04 without introducing any breaking changes or modifying the API contract. [4b26f0f9](https://github.com/electrocucaracha/krd/commit/4b26f0f90224af509c630e1115bec92cd22626b1)

## [3.1.1] - 2025-01-15

### Changed

- The arc garbage collector now periodically deletes succeeded virtual machine instances in addition to ephemeral runners. [e2cab980](https://github.com/electrocucaracha/krd/commit/e2cab980f73e673d0a2a2703a0b95c1d3b76b6d6)

## [3.1.0] - 2025-01-15

### Added

- Enabled consistent namespace naming conventions in ARC installation by converting underscores to hyphens and forcing lowercase in GitHub URLs. [6089d72d](https://github.com/electrocucaracha/krd/commit/6089d72df4dfd9d9ce6aa03de876d9d62baf8ec7)

## [3.0.11] - 2025-01-10

### Changed

- Standardized Ansible group names to "kube_control_plane", "kube_node", and "etcd" for simplified Kubernetes role naming conventions in the Kubespray deployment tool. [ffdda328](https://github.com/electrocucaracha/krd/commit/ffdda328541d07764901c0c8b647abbaf80d2b27)

## [3.0.10] - 2025-01-10

### Changed

- Tox installation is now properly configured in GitHub workflows to allow molecule tests to run correctly without any limitations on parallel job execution. [ef136d76](https://github.com/electrocucaracha/krd/commit/ef136d76ee1c828524ee492ff4f0087287d9c8db)

## [3.0.9] - 2025-01-10

### Changed

- Updated the CDI version to v1.61.0 in krd-vars.yml without introducing breaking behavior and preserving an unchanged config schema. [db892bc2](https://github.com/electrocucaracha/krd/commit/db892bc2e041f55038a62a58b036e1c00a79c2b4)

## [3.0.8] - 2025-01-10

### Changed

- Updated python test requirements to ensure compatibility with latest tools and libraries, requiring users to review the updated list for any potential impact on their test environments. [d868d40c](https://github.com/electrocucaracha/krd/commit/d868d40cf1fb001bf4f9d000a9d21b628d6f4284)

## [3.0.7] - 2025-01-10

### Changed

- Upgraded metallb to version v0.14.9 without introducing any breaking behavior, API contract changes, or requiring migration steps. [d3ce9bdc](https://github.com/electrocucaracha/krd/commit/d3ce9bdc67dc5e6a38ccf394fd873c873c64298b)

## [3.0.6] - 2025-01-10

### Changed

- Updated Istio to version 1.24.2 which may require users to reapply their configurations due to potential changes in the Istio service mesh configuration schema. [b6121689](https://github.com/electrocucaracha/krd/commit/b612168998e53e8f8992c00b2e6b6033008f1248)

## [3.0.5] - 2025-01-10

### Changed

- Upgraded the virtink version to v0.17.0, which may necessitate users to adapt their setup if they have customized dependencies on the previous version. [934c2688](https://github.com/electrocucaracha/krd/commit/934c2688c2105fd5ed5bc2c0a434e1c739e669d0)

## [3.0.4] - 2025-01-10

### Changed

- Upgraded Knative to version v1.16.1, ensuring continued compatibility of configurations for users without requiring any migration steps. [8a34cf5c](https://github.com/electrocucaracha/krd/commit/8a34cf5c07cb3fb437e9d16e9d4717f2727518de)

## [3.0.3] - 2025-01-10

### Changed

- Updated the Tekton tasks for Kubevirt to version v0.23.0, requiring users with affected configurations to update their settings accordingly. [840b33a6](https://github.com/electrocucaracha/krd/commit/840b33a6e588592a6fc8d94fce48d255c3e10090)

## [3.0.2] - 2025-01-10

### Changed

- The update version script now automatically re-formats code on exit to maintain consistency and cleanliness. [6f227bfd](https://github.com/electrocucaracha/krd/commit/6f227bfd791c75e144e2cbc3603d221d90a61be9)

## [3.0.1] - 2025-01-10

### Changed

- The storage requirements for users relying on the runner image have increased from 25G to 35G due to the addition of a vagrant boxes cache. [679fdf78](https://github.com/electrocucaracha/krd/commit/679fdf787993e380268bdfccdbd55a9bfb57d0d6)

## [3.0.0] - 2025-01-10

### Removed

- Simplified configuration files by eliminating legacy TODO instructions, reducing clutter and the risk of outdated information causing issues for maintainers without introducing breaking behavior or requiring migration steps. [50d8667e](https://github.com/electrocucaracha/krd/commit/50d8667e2265d4d35c23692bb287f8b5a95c9953)

## [2.1.9] - 2025-01-10

### Changed

- Updated Kube OVN to v1.13.2, which may require migration steps for users running previous versions due to potential changes in minor patch release bug fixes or performance improvements. [203269ee](https://github.com/electrocucaracha/krd/commit/203269ee0c45f789c937a4bc9ebb8433aedfcb1e)

## [2.1.8] - 2025-01-10

### Changed

- Updated the Prometheus operator to v0.79.2 in Kubernetes deployment configuration without introducing breaking behavior, allowing maintainers to adapt their scripts accordingly. [1bc0a809](https://github.com/electrocucaracha/krd/commit/1bc0a8092390c64bc943ca7aa44e5245602dc40d)

## [2.1.7] - 2025-01-10

### Changed

- Upgraded Kubernetes version to v1.31.4, requiring users to update their cluster configurations and manually trigger the upgrade process accordingly. [fd3d95c2](https://github.com/electrocucaracha/krd/commit/fd3d95c21e90588ff1a4f946c21221d882584d57)

## [2.1.6] - 2025-01-10

### Changed

- Upgraded kubespray to version v2.27.0, incorporating security patches and minor feature enhancements that may necessitate manual configuration updates for users with custom configurations. [555fa2b5](https://github.com/electrocucaracha/krd/commit/555fa2b586d2fb699b6b042cd8ed31312972953e)

## [2.1.5] - 2025-01-09

### Changed

- Modernized the PMEM driver to version 2.13.0 without introducing any breaking behavior or API changes but modifying the default configuration schema for the pmem_driver_registrar_version parameter which may require migration steps for users relying on the older version. [9babcc3b](https://github.com/electrocucaracha/krd/commit/9babcc3b005ecc443b31b6c41b35caa2df011f58)

## [2.1.4] - 2025-01-09

### Changed

- Upgraded k8sgpt to v0.3.48 in the local configuration, requiring no migration steps due to this minor version bump and ensuring users have access to the latest k8sgpt functionality within their system. [511d1033](https://github.com/electrocucaracha/krd/commit/511d103305dfd8db12bb121450e701299f521a33)

## [2.1.3] - 2025-01-09

### Changed

- Upgraded galaxy collections and roles versions to newer releases, requiring users who rely on these dependencies in their Ansible playbooks to potentially perform migration steps due to changes in collection and role versions. [1be4c679](https://github.com/electrocucaracha/krd/commit/1be4c679db1b271198904431b4f5cf821a138e8b)

## [2.1.2] - 2025-01-09

### Changed

- Upgraded GH action versions to 4.2.0 for the cache action and 5.2.0 for setup-go, while reviewdog/action-misspell was updated to 1.26.1, potentially impacting workflows that depend on specific versions of these actions. [17ab3857](https://github.com/electrocucaracha/krd/commit/17ab3857cf03d2eb4ffbbbcedae012a84980a68d)

## [2.1.1] - 2025-01-09

### Changed

- Upgraded NFD version to v0.17.0, primarily affecting maintainers who will need to update the NFD role configuration due to potential changes in template folders and versions that may require user migration. [0180aa73](https://github.com/electrocucaracha/krd/commit/0180aa73b596d119af45b6d445633c93a7cc9deb)

## [2.1.0] - 2025-01-09

### Added

- Enabled periodic cleanup of ephemeral runners that have failed too many times through the introduction of a new ServiceAccount and CronJob which run every 15 minutes to delete such runners in parallel. [8f5faf4c](https://github.com/electrocucaracha/krd/commit/8f5faf4c25a13833a473036b0f0dde7d4661a995)

## [2.0.3] - 2025-01-08

### Changed

- The image for the kubevirt-actions-runner container has been updated to reference the new artifact generated by the repository located at ghcr.io/electrocucaracha/kubevirt-actions-runner:master. [c9545ad6](https://github.com/electrocucaracha/krd/commit/c9545ad61edf9d2b598e2cfb2158bcdf931b4766)

## [2.0.2] - 2025-01-08

### Changed

- Increased the Ubuntu runner disk size to 25G from its previous allocation of 14G in pipeline configurations. [bc2b98d7](https://github.com/electrocucaracha/krd/commit/bc2b98d7db986eca279fc2f644bfb8a219c4a298)

## [2.0.1] - 2025-01-08

### Changed

- Optimized the configuration for arc runners by enforcing a maximum of three instances to ensure efficient resource allocation and prevent potential overload issues without altering the API contract or requiring explicit migration steps. [8c13a0c3](https://github.com/electrocucaracha/krd/commit/8c13a0c387929180b035d9ad33cace3ef0f189a1)

## [2.0.0] - 2025-01-08

### Removed

- Simplified the installation workflow by eliminating non-critical Istio installation verification steps that could cause potential delays without impacting API or CLI contracts, security, or config schema. [768879b0](https://github.com/electrocucaracha/krd/commit/768879b04a61ef1f7cadee62ebc1532c32c2ff9a)

## [1.5.3] - 2025-01-08

### Changed

- Workflows can now run on self-hosted virtual machines instead of relying on GitHub's infrastructure. [5c8aa805](https://github.com/electrocucaracha/krd/commit/5c8aa805a2f38a65888535af1a4b021ca5afd443)

## [1.5.2] - 2024-12-31

### Changed

- Enabled users to specify chart versions during installations by supporting the --version flag for chart installations. [438fed80](https://github.com/electrocucaracha/krd/commit/438fed800c6a3ae59a3485b274b26651ad74022c)

## [1.5.1] - 2024-12-31

### Changed

- Updated the ubuntu runner's sources list to include the latest virtualbox version and modified dependencies accordingly, requiring users who utilize this runner in their pipelines to update their configurations. [4f0084be](https://github.com/electrocucaracha/krd/commit/4f0084be0242231390826de7dd74ed211cd8c411)

## [1.5.0] - 2024-12-18

### Added

- The Ubuntu runner pipeline now uses a passwordless sudo account, allowing for automated tasks without user intervention. [06bc4724](https://github.com/electrocucaracha/krd/commit/06bc4724ef48cd5589478e17c12fe4dd661f55b2)

## [1.4.0] - 2024-12-18

### Added

- Enabled specification of the default provider for Vagrant through the introduction of the VAGRANT_DEFAULT_PROVIDER environment variable, which now defaults to "virtualbox". [93453ba2](https://github.com/electrocucaracha/krd/commit/93453ba283d78b0d755ee44957215b4b7b2ef0c5)

## [1.3.0] - 2024-12-17

### Added

- Introduced support for Python-based workflows by installing essential packages in the Ubuntu runner pipeline, requiring no migration steps from existing pipelines due to a non-breaking change. [7207b563](https://github.com/electrocucaracha/krd/commit/7207b5632713e5a0cd18e4512f7c385100649060)

## [1.2.0] - 2024-12-17

### Added

- Enabled the Ubuntu runner pipeline to install and utilize the git package on each run without requiring any migration steps from users who rely on it for tasks involving Git repositories. [4d52d858](https://github.com/electrocucaracha/krd/commit/4d52d8581a045d7c2c6fa48f90c347c4b11d8894)

## [1.1.1] - 2024-12-17

### Changed

- Updated Kubernetes runner to use electrocucaracha GH actions, which may require users who had previously configured zhaofengli repository settings to update their setups; the API contract has been updated with new permissions for datavolumes in cdi.kubevirt.io group and config schema now uses a different image for the runner container. [002d4e79](https://github.com/electrocucaracha/krd/commit/002d4e790d455324fca8c10c8393db30d566c4e1)

## [1.1.0] - 2024-12-13

### Added

- Enabled GitHub actions to recognize new terms through an updated wordlist that includes Tekton, textlint, TopoLVM, and tox, potentially affecting automated workflows relying on these terms without introducing breaking changes or migration requirements. [2cb882ed](https://github.com/electrocucaracha/krd/commit/2cb882ed936bdc868a06da6220acc3b307388a1b)

## [1.0.5] - 2024-12-13

### Changed

- The default storage class for new deployments has been modernized to Topolvm-provisioner, requiring users to update workflows and test scripts accordingly but no migration steps are necessary. [ee82fd89](https://github.com/electrocucaracha/krd/commit/ee82fd8924b5c9387756ce904d2e7e365e5c0ba7)

## [1.0.4] - 2024-12-13

### Changed

- Optimized Gitleaks scanning by exempting specific key IDs from security checks in the Ubuntu runner pipeline configuration. [ef288648](https://github.com/electrocucaracha/krd/commit/ef288648e2118c3da82ddcf16f92fbebc95a7169)

## [1.0.3] - 2024-12-13

### Changed

- Updated pipeline parameters to conform to kebab-case and reformatted URLs in the `http` source, requiring pipelines referencing these parameters to be updated accordingly. [de280214](https://github.com/electrocucaracha/krd/commit/de2802147eaf0f6aa65510e49a523c31fd32c7fa)

## [1.0.2] - 2024-12-13

### Changed

- Volumes are now managed by specifying either a mount point or a volume group in the `volumes` configuration and the `node.sh` script creates Logical Volume groups accordingly. [8817ee8a](https://github.com/electrocucaracha/krd/commit/8817ee8a442093b5528a8dd38d1a12447f8d586a)

## [1.0.1] - 2024-12-13

### Changed

- Enabling namespace deployments for arc allows users to deploy runners in their own custom namespaces instead of the default one, affecting API behavior by allowing helm installation and deployment in these custom namespaces. [105fd4d7](https://github.com/electrocucaracha/krd/commit/105fd4d72389de7bdd89d50ba36da5db8517dbcc)

## [1.0.0] - 2024-12-10

### Changed

- Resolved the Tekton installation order to ensure proper functionality and prevent potential errors during setup without introducing any breaking behavior. [d8f2e8e6](https://github.com/electrocucaracha/krd/commit/d8f2e8e6a80afbffe5126215b17370112cc80e7e)
