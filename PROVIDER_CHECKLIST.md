# Provider Checklist

Crossplane manages Resources external via
[Providers](https://crossplane.io/docs/master/concepts/providers.html).
Providers are composed of Kubernetes [Custom Resource
Definitions](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/#customresourcedefinitions)
and [Controllers](https://kubernetes.io/docs/concepts/architecture/controller)
that communicate to a remote API and manages the lifecycle of a resource from
Creation to Deletion.

To build a new provider, please refer to the [Provider Development
Guide](https://crossplane.io/docs/master/contributing/provider_development_guide.html).

This document contains list of items that are usually involved in managing Open
Source contributions to a Crossplane provider. In general your provider should
follow the guidelines documented in the [Crossplane
Contributing](https://github.com/crossplane/crossplane/blob/master/CONTRIBUTING.md)
guide.

## Repository

Although providers can be hosted in any source code repository, the [crossplane-contrib](https://github.com/orgs/crossplane-contrib) Github Organization is available as a neutral home that is under Crossplane's project [governance](https://github.com/crossplane/crossplane/blob/master/GOVERNANCE.md).

Members of the Crossplane community are happy to create a repository in the *crossplane-contrib* organization and configure access, continuous integration, and storage
for software artifacts. Please open an issue in the Crossplane
[org](https://github.com/crossplane/org) repository or reach out to the Crossplane
[#dev](https://crossplane.slack.com/archives/CEF5N8X08) channel.

Generally projects are named `provider-<name>`, with `name` being the API being
managed. Example project names are `provider-aws`, `provider-kubernetes`,
and `provider-github`.

The [provider-template](https://github.com/crossplane/provider-template) repository can be
used as a starting point for new providers. For [terrajet](https://github.com/crossplane/terrajet)-based providers, the
[provider-jet-template](https://github.com/crossplane-contrib/provider-jet-template) is
available.

## Files

Most Crossplane providers include the following files:

- [ ]  A descriptive README.md at the root of the project (see
  [provider-gcp/README.md](https://github.com/crossplane/provider-gcp/blob/master/README.md)
  as an example)
- [ ]  Code is licensed under the [Apache 2.0
  License](https://github.com/crossplane/provider-template/blob/main/LICENSE)
- [ ]  Include a “Developer Certificate of Origin”. Example:
  [DCO](https://github.com/upbound/build/blob/master/DCO)
- [ ]  Include the CNCF [Code of
  Conduct](https://github.com/crossplane/crossplane/blob/master/CODE_OF_CONDUCT.md)
- [ ]  Update
  [OWNERS.md](https://github.com/crossplane/provider-template/blob/main/OWNERS.md)
  with contacts for project Owners
- [ ]  Ensure `hack/boilerplate.go.txt` (used in Code generation) includes
  Crossplane Authors, Apache license and any other Copyright statements:
  [https://github.com/crossplane/provider-template/blob/main/hack/boilerplate.go.txt](https://github.com/crossplane/provider-template/blob/main/hack/boilerplate.go.txt)
- [ ] Include Documentation on how to:
  - [ ] Install Provider
  - [ ] Contribute to Development
  - [ ] Authenticate to backend API, including creating Kubernetes secrets for
    the ProviderConfig
- [ ] Include examples for the ProviderConfig and each resource in the
  `examples/` directory.

## Build Process

There are a number of build tools and processes that are common across the
Crossplane ecosystem. Using these ensures a consistent development environment
across projects.

The [provider-template](https://github.com/crossplane/provider-template)
repository contains most of these settings.

- [ ] Use the [Upbound build](https://github.com/upbound/build) submodule. (see
  [https://github.com/crossplane/crossplane/blob/master/CONTRIBUTING.md#establishing-a-development-environment](https://github.com/crossplane/crossplane/blob/master/CONTRIBUTING.md#establishing-a-development-environment))
- [ ] Include a
  [Makefile](https://github.com/crossplane/provider-gcp/blob/master/Makefile)
  that supports common build targets.
- [ ] Use a Golang linter. Example:
  [https://github.com/crossplane/provider-aws/blob/master/.golangci.yml](https://github.com/crossplane/provider-aws/blob/master/.golangci.yml)
- [ ] Create a [Crossplane
  Package](https://crossplane.io/docs/master/concepts/packages.html)
  configuration (see
  [package/crossplane.yaml)](https://github.com/crossplane/provider-template/blob/main/package/crossplane.yaml)

## Deployment of Artifacts

When deploying provider artifacts, projects should generally follow the Crossplane
[release process](https://crossplane.io/docs/master/contributing/release-process.html).

Most Crossplane projects use [Github Actions](https://docs.github.com/en/actions/learn-github-actions/understanding-github-actions) to build, tag, and promote software releases.

Providers are packaged as OCI (Docker) images and pushed to an OCI registry as part of
the publish and promotion workflows.

In general, providers should:

- [ ] Utilize GitHub workflows from
  <https://github.com/crossplane/provider-template/tree/main/.github/workflows>
- [ ] Create OCI image repos to push Package and Controller images.
- [ ] Automatically push Provider images and packages via CI
- [ ] Add GitHub Secrets to push to Docker repository. (To be performed by
  Crossplane-contrib administrators).

If you're part of the crossplane-contrib org and want to enable Github CI, push
OCI images or packages to the crossplane org in Docker Hub please ask a
[steering committee
member](https://github.com/crossplane/crossplane/blob/master/OWNERS.md#steering-committee)
to grant your project access to the GitHub org scoped secrets.

## Governance

- [ ] Follow recommendations at
  [https://github.com/crossplane/crossplane/blob/master/GOVERNANCE.md#repository-governance](https://github.com/crossplane/crossplane/blob/master/GOVERNANCE.md#repository-governance)
- [ ] Enable Issues on your project and configure Issue templates (examples at:
  [.github/ISSUE_TEMPLATE](https://github.com/crossplane/provider-template/tree/master/.github/ISSUE_TEMPLATE))
- [ ] Create Pull Request Templates: (example:
  [PULL_REQUEST_TEMPLATE.md](https://github.com/crossplane/provider-template/blob/master/.github/PULL_REQUEST_TEMPLATE.md))
