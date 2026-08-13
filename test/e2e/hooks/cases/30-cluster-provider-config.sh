#!/usr/bin/env bash
# Two things no other case touches:
#
#   1. Connect()'s ClusterProviderConfig branch. Every other test resource
#      resolves credentials through the namespaced ProviderConfig.
#   2. Regression cover for "block deletion of in-use ClusterProviderConfigs".
#      Managed resources here are namespaced, so their usage is recorded as a
#      namespaced ProviderConfigUsage even when the config is cluster scoped.
#      When that wiring is wrong the config's reconciler counts zero users and
#      drops its finalizer, letting an in-use config be deleted out from under
#      resources that still need it.
#
# Uses a dedicated ClusterProviderConfig: a deletionTimestamp cannot be undone,
# so this must never be run against the shared "example" config.
set -euo pipefail

NAMESPACE="default"
CPC="e2e-cpc-inuse"
RESOURCE="e2e-cpc-user"

cleanup() {
  rc=$?
  ${KUBECTL} delete mytype "${RESOURCE}" -n "${NAMESPACE}" --ignore-not-found >/dev/null 2>&1 || true
  ${KUBECTL} delete clusterproviderconfig "${CPC}" --ignore-not-found --wait=false >/dev/null 2>&1 || true
  exit $rc
}
trap cleanup EXIT

cat <<EOF | ${KUBECTL} apply -f -
apiVersion: template.crossplane.io/v1alpha1
kind: ClusterProviderConfig
metadata:
  name: ${CPC}
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: ${NAMESPACE}
      name: example-provider-secret
      key: credentials
---
apiVersion: sample.template.crossplane.io/v1alpha1
kind: MyType
metadata:
  name: ${RESOURCE}
  namespace: ${NAMESPACE}
spec:
  forProvider:
    configurableField: "cluster-scoped-creds"
  providerConfigRef:
    name: ${CPC}
    kind: ClusterProviderConfig
EOF

# 1. Credentials resolve through the cluster scoped config.
${KUBECTL} wait mytype "${RESOURCE}" -n "${NAMESPACE}" --for=condition=Synced=True --timeout=90s
${KUBECTL} wait mytype "${RESOURCE}" -n "${NAMESPACE}" --for=condition=Ready=True --timeout=90s
echo "PASS: MyType reconciled using a ClusterProviderConfig"

# 2. Usage is recorded as a namespaced ProviderConfigUsage that names the
#    cluster scoped kind. This is the record the fix depends on.
USAGE=$(${KUBECTL} get providerconfigusage -n "${NAMESPACE}" \
  -o jsonpath="{.items[?(@.providerConfigRef.name=='${CPC}')].providerConfigRef.kind}")
if [[ "${USAGE}" != "ClusterProviderConfig" ]]; then
  echo "FAIL: expected a namespaced ProviderConfigUsage naming ClusterProviderConfig, got '${USAGE}'"
  exit 1
fi
echo "PASS: usage recorded as namespaced ProviderConfigUsage (kind=ClusterProviderConfig)"

FINALIZERS=$(${KUBECTL} get clusterproviderconfig "${CPC}" -o jsonpath='{.metadata.finalizers}')
if [[ "${FINALIZERS}" != *"in-use.crossplane.io"* ]]; then
  echo "FAIL: ClusterProviderConfig is missing the in-use finalizer: ${FINALIZERS}"
  exit 1
fi
echo "PASS: in-use finalizer present on the ClusterProviderConfig"

# 3. Deleting it while in use must not remove it.
${KUBECTL} delete clusterproviderconfig "${CPC}" --wait=false
sleep 10
if ! ${KUBECTL} get clusterproviderconfig "${CPC}" >/dev/null 2>&1; then
  echo "FAIL: in-use ClusterProviderConfig was deleted while a MyType still referenced it"
  exit 1
fi
DELETING=$(${KUBECTL} get clusterproviderconfig "${CPC}" -o jsonpath='{.metadata.deletionTimestamp}')
if [[ -z "${DELETING}" ]]; then
  echo "FAIL: expected a deletionTimestamp on the ClusterProviderConfig"
  exit 1
fi
echo "PASS: deletion blocked while in use (deletionTimestamp=${DELETING})"

# 4. Once the last user goes away the finalizer is released and it completes.
${KUBECTL} delete mytype "${RESOURCE}" -n "${NAMESPACE}" --ignore-not-found
${KUBECTL} wait --for=delete clusterproviderconfig/"${CPC}" --timeout=120s
echo "PASS: deletion completed once the last user was removed"
