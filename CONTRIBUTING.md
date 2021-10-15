# Contributing to KRD

Welcome! We are glad that you want to contribute to our project! 💖

As you get started, you are in the best position to give us feedback on areas of
our project that we need help with including:

* Problems found during setting up a new environment
* Gaps in our documentation
* Bugs in our automation scripts

If anything doesn't make sense, or doesn't work when you run it, please open a
bug report and let us know!

## Ways to Contribute

We welcome many different types of contributions including:

* New features
* Builds, CI/CD
* Bugfixes
* Documentation

## When to open a pull request

It's OK to submit a PR directly for problems such as misspellings or other
things where the motivation/problem is unambiguous.

If there isn't an issue for your PR, please make an issue first and explain the
problem or motivation for the change you are proposing. When the solution isn't
straightforward, for example "Implement missing command X", then also outline
your proposed solution. Your PR will go smoother if the solution is agreed upon
before you've spent a lot of time implementing it.

## Pull Request Lifecycle

1. You create a draft or WIP pull request. Reviewers will ignore it mostly
   unless you mention someone and ask for help. Feel free to open one and use
   the pull request to see if the CI passes. Once you are ready for a review,
   remove the WIP or click "Ready for Review" and leave a comment that it's
   ready for review.

   If you create a regular pull request, a reviewer won't wait to review it.
1. A reviewer will assign themselves to the pull request. If you don't see
   anyone assigned after 3 business days, you can leave a comment asking for a
   review. Sometimes we have busy days, sick days, weekends and vacations, so a
   little patience is appreciated! 🙇‍♀️
1. The reviewer will leave feedback.
    * `nits`: These are suggestions that you may decide incorporate into your
      pull request or not without further comment.
    * It can help to put a 👍 on comments that you have implemented so that you
      can keep track.
    * It is okay to clarify if you are being told to make a change or if it is a
      suggestion.
1. After you have made the changes (in new commits please!), leave a comment. If
   3 business days go by with no review, it is okay to bump.
1. When a pull request has been approved, the reviewer will squash and merge
   your commits. If you prefer to rebase your own commits, at any time leave a
   comment on the pull request to let them know that.

## How to get your pull request reviewed fast

🚧 If you aren't done yet, create a draft pull request or put WIP in the title
so that reviewers wait for you to finish before commenting.

1️⃣ Limit your pull request to a single task. Don't tackle multiple unrelated
things, especially refactoring. If you need large refactoring for your change,
chat with a maintainer first, then do it in a separate PR first without any
functionality changes.

🎳 Group related changes into commits will help us out a bunch when reviewing!
For example, when you change dependencies and check in vendor, do that in a
separate commit.

😅 Make requested changes in new commits. Please don't amend or rebase commits
that we have already reviewed. When your pull request is ready to merge, you can
rebase your commits yourself, or we can squash when we merge. Just let us know
what you are more comfortable with.

🚀 We encourage follow-on PRs and a reviewer may let you know in their comment
if it is okay for their suggestion to be done in a follow-on PR. You can decide
to make the change in the current PR immediately, or agree to tackle it in a
reasonable amount of time in a subsequent pull request. If you can't get to it
soon, please create an issue and link to it from the pull
request comment so that we don't collectively forget.

## Environment Setup

This project uses [Vagrant tool][1] for provisioning Virtual Machines
automatically. The *setup.sh* script of the [bootstrap-vagrant project][2]
contains the Linux instructions to install dependencies and plugins required for
its usage. This script supports two Virtualization technologies (Libvirt and
VirtualBox) and they can be specified by *PROVIDER* environment variable.

    curl -fsSL http://bit.ly/initVagrant | PROVIDER=libvirt bash

Once Vagrant is installed, it's possible to provision a cluster nodes with the
following instruction:

    vagrant up

> Note: Vagrant will utilize the default configuration values defined in
[*this*](config/default.yml) file to setup the VM nodes of the cluster. Those
values can be overwritten creating a valid  *pdf.yml* file in
the [config](config) folder.

An additional *installer* VM will be used for provisioning the Kubernetes
cluster. Several [environment variables](README.md#environment-variables)
can be used to control the provisioning workflow.

### Kubespray Development Environment Setup

The following example shows how KRD can be used to provision a Kubespray
development environment. Through the `KRD_KUBESPRAY_REPO` environment
variable is possible to specify the Kubespray's fork to fetch source
code and the `KRD_KUBESPRAY_VERSION` can be used to define the branch
to be selected.

    KRD_KUBESPRAY_REPO=https://github.com/electrocucaracha/kubespray KRD_KUBESPRAY_VERSION=origin/release-2.9 vagrant up installer

## Pull Request Checklist

When you submit your pull request, or you push new commits to it, our automated
systems will run some checks on your new code. We require that your pull request
passes these checks, but we also have more criteria than just that before we can
accept and merge it. We recommend that you run the following things locally
before you submit your code:

    make lint

[1]: https://www.vagrantup.com/
[2]: https://github.com/electrocucaracha/bootstrap-vagrant
