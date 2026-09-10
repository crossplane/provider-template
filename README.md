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
lints, and passes its tests — and, unlike the scaffolded stub, actually does
something: it manages a Kubernetes `ConfigMap`. They're shown for a provider
named `Example` with a `config` group and a `ManagedConfigMap` type —
substitute your own provider, group, and kind throughout.

### Prerequisites

Any recent Go will do — the `Makefile` pins `GOTOOLCHAIN` to [`go.mod`](go.mod)'s
directive. Don't remove that pin: the bundled `golangci-lint` cannot typecheck a
standard library newer than the Go that built it, and `make reviewable` then
fails before you have changed anything.

Docker is only needed if you also want `make build` to produce OCI images.

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
make provider.prepare provider=Example
```

> **Warning:** `provider.prepare` runs `git clean -fd`, which deletes
> **every** untracked file in the repository. Only run it on a clean,
> freshly cloned tree — before adding any untracked work of your own. It can
> only be run once; to re-run it, stash or reset your git state first.
>
> It also finds-and-replaces this placeholder name (and its capitalized
> form) with your provider name across nearly every tracked file, including
> **this README.md and the Makefile themselves** (`PROVIDER_CHECKLIST.md` is
> deliberately exempt — it's a guide about authoring a provider, not about
> this one). If you're reading this file from disk rather than from memory,
> the copy in your clone will read slightly differently from here on.

This moves the API aggregator to `apis/example.go` and the controller
aggregator from `internal/controller/register.go` to
`internal/controller/example.go`, and deletes the placeholder `apis/sample`,
`internal/controller/mytype`, and `examples/sample` packages.

Your API groups default to `example.crossplane.io` (`ProviderConfig`) and
`<group>.example.crossplane.io` (your types). Pass `domain=` for your own:

```shell
make provider.prepare provider=Example domain=example.com
```

Only this provider's groups move — Crossplane's own `meta.pkg.crossplane.io`
and `crossplane.io/external-name` are left alone. `provider.addtype` takes no
`domain=`; it reads the suffix back out of `apis/v1alpha1/register.go`.

**The tree does not compile after this step.** `apis/example.go` and
`internal/controller/example.go` still import the packages that were just
deleted. Steps 5–6 below fix that — don't run `make generate` or
`make reviewable` before then; they fail with "not all generators ran
successfully" while those imports are dangling.

### 4. Add your first API type

```shell
make provider.addtype provider=Example group=config kind=ManagedConfigMap
```

Pass `apiversion=v1beta1` (defaults to `v1alpha1`) to generate a different
API version — the paths below move with it, e.g. `apis/config/v1beta1/...`
if you did. There is no `domain=` here; step 3 already settled it. This
writes:

- `apis/config/config.go` and
  `apis/config/<apiversion>/{doc,groupversion_info,managedconfigmap_types}.go`
- `internal/controller/managedconfigmap/{managedconfigmap,managedconfigmap_test}.go`

The scaffolded controller is a **no-op stub**: its `Connect`/`Observe`/
`Create`/`Update`/`Delete` methods don't call any real external API. Step 7
below replaces it with a real, if simple, implementation that manages a
`corev1.ConfigMap`.

Unlike `apis/sample/v1alpha1/mytype_types.go`, the generated
`managedconfigmap_types.go` does **not** assert
`resource.ModernManaged`/`resource.ManagedList` conformance. It can't: that
assertion only compiles once `zz_generated.managed.go` exists, but
`go generate` (step 10) has to typecheck this package *before* it can write
that file — so a fresh type with the assertion already present fails
generation with `missing method GetCondition` on the very first run. Once
step 10 has succeeded at least once, you can add the assertion by hand for
parity with the sample:

```go
resource "github.com/crossplane/crossplane-runtime/v2/pkg/resource"

