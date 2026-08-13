#!/usr/bin/env bash
# The crossplane.io/paused annotation must actually stop reconciliation --
# not merely report that it did. Uses its own resource so it does not entangle
# with the import step, which pauses the lifecycle resource itself.
set -euo pipefail

NAMESPACE="default"
RESOURCE="e2e-pause"

trap 'rc=$?; ${KUBECTL} delete mytype "${RESOURCE}" -n "${NAMESPACE}" --ignore-not-found >/dev/null 2>&1 || true; exit $rc' EXIT

cat <<EOF | ${KUBECTL} apply -f -
apiVersion: sample.template.crossplane.io/v1alpha1
kind: MyType
metadata:
  name: ${RESOURCE}
  namespace: ${NAMESPACE}
spec:
  forProvider:
    configurableField: "before-pause"
  providerConfigRef:
    name: example
    kind: ProviderConfig
EOF

${KUBECTL} wait mytype "${RESOURCE}" -n "${NAMESPACE}" \
  --for=jsonpath='{.status.atProvider.configurableField}'=before-pause --timeout=90s
${KUBECTL} wait mytype "${RESOURCE}" -n "${NAMESPACE}" --for=condition=Ready=True --timeout=60s
echo "PASS: resource is Ready before pausing"

${KUBECTL} annotate mytype "${RESOURCE}" -n "${NAMESPACE}" crossplane.io/paused=true --overwrite

# kubectl wait --for=condition cannot match on reason, so match the reason directly.
${KUBECTL} wait mytype "${RESOURCE}" -n "${NAMESPACE}" \
  --for=jsonpath='{.status.conditions[?(@.type=="Synced")].reason}'=ReconcilePaused --timeout=60s
echo "PASS: Synced reports ReconcilePaused"

# Ready is sticky: it keeps its last value rather than being unset on pause.
# This is exactly why asserting Ready alone cannot detect a stalled provider.
READY=$(${KUBECTL} get mytype "${RESOURCE}" -n "${NAMESPACE}" \
  -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
if [[ "${READY}" != "True" ]]; then
  echo "FAIL: expected Ready to remain True while paused, got ${READY}"
  exit 1
fi
echo "PASS: Ready stayed True while paused (conditions are sticky)"

# A paused resource must ignore spec changes entirely.
${KUBECTL} patch mytype "${RESOURCE}" -n "${NAMESPACE}" --type=merge \
  -p '{"spec":{"forProvider":{"configurableField":"changed-while-paused"}}}'
sleep 15
OBSERVED=$(${KUBECTL} get mytype "${RESOURCE}" -n "${NAMESPACE}" \
  -o jsonpath='{.status.atProvider.configurableField}')
if [[ "${OBSERVED}" != "before-pause" ]]; then
  echo "FAIL: paused resource reconciled a spec change (status is ${OBSERVED})"
  exit 1
fi
echo "PASS: spec change was ignored while paused"

${KUBECTL} annotate mytype "${RESOURCE}" -n "${NAMESPACE}" crossplane.io/paused- --overwrite

${KUBECTL} wait mytype "${RESOURCE}" -n "${NAMESPACE}" \
  --for=jsonpath='{.status.atProvider.configurableField}'=changed-while-paused --timeout=90s
${KUBECTL} wait mytype "${RESOURCE}" -n "${NAMESPACE}" --for=condition=Synced=True --timeout=60s
echo "PASS: reconciliation resumed and caught up after unpause"
