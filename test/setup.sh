#!/usr/bin/env bash
set -euo pipefail

echo "Granting provider CRD access for safe-start capability..."

SA_NAME=""
for i in $(seq 1 60); do
  SA_NAME=$(${KUBECTL} get sa -n crossplane-system -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep '^provider-template-' | head -1 || true)
  if [[ -n "${SA_NAME}" ]]; then
    break
  fi
  echo "Waiting for provider service account to be created... (attempt ${i}/60)"
  sleep 2
done

if [[ -z "${SA_NAME}" ]]; then
  echo "FAIL: could not find provider-template service account after 120s"
  exit 1
fi
echo "Found provider service account: ${SA_NAME}"

# Required by safe-start gate: provider needs CRD list/watch access
cat <<EOF | ${KUBECTL} apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: provider-template-crd-access
  labels:
    pkg.crossplane.io/provider: provider-template
rules:
  - apiGroups: ["apiextensions.k8s.io"]
    resources: ["customresourcedefinitions"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: provider-template-crd-access
  labels:
    pkg.crossplane.io/provider: provider-template
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: provider-template-crd-access
subjects:
  - kind: ServiceAccount
    name: ${SA_NAME}
    namespace: crossplane-system
EOF

echo "Waiting for provider to become healthy..."
${KUBECTL} wait provider.pkg provider-template \
  --for=condition=Healthy \
  --timeout=180s

# Resolve project root relative to this script's location
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "Creating ProviderConfig and credentials from examples..."
${KUBECTL} apply -f "${PROJECT_ROOT}/examples/provider/config.yaml"

echo "Setup complete."
