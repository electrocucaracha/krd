<!-- Markdownlint-disable MD024 -->

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [21.1.0] - 2026-07-02

### Added

- BREAKING: Enabled support for Ubuntu Noble runners by updating pipeline runs, VM templates, and associated resources to use the new image and naming convention, allowing streamlined deployment of both Jammy and Noble runners while enhancing security and flexibility for GitHub Actions integration with KubeVirt. (1b2c8e84)

## [21.0.0] - 2026-07-02

### Removed

- Simplified runner provisioning by removing obsolete service definitions and consolidating initialization steps under runcmd to reduce configuration clutter and improve reliability. (733d1c99)

## [20.4.0] - 2026-07-02

### Added

- Enabled flexible and reliable dynamic storage provisioning by allowing users to resize persistent volumes and deferring binding until a pod is scheduled thereby reducing failed provisioning attempts and improving placement decisions. (4d53618f)

## [20.3.2] - 2026-07-02

### Fixed

- Resolved compatibility issues for users relying on default environment configuration by reverting containerd version to 2.2.3 from the previously unstable 2.3.2, which allowed dependent components that have not yet been updated to function correctly again without requiring any migration effort. (261a6737)

## [20.3.1] - 2026-07-01

### Changed

- Updated GitHub Actions runners to ubuntu-24.04 for improved performance and updated software packages, ensuring continued compatibility with GitHub-hosted runners and leveraging the latest available environment for CI workflows. (8148c7d3)

## [20.3.0] - 2026-07-01

### Added

- Introduced automation for rapid and repeatable environment resets in Kubernetes, enabling efficient testing and CI purposes through streamlined volume cleanup, cluster installation, key component deployment, and self-hosted GitHub Actions runner configuration. (87d82c49)

## [20.2.1] - 2026-07-01

### Changed

- Upgraded dependencies and container images to latest versions, ensuring support for recent Kubernetes versions and improving reliability, security, and alignment with upstream projects, without introducing any breaking changes but requiring downstream consumers to verify compatibility with updated versions. (94ea4256)

## [20.2.0] - 2026-06-10

### Added

- BREAKING: Enabled pinned GitHub Actions to remain at specific versions while others are updated automatically, introducing a new array that skips auto-updating listed actions and preventing breaking changes from automatic updates unless explicitly removed. (2fc3cfff)

## [20.1.7] - 2026-04-25

### Changed

- Standardized GitHub Actions workflows to safely reference secrets within dedicated environments and optimized tool versions across lint, spell check, and update jobs. (493e278e)

## [20.1.6] - 2026-04-25

### Changed

- Updated dictionary definitions used by the spell checker bot to include Ons and exclude MKE. (aef4179e)

## [20.1.5] - 2026-04-25

### Changed

- Upgraded galaxy requirements and krd versions to ensure compatibility with latest dependencies, requiring users to migrate if relying on previous versions of these dependencies. (92262b3c)

## [20.1.4] - 2026-04-25

### Changed

- Upgraded galaxy requirements and krd versions files to latest supported versions for cert-manager, knative serving, eventing, Ansible core, click, filelock, and packaging. (10e74743)

## [20.1.3] - 2026-03-20

### Changed

- Upgraded galaxy requirements and krd versions files to newer versions, including actions/cache from 5.0.3 to 5.0.4, actions/ai-inference from 2.0.7 to 2.0.8, dorny/paths-filter from 4.0.0 to 4.0.1, and other dependencies like argocd_version, kagent_version, and litellm image version; this may require re-running CI pipelines or updating local environments. (c6426728)

## [20.1.2] - 2026-03-20

### Changed

- Updated galaxy requirements and krd versions files to ensure compatibility with latest tools and libraries, requiring users to update their environments to use new package versions such as ansible-lint and filelock. (9fe327b1)

## [20.1.1] - 2026-03-20

### Changed

- Upgraded galaxy requirements and krd versions files to reflect newer dependencies such as dorny/paths-filter version 4.0.0 and various package versions including istio, knative, and kube-ovn, potentially requiring migration steps from previous versions. (5a7aefd6)

## [20.1.0] - 2026-03-15

### Added

- Enabled pull requests labeling for automated actions by introducing necessary permissions in the triage workflow YAML file. (befa7799)

## [20.0.0] - 2026-03-15

### Removed

- Simplified the \_installers.sh script by eliminating an unnecessary for loop that installed the Grafana Istio AddOn, allowing users to maintain their existing workflows without any modifications. (4a61bce4)

## [19.4.7] - 2026-03-15

### Changed

- Improved linting accuracy is now enabled for the codebase through the introduction of a .codespellrc configuration that ignores specific words during CI runs. (00f5a3ef)

## [19.4.6] - 2026-02-27

### Changed

- Upgraded various dependencies and configurations to new versions of Ansible, Kubernetes package, Kubespray, Python, and pip across multiple workflows. (f939211b)

## [19.4.5] - 2026-02-27

### Changed

- Updated dependencies in galaxy requirements and krd versions files to reflect new version numbers for various dependencies without introducing breaking behavior or requiring migration steps. (b054ca5d)

## [19.4.4] - 2026-02-27

### Changed

- Upgraded several dependencies to newer versions including super-linter 8.5.0 and community.docker 5.0.6 resulting in no breaking changes for developers or operators. (a22b147d)

