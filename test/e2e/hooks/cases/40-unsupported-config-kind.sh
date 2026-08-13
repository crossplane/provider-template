#!/usr/bin/env bash
# Connect() switches on providerConfigRef.kind and rejects anything that is
# neither ProviderConfig nor ClusterProviderConfig. Nothing validates the kind
# at admission, so this branch is reachable from a plain manifest and a real
# provider forked from this template will hit it via typos.
set -euo pipefail

NAMESPACE="default"
RESOURCE="e2e-bad-config-kind"

trap 'rc=$?; ${KUBECTL} delete mytype "${RESOURCE}" -n "${NAMESPACE}" --ignore-not-found >/dev/null 2>&1 || true; exit $rc' EXIT

cat <<EOF | ${KUBECTL} apply -f -
apiVersion: sample.template.crossplane.io/v1alpha1
kind: MyType
metadata:
  name: ${RESOURCE}
  namespace: ${NAMESPACE}
spec:
  forProvider:
    configurableField: "unsupported-kind"
  providerConfigRef:
    name: example
    kind: NotAProviderConfigKind
EOF

${KUBECTL} wait mytype "${RESOURCE}" -n "${NAMESPACE}" \
  --for=jsonpath='{.status.conditions[?(@.type=="Synced")].status}'=False --timeout=60s
echo "PASS: Synced=False for an unsupported providerConfigRef kind"

MESSAGE=$(${KUBECTL} get mytype "${RESOURCE}" -n "${NAMESPACE}" \
  -o jsonpath='{.status.conditions[?(@.type=="Synced")].message}')
if [[ "${MESSAGE}" != *"unsupported provider config kind"* ]]; then
  echo "FAIL: error does not explain the unsupported kind: ${MESSAGE}"
  exit 1
fi
echo "PASS: error names the problem: ${MESSAGE}"

# The resource must still be deletable even though Connect() can never succeed,
# otherwise a typo would leave an undeletable resource behind.
${KUBECTL} delete mytype "${RESOURCE}" -n "${NAMESPACE}" --timeout=90s
echo "PASS: resource deletes cleanly despite Connect() always failing"
