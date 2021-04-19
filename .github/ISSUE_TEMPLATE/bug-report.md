---
name: Bug Report
about: Report a bug encountered while operating Kubernetes
labels: kind/bug

---
<!--
Please, be ready for followup questions, and please respond in a timely
manner.  If we can't reproduce a bug or think a feature already exists, we
might close your issue.  If we're wrong, PLEASE feel free to reopen it and
explain why.
-->

# Summary

Describe your issue here

## Steps

How to reproduce this issue

## Expected behaviour

## Actual behaviour

## Environment

### Pod Description File

`cat config/pdf.yml`

### KRD environment variables

`vagrant ssh installer -- printenv | grep KRD`

### KRD version (commit)

`git rev-parse --short HEAD`

### Output of Setup Kubernetes log file
<!-- We recommend using snippets services like https://gist.github.com/ etc. -->

`vagrant ssh installer -- cat /vagrant/setup-kubernetes.log`