## [19.4.3] - 2026-02-27

### Changed

- Updated galaxy requirements and KRD versions files to reflect newer dependency versions, necessitating users to update their configurations accordingly. (3925d75e)

## [19.4.2] - 2026-02-27

### Changed

- Upgraded galaxy requirements and krd versions files to ensure compatibility with the latest dependencies. (2ce0d2d6)

## [19.4.1] - 2026-01-31

### Fixed

- Stabilized the update schedule for distro verification to run daily at 2am instead of 1am, ensuring consistent automated checks for latest Vagrant Boxes without introducing any breaking behavior or requiring migration steps from previous schedules. (1a899c04)

## [19.4.0] - 2026-01-23

### Added

- Enabled a Prometheus stack collection of Kubernetes manifests, Grafana dashboards, and Prometheus rules via the kube-prometheus-stack feature, introducing breaking behavior for helm upgrade commands due to the addition of a new chart with default admin credentials for Grafana. (932328da)

## [19.3.4] - 2026-01-23

### Changed

- Upgraded galaxy requirements and krd versions files to newer dependencies, requiring re-running workflows that utilize these updated dependencies. (62bb0e7f)

## [19.3.3] - 2026-01-23

### Changed

- Updated galaxy requirements and krd versions files to reflect new dependencies and versioned packages such as ansible-lint, filelock, and jsonschema, affecting various project modules including litellm image and test-requirements.txt. (59ff041c)

## [19.3.2] - 2026-01-08

### Fixed

- resolved issues identified by Zizmor with the GitHub Actions workflow for linter checks updated to use the latest version of the markdown-link-check action without introducing any breaking behavior and requiring no migration steps from users. (75940e98)

## [19.3.1] - 2026-01-08

### Fixed

- Resolved linting issues affecting GitHub Actions workflows by updating the `sh-checker` and `misspell` actions to version 0.10.0, ensuring continued CI workflow stability without breaking behavior or API changes but potentially requiring users to update action versions in their own workflows. (940b3519)

## [19.3.0] - 2026-01-08

### Added

- Enabled expert-level troubleshooting and code suggestions in failed CI workflow runs through the integration of AI-driven analysis into the linter's diagnostic capabilities. (9aa18edb)

## [19.2.1] - 2026-01-08

### Fixed

- Optimized kubevirt test hardware resource utilization by reducing memory requests and switching to a smaller Alpine-based container disk image. (39b3868e)

## [19.2.0] - 2026-01-08

### Added

- Enabled multiqueue network interfaces and switched to virtio as the default network interface model for KubeVirt runner configurations, potentially requiring adjustments in user settings due to changes in CPU model used for virtual machines. (1de1c48a)

## [19.1.0] - 2026-01-08

### Added

- Enabled emulation for certain CPU architectures in the kubevirt configuration during installation, dynamically applying updated feature gates to support host devices and storage volumes. (98625e5a)

## [19.0.0] - 2026-01-02

### Removed

- The dictionary definitions used by the spell checker bot have been streamlined, eliminating certain terms from its wordlist that were previously recognized as valid, which may impact users relying on these words for accurate spelling suggestions. (e7cc1295)

## [18.2.1] - 2025-12-30

### Fixed

- The GitHub Actions workflow for super-linter validation was updated to meet new requirements enabling it to function correctly and access all dependencies. (9a9151d6)

## [18.2.0] - 2025-12-30

### Added

- Enabled support for running tests on Ubuntu 24.04 by introducing the ubuntu2404 box to the Ubuntu runner pipeline, requiring users to update their pipelines accordingly. (c77185ca)

## [18.1.1] - 2025-12-30

### Fixed

- Resolves issues where tests trapping errors were unable to handle get_status output correctly by enabling the function to run on error. (9d07c3d4)

## [18.1.0] - 2025-12-30

### Added

- Improved failure messages in the Vagrant-up action now provide more detailed system information on failure, including system uptime, memory usage, disk space, and kernel logs to aid users in diagnosing and troubleshooting issues with their environment. (dcab606c)

## [18.0.0] - 2025-12-30

### Removed

- Eliminated Virtlet support from the project, which impacts users who relied on its services and configuration, requiring updates to dependent components such as criproxy and virtlet roles for a seamless transition. (a92e33eb)

## [17.0.1] - 2025-12-27

### Fixed

- Stabilized code quality by incorporating additional linting checks from Biome Lint and Python Ruff Format into the existing configuration. (9aa5ebd4)

## [17.0.0] - 2025-12-27

### Removed

- The archive rebase action is no longer available for manual triggering in GitHub workflows, allowing users to focus on other tasks without the option of an automatic pull request rebase. (7c7c376f)

## [16.1.3] - 2025-12-27

### Changed

- Updated versions of dependencies and container images were introduced across the project, affecting ARC Garbage collector resources by changing their schedule to run every three hours instead of hourly. (357a82de)

## [16.1.2] - 2025-12-26

### Fixed

- Storageclass configuration for runners is now optimized by default to use the topolvm-provisioner class, replacing a previously hardcoded value and affecting users who manage storage classes in their Kubernetes environment. (4eec3fd1)

## [16.1.1] - 2025-12-23

### Fixed

- Resolved the Tekton operator installation link issue by updating it to point to infra.tekton.dev from storage.googleapis.com, requiring users who install via the operator to update their configuration accordingly with no breaking changes necessary. (5cb0b25b)

