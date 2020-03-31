# provider-template

`provider-template` is a minimal [Crossplane](https://crossplane.io/) Provider
that is meant to be used as a template for implementing new Providers. It comes
with the following features that are meant to be refactored:

- A `Provider` resource type that only points to a credentials `Secret`.
- A `MyType` resource type that serves as an example managed resource.
- A managed resource controller that reconciles `MyType` objects and simply
  prints their configuration in its `Observe` method.

## Install

If you would like to install `provider-template` without modifications create
the following `ClusterStackInstall` in a Kubernetes cluster where Crossplane is
installed:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: template
---
apiVersion: stacks.crossplane.io/v1alpha1
kind: ClusterStackInstall
metadata:
  name: provider-template
  namespace: template
spec:
  package: "crossplanebook/provider-template:latest"
```

## Developing

Run against a Kubernetes cluster:
```
make run
```

Install `latest` into Kubernetes cluster where Crossplane is installed:
```
make install
```

Install local build into [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/)
cluster where Crossplane is installed:
```
make install-local
```

Build, push, and install:
```
make all
```

Build image:
```
make image
```

Push image:
```
make push
```

Build binary:
```
make build
```

Build stack package:
```
make build-stack-package
```