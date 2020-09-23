module github.com/crossplanebook/provider-template

go 1.13

require (
	github.com/crossplane/crossplane-runtime v0.9.1-0.20200923111851-e1fc0493b2e8
	github.com/crossplane/crossplane-tools v0.0.0-20200923030414-95b434323cd4
	github.com/go-logr/zapr v0.1.1 // indirect
	github.com/golang/groupcache v0.0.0-20190702054246-869f871628b6 // indirect
	github.com/pkg/errors v0.9.1
	github.com/prometheus/client_golang v1.1.0 // indirect
	gopkg.in/alecthomas/kingpin.v2 v2.2.6
	k8s.io/api v0.18.6
	k8s.io/apimachinery v0.18.6
	sigs.k8s.io/controller-runtime v0.6.2
	sigs.k8s.io/controller-tools v0.2.4
)