## [16.1.0] - 2025-12-23

### Added

- Enabled external snapshot management for Kubernetes clusters through installation of CSI Snapshotter and its dependencies via the `install_external_snapshotter` function. (5a338d39)

## [16.0.2] - 2025-12-23

### Changed

- Upgraded Kubernetes version to v1.33.7, requiring updates to environment variables and configuration files, as well as modifications to the KRD_KUBE_VERSION variable in README.md and assertions in ci/check.sh. (f48bc916)

## [16.0.1] - 2025-12-23

### Fixed

- Optimized multinode tests by reducing CPU requirements to two cores from one core. (b1e9e804)

## [16.0.0] - 2025-12-23

### Removed

- Simplified instructions for obtaining the jwtSecret in the \_untested_installers.sh script to avoid confusion caused by a typo. (7ad8c963)

## [15.0.2] - 2025-12-23

### Changed

- Upgraded several dependencies to newer versions, including actions/cache from 4.3.0 to 5.0.1 and super-linter/super-linter from 8.3.0 to 8.3.1, without introducing any breaking changes. (3e4bd36a)

## [15.0.1] - 2025-12-11

### Changed

- Updated galaxy requirements and krd versions files to reflect new dependencies, including upgraded Kubernetes and Kubespray versions, requiring users to update their configurations accordingly for compatibility with the latest software releases. (9cc76249)

## [15.0.0] - 2025-12-11

### Removed

- Simplified the dictionary definitions used by the spell checker bot to remove outdated terms like "datasets" and "runtime", without affecting API or CLI contract or introducing any security risks. (5d8440fe)

## [14.0.2] - 2025-11-19

### Changed

- Upgraded molecule module to version 25.1.0 in test requirements, superseding the previous dependency on version 25.7.0 and potentially necessitating updates from users relying on this testing framework. (7e0b04be)

## [14.0.1] - 2025-11-19

### Changed

- Enabled PR creation in CI workflows by persisting credentials during the process, affecting all related configurations without requiring any migration steps or introducing API changes. (0accbdf2)

## [14.0.0] - 2025-10-09

### Removed

- Eliminated the cache CI task from the Vagrant setup process which may affect users who relied on this feature to speed up their builds and does not introduce any breaking behavior requiring migration steps. (b7e49471)

## [13.3.2] - 2025-10-09

### Changed

- Updated VirtualBox to version 7.2 in the Ubuntu runner pipeline, requiring users who relied on specific features of the previous version to re-run their pipelines. (8f2f67a8)

## [13.3.1] - 2025-10-08

### Changed

- Updated the local box repository to point to a specific node's URL, simplifying how the generic/ubuntu2204 box is added during deployment without affecting the API or CLI contract but introducing a new service and endpoint in the Kubernetes configuration. (329fb81c)

## [13.3.0] - 2025-09-14

### Added

- Enabled users to rely on an updated wordlist for certain operations by introducing new words: "datasets", "runtime", and "runtimes". (fea9845e)

## [13.2.0] - 2025-09-14

### Added

- Enabled specification of vulnerability severities during Trivy scans through the introduction of a severity filter in the trivy.yaml file, where CRITICAL and HIGH levels are enabled by default. (261fb2af)

## [13.1.0] - 2025-09-14

### Added

- Enabled GitHub Actions workflows to be linted correctly by persisting credentials only when necessary. (b4f569da)

## [13.0.5] - 2025-09-14

### Changed

- Upgraded Kubernetes to version v1.32.8, requiring updates to default cluster configuration and CI checks for deployments relying on the KRD_KUBE_VERSION environment variable. (cbf2c5a8)

## [13.0.4] - 2025-09-04

### Changed

- Updated the LLM Lite image in the litellm.yml file to reference the main-v1.76.2-nightly version from ghcr.io/berriai/litellm instead of main-v1.67.0-stable. (329ba194)

## [13.0.3] - 2025-09-04

### Changed

- Upgraded galaxy requirements and krd versions files to newer versions including super-linter 8.1.0, geerlingguy.docker 7.5.0, ansible.posix 2.1.0, community.general 11.2.1, knative 1.19.1, prometheus-operator 0.85.0, and tekton 0.77.0 with no breaking behavior introduced. (984a5c12)

## [13.0.2] - 2025-09-04

### Changed

- Upgraded dependencies for galaxy requirements and krd versions files to newer versions, requiring users who rely on these dependencies in their pipelines and tests to update their dependencies accordingly. (423421e5)

## [13.0.1] - 2025-09-04

### Changed

- Upgraded galaxy requirements and krd versions to align with latest package releases, affecting users who rely on these specific versions for their deployments. (1a1793f6)

## [13.0.0] - 2025-08-12

### Removed

- The obsolete terms "datasets" and "runtime" have been eliminated from the spell checker bot's wordlist to maintain relevance and effectiveness of the tool. (fe1e68e3)

## [12.0.1] - 2025-08-12

### Changed

- Upgraded galaxy requirements and krd versions files to newer versions including Kubernetes Core 6.1.0, Community Docker 4.7.0, Ansible POSIX 2.1.0, Community General 11.2.0, and other dependencies which may require migration steps for users relying on previous versions. (39441963)

## [12.0.0] - 2025-08-11

### Removed

