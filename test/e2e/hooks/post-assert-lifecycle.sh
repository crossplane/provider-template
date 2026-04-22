#!/usr/bin/env bash
set -euo pipefail

RESOURCE_NAME="e2e-lifecycle-test"
NAMESPACE="default"

# Verify status and external-name are set
CONFIGURED=$(${KUBECTL} get mytype "${RESOURCE_NAME}" -n "${NAMESPACE}" \
  -o jsonpath='{.status.atProvider.configurableField}')

if [[ -z "${CONFIGURED}" ]]; then
  echo "FAIL: status.atProvider.configurableField is empty"
  exit 1
fi
echo "PASS: status.atProvider.configurableField = ${CONFIGURED}"

EXTERNAL_NAME=$(${KUBECTL} get mytype "${RESOURCE_NAME}" -n "${NAMESPACE}" \
  -o jsonpath='{.metadata.annotations.crossplane\.io/external-name}')

if [[ -z "${EXTERNAL_NAME}" ]]; then
  echo "FAIL: external-name annotation is not set"
  exit 1
fi
echo "PASS: external-name = ${EXTERNAL_NAME}"

# ---- Error case: MyType with non-existent ProviderConfig ----
echo ""
echo "Testing error case: MyType with missing ProviderConfig..."

ERROR_RESOURCE="e2e-error-no-config"

# Ensure cleanup on any exit, preserving the original exit code
trap 'rc=$?; ${KUBECTL} delete mytype "${ERROR_RESOURCE}" -n "${NAMESPACE}" --ignore-not-found || true; exit $rc' EXIT

cat <<EOF | ${KUBECTL} apply -f -
apiVersion: sample.template.crossplane.io/v1alpha1
kind: MyType
metadata:
  name: ${ERROR_RESOURCE}
  namespace: ${NAMESPACE}
spec:
  forProvider:
    configurableField: "test"
  providerConfigRef:
    name: nonexistent-config
    kind: ProviderConfig
EOF

# Wait for Synced=False instead of a fixed sleep
echo "Waiting for Synced=False on error resource..."
${KUBECTL} wait mytype "${ERROR_RESOURCE}" -n "${NAMESPACE}" \
  --for=jsonpath='{.status.conditions[?(@.type=="Synced")].status}'=False \
  --timeout=60s

echo "PASS: Synced=False as expected"

# Verify the error message references the missing ProviderConfig
MESSAGE=$(${KUBECTL} get mytype "${ERROR_RESOURCE}" -n "${NAMESPACE}" \
  -o jsonpath='{.status.conditions[?(@.type=="Synced")].message}')

if [[ "${MESSAGE}" != *"nonexistent-config"* ]]; then
  echo "FAIL: error message does not reference missing ProviderConfig: ${MESSAGE}"
  exit 1
fi
echo "PASS: error message indicates config issue: ${MESSAGE}"
