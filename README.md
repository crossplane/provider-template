# provider-template

`provider-template` is a minimal [Crossplane](https://crossplane.io/) Provider
that is meant to be used as a starting point for implementing new Providers.
Before you run the steps in [Developing](#developing) below, it ships with:

- A `ProviderConfig` type that only points to a credentials `Secret`.
- A `MyType` resource type that serves as an example managed resource.
- A managed resource controller that reconciles `MyType` objects and simply
  prints their configuration in its `Observe` method.

## Developing

The steps below take this repository to a new provider that compiles,
lints, and passes its tests. They're shown for a provider named `Acme` with
a `storage` group and a `Bucket` type — substitute your own provider, group,
and kind throughout.

### Prerequisites

Use the Go toolchain version pinned in [`go.mod`](go.mod). If your local
`go version` is newer, pin it before running `make reviewable` (step 9):

```shell
GOTOOLCHAIN=go$(sed -n 's/^go //p' go.mod) make reviewable
```

The pinned `golangci-lint` (its exact version is set in
`build/makelib/k8s_tools.mk`, added by step 2 below) can't typecheck a newer
Go standard library, so plain `make reviewable`/`make lint` fails with
`could not import math/rand/v2 ... (typecheck)` on a newer local Go — even
before you touch anything in this repo. `go build`/`go test`/`go generate`
themselves are unaffected; only the lint step needs the pin. Docker is only
needed if you also want `make build` to produce OCI images.

### 1. Create your repository

Create a new repository based on this one, then clone it:

```shell
git clone <your-new-repo-url>
cd <your-new-repo>
```

### 2. Initialize the build submodule

```shell
make submodules
```

### 3. Rename the provider

```shell
make provider.prepare provider=Acme
```

> **Warning:** `provider.prepare` runs `git clean -fd`, which deletes
> **every** untracked file in the repository. Only run it on a clean,
> freshly cloned tree — before adding any untracked work of your own. It can
> only be run once; to re-run it, stash or reset your git state first.
>
> It also finds-and-replaces this placeholder name (and its capitalized
> form) with your provider name across nearly every tracked file, including
> **this README.md, the Makefile, and PROVIDER_CHECKLIST.md themselves**. If
> you're reading this file from disk rather than from memory, the copy in
> your clone will read slightly differently from here on.

This moves the API aggregator to `apis/acme.go` and the controller
aggregator from `internal/controller/register.go` to
`internal/controller/acme.go`, and deletes the placeholder `apis/sample`,
`internal/controller/mytype`, and `examples/sample` packages.

**The tree does not compile after this step.** `apis/acme.go` and
`internal/controller/acme.go` still import the packages that were just
deleted. Steps 5–6 below fix that — don't run `make generate` or
`make reviewable` before then; they fail with "not all generators ran
successfully" while those imports are dangling.

### 4. Add your first API type

```shell
make provider.addtype provider=Acme group=storage kind=Bucket
```

Pass `apiversion=v1beta1` (defaults to `v1alpha1`) to generate a different
API version — the paths below move with it, e.g. `apis/storage/v1beta1/...`
if you did. This writes:

- `apis/storage/storage.go` and
  `apis/storage/<apiversion>/{doc,groupversion_info,bucket_types}.go`
- `internal/controller/bucket/{bucket,bucket_test}.go`

The scaffolded controller is a **no-op stub**: its `Connect`/`Observe`/
`Create`/`Update`/`Delete` methods don't call any real external API — you
still need to replace them with calls to your actual backend.

Unlike `apis/sample/v1alpha1/mytype_types.go`, the generated `bucket_types.go`
does **not** assert `resource.ModernManaged`/`resource.ManagedList`
conformance. It can't: that assertion only compiles once
`zz_generated.managed.go` exists, but `go generate` (step 9) has to
typecheck this package *before* it can write that file — so a fresh type
with the assertion already present fails generation with `missing method
GetCondition` on the very first run. Once step 9 has succeeded at least
once, you can add the assertion by hand for parity with the sample:

```go
resource "github.com/crossplane/crossplane-runtime/v2/pkg/resource"

// interface checks to ensure our types conform to the crossplane-runtime interfaces
var (
	_ resource.ModernManaged = &Bucket{}
	_ resource.ManagedList   = &BucketList{}
)
```

This step does **not** register the new type anywhere, and it does not run
code generation (`zz_generated.*.go`, `package/crds/**`) — steps 5–9 below
cover that.

### 5. Register the new type in `apis/acme.go`

```diff
 import (
 	"k8s.io/apimachinery/pkg/runtime"

-	samplev1alpha1 "github.com/crossplane/provider-acme/apis/sample/v1alpha1"
+	storagev1alpha1 "github.com/crossplane/provider-acme/apis/storage/v1alpha1"
 	acmev1alpha1 "github.com/crossplane/provider-acme/apis/v1alpha1"
 )

 func init() {
 	// Register the types with the Scheme so the components can map objects to GroupVersionKinds and back
 	AddToSchemes = append(AddToSchemes,
 		acmev1alpha1.SchemeBuilder.AddToScheme,
-		samplev1alpha1.SchemeBuilder.AddToScheme,
+		storagev1alpha1.SchemeBuilder.AddToScheme,
 	)
 }
```

### 6. Register the new controller in `internal/controller/acme.go`

```diff
 import (
 	"github.com/crossplane/crossplane-runtime/v2/pkg/controller"
 	ctrl "sigs.k8s.io/controller-runtime"

 	"github.com/crossplane/provider-acme/internal/controller/config"
-	"github.com/crossplane/provider-acme/internal/controller/mytype"
+	"github.com/crossplane/provider-acme/internal/controller/bucket"
 )

 func SetupGated(mgr ctrl.Manager, o controller.Options) error {
 	for _, setup := range []func(ctrl.Manager, controller.Options) error{
 		config.Setup,
-		mytype.SetupGated,
+		bucket.SetupGated,
 	} {
 		if err := setup(mgr, o); err != nil {
 			return err
 		}
 	}
 	return nil
 }
```

### 7. Add an example manifest

Step 3 deletes `examples/sample/`. Add `examples/storage/bucket.yaml`:

```yaml
apiVersion: storage.acme.crossplane.io/v1alpha1
kind: Bucket
metadata:
  name: example
  namespace: default
spec:
  forProvider:
    configurableField: test
  providerConfigRef:
    name: example
    kind: ProviderConfig
```

`providerConfigRef.kind` is either `ProviderConfig` (namespaced, shown above)
or `ClusterProviderConfig`; both are valid because the generated `Bucket`
type embeds `xpv2.ManagedResourceSpec`, same as `MyType`.

### 8. Format your edits

Hand-editing an import block can misalign it in a way `gofmt` — and
therefore `make reviewable`'s lint check — rejects:

```shell
gofmt -w apis/acme.go internal/controller/acme.go
```

### 9. Verify

```shell
GOTOOLCHAIN=go$(sed -n 's/^go //p' go.mod) make reviewable
```

This is the compile-and-lint gate for the branch: it regenerates
`zz_generated.*.go` and `package/crds/**`, runs `golangci-lint`, and runs the
unit tests.

From here, `make build` builds the provider binary and, with a Docker daemon
running, its OCI package and controller images (not re-verified as part of
the steps above). `make run` runs the provider out-of-cluster for local
debugging, and `make dev`/`make dev-clean` stand up or tear down a local
kind cluster to deploy into.

Refer to Crossplane's [CONTRIBUTING.md] file for more information on how the
Crossplane community prefers to work. The [Provider Development][provider-dev]
guide may also be of use.

[CONTRIBUTING.md]: https://github.com/crossplane/crossplane/blob/main/CONTRIBUTING.md
[provider-dev]: https://github.com/crossplane/crossplane/blob/main/contributing/guide-provider-development.md