- Eliminated dead external links from the documentation to maintain a clean and up-to-date user experience without introducing any breaking behavior, API contract changes, or migration requirements. (167421ca)

## [11.2.0] - 2025-08-11

### Added

- Enabled users to specify which branch to run linters on by default through the addition of a new DEFAULT_BRANCH option in GitHub Actions workflows. (d67291d1)

## [11.1.7] - 2025-07-28

### Changed

- Updated dependencies to their latest available versions at the time of update, requiring users who rely on these dependencies for functionality to migrate to the new versions if they haven't already. (08f42a3b)

## [11.1.6] - 2025-07-27

### Changed

- Modernized kagent deployment versions to be controlled by the kagent chart's version, requiring users who rely on hardcoded chart versions to migrate to using the `_get_version` function. (f7db95c6)

## [11.1.5] - 2025-07-27

### Changed

- Optimized the kagent ollama agent configuration to simplify its operation and improve performance by modifying the agent's name, model configuration, and tool server with additional streamable HTTP settings including sseReadTimeout and timeout options. (db63aa79)

## [11.1.4] - 2025-07-27

### Changed

- Modernized kagent database configuration to utilize CNPG, requiring users to update their configurations and leveraging the renamed helm chart from "postgres". (ccd1b795)

## [11.1.3] - 2025-07-27

### Changed

- kagent setup instructions now reference environment-specific namespaces stored in KRD_KAGENT_NAMESPACE variables instead of the default "kagent" namespace. (e1091478)

## [11.1.2] - 2025-07-22

### Changed

- Updated knative serving configurations to reflect version 1.19.0, requiring users to update their settings accordingly. (2af5b590)

## [11.1.1] - 2025-07-22

### Changed

- Introduced prefixes for image tags in kubespray_images.tpl, requiring the new prefix parameter to be specified when using versions >= 2.28.0 with set_kubespray_img_version function calls and necessitating updates to existing image tags. (6e9e4114)

## [11.1.0] - 2025-07-22

### Added

- Enabled improved spell checking accuracy for users by updating the wordlist in the project's GitHub repository to include new words such as "datasets" and "runtime". (a7c4ef45)

## [11.0.5] - 2025-07-22

### Changed

- The project's documentation has been modernized to ensure consistency and accuracy of information by updating job names and descriptions in workflow files and modifying environment variable settings in the readme file without introducing any breaking behavior or requiring migration steps. (d528bb43)

## [11.0.4] - 2025-07-22

### Changed

- Updated various package versions including Go setup to version 5.5.0, super-linter validation to version 8.0.0, pyspelling-any to version 1.0.5, and kubernetes, cert-manager, and knative, without introducing breaking behavior or requiring migration. (0be57358)

## [11.0.3] - 2025-07-07

### Changed

- Updated indentation format value in Makefile from 2 spaces to 4 spaces, requiring users who rely on this setting for code formatting to update their customized settings accordingly. (6444f82f)

## [11.0.2] - 2025-07-05

### Changed

- Modernized dictionary definitions in the spell checker bot's wordlist to uppercase, potentially requiring maintainers to update configurations and scripts that interact with the bot. (1ace4ef5)

## [11.0.1] - 2025-07-05

### Changed

- Clarified documentation for architecture and other key components to enhance overall readability and comprehension. (4b8d11cc)

## [11.0.0] - 2025-06-28

### Removed

- Kyverno can now be installed independently of Gatekeeper without any issues. (fde2f94a)

## [10.1.0] - 2025-06-26

### Added

- Enabled accurate representation of relevant technologies by updating the project's GitHub repository wordlist to include Agentic, Kagent, and KRM terms. (f0ebb186)

## [10.0.4] - 2025-06-26

### Changed

- Clarified documentation for Kubernetes cluster deployment on bare-metal and virtual machines using Ansible, providing more transparent explanations of the POD Descriptor File concept, custom cluster definitions, supported Linux distributions, and components. (ca335091)

## [10.0.3] - 2025-06-26

### Changed

- Updated links in the README.md file to point to correct resources, improving documentation accuracy for users referencing these external resources without introducing any breaking behavior or modifying the existing API and CLI contract. (7cd181ed)

## [10.0.2] - 2025-06-26

### Changed

- Improved accuracy in identifying Kubernetes versions is now achieved by correctly handling versions prefixed with "v". (2b1b7a8e)

## [10.0.1] - 2025-06-26

### Changed

- Updated Kubernetes version to 1.32.5, requiring migration of existing clusters to the updated configuration and necessitating updates to scripts in \_commons.sh and ci/check.sh. (5ec505df)

## [10.0.0] - 2025-06-26

### Removed

- Resolved linting issues in the \_chart_installers.sh script to improve code quality for users who maintain this file without introducing any breaking behavior, API changes, or security impact, and no migration steps are required from users or maintainers. (4b68d942)

## [9.0.2] - 2025-06-26

### Changed

- Upgraded Kubespray version from v2.27.0 to v2.28.0 affecting various configuration variables and scripts requiring users to review their custom configurations for compatibility with the new version. (698c7cac)

## [9.0.1] - 2025-04-30

### Changed

- Enabled support for the Agentic AI KRM platform by adding it to the list of supported scenarios in the README.md file and updating installation and uninstallation procedures accordingly. (f0b26b21)

## [9.0.0] - 2025-04-28

### Removed

