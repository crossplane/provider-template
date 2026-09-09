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

# ---- Update case: change the spec and assert it propagates to status ----
# uptest's own update step is unusable here: it requires the
# uptest.upbound.io/update-parameter annotation to be valid JSON, but v2.2.0
# interpolates that value raw into a double-quoted shell command, so the JSON
# quotes are stripped before kubectl sees them. Drive the update ourselves.
echo ""
echo "Testing update: patching spec.forProvider.configurableField..."

${KUBECTL} patch mytype "${RESOURCE_NAME}" -n "${NAMESPACE}" --type=merge \
  -p '{"spec":{"forProvider":{"configurableField":"updated-value"}}}'

${KUBECTL} wait mytype "${RESOURCE_NAME}" -n "${NAMESPACE}" \
  --for=jsonpath='{.status.atProvider.configurableField}'=updated-value \
  --timeout=60s

echo "PASS: update propagated to status.atProvider.configurableField"

# The resource must still be Synced and Ready after the update.
for cond in Synced Ready; do
  ${KUBECTL} wait mytype "${RESOURCE_NAME}" -n "${NAMESPACE}" \
    --for=condition="${cond}"=True --timeout=60s
  echo "PASS: ${cond}=True after update"
done

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

# ---- Controller behaviours beyond the resource lifecycle ----
# CHAINSAW is exported by uptest.mk, so no Makefile wiring is needed.
PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
BEHAVIOR_DIR="${PROJECT_ROOT}/test/behavior"

echo ""
echo "Running controller behaviour tests from ${BEHAVIOR_DIR}..."
# --quiet keeps per-operation logging out of the terminal; failures, errors and
# the summary are still printed.
#
# --report-path must be absolute. chainsaw runs a hook with its working
# directory set to the generated test directory, so a relative path would write
# the report into uptest's temp dir and it would be lost.
"${CHAINSAW}" test "${BEHAVIOR_DIR}" --parallel 1 --quiet \
  --report-format JUNIT-TEST \
  --report-path "${PROJECT_ROOT}" \
  --report-name junit \
  ${CHAINSAW_ARGS:-}
