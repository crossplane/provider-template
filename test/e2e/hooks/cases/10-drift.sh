#!/usr/bin/env bash
# Drift correction: the controller must repair external state that no longer
# matches the spec, without anyone touching the spec. This is the core
# Crossplane promise, and Observe() -> Update() is the loop that delivers it.
set -euo pipefail

NAMESPACE="default"
RESOURCE="e2e-drift"

trap 'rc=$?; ${KUBECTL} delete mytype "${RESOURCE}" -n "${NAMESPACE}" --ignore-not-found >/dev/null 2>&1 || true; exit $rc' EXIT

cat <<EOF | ${KUBECTL} apply -f -
apiVersion: sample.template.crossplane.io/v1alpha1
kind: MyType
metadata:
  name: ${RESOURCE}
  namespace: ${NAMESPACE}
spec:
  forProvider:
    configurableField: "drift-value"
  providerConfigRef:
    name: example
    kind: ProviderConfig
EOF

${KUBECTL} wait mytype "${RESOURCE}" -n "${NAMESPACE}" \
  --for=jsonpath='{.status.atProvider.configurableField}'=drift-value --timeout=90s
echo "PASS: resource reached desired state"

# Simulate drift in the external system by clearing what the provider observed.
${KUBECTL} patch mytype "${RESOURCE}" -n "${NAMESPACE}" --subresource=status --type=merge \
  -p '{"status":{"atProvider":{"configurableField":"drifted"}}}'
echo "      injected drift: status.atProvider.configurableField = drifted"

# The spec was untouched, so this is a status-only change and raises no watch
# event the controller acts on -- recovery waits for the poll interval
# (--poll, default 1m). Hence the generous timeout.
${KUBECTL} wait mytype "${RESOURCE}" -n "${NAMESPACE}" \
  --for=jsonpath='{.status.atProvider.configurableField}'=drift-value --timeout=150s
echo "PASS: controller repaired the drift without a spec change"

${KUBECTL} wait mytype "${RESOURCE}" -n "${NAMESPACE}" --for=condition=Synced=True --timeout=60s
${KUBECTL} wait mytype "${RESOURCE}" -n "${NAMESPACE}" --for=condition=Ready=True --timeout=60s
echo "PASS: Synced=True and Ready=True after repair"