- Eliminated the deletion of containerized data importer resources during Kubevirt uninstallation, requiring users to manually delete these resources after uninstalling. (deab1bce)

## [8.1.1] - 2025-04-28

### Changed

- Enabled OpenAI support for AI services by introducing a new environment variable to securely store the API key and modifying resource configurations accordingly. (c68941d8)

## [8.1.0] - 2025-04-28

### Added

- Introduced Ollama models for continued use, modifying available model options and their associated API bases in the litellm.yml configuration file. (24d49ec4)

## [8.0.3] - 2025-04-28

### Changed

- Optimized multi-node testing scenarios by allowing users to override the All-in-One IP address in Ansible inventory when running tests on multiple nodes and updated existing workflows with a migration step. (fbe741c7)

## [8.0.2] - 2025-04-25

### Changed

- Enabled debug output control at the step level for Kubespray deployments through environment variables from GitHub Actions. (76806102)

## [8.0.1] - 2025-04-25

### Changed

- Simplified usage of KRD_DEBUG by centralizing its definition, requiring users to update custom code referencing the variable to point to the new centralized location instead. (4cc994d3)

## [8.0.0] - 2025-04-25

### Removed

- Eliminated the unnecessary installation of arc-runner-set in self-hosted installations when the namespace does not exist without introducing any breaking changes and no migration steps are required. (569fb4d2)

## [7.6.0] - 2025-04-24

### Added

- Enabled complete removal of Longhorn components during uninstallation by including patching of the deleting-confirmation-flag in the longhorn-system namespace and deletion of this namespace in the process. (9253343f)

## [7.5.1] - 2025-04-24

### Changed

- Optimized test VM memory requirements by reducing the requested amount from 128Mi to 64M and removing the label for specifying virtual machine size, which may necessitate adjustments in existing tests relying on these settings. (aee73b37)

## [7.5.0] - 2025-04-24

### Added

- Enabled local network access for LiteLLM by default on Mac systems for Firefox and Chrome browsers without requiring migration steps from existing configurations. (6189409d)

## [7.4.1] - 2025-04-24

### Changed

- KubeVirt Runner now allows memory overcommit by default, which may break existing VMs that rely on the previous behavior and requires users to update their configurations to account for reduced memory allocation. (e8cb75f0)

## [7.4.0] - 2025-04-24

### Added

- Customizable KubeVirt CPU allocation ratio is now enabled during installation allowing users to adjust the default value from 5 for more flexible resource management. (8a8b667d)

## [7.3.1] - 2025-04-24

### Changed

- Simplified virtlink tests by enabling automated setup through a single `kubectl apply` command and increasing the test timeout to 60 seconds from 1 second. (39c3ad28)

## [7.3.0] - 2025-04-24

### Added

- Increased inotify resources to prevent failures on fsnotify watcher when running `kubectl logs`. (5076bd7e)

## [7.2.1] - 2025-04-24

### Changed

- The dependencies for several GitHub Actions and workflows were modernized to newer versions, requiring users to update their configurations accordingly. (ebcf7670)

## [7.2.0] - 2025-04-23

### Added

- Enabled customization of documentation validation settings through the addition of a rstcheck configuration file that includes a report level setting for users to control warning and error severity. (88811d1b)

## [7.1.1] - 2025-04-23

### Changed

- Updated EditorConfig settings to optimize linter tool configurations without introducing breaking behavior or API changes. (b919b639)

## [7.1.0] - 2025-04-23

### Added

- Enabled access to large language models through the introduction of the LiteLLM service gateway provider, available via the `/litellm` API path, requiring users to migrate their setup for utilization. (5340bc89)

## [7.0.10] - 2025-04-19

### Changed

- Enabled support for PostgreSQL clusters managed by the CloudNativePG operator without introducing any breaking changes or requiring migration efforts. (0f03650b)

## [7.0.9] - 2025-04-16

### Changed

- Updated K8sGPT resources to utilize the latest version, necessitating users to migrate their configurations accordingly. (cc98ba3f)

## [7.0.8] - 2025-04-09

### Changed

- Updated linter validation to directly utilize the super-linter repository, ensuring that the latest rules are applied during validation and maintaining compatibility with existing configurations. (835c76ed)

## [7.0.7] - 2025-04-03

### Changed

- Updated the galaxy collection update script to fetch versions from the latest v3 API endpoint instead of v2. (9b701550)

## [7.0.6] - 2025-03-13

### Changed

- Updated galaxy requirements and krd versions files to ensure compatibility with current software releases by reflecting the latest versions of Istio, Knative Eventing, and ArgoCD dependencies. (fe5f26b2)

## [7.0.5] - 2025-03-13

### Changed

- Updated galaxy requirements to optimize Ansible collection and role versions, requiring re-running of galaxy-requirements.yml to apply the changes. (cda9c527)

## [7.0.4] - 2025-03-13

### Changed

- Upgraded galaxy requirements and krd versions files to new version numbers for Vagrant 4.2.2, Ansible Core 2.18.3, and other dependencies, requiring users to update their environments accordingly. (8ff25137)

## [7.0.3] - 2025-03-13

### Changed

- Updated galaxy requirements and krd versions files to ensure compatibility and functionality in the system, requiring users who rely on outdated versions of tools like Knative, Istio, Prometheus Operator, and others to migrate their configurations. (5fb7837f)

