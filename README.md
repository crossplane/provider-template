# provider-template

`provider-template` is a minimal [Crossplane](https://crossplane.io/) Provider
that is meant to be used as a template for implementing new Providers. It comes
with the following features that are meant to be refactored:

- A `ProviderConfig` type that only points to a credentials `Secret`.
- A `MyType` resource type that serves as an example managed resource.
- A managed resource controller that reconciles `MyType` objects and simply
  prints their configuration in its `Observe` method.

## Developing

1. Use this repository as a template to create a new one.
1. Rename the provider by running the follwing command:
```
  make provider.prepare provider={PascalProviderName}
```
3. Add your new type by running the following command:
```
make provider.addtype provider={PascalProviderName} group={ApiGroup} kind={Type}
```
4. Replace the *sample* group with your new group in apis/{provider}.go
3. Run `make` to initialize the "build" Make submodule we use for CI/CD.
3. Run `make reviewable` to run code generation, linters, and tests.
3. Replace `MyType` with your own managed resource implementation(s).

Refer to Crossplane's [CONTRIBUTING.md] file for more information on how the
Crossplane community prefers to work. The [Provider Development][provider-dev]
guide may also be of use.

[CONTRIBUTING.md]: https://github.com/crossplane/crossplane/blob/master/CONTRIBUTING.md
[provider-dev]: https://github.com/crossplane/crossplane/blob/master/docs/contributing/provider_development_guide.md