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
1. Run `make submodules` to initialize the "build" Make submodule we use for CI/CD.
1. Rename the provider by running the following command:
```shell
  export provider_name=MyProvider # Camel case, e.g. GitHub
  make provider.prepare provider=${provider_name}
```
4. Add your new type by running the following command:
```shell
  export group=sample # lower case e.g. core, cache, database, storage, etc.
  export type=MyType # Camel casee.g. Bucket, Database, CacheCluster, etc.
  make provider.addtype provider=${provider_name} group=${group} kind=${type}
```
5. Replace the *sample* group with your new group in apis/{provider}.go
5. Replace the *mytype* type with your new type in internal/controller/{provider}.go
5. Replace the default controller and ProviderConfig implementations with your own
5. Register your new type into `SetupGated` function in `internal/controller/register.go`
5. Run `make reviewable` to run code generation, linters, and tests.
5. Run `make build` to build the provider.

## Testing

```shell
make test      # unit tests
make e2e       # end-to-end tests against a kind control plane
make uptest    # only the e2e tests, reusing a control plane that is already up
```

`make e2e` runs two suites, and which one a new test belongs in depends on what
it checks:

- **`test/e2e/`** — the managed resource lifecycle: create, observe, update,
  import, delete. [uptest] generates these, so to cover a **new managed resource
  type** you add it to `test/e2e/00-lifecycle.yaml` as another YAML document
  with a `uptest.upbound.io/conditions` annotation. Point
  `uptest.upbound.io/post-assert-hook` at a script to assert more than
  conditions.
- **`test/behavior/`** — everything else: drift, the pause annotation,
  credential resolution, error paths. To cover a **controller behaviour**, add
  `test/behavior/<name>/chainsaw-test.yaml`; it is picked up automatically.
  Prefer declarative [chainsaw] operations — `apply`, `assert`, `patch`,
  `delete`, and `error` (which passes only when a resource is *absent*).

Validate a new chainsaw test before running it:

```shell
.cache/tools/*/chainsaw-* lint test -f test/behavior/<name>/chainsaw-test.yaml
```

`test/README.md` is the reference: every uptest annotation and where it is
documented, the make variables, what each test covers, and the known gotchas.

Refer to Crossplane's [CONTRIBUTING.md] file for more information on how the
Crossplane community prefers to work. The [Provider Development][provider-dev]
guide may also be of use.

[uptest]: https://github.com/crossplane/uptest
[chainsaw]: https://kyverno.github.io/chainsaw/
[CONTRIBUTING.md]: https://github.com/crossplane/crossplane/blob/master/CONTRIBUTING.md
[provider-dev]: https://github.com/crossplane/crossplane/blob/master/contributing/guide-provider-development.md