// interface checks to ensure our types conform to the crossplane-runtime interfaces
var (
	_ resource.ModernManaged = &ManagedConfigMap{}
	_ resource.ManagedList   = &ManagedConfigMapList{}
)
```

This step does **not** register the new type anywhere, and it does not run
code generation (`zz_generated.*.go`, `package/crds/**`) — steps 5–6 below
register it, and step 10 generates code.

### 5. Register the new type in `apis/example.go`

```diff
 import (
 	"k8s.io/apimachinery/pkg/runtime"

-	samplev1alpha1 "github.com/crossplane/provider-example/apis/sample/v1alpha1"
+	configv1alpha1 "github.com/crossplane/provider-example/apis/config/v1alpha1"
 	examplev1alpha1 "github.com/crossplane/provider-example/apis/v1alpha1"
 )

 func init() {
 	// Register the types with the Scheme so the components can map objects to GroupVersionKinds and back
 	AddToSchemes = append(AddToSchemes,
 		examplev1alpha1.SchemeBuilder.AddToScheme,
-		samplev1alpha1.SchemeBuilder.AddToScheme,
+		configv1alpha1.SchemeBuilder.AddToScheme,
 	)
 }
```

On `apiversion=v1beta1`, only the *new* type's import changes: use
`configv1beta1 "github.com/crossplane/provider-example/apis/config/v1beta1"`.
`examplev1alpha1` above is this provider's own `apis/v1alpha1` package (the
`ProviderConfig` types) and stays `v1alpha1` regardless of the managed
type's API version.

### 6. Register the new controller in `internal/controller/example.go`

```diff
 import (
 	"github.com/crossplane/crossplane-runtime/v2/pkg/controller"
 	ctrl "sigs.k8s.io/controller-runtime"

 	"github.com/crossplane/provider-example/internal/controller/config"
-	"github.com/crossplane/provider-example/internal/controller/mytype"
+	"github.com/crossplane/provider-example/internal/controller/managedconfigmap"
 )

 // SetupGated creates all Example controllers with safe-start support and adds them to
 // the supplied manager.
 func SetupGated(mgr ctrl.Manager, o controller.Options) error {
 	for _, setup := range []func(ctrl.Manager, controller.Options) error{
 		config.Setup,
-		mytype.SetupGated,
+		managedconfigmap.SetupGated,
 	} {
 		if err := setup(mgr, o); err != nil {
 			return err
 		}
 	}
 	return nil
 }
```

> `internal/controller/config` above is the built-in `ProviderConfig`
> controller — unrelated to the `config` API *group* picked in step 4. They
> only share a name because of this example's naming, not because one
> depends on the other.

### 7. Implement a real ManagedConfigMap

The scaffolded controller doesn't talk to anything real. Replace it with an
implementation that manages one `corev1.ConfigMap` per `ManagedConfigMap`,
in the resource's own namespace, named by its external-name annotation.

**This implementation is real, but deliberately minimal — it doesn't set an
owner reference or otherwise record that it created the ConfigMap.** In
practice that means: a pre-existing, unrelated ConfigMap with the same name
in the same namespace is silently adopted on the first `Observe` (its data
gets overwritten on the next `Update`), and deleting the `ManagedConfigMap`
later deletes that ConfigMap even though this provider never created it. A
production implementation should check for and refuse to adopt resources it
didn't create — e.g. by tracking a provider-owned label or annotation, or an
owner reference — before treating a `Get` hit as "this is mine."

The diffs below are shown for the default `apiversion=v1alpha1`. If you
generated `v1beta1` in step 4, the file paths change accordingly and the
import alias from step 5 is `configv1beta1`. More importantly, **every**
`v1alpha1.` type qualifier below becomes `v1beta1.` — not just in function
signatures, but also the test file's `apis/config/v1alpha1` import and its
`notYetCreated := &v1alpha1.ManagedConfigMap{}` line. Copying these diffs
verbatim on a `v1beta1` type compiles with an "undefined: v1alpha1" error;
search the pasted code for `v1alpha1` and replace every occurrence.

**`apis/config/v1alpha1/managedconfigmap_types.go`** — replace the
placeholder fields with the ConfigMap's data:

```diff
 // ManagedConfigMapParameters are the configurable fields of a ManagedConfigMap.
 type ManagedConfigMapParameters struct {
-	ConfigurableField string `json:"configurableField"`
+	// Data are the key/value pairs to set on the managed ConfigMap.
+	Data map[string]string `json:"data"`
 }

 // ManagedConfigMapObservation are the observable fields of a ManagedConfigMap.
-type ManagedConfigMapObservation struct {
-	ConfigurableField string `json:"configurableField"`
-	ObservableField   string `json:"observableField,omitempty"`
-}
+type ManagedConfigMapObservation struct{}
```

**`internal/controller/managedconfigmap/managedconfigmap.go`** — the
imports and error strings:

```diff
 import (
 	"context"
-	"fmt"
+	"maps"

 	"github.com/crossplane/crossplane-runtime/v2/pkg/controller"
 	"github.com/crossplane/crossplane-runtime/v2/pkg/errors"
 	"github.com/crossplane/crossplane-runtime/v2/pkg/event"
 	"github.com/crossplane/crossplane-runtime/v2/pkg/feature"
 	"github.com/crossplane/crossplane-runtime/v2/pkg/meta"
 	"github.com/crossplane/crossplane-runtime/v2/pkg/ratelimiter"
 	"github.com/crossplane/crossplane-runtime/v2/pkg/reconciler/managed"
 	"github.com/crossplane/crossplane-runtime/v2/pkg/resource"
 	"github.com/crossplane/crossplane-runtime/v2/pkg/statemetrics"
+	corev1 "k8s.io/api/core/v1"
+	kerrors "k8s.io/apimachinery/pkg/api/errors"
+	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
 	"k8s.io/apimachinery/pkg/types"
 	ctrl "sigs.k8s.io/controller-runtime"
 	"sigs.k8s.io/controller-runtime/pkg/client"
```

```diff
 	errNewClient = "cannot create new Service"
+
+	errGetConfigMap    = "cannot get ConfigMap"
+	errCreateConfigMap = "cannot create ConfigMap"
+	errUpdateConfigMap = "cannot update ConfigMap"
+	errDeleteConfigMap = "cannot delete ConfigMap"
 )
```

Slotting `corev1`, `kerrors`, and `metav1` alphabetically into the existing
flat `k8s.io`/`sigs.k8s.io` group, rather than giving them a group of their
own, is the layout `goimports` produces — `goimports` and `gofmt` are the
two formatters `golangci-lint` (step 10) enforces. It's not the *only*
grouping that passes lint (a separate group for them passes too), so treat
this as what running the formatter gives you, not a rule to memorize —
trust the linter's actual output over guessing at import grouping by hand.

`Connect` hands its own `kube` client straight to `external`, alongside the
existing (still-unused-for-this-example) credential-fetching plumbing:

```diff
-	return &external{service: svc}, nil
+	return &external{kube: c.kube, service: svc}, nil
 }

 // An ExternalClient observes, then either creates, updates, or deletes an
 // external resource to ensure it reflects the managed resource's desired state.
 type external struct {
+	// kube is used to manage the ConfigMap this managed resource represents.
+	kube client.Client
+
 	// A 'client' used to connect to the external resource API. In practice this
 	// would be something like an AWS SDK client.
 	service interface{}
 }
```

`Observe`, `Create`, `Update`, and `Delete` become real:

```diff
 func (c *external) Observe(ctx context.Context, cr *v1alpha1.ManagedConfigMap) (managed.ExternalObservation, error) {
-	// If the managed resource is marked for deletion then deleted it.
-	// Because there is no external resource to observe, we return false for
-	// ResourceExists.
-	if meta.WasDeleted(cr) {
+	// Belt-and-braces: nothing to look up without an external name. In
+	// practice this never fires — see the note below this diff.
+	if meta.GetExternalName(cr) == "" {
 		return managed.ExternalObservation{
 			ResourceExists: false,
 		}, nil
 	}

-	// These fmt statements should be removed in the real implementation.
-	fmt.Printf("Observing: %+v", cr)
-
-	// Simulate external resource doesn't exist, and enter to create the flow
-	if meta.GetExternalName(cr) == "" {
+	cm := &corev1.ConfigMap{}
+	err := c.kube.Get(ctx, types.NamespacedName{Name: meta.GetExternalName(cr), Namespace: cr.GetNamespace()}, cm)
+	if kerrors.IsNotFound(err) {
 		return managed.ExternalObservation{
 			ResourceExists: false,
 		}, nil
 	}
+	if err != nil {
+		return managed.ExternalObservation{}, errors.Wrap(err, errGetConfigMap)
+	}

-	// Simulate external resource exists and not in sync
-	if cr.Status.AtProvider.ConfigurableField != cr.Spec.ForProvider.ConfigurableField {
-		// This case should trigger an update
-		return managed.ExternalObservation{
-			ResourceExists:   true,
-			ResourceUpToDate: false,
-		}, nil
+	upToDate := maps.Equal(cm.Data, cr.Spec.ForProvider.Data)
+	if upToDate {
+		// Now the resource is in sync and ready to use, so mark it as available.
+		cr.Status.SetConditions(xpv2.Available())
 	}

-	// Now the resource is in sync and ready to use, so mark it as available.
-	cr.Status.SetConditions(xpv2.Available())
 	return managed.ExternalObservation{
-		// Return false when the external resource does not exist. This lets
-		// the managed resource reconciler know that it needs to call Create to
-		// (re)create the resource, or that it has successfully been deleted.
+		// Both "doesn't exist" cases already returned above, so this is
+		// always true by the time execution reaches here.
 		ResourceExists: true,

 		// Return false when the external resource exists, but it not up to date
 		// with the desired managed resource state. This lets the managed
 		// resource reconciler know that it needs to call Update.
-		ResourceUpToDate: true,
-
-		// Return any details that may be required to connect to the external
-		// resource. These will be stored as the connection secret.
-		ConnectionDetails: managed.ConnectionDetails{},
+		ResourceUpToDate: upToDate,
 	}, nil
 }

 func (c *external) Create(ctx context.Context, cr *v1alpha1.ManagedConfigMap) (managed.ExternalCreation, error) {
 	cr.Status.SetConditions(xpv2.Creating())

-	fmt.Printf("Creating: %+v", cr)
+	cm := &corev1.ConfigMap{
+		ObjectMeta: metav1.ObjectMeta{
+			Name:      meta.GetExternalName(cr),
+			Namespace: cr.GetNamespace(),
+		},
+		Data: cr.Spec.ForProvider.Data,
+	}

-	// Copy ConfigurableField to AtProvider and complete the creation.
-	cr.Status.AtProvider.ConfigurableField = cr.Spec.ForProvider.ConfigurableField
-	meta.SetExternalName(cr, "my-external-name")
+	if err := c.kube.Create(ctx, cm); err != nil {
+		return managed.ExternalCreation{}, errors.Wrap(err, errCreateConfigMap)
+	}

-	return managed.ExternalCreation{
-		// Optionally return any details that may be required to connect to the
-		// external resource. These will be stored as the connection secret.
-		ConnectionDetails: managed.ConnectionDetails{},
-	}, nil
+	return managed.ExternalCreation{}, nil
 }

 func (c *external) Update(ctx context.Context, cr *v1alpha1.ManagedConfigMap) (managed.ExternalUpdate, error) {
-	fmt.Printf("Updating: %+v", cr)
+	cm := &corev1.ConfigMap{}
+	if err := c.kube.Get(ctx, types.NamespacedName{Name: meta.GetExternalName(cr), Namespace: cr.GetNamespace()}, cm); err != nil {
+		return managed.ExternalUpdate{}, errors.Wrap(err, errGetConfigMap)
+	}

-	// Copy ConfigurableField to AtProvider and complete the update.
-	cr.Status.AtProvider.ConfigurableField = cr.Spec.ForProvider.ConfigurableField
+	cm.Data = cr.Spec.ForProvider.Data
+	if err := c.kube.Update(ctx, cm); err != nil {
+		return managed.ExternalUpdate{}, errors.Wrap(err, errUpdateConfigMap)
+	}

-	return managed.ExternalUpdate{
-		// Optionally return any details that may be required to connect to the
-		// external resource. These will be stored as the connection secret.
-		ConnectionDetails: managed.ConnectionDetails{},
-	}, nil
+	return managed.ExternalUpdate{}, nil
 }

 func (c *external) Delete(ctx context.Context, cr *v1alpha1.ManagedConfigMap) (managed.ExternalDelete, error) {
 	cr.Status.SetConditions(xpv2.Deleting())

-	fmt.Printf("Deleting: %+v", cr)
+	cm := &corev1.ConfigMap{
+		ObjectMeta: metav1.ObjectMeta{
+			Name:      meta.GetExternalName(cr),
+			Namespace: cr.GetNamespace(),
+		},
+	}

+	if err := c.kube.Delete(ctx, cm); err != nil && !kerrors.IsNotFound(err) {
+		return managed.ExternalDelete{}, errors.Wrap(err, errDeleteConfigMap)
+	}
+
 	return managed.ExternalDelete{}, nil
 }
```

> **The stub's `if meta.WasDeleted(cr) { return ResourceExists: false }`
> early return is deleted, not moved.** In the stub it's harmless — there's
> no backend to clean up either way. With a real backend, keeping it would
> make `Observe` report `ResourceExists: false` for a resource that's
> pending deletion *without `Delete` ever being called*, orphaning the
> ConfigMap. Of everything in this step, getting this one backwards is a
> correctness bug, not a style choice.

With a real `Observe`, `Create()` is reachable, unlike in the stub: the
scaffolded `Observe` decided a resource "didn't exist" purely from whether
its external-name annotation was empty, and the default `NameAsExternalName`
initializer sets that annotation before the very first `Observe` ever runs —
so that branch was dead code, and every resource silently entered through
`Update()` instead. Here, existence is decided by an actual `Get` against
the cluster, so a genuinely new resource really does 404 the first time and
reaches `Create`.

The new `Observe` keeps a lookalike check — `if meta.GetExternalName(cr) ==
"" { return ResourceExists: false }` — at its top, and by the argument just
given, that check is *also* dead code for exactly the same reason. It's kept
anyway, purely so a `Get` is never attempted with an empty name; without it,
that call would fail with a Kubernetes API validation error rather than a
clean `ResourceExists: false`. Unlike the deleted `WasDeleted` check, getting
this one "wrong" (i.e. deleting it) is not a bug — the `Get`'s own error path
already handles it correctly via `errGetConfigMap` — so treat it as optional
belt-and-braces, not as load-bearing logic.

One more gap worth knowing about: `Observe` only calls
`cr.Status.SetConditions(xpv2.Available())` when `upToDate` is true — it
never explicitly does anything when the ConfigMap has drifted. That's
harmless in the sense that `ResourceUpToDate: false` still makes the
reconciler call `Update`, but the `Ready` condition set by a *previous*,
in-sync `Observe` is left in place until the drift is corrected, so a reader
watching `status.conditions` can see `Ready: True` for a resource that's
momentarily out of sync.

**`internal/controller/managedconfigmap/managedconfigmap_test.go`** — the
scaffolded test builds `external{service: tc.fields.service}` with a keyed
struct literal, so it still compiles once `external` gains a `kube` field
too; but it wouldn't exercise anything you just wrote. Update it to build
`kube` instead, with one case using `test.MockClient`:

```diff
 import (
 	"context"
 	"testing"

 	"github.com/google/go-cmp/cmp"

+	"github.com/crossplane/crossplane-runtime/v2/pkg/meta"
 	"github.com/crossplane/crossplane-runtime/v2/pkg/reconciler/managed"
 	"github.com/crossplane/crossplane-runtime/v2/pkg/test"
+	kerrors "k8s.io/apimachinery/pkg/api/errors"
+	"k8s.io/apimachinery/pkg/runtime/schema"
+	"sigs.k8s.io/controller-runtime/pkg/client"

 	v1alpha1 "github.com/crossplane/provider-example/apis/config/v1alpha1"
 )
```

```diff
 func TestObserve(t *testing.T) {
 	type fields struct {
-		service interface{}
+		kube client.Client
 	}

 	type args struct {
```

```diff
 		err error
 	}

+	notYetCreated := &v1alpha1.ManagedConfigMap{}
+	meta.SetExternalName(notYetCreated, "cool-configmap")
+
 	cases := map[string]struct {
 		reason string
 		fields fields
 		args   args
 		want   want
 	}{
-		// TODO: Add test cases.
+		"DoesNotExist": {
+			reason: "Observe should report ResourceExists: false when the ConfigMap does not exist yet.",
+			fields: fields{
+				kube: &test.MockClient{
+					MockGet: test.NewMockGetFn(kerrors.NewNotFound(schema.GroupResource{}, "cool-configmap")),
+				},
+			},
+			args: args{
+				cr: notYetCreated,
+			},
+			want: want{
+				o: managed.ExternalObservation{ResourceExists: false},
+			},
+		},
+		// TODO: Add more test cases.
 	}

 	for name, tc := range cases {
 		t.Run(name, func(t *testing.T) {
-			e := external{service: tc.fields.service}
+			e := external{kube: tc.fields.kube}
 			got, err := e.Observe(tc.args.ctx, tc.args.cr)
```

### 8. Add an example manifest

Step 3 deletes `examples/sample/`. Add `examples/config/managedconfigmap.yaml`:

```yaml
apiVersion: config.example.crossplane.io/v1alpha1
kind: ManagedConfigMap
metadata:
  name: example
  namespace: default
spec:
  forProvider:
    data:
      example: test
  providerConfigRef:
    name: example
    kind: ProviderConfig
```

`providerConfigRef.kind` is either `ProviderConfig` (namespaced, shown above)
or `ClusterProviderConfig`; both are valid because the generated
`ManagedConfigMap` type embeds `xpv2.ManagedResourceSpec`, same as `MyType`.

### 9. Format your edits

Hand-editing an import block can misalign it in a way `gofmt` — and
therefore `make reviewable`'s lint check — rejects:

```shell
gofmt -w apis/example.go internal/controller/example.go \
  apis/config/v1alpha1/managedconfigmap_types.go \
  internal/controller/managedconfigmap/managedconfigmap.go \
  internal/controller/managedconfigmap/managedconfigmap_test.go
```

### 10. Verify

```shell
make reviewable
```

This is the compile-and-lint gate for the branch: it regenerates
`zz_generated.*.go` and `package/crds/**`, runs `golangci-lint`, and runs the
unit tests.

This example needs no extra RBAC to run. Crossplane's RBAC manager already
grants every provider pod full access to core `configmaps` (along with
`secrets`, `events`, and `leases`) via a fixed set of rules appended to the
"system" `ClusterRole` bound to the provider's own `ServiceAccount` —
see `rulesSystemExtra` in
[`internal/controller/rbac/provider/roles/roles.go`](https://github.com/crossplane/crossplane/blob/main/internal/controller/rbac/provider/roles/roles.go)
in the core Crossplane repository. If a future example needs RBAC for some
other core or third-party resource, note that `package/crossplane.yaml`'s
`meta.pkg.crossplane.io/v1alpha1` `Provider` kind — from
`github.com/crossplane/crossplane/apis/v2`, what this template actually
depends on — has **no** `spec.controller.permissionRequests` field; its
`ProviderSpec` is just `MetaSpec` inlined, nothing else. That field only
exists on the `Provider` kind from Crossplane's legacy, pre-v2
`github.com/crossplane/crossplane` module (same group name, different Go
module entirely). Adding it here parses as valid YAML but is silently
dropped when the package is built, so a reader who copies it over by
name-matching the key would believe they'd granted RBAC they hadn't.

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
