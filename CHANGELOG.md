<!-- Markdownlint-disable MD024 -->

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [23.0.5] - 2026-08-11

### Changed

- Updated the changelog to accurately reflect recent project developments and provide users with a comprehensive history of changes without introducing any breaking behavior. [38ea7da0](https://github.com/electrocucaracha/krd/commit/38ea7da0973c7dc9afa142401a8a234839edf5e9)

## [23.0.4] - 2026-08-11

### Fixed

- Kubespray version replacement in check.sh was simplified to reduce maintenance overhead and risk of breakage due to surrounding syntax changes. [e34d963f](https://github.com/electrocucaracha/krd/commit/e34d963fb6eee3497c692bfed133d4a3c95c8cad)

## [23.0.3] - 2026-08-11

### Fixed

- The default kubespray version was updated from v2.29.1 to v2.31.0 in CI checks, ensuring compatibility with newer Kubernetes versions and incorporating upstream improvements. [da8abc29](https://github.com/electrocucaracha/krd/commit/da8abc290bf59d0d05c57a180cc93d94c2d76c72)

## [23.0.2] - 2026-08-11

### Changed

- Generated YAML manifests now have consistent indentation, aligning with YAML best practices for better readability. [c69c47ff](https://github.com/electrocucaracha/krd/commit/c69c47ff85e739a2f070aaef5572f4de7b25704c)

## [23.0.1] - 2026-08-11

### Fixed

- The location where free memory information is printed has been changed to standard error instead of standard output. [26f48405](https://github.com/electrocucaracha/krd/commit/26f48405ba8371d7fb9b1f63362986e88992df5b)

## [23.0.0] - 2026-08-11

### Removed

- The test environment list in tox.ini has been modified to remove an extraneous comma, ensuring compatibility and improving readability across different versions of tox. [a2b7bfea](https://github.com/electrocucaracha/krd/commit/a2b7bfeaf8b08d1d694c7e6423d09d9b9d563bdd)

## [22.0.1] - 2026-08-11

### Changed

- The project's documentation has been updated to standardize spelling and capitalization for tool names, including "spellchecker," "EditorConfig," "Git," and "Ubuntu runner." This change improves clarity and consistency with official tool names. [8b19affe](https://github.com/electrocucaracha/krd/commit/8b19affe50fa9187f057c7ce266aedfc7966f708)

## [22.0.0] - 2026-08-11

### Removed

- The test matrix for CI runs no longer includes the criproxy role, which was removed from the repository. [8967ff24](https://github.com/electrocucaracha/krd/commit/8967ff245a25624bcf1c6a0310c70ac70baead13)

## [21.2.2] - 2026-08-11

### Changed

- Molecule test environments for multiple roles were updated to use the generic/ubuntu2204 Vagrant box instead of ubuntu2004, ensuring alignment with current LTS releases and improving compatibility with newer software dependencies. [4cd58bc3](https://github.com/electrocucaracha/krd/commit/4cd58bc3e1155010c1c21dbe5d5e6627468fe75e)

## [21.2.1] - 2026-08-11

### Fixed

- The failed_when condition in the pmem role's molecule prepare step was corrected to reference the correct variable name, pmem_kind_cluster, instead of kind_cluster. [7b76fbf4](https://github.com/electrocucaracha/krd/commit/7b76fbf44de1653a0575de0863721c4472336b1e)

## [21.2.0] - 2026-08-11

### Added

- A comprehensive changelog was added to the project, following the Keep a Changelog format and adhering to Semantic Versioning. [9e0c6404](https://github.com/electrocucaracha/krd/commit/9e0c6404a81f77c158ac98962daa9cfc1ecd7757)

## [21.1.0] - 2026-07-02

### Added

- BREAKING: Ubuntu Noble runners are introduced, updating pipeline runs, VM templates, and resources to use the new image and naming. [1b2c8e84](https://github.com/electrocucaracha/krd/commit/1b2c8e84d41cfc4cb3698fada688bad103952a6c)

## [21.0.0] - 2026-07-02

### Removed

- Runner setup has been streamlined, removing redundant Vagrant box additions and obsolete Service and EndpointSlice definitions for nuc10-node06 to reduce configuration clutter. [733d1c99](https://github.com/electrocucaracha/krd/commit/733d1c99849c5a999660384c17c2f224822a6777)

## [20.4.0] - 2026-07-02

### Added

- Default storage class settings have been updated to improve dynamic provisioning reliability and user flexibility. [4d53618f](https://github.com/electrocucaracha/krd/commit/4d53618f835e1065418e23a61d76939a3308f921)

## [20.3.2] - 2026-07-02

### Fixed

- The default containerd version was downgraded from 2.3.2 to 2.2.3 due to compatibility issues with dependent components that have not been updated for this release, restoring stability for users relying on the default environment configuration. [261a6737](https://github.com/electrocucaracha/krd/commit/261a6737ba1a2b935f7bb1299eb07a186e2f44d3)

## [20.3.1] - 2026-07-01

### Changed

- GitHub Actions runners have been updated from ubuntu-22.04 to ubuntu-24.04, which offers improved performance and updated software packages. [8148c7d3](https://github.com/electrocucaracha/krd/commit/8148c7d32d23d8724d0defd0468eeefe003c8710)

## [20.3.0] - 2026-07-01

### Added

- A script has been added to automate the recreation of a full Kubernetes environment, including volume cleanup, cluster installation, deployment of key components, and configuration of self-hosted GitHub Actions runners. [87d82c49](https://github.com/electrocucaracha/krd/commit/87d82c49b1b3205dd8aabe0a5f9cfb82b2a7de19)

## [20.2.1] - 2026-07-01

### Changed

- Multiple GitHub Actions, Ansible Galaxy roles and collections, and various playbook and resource image versions were updated to their latest stable releases for security and compatibility improvements. [94ea4256](https://github.com/electrocucaracha/krd/commit/94ea4256939bf55746e6727ec624dcee08507eb1)

## [20.2.0] - 2026-06-10

### Added

- BREAKING: The version update script now supports pinned GitHub Actions, allowing certain actions to remain at specific versions while others are updated automatically. [2fc3cfff](https://github.com/electrocucaracha/krd/commit/2fc3cfff2f5f4d8f8198d0cb7ae75e85d11f734a)

## [20.1.7] - 2026-04-25

### Changed

- GitHub Actions workflows were standardized across lint, spellcheck, and update processes to ensure consistent behavior. [493e278e](https://github.com/electrocucaracha/krd/commit/493e278ef9a0515b39588a0beceb875f523dd16c)

## [20.1.6] - 2026-04-25

### Changed

- The dictionary definitions in the wordlist have been updated, removing MKE and adding Ons. [aef4179e](https://github.com/electrocucaracha/krd/commit/aef4179ebb0580b105c06c016dcab6116c26be48)

## [20.1.5] - 2026-04-25

### Changed

- Galaxy requirements and krd versions files were updated to newer versions, including Go 1.24.0, super-linter 8.6.0, and various other dependencies like knative-serving 1.21.2 and cert-manager 1.20.1. [92262b3c](https://github.com/electrocucaracha/krd/commit/92262b3c14a95ea3ee750b5c21490b53b3d5d128)

## [20.1.4] - 2026-04-25

### Changed

- Galaxy requirements and krd versions files were updated to reflect new dependencies and versions, including Ansible core 2.20.5, click 8.3.3, filelock 3.29.0, packaging 26.1, rich 15.0.0, and various other package upgrades, with no breaking behavior or migration requirements mentioned in the provided changes. [10e74743](https://github.com/electrocucaracha/krd/commit/10e74743c339c8046038551c2486f312d91c0965)

## [20.1.3] - 2026-03-20

### Changed

- The galaxy requirements and krd versions files have been updated to newer versions, including actions/cache from 5.0.3 to 5.0.4, ai-inference from 2.0.7 to 2.0.8, dorny/paths-filter from 4.0.0 to 4.0.1, and other dependencies such as argocd_version, kagent_version, and litellm image version. [c6426728](https://github.com/electrocucaracha/krd/commit/c642672814b8f513d04846b28a9ed4d02b3e133b)

## [20.1.2] - 2026-03-20

### Changed

- Galaxy requirements and krd versions files were updated to reflect the latest dependencies, including upgraded images for Kubernetes and other tools, ensuring compatibility and stability in deployments. [9fe327b1](https://github.com/electrocucaracha/krd/commit/9fe327b1a54338def793e9bfe71a2d84fa84090e)

## [20.1.1] - 2026-03-20

### Changed

- Galaxy requirements were updated, including dependencies for Knative versions, Cert Manager, and other components, which may require users to adjust their configurations accordingly. [5a7aefd6](https://github.com/electrocucaracha/krd/commit/5a7aefd61eec0dabbc2bba3057c3b4ed28fa0fee)

## [20.1.0] - 2026-03-15

### Added

- The triage workflow YAML file has been updated to include the pull-requests: write permission, which allows the actions/labeler action to modify pull requests. [befa7799](https://github.com/electrocucaracha/krd/commit/befa7799640fc8a454878660e47bb288c1ce7f9a)

## [20.0.0] - 2026-03-15

### Removed

- The shellcheck SC2043 warning was addressed by removing a single-item for loop in the _installers.sh script. [4a61bce4](https://github.com/electrocucaracha/krd/commit/4a61bce477485ed98b76e7da1cc4b33d654b2237)

## [19.4.7] - 2026-03-15

### Changed

- Codespell linting errors were fixed, and a `.codespellrc` configuration file was added to ignore specific words. [00f5a3ef](https://github.com/electrocucaracha/krd/commit/00f5a3ef2921ba3f72fae82fced982f58cf2f603)

## [19.4.6] - 2026-02-27

### Changed

- Galaxy requirements were updated, including Ansible collections, Kubernetes version, and Kubespray version. [f939211b](https://github.com/electrocucaracha/krd/commit/f939211be839552865ff59f8f670ac24797d0b55)

## [19.4.5] - 2026-02-27

### Changed

- Galaxy requirements and krd versions files were updated to reflect newer versions of various dependencies, including kpt, go, istio, argocd, and others. [b054ca5d](https://github.com/electrocucaracha/krd/commit/b054ca5defa792ffb558e8d8000c8f6dc8fce1c9)

## [19.4.4] - 2026-02-27

### Changed

- The galaxy requirements and krd versions files have been updated to reflect newer versions of dependencies, including super-linter 8.5.0, ai-inference 2.0.6, and external snapshotter v8.5.0. [a22b147d](https://github.com/electrocucaracha/krd/commit/a22b147da04070559b6b997ddb897cc1dcda9992)

## [19.4.3] - 2026-02-27

### Changed

- The galaxy requirements and krd versions files have been updated to reflect new version numbers for various dependencies, including Go, Ansible, and Knative. [3925d75e](https://github.com/electrocucaracha/krd/commit/3925d75e8e0993062d92d1fe5958043c0b320f0b)

## [19.4.2] - 2026-02-27

### Changed

- Galaxy requirements were updated, including krd versions files, to reflect the latest versions of required dependencies. [2ce0d2d6](https://github.com/electrocucaracha/krd/commit/2ce0d2d67de36d93eff5a56a67a4f9b93b818201)

## [19.4.1] - 2026-01-31

### Fixed

- The update schedule for distro verification has been modified to run daily at 2am instead of the previous time, which was the start of each month. [1a899c04](https://github.com/electrocucaracha/krd/commit/1a899c0488bf059675acb020e8cef6629ceb55fc)

## [19.4.0] - 2026-01-23

### Added

- Kube-prometheus-stack was added, enabling a Prometheus stack with Grafana dashboards. [932328da](https://github.com/electrocucaracha/krd/commit/932328daed33b75a4c28639dadd0caef893b312e)

## [19.3.4] - 2026-01-23

### Changed

- The galaxy requirements and krd versions files were updated to reflect new dependencies and versions, including actions/checkout version 6.0.2, geerlingguy.docker role version 8.0.0, and prometheus-operator_version v0.88.0. [62bb0e7f](https://github.com/electrocucaracha/krd/commit/62bb0e7fe119dcc9ca3052858ce61071f3e89579)

## [19.3.3] - 2026-01-23

### Changed

- Galaxy requirements were updated in multiple files, including galaxy-requirements.yml, krd-vars.yml, and test-requirements.txt. [59ff041c](https://github.com/electrocucaracha/krd/commit/59ff041cae4fdca07915cf76228d2d2d12f2cd9e)

## [19.3.2] - 2026-01-08

### Fixed

- The GitHub Actions linter workflow was updated to fix issues, specifically changing the version of the markdown link check action from 1.0.17 to 1.1.2 and adding a configuration option to suppress label creation during failed checks. [75940e98](https://github.com/electrocucaracha/krd/commit/75940e98932716ac7615e173ae78cab45fc67898)

## [19.3.1] - 2026-01-08

### Fixed

- The linter configuration was updated to fix issues reported by Zizimor, specifically updating dependencies for the sh-checker and misspell actions in GitHub workflows. [940b3519](https://github.com/electrocucaracha/krd/commit/940b35198d4201b0a7467f6b90b8a1b22c05f517)

## [19.3.0] - 2026-01-08

### Added

- The GitHub Actions workflow for linter analysis has been updated to enable AI-powered analyzer, allowing for automated diagnosis and resolution of build failures. [9aa18edb](https://github.com/electrocucaracha/krd/commit/9aa18edb8c0620e5bb08b3572d2005a659643513)

## [19.2.1] - 2026-01-08

### Fixed

- Test hardware resources for Kubevirt tests were reduced to improve performance by decreasing memory requests from 64M to 256M, changing the container disk image, and disabling network interface multiqueue. [39b3868e](https://github.com/electrocucaracha/krd/commit/39b3868e0613bf5c8aafc5506e40601bbddfa0db)

## [19.2.0] - 2026-01-08

### Added

- Runner configuration values have been updated in the VM specification to improve performance and compatibility. [1de1c48a](https://github.com/electrocucaracha/krd/commit/1de1c48a4d6bd144d1feaf4041c7d726ef304688)

## [19.1.0] - 2026-01-08

### Added

- Kubevirt configuration was improved by removing outdated instructions for enabling emulation and adding patches to enable required features, including host devices and virtio-fs storage volumes. [98625e5a](https://github.com/electrocucaracha/krd/commit/98625e5a2fa0c552d0a4ca39b58b677a00eb6dc3)

## [19.0.0] - 2026-01-02

### Removed

- The dictionary definitions used by the spellchecker bot have been updated, removing several terms including CRI, criproxy, datasets, KVM, QCOW, qemu, runtimes, and VMs. [e7cc1295](https://github.com/electrocucaracha/krd/commit/e7cc1295b70008bbe3b0fddf26b147b7c77cd734)

## [18.2.1] - 2025-12-30

### Fixed

- The GitHub Actions workflow for super-linter validation has been updated to meet new requirements, adding permissions for package reading and status writing, and increasing the fetch depth of the repository. [9a9151d6](https://github.com/electrocucaracha/krd/commit/9a9151d682af9d1bc9890d3abfde4a0df9284437)

## [18.2.0] - 2025-12-30

### Added

- A new Ubuntu 2404 box was added to the system, allowing for vagrant box addition via a specific URL. [c77185ca](https://github.com/electrocucaracha/krd/commit/c77185ca7e9ef492bf5b40d169b0c7fc371a30d0)

## [18.1.1] - 2025-12-30

### Fixed

- The `get_status` function now runs on error, allowing for better test coverage and debugging capabilities in the event of an unexpected failure. [9d07c3d4](https://github.com/electrocucaracha/krd/commit/9d07c3d4e539cab37edd769906d90a8f24fed79b)

## [18.1.0] - 2025-12-30

### Added

- Failure messages in the Vagrant-up action have been improved to provide more detailed information about system resources, including memory, disk usage, and kernel logs, when the action fails. [dcab606c](https://github.com/electrocucaracha/krd/commit/dcab606c556eba931f948d47c10d94e99c4b2255)

## [18.0.0] - 2025-12-30

### Removed

- Virtlet support has been dropped from the project, impacting users who relied on this feature for running VM workloads in Kubernetes. [a92e33eb](https://github.com/electrocucaracha/krd/commit/a92e33eb665cce2ca9d53fb857d6f58e84478170)

## [17.0.1] - 2025-12-27

### Fixed

- Linter configuration was updated to ignore certain validation rules, including Biome linting and formatting checks, Python Ruff format checking, and environment variable validation. [9aa5ebd4](https://github.com/electrocucaracha/krd/commit/9aa5ebd45f05423b28c329aba3b1a489984b0246)

## [17.0.0] - 2025-12-27

### Removed

- The rebase action workflow has been removed, which previously allowed users to automatically rebase changes in their pull requests. [7c7c376f](https://github.com/electrocucaracha/krd/commit/7c7c376f4e7cace1e2fb10d6fb08713e5e54fdff)

## [16.1.3] - 2025-12-27

### Changed

- Versions were updated across the project, including dependencies in galaxy-requirements.yml, playbooks/krd-vars.yml, and resources/arc-cleanup.yml. [357a82de](https://github.com/electrocucaracha/krd/commit/357a82de25ff029a4e52ce924dc3602cf4d2ab98)

## [16.1.2] - 2025-12-26

### Fixed

- Storageclass configuration for runners was updated to use the default storage class instead of setting it manually, simplifying chart installation. [4eec3fd1](https://github.com/electrocucaracha/krd/commit/4eec3fd170ef1dfb04db5bd9683adf79ae6a724d)

## [16.1.1] - 2025-12-23

### Fixed

- The Tekton operator link was updated in the _installers.sh script, affecting users who install Tekton. [5cb0b25b](https://github.com/electrocucaracha/krd/commit/5cb0b25ba3782ee1734bda03d19bb7b15256e488)

## [16.1.0] - 2025-12-23

### Added

- The install_external_snapshotter function was added to the _installers.sh script, allowing for the installation of CSI Snapshotter. [5a338d39](https://github.com/electrocucaracha/krd/commit/5a338d391918c0cfc32ff92d089a366167226c7d)

## [16.0.2] - 2025-12-23

### Changed

- Kubernetes version was bumped from v1.32.8 to v1.33.7, affecting various configuration variables and scripts that interact with Kubernetes. [f48bc916](https://github.com/electrocucaracha/krd/commit/f48bc91606604adb44564d1b7880d3123d9e75ef)

## [16.0.1] - 2025-12-23

### Fixed

- Multinode tests now use two CPUs instead of one, which may affect performance or resource allocation in these environments. [b1e9e804](https://github.com/electrocucaracha/krd/commit/b1e9e804dd995bb7750a07fa4848643abec95492)

## [16.0.0] - 2025-12-23

### Removed

- A typo in the _untested_installers.sh script was corrected, specifically in the authentication section where instructions for retrieving the jwtSecret were revised to use "Retrieve" instead of "Retrive". [7ad8c963](https://github.com/electrocucaracha/krd/commit/7ad8c9634755dfeb5bbb7b572fa6d8d03d309530)

## [15.0.2] - 2025-12-23

### Changed

- Galaxy requirements were updated, including Ansible core to 2.20.1, super-linter to 8.3.1, and several dependencies in test-requirements.txt, galaxy-requirements.yml, playbooks/krd-vars.yml, and other files. [3e4bd36a](https://github.com/electrocucaracha/krd/commit/3e4bd36a23a03419fd92eaaaab78e6cd4947ce3c)

## [15.0.1] - 2025-12-11

### Changed

- The galaxy requirements and krd versions files were updated to use newer versions of various dependencies, including Python, Kubernetes, Kubespray, and other tools. [9cc76249](https://github.com/electrocucaracha/krd/commit/9cc7624967739cc0def2340b3ddfd5ee92f0f2df)

## [15.0.0] - 2025-12-11

### Removed

- The dictionary definitions used by the spellchecker bot have been updated, removing two outdated terms: "datasets" and "runtime". [5d8440fe](https://github.com/electrocucaracha/krd/commit/5d8440fe96388c8edfaf4754bdad21d7e8cff44a)

## [14.0.2] - 2025-11-19

### Changed

- The molecule module was pinned to version 25.1.0 in test-requirements.in and test-requirements.txt, updating dependencies for ansible-compat, ansible-core, and other related packages. [7e0b04be](https://github.com/electrocucaracha/krd/commit/7e0b04be9f9774b9331b796417299f889f6fcbf8)

## [14.0.1] - 2025-11-19

### Changed

- PR creation in the update CI workflow has been fixed, which affects maintainers who rely on this process to create pull requests. [0accbdf2](https://github.com/electrocucaracha/krd/commit/0accbdf24c1f6de90375feb0136b6e35ad111e9d)

## [14.0.0] - 2025-10-09

### Removed

- The cache CI task for Vagrant boxes has been removed, which may cause issues if users relied on this feature to speed up their builds. [b7e49471](https://github.com/electrocucaracha/krd/commit/b7e49471debe2ffad23adafbe34192794c292ca8)

## [13.3.2] - 2025-10-09

### Changed

- VirtualBox was updated from version 7.1 to 7.2 in the Ubuntu runner pipeline configuration, which may require users to update their VirtualBox installations if they are using an older version. [8f2f67a8](https://github.com/electrocucaracha/krd/commit/8f2f67a89ae0ac217a43216e6aaa9e76510050ec)

## [13.3.1] - 2025-10-08

### Changed

- The local box repository has been updated to point to a specific machine's address, requiring users to migrate their configuration to use the new URL for adding boxes. [329fb81c](https://github.com/electrocucaracha/krd/commit/329fb81cfa460c3f318ddd283bdcc774b15a3684)

## [13.3.0] - 2025-09-14

### Added

- The dictionary used for wordlist filtering has been updated to include new terms, specifically "datasets" and "runtime". [fea9845e](https://github.com/electrocucaracha/krd/commit/fea9845ef7256de3439b290dbc6e284c9e95268d)

## [13.2.0] - 2025-09-14

### Added

- Trivy vulnerability filtering was added, allowing users to specify severity levels for detection. [261fb2af](https://github.com/electrocucaracha/krd/commit/261fb2af1fed18412e1754b3be9d2a618acf08ca)

## [13.1.0] - 2025-09-14

### Added

- GitHub Actions workflows were updated to persist credentials in a false state, ensuring that sensitive information is not stored unnecessarily. [b4f569da](https://github.com/electrocucaracha/krd/commit/b4f569dadb450039a513bba2f82403b74be6d15b)

## [13.0.5] - 2025-09-14

### Changed

- Kubernetes version has been bumped from v1.32.5 to v1.32.8 in multiple files, including configuration templates and assertion scripts. [cbf2c5a8](https://github.com/electrocucaracha/krd/commit/cbf2c5a88c77bc0f38b639c186f134fe5cbc9b33)

## [13.0.4] - 2025-09-04

### Changed

- The LLM Lite image in the litellm.yml file has been updated to use the main-v1.76.2-nightly tag from ghcr.io/berriai/litellm, replacing the previous main-v1.67.0-stable tag. [329ba194](https://github.com/electrocucaracha/krd/commit/329ba194c634b4427552c303524df5baf68ba94d)

## [13.0.3] - 2025-09-04

### Changed

- Galaxy requirements and krd versions files were updated to newer versions, including super-linter to 8.1.0, galaxy-requirements.yml to 7.5.0 for geerlingguy.docker and 11.2.1 for community.general, and krd-vars.yml to knative-v1.19.1 for knative and net_istio_version to vknative-v1.19.1. [984a5c12](https://github.com/electrocucaracha/krd/commit/984a5c12898efe0b32451f77e4ac5bf9326773ab)

## [13.0.2] - 2025-09-04

### Changed

- Galaxy requirements and krd versions files were updated to reflect newer versions of various dependencies, including argocd, tekton, and ansible-lint. [423421e5](https://github.com/electrocucaracha/krd/commit/423421e59715b435b36248cf0522b90163c761e1)

## [13.0.1] - 2025-09-04

### Changed

- Kubespray and Ansible versions have been updated in the galaxy-requirements.yml file, affecting several dependencies including Kubernetes, Knative, and Kubesphere. [1a1793f6](https://github.com/electrocucaracha/krd/commit/1a1793f64950411f34d845eaf9756d75731ee90a)

## [13.0.0] - 2025-08-12

### Removed

- The dictionary definitions used by the spellchecker bot have been updated, removing "datasets" and "runtime" from the list of words to be checked. [fe1e68e3](https://github.com/electrocucaracha/krd/commit/fe1e68e38173ed9d8f16566980018ed0362fe408)

## [12.0.1] - 2025-08-12

### Changed

- The galaxy requirements and krd versions files have been updated to new versions, which will likely break some workflows that were relying on the previous versions. [39441963](https://github.com/electrocucaracha/krd/commit/39441963a558656e61ae83684a800b89083a3735)

## [12.0.0] - 2025-08-11

### Removed

- Removed dead external links from README.md, specifically removing references to KubeSphere DevOps System and Service Mesh documentation URLs that no longer exist. [167421ca](https://github.com/electrocucaracha/krd/commit/167421ca568feaf721fe061604d27a083729de1e)

## [11.2.0] - 2025-08-11

### Added

- The default branch for the super-linter has been added to GitHub workflows, automatically setting it to either the current head ref or the repository's default branch name. [d67291d1](https://github.com/electrocucaracha/krd/commit/d67291d1f61c96c9caf3bc473ae954807d746601)

## [11.1.7] - 2025-07-28

### Changed

- Versions were upgraded in various dependencies, including Knative, ArgoCD, Tekton, and Kubevirt, among others. [08f42a3b](https://github.com/electrocucaracha/krd/commit/08f42a3b9c1b016ec4887121219ec875c26820a4)

## [11.1.6] - 2025-07-27

### Changed

- Kagent deployment versions are now controlled, requiring users to specify the version when installing kagent-crds and kagent. [f7db95c6](https://github.com/electrocucaracha/krd/commit/f7db95c65b536500631b1e93b3619d9fbd4e9ca0)

## [11.1.5] - 2025-07-27

### Changed

- The kagent ollama agent configuration has been updated to improve its functionality. [db63aa79](https://github.com/electrocucaracha/krd/commit/db63aa7916cd4495f0a8372b17340a7ebd14d080)

## [11.1.4] - 2025-07-27

### Changed

- Kagent database now uses CNPG instead of the previous setup, requiring no migration steps for users. [ccd1b795](https://github.com/electrocucaracha/krd/commit/ccd1b7951813ed6288cd0337d9fca362b1dd17b2)

## [11.1.3] - 2025-07-27

### Changed

- The setup instructions for kagent have been updated to reflect changes in namespace management, API key secret references, and tool server configurations. [e1091478](https://github.com/electrocucaracha/krd/commit/e1091478e430609cc4bc0e11252a848bd01f546f)

## [11.1.2] - 2025-07-22

### Changed

- Knative serving version was bumped from 1.18.1 to 1.19.0, which may require migration steps for users running this component. [2af5b590](https://github.com/electrocucaracha/krd/commit/2af5b590796bfb34ccba899e4aef1f3b4ce4e8df)

## [11.1.1] - 2025-07-22

### Changed

- Prefix image tags were updated in Kubespray to include a version prefix, changing the format of some images from `image:version` to `image:vversion`. [6e9e4114](https://github.com/electrocucaracha/krd/commit/6e9e41145901b94116d6d205e22b1b96bb661e78)

## [11.1.0] - 2025-07-22

### Added

- The list of misspelled words in the project's wordlist has been updated to include "datasets" and "runtime". [a7c4ef45](https://github.com/electrocucaracha/krd/commit/a7c4ef4549e5fbf524a7432f0b15ca8f42654360)

## [11.0.5] - 2025-07-22

### Changed

- The natural language linting issues in the project's workflows and README files have been fixed, addressing potential formatting problems that could affect users. [d528bb43](https://github.com/electrocucaracha/krd/commit/d528bb439a8d879304288c98193c73d2f1af4a1b)

## [11.0.4] - 2025-07-22

### Changed

- CI process updated to use newer versions of dependencies, including Go, super-linter, pyspelling-any, kubernetes, cert-manager, and others. [0be57358](https://github.com/electrocucaracha/krd/commit/0be57358816abe36abbf71d176075612d707f6d7)

## [11.0.3] - 2025-07-07

### Changed

- The identation fmt value in the Makefile was updated to use an indentation of 4 spaces instead of the default, which will affect users who rely on automatic formatting tools. [6444f82f](https://github.com/electrocucaracha/krd/commit/6444f82f9ea4d6321c2adf3a2beffd702f53c92b)

## [11.0.2] - 2025-07-05

### Changed

- The dictionary definitions in the spellchecker bot's wordlist have been updated, replacing mixed-case words with their standardized forms to improve accuracy. [1ace4ef5](https://github.com/electrocucaracha/krd/commit/1ace4ef5cc64273bfc7b6dcadcc6d28b53414980)

## [11.0.1] - 2025-07-05

### Changed

- Documentation improvements were made to the Kubernetes Reference Deployment (KRD) project, specifically in its architecture documentation. [4b8d11cc](https://github.com/electrocucaracha/krd/commit/4b8d11cc72d57aa596b89e3e11d785ee929a04d2)

## [11.0.0] - 2025-06-28

### Removed

- Kyverno installation no longer depends on Gatekeeper, removing this dependency from the install process. [fde2f94a](https://github.com/electrocucaracha/krd/commit/fde2f94a25a0e4c82105bdf6ec2079285f7f5b32)

## [10.1.0] - 2025-06-26

### Added

- The list of known words in the GitHub wordlist has been updated to include several new terms, specifically Agentic, kagent, KRM, aio, and Allocatable. [f0ebb186](https://github.com/electrocucaracha/krd/commit/f0ebb186f761bec7e84f35728e7da298ccc6bc83)

## [10.0.4] - 2025-06-26

### Changed

- Documentation improvements were made to the KRD project, including updating the README.md file and .github/.wordlist.txt file. [ca335091](https://github.com/electrocucaracha/krd/commit/ca335091b9c1771be7d0cd274c21c1d5bba0e7a0)

## [10.0.3] - 2025-06-26

### Changed

- Dead links in the README.md file were updated to point to the correct locations, ensuring users have access to accurate information. [7cd181ed](https://github.com/electrocucaracha/krd/commit/7cd181ed98566d6119d857afff03ce311246cb74)

## [10.0.2] - 2025-06-26

### Changed

- Kube_version retrieval value was updated in multiple functions to remove the leading "v" prefix when echoing the version, affecting how users see the version number in certain cases. [2b1b7a8e](https://github.com/electrocucaracha/krd/commit/2b1b7a8e57aaa21422038d3d1e04d584d0acc13e)

## [10.0.1] - 2025-06-26

### Changed

- Kubernetes version was updated from v1.31.4 to v1.32.5, affecting the default Kubernetes version used during upgrades and in various scripts. [5ec505df](https://github.com/electrocucaracha/krd/commit/5ec505df9da23060173f5514eed8e4ec6cd0fa48)

## [10.0.0] - 2025-06-26

### Removed

- The removal of the `return` statement in the `install_kagent` function resolves linting issues, but also removes a temporary fix for an unimplemented feature requiring model info values. [4b68d942](https://github.com/electrocucaracha/krd/commit/4b68d942fe813b59788f848ad5ff7e04da0391b3)

## [9.0.2] - 2025-06-26

### Changed

- Kubespray version was bumped from v2.27.0 to v2.28.0, requiring users to update their Kubespray configuration. [698c7cac](https://github.com/electrocucaracha/krd/commit/698c7cac93c68c264fc951058f091d99ccbebe14)

## [9.0.1] - 2025-04-30

### Changed

- The kagent service has been enabled, adding an Agentic AI KRM platform to the list of supported tools in the README.md file. [f0b26b21](https://github.com/electrocucaracha/krd/commit/f0b26b21aa136dd5da0771471182f5de7411b659)

## [9.0.0] - 2025-04-28

### Removed

- Kubevirt uninstallation now removes the containerized data importer, which was previously deleted separately. [deab1bce](https://github.com/electrocucaracha/krd/commit/deab1bce57d7ae8162faf099053e478ce1a6aee3)

## [8.1.1] - 2025-04-28

### Changed

- K8Sgpt has been updated to support OpenAI, adding a new configuration option for using the OpenAI API instead of local AI models. [c68941d8](https://github.com/electrocucaracha/krd/commit/c68941d83dd82ed832b0d3049ec406b145aa0579)

## [8.1.0] - 2025-04-28

### Added

- Ollama models have been added for continued use, introducing new model names, parameters, and API bases in the litellm.yml configuration file. [24d49ec4](https://github.com/electrocucaracha/krd/commit/24d49ec4f7200f2903ddab5e3d4d864f9dfa9498)

## [8.0.3] - 2025-04-28

### Changed

- The host-installer feature was improved, allowing users to override the All-in-One IP address in Ansible Inventory when using the installer. [fbe741c7](https://github.com/electrocucaracha/krd/commit/fbe741c761b7e04a6ccdd8325a789b847725025e)

## [8.0.2] - 2025-04-25

### Changed

- The debug mode for Kubernetes deployments has been updated to use the ACTIONS_RUNNER_DEBUG and ACTIONS_STEP_DEBUG environment variables, allowing users to control debugging behavior through these standardized variables instead of a custom KRD_DEBUG variable. [76806102](https://github.com/electrocucaracha/krd/commit/7680610203e689a7a43e6ab24df744c6297636da)

## [8.0.1] - 2025-04-25

### Changed

- The KRD_DEBUG definition has been centralized by removing its explicit declaration in various workflows and scripts, instead relying on an external source to set this environment variable. [4cc994d3](https://github.com/electrocucaracha/krd/commit/4cc994d3d34fb81408781d002a60e8b7aa759f38)

## [8.0.0] - 2025-04-25

### Removed

- The self-hosted installation option for the chart installer was removed, which may break existing installations that relied on this feature. [569fb4d2](https://github.com/electrocucaracha/krd/commit/569fb4d2b5e01acaf516978a760dec3b7973ec70)

## [7.6.0] - 2025-04-24

### Added

- Longhorn uninstallation has been fixed, allowing users to properly remove Longhorn services from their cluster without encountering issues. [9253343f](https://github.com/electrocucaracha/krd/commit/9253343f7a2d24728fb546147cf48ef904a79f08)

## [7.5.1] - 2025-04-24

### Changed

- Test VM memory requirements were reduced from 128Mi to 64M in the testvm.yml file, which is used for testing purposes. [aee73b37](https://github.com/electrocucaracha/krd/commit/aee73b37245cda3bef1bcec3546551f8d2f99b30)

## [7.5.0] - 2025-04-24

### Added

- LiteLLM local network issues were documented to improve user experience, particularly for Firefox and Chrome users on Mac systems. [6189409d](https://github.com/electrocucaracha/krd/commit/6189409d69796a3b0dde4bd784d0a3849fa0c5a0)

## [7.4.1] - 2025-04-24

### Changed

- KubeVirt Runner now allows memory overcommit by default, enabling guests to use more memory than allocated on the host. [e8cb75f0](https://github.com/electrocucaracha/krd/commit/e8cb75f07dbc54ecea5beff0aef41493f6d607f3)

## [7.4.0] - 2025-04-24

### Added

- KubeVirt CPU allocation ratio can now be customized through the KRD_KUBEVIRT_CPU_ALLOCATION_RATIO environment variable, allowing users to fine-tune resource distribution within their clusters. [8a8b667d](https://github.com/electrocucaracha/krd/commit/8a8b667d95c04468c4be034a1dc83a335a283440)

## [7.3.1] - 2025-04-24

### Changed

- The virtlink tests have been improved by replacing manual YAML definitions with externalized resources, allowing for easier management of test configurations. [39c3ad28](https://github.com/electrocucaracha/krd/commit/39c3ad2830de2041b42528892f3f7edecabd13eb)

## [7.3.0] - 2025-04-24

### Added

- Increased inotify resources to prevent failures on fsnotify watcher when running `kubectl logs`. [5076bd7e](https://github.com/electrocucaracha/krd/commit/5076bd7e1ab600f54f0b34b5984682945c76eaa2)

## [7.2.1] - 2025-04-24

### Changed

- Version updates were made across the project, affecting dependencies in GitHub Actions, Ansible roles, and Kubernetes components. [ebcf7670](https://github.com/electrocucaracha/krd/commit/ebcf767090c96174b8122e0b487b89abf494d121)

## [7.2.0] - 2025-04-23

### Added

- A configuration file for rstcheck, a tool to check reStructuredText files, has been added to the project. [88811d1b](https://github.com/electrocucaracha/krd/commit/88811d1b52842fcebb22544272e241e054640f03)

## [7.1.1] - 2025-04-23

### Changed

- Editorconfig linting issues were fixed by updating the .editorconfig file to include root settings, modifying the .editorconfig-checker.json configuration, and changing references in GitHub workflows and Makefile scripts to use the new checker file. [b919b639](https://github.com/electrocucaracha/krd/commit/b919b639483b0bd5fbae2db0888167c6a03b1060)

## [7.1.0] - 2025-04-23

### Added

- LiteLLM service has been enabled, adding a gateway LLM provider to the system. [5340bc89](https://github.com/electrocucaracha/krd/commit/5340bc890350834c585c1b13e3adefef7aff8ce7)

## [7.0.10] - 2025-04-19

### Changed

- The CloudNativePG operator has been enabled, adding support for PostgreSQL clusters managed by this operator to the project's test scenarios. [0f03650b](https://github.com/electrocucaracha/krd/commit/0f03650b422626bdbec8fe0875a33bde5046bf25)

## [7.0.9] - 2025-04-16

### Changed

- K8sGPT resources were updated to fix issues, including the creation of new files for K8sGPT-ollama and the update of version numbers in existing resources. [cc98ba3f](https://github.com/electrocucaracha/krd/commit/cc98ba3f4cdfe838863d692c6f7f29d8e2ca56bc)

## [7.0.8] - 2025-04-09

### Changed

- The GitHub Actions workflow for linter validation has been updated to use the super-linter repository directly, switching from version 7 to 7.3.0. [835c76ed](https://github.com/electrocucaracha/krd/commit/835c76ed29f2509594790bee56dade17cde5948d)

## [7.0.7] - 2025-04-03

### Changed

- The update script for galaxy collection versions was modified to correctly retrieve the latest version from the Ansible Galaxy API, changing the API endpoint used in the process. [9b701550](https://github.com/electrocucaracha/krd/commit/9b70155085c9d76a47d40d38ca358c4b523af7cf)

## [7.0.6] - 2025-03-13

### Changed

- Galaxy requirements were updated, including krd versions files, to reflect changes in dependencies such as Istio, Knative Eventing, and ArgoCD. [fe5f26b2](https://github.com/electrocucaracha/krd/commit/fe5f26b2739cb6d6caadd824867beefae5890b83)

## [7.0.5] - 2025-03-13

### Changed

- Galaxy requirements were updated based on code review suggestions, affecting the versions of several Ansible collections. [cda9c527](https://github.com/electrocucaracha/krd/commit/cda9c5270b09148f8b727d7c64b0e08b8242c61b)

## [7.0.4] - 2025-03-13

### Changed

- The galaxy requirements and krd versions files were updated to reflect the latest available versions, including actions/cache from 4.2.1 to 4.2.2, ansible-core from 2.18.2 to 2.18.3, rpds-py from 0.23.0 to 0.23.1, and argocd_version from v2.14.2 to v2.14.3. [8ff25137](https://github.com/electrocucaracha/krd/commit/8ff251370c55a975515e98b050276b3f38c2540c)

## [7.0.3] - 2025-03-13

### Changed

- Galaxy requirements were updated, affecting several dependencies, including krd versions files, to align with newer versions: kube-ovn upgraded from v1.13.3 to v1.13.4 and prometheus-operator from v0.80.1 to v0.81.0, among others. [5fb7837f](https://github.com/electrocucaracha/krd/commit/5fb7837fa78afb40118dc63f7a9cbaed98d1fbd6)

## [7.0.2] - 2025-02-20

### Changed

- Galaxy requirements and krd versions files have been updated to newer versions, including galaxy-requirements.yml, playbooks/krd-vars.yml, test-requirements.txt, and resources/k8sgpt-local.yml. [d164a189](https://github.com/electrocucaracha/krd/commit/d164a189849e5a04e275cce65d4cf1034a6c9828)

## [7.0.1] - 2025-02-20

### Changed

- Galaxy requirements were updated following code review suggestions, impacting users who rely on these dependencies for their workflows. [42677625](https://github.com/electrocucaracha/krd/commit/42677625e9c6566178196f176a11eb5cc3823b44)

## [7.0.0] - 2025-02-14

### Removed

- The dictionary definitions in the wordlist have been updated, removing datasets and RUNTIME from the list of words to be checked. [cef7bdb8](https://github.com/electrocucaracha/krd/commit/cef7bdb88d7382c5bab5cf05ee0354a4c6b0eef9)

## [6.1.6] - 2025-02-14

### Changed

- Galaxy requirements were updated, including krd versions files, to reflect the latest available versions of various dependencies. [c25db738](https://github.com/electrocucaracha/krd/commit/c25db73873793171e5a92f81d3325fa4f944b038)

## [6.1.5] - 2025-02-14

### Changed

- Galaxy requirements were updated following code review suggestions, affecting several collection versions: kubernetes.core was set to 5.0.0, community.docker to 4.3.0, ansible.posix to 2.0.0, and community.general to 10.2.0. [1faf382b](https://github.com/electrocucaracha/krd/commit/1faf382b212d6993d843c17c772467f9fabaf99c)

## [6.1.4] - 2025-02-14

### Changed

- Galaxy requirements were updated following code review suggestions, affecting the versions of several Ansible collections. [12ca521f](https://github.com/electrocucaracha/krd/commit/12ca521ff86f7e771757be42896a6387a0a933ea)

## [6.1.3] - 2025-02-14

### Changed

- Galaxy requirements and krd versions files were updated to use newer versions of various dependencies, including Python, Go, Kubernetes, and other libraries. [06efa57b](https://github.com/electrocucaracha/krd/commit/06efa57b8eead4ebb9772c7c7ff265a4c5b2753d)

## [6.1.2] - 2025-02-11

### Changed

- The labeler configuration file was updated, changing the rules for documentation, tests, CI, all-in-one, and addons directories. [a7c145f9](https://github.com/electrocucaracha/krd/commit/a7c145f983e862bade1da479aadfaa4b942f329b)

## [6.1.1] - 2025-02-05

### Changed

- Kata containers integration tests have been disabled due to deployment issues, which will prevent users from running these specific tests in the on-demand CI workflow. [d8ae9926](https://github.com/electrocucaracha/krd/commit/d8ae99262ac67596fdb26207536a9a375cffa557)

## [6.1.0] - 2025-02-05

### Added

- Kubevirt runners now enable cpu host-passthrough by default, allowing for more efficient use of host resources. [dc120ab0](https://github.com/electrocucaracha/krd/commit/dc120ab0808285b2fee722943338cce4220182d6)

## [6.0.0] - 2025-02-05

### Removed

- VBox logging has been reduced in the Vagrant up action, removing unnecessary log file retrieval from the process. [a59085c1](https://github.com/electrocucaracha/krd/commit/a59085c1c3473d38bfb9b9e9fc696899517434f8)

## [5.0.2] - 2025-02-05

### Changed

- Longhorn test timeout increased from default to 5 minutes, changing the expected wait time for persistent volume claim binding in automated tests. [0f0c33f3](https://github.com/electrocucaracha/krd/commit/0f0c33f39af2369ccace568d79d9de5d66a18f79)

## [5.0.1] - 2025-02-05

### Changed

- The GitHub Actions workflow now includes gvisor and youki runtimes, enabling their use in on-demand CI jobs. [1fcaff6c](https://github.com/electrocucaracha/krd/commit/1fcaff6ce6863e1f89c9b14ab7ae4508d4b25e61)

## [5.0.0] - 2025-02-05

### Removed

- Failed virtual machine instances are no longer deleted by the garbage collector, which previously removed them after 15 minutes. [4e61660a](https://github.com/electrocucaracha/krd/commit/4e61660a1eeb4052a3f5860d0aa44df7aac985cb)

## [4.4.0] - 2025-02-04

### Added

- The GitHub workflow now uses a secret token for authentication, replacing the previous PAT token. [17e308e6](https://github.com/electrocucaracha/krd/commit/17e308e6442034c9e23cf8c102a7268c4da344e2)

## [4.3.6] - 2025-02-01

### Changed

- Integration tests are now run in batches per instance, reducing the number of tests per job. [81f2bbdc](https://github.com/electrocucaracha/krd/commit/81f2bbdcfe96d097c77b540e6ef3dbf2b3f3ae0a)

## [4.3.5] - 2025-01-24

### Changed

- CRI-O's on-demand CI workflow no longer includes KataContainer tests due to an unresolved issue with CRI-O + Kata containers. [8df12521](https://github.com/electrocucaracha/krd/commit/8df1252134f20880854029bcbc7b148ca735d1b2)

## [4.3.4] - 2025-01-24

### Changed

- The ephemeralrunners garbage collector's frequency has been reduced to run every hour instead of every 15 minutes, which may affect users who rely on timely cleanup of failed runners. [0962192a](https://github.com/electrocucaracha/krd/commit/0962192acf8708e4d9fb106a5f869cbea187bf17)

## [4.3.3] - 2025-01-24

### Changed

- Runtime classes integration tests were refactored to use a single deployment template for all runtime classes, reducing duplication and improving maintainability. [e5cb69db](https://github.com/electrocucaracha/krd/commit/e5cb69db387d555d235845fab9127f09b96a8104)

## [4.3.2] - 2025-01-24

### Changed

- The youki runtime has been enabled in the CI environment, allowing for its use alongside other runtimes like crio and containerd. [b1505176](https://github.com/electrocucaracha/krd/commit/b15051768685323363cbda888d199b54ef6dc7f6)

## [4.3.1] - 2025-01-24

### Changed

- Istio integration tests were updated, removing an assertion that relied on the istiod pod's logs to verify sidecar injection requests. [8a3f05c9](https://github.com/electrocucaracha/krd/commit/8a3f05c9b09d0d2c7bb37d87727990c338da19da)

## [4.3.0] - 2025-01-24

### Added

- CRI-O runtime manager now disables gvisor by default for containerd and crio runtimes, aligning with the deprecation of Dockershim in Kubernetes 1.24 and above. [8042b745](https://github.com/electrocucaracha/krd/commit/8042b745b2add8ae62e436793a3efed5cb4abaec)

## [4.2.0] - 2025-01-24

### Added

- Fluent logging agent has been added to the installation process, allowing for log collection, parsing, and distribution. [54f207cc](https://github.com/electrocucaracha/krd/commit/54f207cc21b11f81f5677190d4efc1862ca604b5)

## [4.1.1] - 2025-01-23

### Changed

- The vagrant boxes for the kubevirt runner have been reduced, specifically removing unnecessary box additions and simplifying the installation process. [aeb8907e](https://github.com/electrocucaracha/krd/commit/aeb8907edf6134a399e34521660c503a7f1004ef)

## [4.1.0] - 2025-01-23

### Added

- The image pull policy for the kubevirt runner has been changed to always, which means that the container will attempt to pull the latest version of the image even if it's already present on the node. [9a5a69b0](https://github.com/electrocucaracha/krd/commit/9a5a69b091914a95aefa7bd1931262bbe8ddd7df)

## [4.0.1] - 2025-01-21

### Changed

- The list of supported Linux distributions has been updated to include Debian, RockyLinux, and remove Fedora 37 and 38. [9d428cda](https://github.com/electrocucaracha/krd/commit/9d428cda73e8162142c6177c4fa93838fc09094f)

## [4.0.0] - 2025-01-17

### Removed

- Ubuntu Bionic support has been dropped from the project, affecting Linux distro versions listed in README.md and molecule.yml files across various roles. [94575275](https://github.com/electrocucaracha/krd/commit/94575275ec26f375b499b26e99ab333fdec42ca0)

## [3.1.2] - 2025-01-17

### Changed

- The Ubuntu version in the Scheduled CI workflow has been updated to 22.04, which may break existing builds running on the previous 20.04 environment. [4b26f0f9](https://github.com/electrocucaracha/krd/commit/4b26f0f90224af509c630e1115bec92cd22626b1)

## [3.1.1] - 2025-01-15

### Changed

- The arc garbage collector now includes removal of virtual machine instances, previously handled separately by the vmi cleaner. [e2cab980](https://github.com/electrocucaracha/krd/commit/e2cab980f73e673d0a2a2703a0b95c1d3b76b6d6)

## [3.1.0] - 2025-01-15

### Added

- Namespace creation in ARC installation has been improved to handle special characters in the GitHub URL by converting underscores to hyphens and forcing lowercase, preventing potential namespace creation issues. [6089d72d](https://github.com/electrocucaracha/krd/commit/6089d72df4dfd9d9ce6aa03de876d9d62baf8ec7)

## [3.0.11] - 2025-01-10

### Changed

- Ansible group names were updated, changing "kube-master" to "kube_control_plane", "kube-node" to "kube_node", and "etcd" remains unchanged. [ffdda328](https://github.com/electrocucaracha/krd/commit/ffdda328541d07764901c0c8b647abbaf80d2b27)

## [3.0.10] - 2025-01-10

### Changed

- Tox installation was modified in GitHub actions to ensure successful molecule tests, which now requires pip install tox explicitly. [ef136d76](https://github.com/electrocucaracha/krd/commit/ef136d76ee1c828524ee492ff4f0087287d9c8db)

## [3.0.9] - 2025-01-10

### Changed

- The CDI version was bumped to v1.61.0, which may break behavior if the previous version was hardcoded in playbooks. [db892bc2](https://github.com/electrocucaracha/krd/commit/db892bc2e041f55038a62a58b036e1c00a79c2b4)

## [3.0.8] - 2025-01-10

### Changed

- Python test requirements were updated, upgrading several dependencies to newer versions: Ansible-compat from 24.9.1 to 24.10.0 and Ansible-core from 2.17.5 to 2.17.7 among others. [d868d40c](https://github.com/electrocucaracha/krd/commit/d868d40cf1fb001bf4f9d000a9d21b628d6f4284)

## [3.0.7] - 2025-01-10

### Changed

- Metallb version was bumped from v0.14.8 to v0.14.9, requiring no migration steps for users. [d3ce9bdc](https://github.com/electrocucaracha/krd/commit/d3ce9bdc67dc5e6a38ccf394fd873c873c64298b)

## [3.0.6] - 2025-01-10

### Changed

- Istio was updated from version 1.24.1 to 1.24.2 in the krd-vars.yml playbook, affecting users who rely on this configuration for their Istio setup. [b6121689](https://github.com/electrocucaracha/krd/commit/b612168998e53e8f8992c00b2e6b6033008f1248)

## [3.0.5] - 2025-01-10

### Changed

- Virtink version was bumped from v0.16.0 to v0.17.0, which may require migration steps for users currently depending on the previous version. [934c2688](https://github.com/electrocucaracha/krd/commit/934c2688c2105fd5ed5bc2c0a434e1c739e669d0)

## [3.0.4] - 2025-01-10

### Changed

- Knative versions were updated in the configuration, bumping the version of Knative to 1.16.1 for serving and eventing components. [8a34cf5c](https://github.com/electrocucaracha/krd/commit/8a34cf5c07cb3fb437e9d16e9d4717f2727518de)

## [3.0.3] - 2025-01-10

### Changed

- The version of the Tekton tasks for Kubevirt has been updated from v0.22.0 to v0.23.0, which may require users to migrate their existing workflows if they were relying on specific features or behavior in the previous version. [840b33a6](https://github.com/electrocucaracha/krd/commit/840b33a6e588592a6fc8d94fce48d255c3e10090)

## [3.0.2] - 2025-01-10

### Changed

- The update version script has been improved, specifically the handling of GitHub actions in the `.github` directory. [6f227bfd](https://github.com/electrocucaracha/krd/commit/6f227bfd791c75e144e2cbc3603d221d90a61be9)

## [3.0.1] - 2025-01-10

### Changed

- The Vagrant boxes cache has been added to the runner image, increasing storage from 25G to 35G. [679fdf78](https://github.com/electrocucaracha/krd/commit/679fdf787993e380268bdfccdbd55a9bfb57d0d6)

## [3.0.0] - 2025-01-10

### Removed

- Legacy TODO instructions were removed from various configuration files, including GitHub workflows and environment variables. [50d8667e](https://github.com/electrocucaracha/krd/commit/50d8667e2265d4d35c23692bb287f8b5a95c9953)

## [2.1.9] - 2025-01-10

### Changed

- Kube OVN version was updated from v1.13.0 to v1.13.2, which may require migration steps for users who have customized their configurations based on the previous version. [203269ee](https://github.com/electrocucaracha/krd/commit/203269ee0c45f789c937a4bc9ebb8433aedfcb1e)

## [2.1.8] - 2025-01-10

### Changed

- The Prometheus operator version was updated from v0.78.2 to v0.79.2 in the krd-vars.yml playbook, which may require migration steps for users who have customized their configuration. [1bc0a809](https://github.com/electrocucaracha/krd/commit/1bc0a8092390c64bc943ca7aa44e5245602dc40d)

## [2.1.7] - 2025-01-10

### Changed

- Kubernetes version was bumped from v1.30.4 to v1.31.4, affecting deployment scripts and tests that rely on this version. [fd3d95c2](https://github.com/electrocucaracha/krd/commit/fd3d95c21e90588ff1a4f946c21221d882584d57)

## [2.1.6] - 2025-01-10

### Changed

- Kubespray version was bumped from v2.26.0 to v2.27.0, requiring users to update their configuration accordingly. [555fa2b5](https://github.com/electrocucaracha/krd/commit/555fa2b586d2fb699b6b042cd8ed31312972953e)

## [2.1.5] - 2025-01-09

### Changed

- The PMEM driver has been upgraded from v2.12.0 to v2.13.0, which may require manual intervention to update configurations that reference the older version. [9babcc3b](https://github.com/electrocucaracha/krd/commit/9babcc3b005ecc443b31b6c41b35caa2df011f58)

## [2.1.4] - 2025-01-09

### Changed

- k8sgpt was upgraded from v0.3.46 to v0.3.48, which may require migration steps if users have customized their configuration. [511d1033](https://github.com/electrocucaracha/krd/commit/511d103305dfd8db12bb121450e701299f521a33)

## [2.1.3] - 2025-01-09

### Changed

- Galaxy collections and roles versions were upgraded, affecting users who rely on these dependencies for their Ansible playbooks. [1be4c679](https://github.com/electrocucaracha/krd/commit/1be4c679db1b271198904431b4f5cf821a138e8b)

## [2.1.2] - 2025-01-09

### Changed

- GH action versions were upgraded, which affects users who rely on these actions for Vagrant setup, Go installation, and spell checking. [17ab3857](https://github.com/electrocucaracha/krd/commit/17ab3857cf03d2eb4ffbbbcedae012a84980a68d)

## [2.1.1] - 2025-01-09

### Changed

- The NFD version has been upgraded from v0.16.6 to v0.17.0, which may require migration steps if users have customized their configurations based on the previous version's settings. [0180aa73](https://github.com/electrocucaracha/krd/commit/0180aa73b596d119af45b6d445633c93a7cc9deb)

## [2.1.0] - 2025-01-09

### Added

- The arc garbage collector has been enabled, which periodically cleans up ephemeral runners that have failed too many times. [8f5faf4c](https://github.com/electrocucaracha/krd/commit/8f5faf4c25a13833a473036b0f0dde7d4661a995)

## [2.0.3] - 2025-01-08

### Changed

- The image for the kubevirt-action-runner container has been updated to use the artifact generated by the new registry URL, specifically `ghcr.io/electrocucaracha/kubevirt-actions-runner:master`. [c9545ad6](https://github.com/electrocucaracha/krd/commit/c9545ad61edf9d2b598e2cfb2158bcdf931b4766)

## [2.0.2] - 2025-01-08

### Changed

- The ubuntu runner disk size has been increased from 14G to 25G in the pipeline configuration, which may require users to update their existing runners to accommodate the larger storage request. [bc2b98d7](https://github.com/electrocucaracha/krd/commit/bc2b98d7db986eca279fc2f644bfb8a219c4a298)

## [2.0.1] - 2025-01-08

### Changed

- The number of arc runners has been restricted to 3, which may break behavior for users who relied on the previous default configuration. [8c13a0c3](https://github.com/electrocucaracha/krd/commit/8c13a0c387929180b035d9ad33cace3ef0f189a1)

## [2.0.0] - 2025-01-08

### Removed

- Istio installation verification has been removed from the install process, which may break behavior for users who relied on this step to ensure Istio was properly installed. [768879b0](https://github.com/electrocucaracha/krd/commit/768879b04a61ef1f7cadee62ebc1532c32c2ff9a)

## [1.5.3] - 2025-01-08

### Changed

- Self-hosted runners have been enabled, allowing users to run workflows on their own virtual machines rather than relying on GitHub's infrastructure. [5c8aa805](https://github.com/electrocucaracha/krd/commit/5c8aa805a2f38a65888535af1a4b021ca5afd443)

## [1.5.2] - 2024-12-31

### Changed

- Chart version control was implemented, allowing users to specify chart versions when installing charts. [438fed80](https://github.com/electrocucaracha/krd/commit/438fed800c6a3ae59a3485b274b26651ad74022c)

## [1.5.1] - 2024-12-31

### Changed

- The sources list for the Ubuntu runner was updated to fix issues with package installation. [4f0084be](https://github.com/electrocucaracha/krd/commit/4f0084be0242231390826de7dd74ed211cd8c411)

## [1.5.0] - 2024-12-18

### Added

- The Ubuntu runner pipeline was modified to create a sudo passwordless account for the 'runner' user, allowing it to execute commands without prompting for a password. [06bc4724](https://github.com/electrocucaracha/krd/commit/06bc4724ef48cd5589478e17c12fe4dd661f55b2)

## [1.4.0] - 2024-12-18

### Added

- The VAGRANT_DEFAULT_PROVIDER environment variable was defined to specify the default provider for Vagrant, which affects how virtual machines are provisioned. [93453ba2](https://github.com/electrocucaracha/krd/commit/93453ba283d78b0d755ee44957215b4b7b2ef0c5)

## [1.3.0] - 2024-12-17

### Added

- The ubuntu runner pipeline now installs python packages, including the interpreter and development tools, to support Python-based workflows. [7207b563](https://github.com/electrocucaracha/krd/commit/7207b5632713e5a0cd18e4512f7c385100649060)

## [1.2.0] - 2024-12-17

### Added

- The Ubuntu runner pipeline now installs the Git package, which is necessary for certain workflows that rely on Git functionality. [4d52d858](https://github.com/electrocucaracha/krd/commit/4d52d8581a045d7c2c6fa48f90c347c4b11d8894)

## [1.1.1] - 2024-12-17

### Changed

- The Kubernetes runner has been updated from the `zhaofengli/kubevirt-actions-runner` image to the `electrocucaracha/kubevirt-actions-runner` image. [002d4e79](https://github.com/electrocucaracha/krd/commit/002d4e790d455324fca8c10c8393db30d566c4e1)

## [1.1.0] - 2024-12-13

### Added

- The wordlist used in GitHub actions has been updated to correct spelling issues, specifically adding the words "Tekton" and "TopoLVM". [2cb882ed](https://github.com/electrocucaracha/krd/commit/2cb882ed936bdc868a06da6220acc3b307388a1b)

## [1.0.5] - 2024-12-13

### Changed

- Topolvm storage solution has been enabled, adding it to the list of supported storage operators alongside Longhorn. [ee82fd89](https://github.com/electrocucaracha/krd/commit/ee82fd8924b5c9387756ce904d2e7e365e5c0ba7)

## [1.0.4] - 2024-12-13

### Changed

- The Ubuntu runner pipeline configuration was updated to address gitleaks linting issues by allowing specific keys for the VirtualBox and Hashicorp repositories, which were previously flagged as security vulnerabilities. [ef288648](https://github.com/electrocucaracha/krd/commit/ef288648e2118c3da82ddcf16f92fbebc95a7169)

## [1.0.3] - 2024-12-13

### Changed

- The tekton linter configuration was updated to fix issues, including disabling the prefer-kebab-case rule and specifying external tasks for kubevirt. [de280214](https://github.com/electrocucaracha/krd/commit/de2802147eaf0f6aa65510e49a523c31fd32c7fa)

## [1.0.2] - 2024-12-13

### Changed

- LVM implementation was enabled, changing how volumes are mounted and managed in the system. [8817ee8a](https://github.com/electrocucaracha/krd/commit/8817ee8a442093b5528a8dd38d1a12447f8d586a)

## [1.0.1] - 2024-12-13

### Changed

- Arc deployments are now namespaced, allowing for multiple instances to coexist in the same cluster. [105fd4d7](https://github.com/electrocucaracha/krd/commit/105fd4d72389de7bdd89d50ba36da5db8517dbcc)

## [1.0.0] - 2024-12-10

### Changed

- The installation order for Tekton has been fixed, which affects users who rely on this tool. [d8f2e8e6](https://github.com/electrocucaracha/krd/commit/d8f2e8e6a80afbffe5126215b17370112cc80e7e)
