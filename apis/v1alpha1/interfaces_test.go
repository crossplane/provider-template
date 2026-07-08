/*
Copyright 2026 The Crossplane Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package v1alpha1

import (
	resource "github.com/crossplane/crossplane-runtime/v2/pkg/resource"
)

// interface checks to ensure our types conform to the crossplane-runtime interfaces
var (
	_ resource.ProviderConfig           = &ProviderConfig{}
	_ resource.ProviderConfig           = &ClusterProviderConfig{}
	_ resource.TypedProviderConfigUsage = &ProviderConfigUsage{}
	_ resource.TypedProviderConfigUsage = &ClusterProviderConfigUsage{}
	_ resource.ProviderConfigUsageList  = &ProviderConfigUsageList{}
	_ resource.ProviderConfigUsageList  = &ClusterProviderConfigUsageList{}
)
