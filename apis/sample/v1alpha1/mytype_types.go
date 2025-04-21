/*
Copyright 2025 The Crossplane Authors.

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
	"reflect"

	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime/schema"

	xpv1 "github.com/crossplane/crossplane-runtime/apis/common/v1"
)

// MyTypeParameters are the configurable fields of a MyType.
type MyTypeParameters struct {
	ConfigurableField string `json:"configurableField"`
}

// MyTypeObservation are the observable fields of a MyType.
type MyTypeObservation struct {
	ConfigurableField string `json:"configurableField"`
	ObservableField   string `json:"observableField,omitempty"`
}

// A MyTypeSpec defines the desired state of a MyType.
type MyTypeSpec struct {
	xpv1.ResourceSpec `json:",inline"`
	ForProvider       MyTypeParameters `json:"forProvider"`
}

// A MyTypeStatus represents the observed state of a MyType.
type MyTypeStatus struct {
	xpv1.ResourceStatus `json:",inline"`
	AtProvider          MyTypeObservation `json:"atProvider,omitempty"`
}

// +kubebuilder:object:root=true

// A MyType is an example API type.
// +kubebuilder:printcolumn:name="READY",type="string",JSONPath=".status.conditions[?(@.type=='Ready')].status"
// +kubebuilder:printcolumn:name="SYNCED",type="string",JSONPath=".status.conditions[?(@.type=='Synced')].status"
// +kubebuilder:printcolumn:name="EXTERNAL-NAME",type="string",JSONPath=".metadata.annotations.crossplane\\.io/external-name"
// +kubebuilder:printcolumn:name="AGE",type="date",JSONPath=".metadata.creationTimestamp"
// +kubebuilder:subresource:status
// +kubebuilder:resource:scope=Cluster,categories={crossplane,managed,template}
type MyType struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   MyTypeSpec   `json:"spec"`
	Status MyTypeStatus `json:"status,omitempty"`
}

// +kubebuilder:object:root=true

// MyTypeList contains a list of MyType
type MyTypeList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []MyType `json:"items"`
}

// MyType type metadata.
var (
	MyTypeKind             = reflect.TypeOf(MyType{}).Name()
	MyTypeGroupKind        = schema.GroupKind{Group: Group, Kind: MyTypeKind}.String()
	MyTypeKindAPIVersion   = MyTypeKind + "." + SchemeGroupVersion.String()
	MyTypeGroupVersionKind = SchemeGroupVersion.WithKind(MyTypeKind)
)

func init() {
	SchemeBuilder.Register(&MyType{}, &MyTypeList{})
}