## [7.0.2] - 2025-02-20

### Changed

- Upgraded galaxy requirements and krd versions to ensure compatibility with latest features and tools such as Kubernetes, Istio, and Prometheus Operator, requiring manual intervention for some upgrades due to version constraints affecting installation. (d164a189)

## [7.0.1] - 2025-02-20

### Changed

- Updated dependencies in galaxy-requirements.yml to ensure compatibility with latest Ansible collection versions, which may require users to update their environments accordingly. (42677625)

## [7.0.0] - 2025-02-14

### Removed

- Eliminated outdated dictionary terms to improve spell checker accuracy for users. (cef7bdb8)

## [6.1.6] - 2025-02-14

### Changed

- Updated galaxy configurations to reflect the latest cryptographic library and cert manager versions, potentially requiring users to update their dependency management accordingly. (c25db738)

## [6.1.5] - 2025-02-14

### Changed

- Upgraded Ansible role versions for kubernetes.core, community.docker, ansible.posix, and community.general collections to 5.0.0, 4.3.0, 2.0.0, and 10.2.0 respectively, replacing placeholder versions previously used. (1faf382b)

## [6.1.4] - 2025-02-14

### Changed

- Updated Galaxy requirements to reference specific versions of collections instead of placeholders for maximum attempts reached. (12ca521f)

## [6.1.3] - 2025-02-14

### Changed

- Upgraded galaxy requirements and krd versions files to ensure compatibility with the latest software releases, potentially requiring users to update customized workflows or configurations. (06efa57b)

## [6.1.2] - 2025-02-11

### Changed

- The labeler configuration syntax was modernized to specify changed files using a new syntax that may require migration of existing configurations to maintain compatibility. (a7c145f9)

## [6.1.1] - 2025-02-05

### Changed

- Disabled Kata containers integration tests in the on-demand CI workflow due to deployment issues affecting users who relied on these tests for validation. (d8ae9926)

## [6.1.0] - 2025-02-05

### Added

- Kubevirt runners now enable CPU host-passthrough by default allowing for more efficient virtual machine performance this change affects users who rely on precise CPU emulation and may require adjustments to their configuration. (dc120ab0)

## [6.0.0] - 2025-02-05

### Removed

- Simplified VBox logging in the vagrant-up action to remove unnecessary log file retrieval, resulting in improved performance without introducing breaking behavior or migration requirements and with no impact on the API or CLI contract. (a59085c1)

## [5.0.2] - 2025-02-05

### Changed

- Optimized longhorn test timeouts to allow for longer-running tests without timing out and updated the `kubectl wait` command in the test script to include a dynamically adjustable timeout parameter. (0f0c33f3)

## [5.0.1] - 2025-02-05

### Changed

- Enabled support for gvisor and youki runtimes in on-demand builds, allowing developers to test with Kata containers alongside CRI-O by default. (1fcaff6c)

## [5.0.0] - 2025-02-05

### Removed

- Stabilized cleanup of failed virtual machine instances by introducing a new CronJob that periodically deletes them and requires migration to the new job template configuration in arc-cleanup.yml. (4e61660a)

## [4.4.0] - 2025-02-04

### Added

- Enabled secure authentication for GitHub Actions workflows by introducing the WORKFLOW_TOKEN secret token to replace PATs with specific scopes, thus reducing exposure of sensitive authentication credentials and maintaining API and CLI contract consistency without introducing breaking behavior. (17e308e6)

## [4.3.6] - 2025-02-01

### Changed

- Optimized the testing process by reducing integration tests per instance through targeted workflow splitting, resulting in more efficient resource utilization and potentially requiring adjustments to existing CI/CD pipeline configurations. (81f2bbdc)

## [4.3.5] - 2025-01-24

### Changed

- Optimized KataContainer test in CRI-O by disabling it due to issues with the combination of CRI-O and Kata containers affecting on-demand CI workflows for runtime environments that use CRI-O. (8df12521)

## [4.3.4] - 2025-01-24

### Changed

- Optimized ephemeral runner cleanup by reducing the garbage collector's frequency to run every hour instead of every 15 minutes. (0962192a)

## [4.3.3] - 2025-01-24

### Changed

- The runtime classes integration tests were optimized to dynamically create and delete deployments based on the available runtime classes, improving test scalability and efficiency without introducing any breaking behavior or API changes. (e5cb69db)

## [4.3.2] - 2025-01-24

### Changed

- Optimized CI workflows now offer users the option to run tests with Youki runtime by default, thanks to the addition of `youki-enabled` and `KRD_YOUKI_ENABLED` input parameters in the on-demand workflow. (b1505176)

## [4.3.1] - 2025-01-24

### Changed

- Optimized Istio integration tests to accurately reflect sidecar injection behavior by updating the expected log messages for successful and failed injections. (8a3f05c9)

## [4.3.0] - 2025-01-24

### Added

- CRI-O runtime manager now disables gvisor by default when used affecting users who rely on this feature for their container runtime environment. (8042b745)

## [4.2.0] - 2025-01-24

### Added

- Enabled users to easily set up log collection and distribution through the addition of a fluent logging agent installation script in the chart installers. (54f207cc)

## [4.1.1] - 2025-01-23

### Changed

- Simplified the vagrant boxes for kubevirt runner to improve efficiency and reduce complexity in managing these boxes, requiring users who rely on them to update their setup accordingly. (aeb8907e)

