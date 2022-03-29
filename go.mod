module github.com/crossplane/provider-template

go 1.16

require (
	github.com/crossplane/crossplane-runtime v0.15.0
	github.com/crossplane/crossplane-tools v0.0.0-20220310165030-1f43fc12793e
	github.com/google/go-cmp v0.5.6
	github.com/pkg/errors v0.9.1
	gopkg.in/alecthomas/kingpin.v2 v2.2.6
	k8s.io/apimachinery v0.23.0
	k8s.io/client-go v0.23.0
	sigs.k8s.io/controller-runtime v0.11.0
	sigs.k8s.io/controller-tools v0.8.0
)

replace github.com/crossplane/crossplane-runtime => github.com/turkenh/crossplane-runtime v0.0.0-20220314141040-6f74175d3c1f