## [4.1.0] - 2025-01-23

### Added

- The image pull policy for the kubevirt runner is now enabled to always attempt to pull the latest version of the image on every run without requiring any migration steps from users. (9a5a69b0)

## [4.0.1] - 2025-01-21

### Changed

- Updated the list of supported Linux distributions to include Debian Bullseye, Rocky 9, and updated versions for Ubuntu Focal, Jammy, and OpenSUSE Leap, with no breaking behavior or migration requirements. (9d428cda)

## [4.0.0] - 2025-01-17

### Removed

- Dropped support for Ubuntu Bionic to simplify configurations and dependencies, impacting Linux distros supported, vagrant setup, and molecule platform definitions, requiring users to migrate to newer Ubuntu versions. (94575275)

## [3.1.2] - 2025-01-17

### Changed

- Updated the Ubuntu version in Scheduled CI to 22.04 without requiring any migration steps and preserving compatibility with existing jobs. (4b26f0f9)

## [3.1.1] - 2025-01-15

### Changed

- Stabilized removal of virtual machine instances by integrating their cleanup into the arc garbage collector's existing workflow. (e2cab980)

## [3.1.0] - 2025-01-15

### Added

- Namespace creation in ARC installation has been optimized to ensure consistency by converting the namespace name to lowercase and replacing underscores with hyphens. (6089d72d)

## [3.0.11] - 2025-01-10

### Changed

- Modernized Ansible group names to conform to standard naming conventions, replacing "kube-master" and "kube-node" with "kube_control_plane" and "kube_node", respectively, impacting various files including Vagrantfiles, Ansible playbooks, and configuration samples. (ffdda328)

## [3.0.10] - 2025-01-10

### Changed

- Tox installation is now properly configured in GitHub workflows for molecule tests to run successfully without any limitations. (ef136d76)

## [3.0.9] - 2025-01-10

### Changed

- Updated containerized data importer configurations to require users to specify version v1.61.0 of the CDI, necessitating potential updates from relying on settings specific to the previous version. (db892bc2)

## [3.0.8] - 2025-01-10

### Changed

- Upgraded python test requirements to newer versions including Ansible-compat 24.10.0, Ansible-core 2.17.7, and cryptography 44.0.0 which may require migration steps for users running tests with older dependencies. (d868d40c)

## [3.0.7] - 2025-01-10

### Changed

- Upgraded metallb to v0.14.9, which may necessitate users to update their configurations if they are relying on specific features or bugfixes introduced in this new version. (d3ce9bdc)

## [3.0.6] - 2025-01-10

### Changed

- Updated Istio to version 1.24.2, which may require users to reapply their configurations due to potential changes in the Istio service mesh configuration. (b6121689)

## [3.0.5] - 2025-01-10

### Changed

- The virtink version was updated to v0.17.0, introducing new features and improvements that may require migration steps for users depending on their current setup. (934c2688)

## [3.0.4] - 2025-01-10

### Changed

- Updated Knative versions to 1.16.1 for serving and eventing components, requiring users who rely on these components to migrate their configurations accordingly. (8a34cf5c)

## [3.0.3] - 2025-01-10

### Changed

- Updated the kubevirt task in Tekton to version v0.23.0, maintaining an unchanged API/CLI contract and requiring no migration steps from affected users who rely on this task for Kubernetes virtualization. (840b33a6)

## [3.0.2] - 2025-01-10

### Changed

- Improved handling of GitHub Actions in CI pipeline ensures that version updates are properly reflected in GitHub workflows. (6f227bfd)

## [3.0.1] - 2025-01-10

### Changed

- Optimized storage requirements for users relying on Vagrant boxes by increasing the available capacity from 25G to 35G without altering the CLI contract or introducing security risks. (679fdf78)

## [3.0.0] - 2025-01-10

### Removed

- Eliminated legacy todo instructions from configuration files to prevent confusion and enable smoother alignment with upstream dependencies. (50d8667e)

## [2.1.9] - 2025-01-10

### Changed

- Updated Kube OVN to v1.13.2, which may require migration steps for users running this component due to changes in the `krd-vars.yml` file. (203269ee)

## [2.1.8] - 2025-01-10

### Changed

- Updated the Prometheus operator to version v0.79.2 without introducing breaking behavior or API/CLI contract changes and no security impact is involved. (1bc0a809)

## [2.1.7] - 2025-01-10

### Changed

- Upgraded Kubernetes version to v1.31.4, requiring users to update their cluster configurations accordingly to reflect the new version and potentially affecting CI scripts utilizing related assertions. (fd3d95c2)

## [2.1.6] - 2025-01-10

### Changed

- The kubespray version was updated to v2.27.0, requiring migration of existing deployments to the new version and incorporating the latest multus tasks from the master branch due to a merge in kubespray. (555fa2b5)

## [2.1.5] - 2025-01-09

### Changed

- Upgraded the PMEM driver to version 2.13.0, which may require users currently relying on the older version to take migration steps due to an updated configuration schema with a new pmem_driver_registrar_version value. (9babcc3b)

## [2.1.4] - 2025-01-09

### Changed

- Upgraded k8sgpt to v0.3.48 in the local configuration file, requiring manual migration steps if existing code relies on specific features or behavior present in the previous version. (511d1033)

## [2.1.3] - 2025-01-09

### Changed

- Upgraded galaxy collections and roles versions to ensure compatibility with latest dependencies such as geerlingguy.docker, andrewrothstein.gcc-toolbox, kubernetes.core, community.docker, ansible.posix, and community.general. (1be4c679)

## [2.1.2] - 2025-01-09

### Changed

- Upgraded GH action versions across workflows to new dependencies, including actions/cache at 4.2.0 and reviewdog/action-misspell at 1.26.1, with no breaking changes affecting Vagrant setup, Go installation, or spell checking actions. (17ab3857)

## [2.1.1] - 2025-01-09

### Changed

- Upgraded NFD version to v0.17.0, which may require users to migrate their configurations if they directly referenced the previous version in their playbooks. (0180aa73)

## [2.1.0] - 2025-01-09

### Added

- Enabled automatic cleanup of ephemeral runners in the Actions system through periodic deletion of failed instances. (8f5faf4c)

## [2.0.3] - 2025-01-08

### Changed

- Updated the image used for the kubevirt-actions-runner container to utilize the artifact generated by the new GitHub Container Registry URL instead of the electrocucaracha repository without introducing any breaking behavior and maintaining the existing API contract. (c9545ad6)

## [2.0.2] - 2025-01-08

### Changed

- Optimized Ubuntu runner disk size to 25G in pipeline configuration, requiring users who customized their pipelines for the original 14G storage limit to make manual adjustments for continued compatibility. (bc2b98d7)

## [2.0.1] - 2025-01-08

### Changed

- Optimized the arc runner configuration to limit it to three instances by introducing the maxRunners parameter in chart values. (8c13a0c3)

## [2.0.0] - 2025-01-08

### Removed

- Istio installation verification is no longer performed during the install process allowing users to integrate with Istio without requiring explicit verification of its installation but may necessitate modifications to scripts that relied on this step. (768879b0)

## [1.5.3] - 2025-01-08

### Changed

- Workflows can now run on users' own virtual machines, replacing the need for GitHub's infrastructure, after self-hosted runners were enabled and several workflows updated to use vm-self-hosted labels with no breaking behavior or API changes introduced but possibly requiring migration steps. (5c8aa805)

## [1.5.2] - 2024-12-31

### Changed

- Improved flexibility in managing dependencies between components is now enabled by allowing users to specify chart versions during installation via the Actions Runner Controller. (438fed80)

## [1.5.1] - 2024-12-31

### Changed

- Optimized the sources list for the Ubuntu runner to improve virtualbox installation by adding rsync and virtualbox-7.1 packages while removing virtualbox, introducing an API contract change with no migration steps required and maintaining the same security impact as before. (4f0084be)

## [1.5.0] - 2024-12-18

### Added

- Enabled automated tasks to run with elevated privileges through the runner's sudo passwordless account without requiring pipeline configuration changes or migration steps. (06bc4724)

## [1.4.0] - 2024-12-18

### Added

- Enabled specification of default provider for Vagrant through the introduction of the VAGRANT_DEFAULT_PROVIDER environment variable, which affects how virtual machines are provisioned and has been set to virtualbox by default. (93453ba2)

## [1.3.0] - 2024-12-17

### Added

- Enabled Python-based actions by installing necessary packages and creating a symbolic link to python3 as /usr/bin/python in the Ubuntu runner pipeline, introducing breaking behavior for pipelines relying on the default Python version. (7207b563)

## [1.2.0] - 2024-12-17

### Added

- Introduced the Git package into the Ubuntu runner pipeline, enabling users to execute commands that require Git without any breaking behavior or migration requirements. (4d52d858)

## [1.1.1] - 2024-12-17

### Changed

- Normalized the GitHub Actions runner for Kubernetes to use electrocucaracha/kubevirt-actions-runner:latest, requiring users to update their configurations and introducing new rolebindings and permissions. (002d4e79)

## [1.1.0] - 2024-12-13

### Added

- Enabled automated tools to accurately spell words related to "Tekton" and "TopoLVM" by updating the GitHub repository's wordlist without introducing any breaking changes or modifying API contracts. (2cb882ed)

## [1.0.5] - 2024-12-13

### Changed

- Enabled support for distributed block storage systems through the Topolvm storage solution, affecting the default test suite and installation scripts. (ee82fd89)

## [1.0.4] - 2024-12-13

### Changed

- Optimized gitleaks linting to prevent false positives and allow pipeline execution by relaxing specific key checks in the ubuntu-runner-pipeline configuration. (ef288648)

## [1.0.3] - 2024-12-13

### Changed

- Updated pipeline configurations to disable specific linter rules and adjust parameter names, requiring users who rely on these pipelines to update their settings accordingly. (de280214)

## [1.0.2] - 2024-12-13

### Changed

- Volumes are now managed using volume groups defined by the -g option in node.sh instead of the mount parameter. (8817ee8a)

## [1.0.1] - 2024-12-13

### Changed

- Enabled users to deploy arc in their own namespace instead of the default one by allowing namespace deployments for arc, which can be specified during deployment and is determined by a new variable `KRD_ARC_GITHUB_URL`. (105fd4d7)

## [1.0.0] - 2024-12-10

### Changed

- Corrected the installation order for Tekton to ensure proper setup of the project and updated installation scripts are required by users who install Tekton as a result. (d8f2e8e6)
