#!/usr/bin/env bash
set -euo pipefail

RESOURCE_NAME="e2e-lifecycle-test"
NAMESPACE="default"

# Fetch all needed fields
READY=$(${KUBECTL} get mytype "${RESOURCE_NAME}" -n "${NAMESPACE}" \
  -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
SPEC_VALUE=$(${KUBECTL} get mytype "${RESOURCE_NAME}" -n "${NAMESPACE}" \
  -o jsonpath='{.spec.forProvider.configurableField}')
STATUS_VALUE=$(${KUBECTL} get mytype "${RESOURCE_NAME}" -n "${NAMESPACE}" \
  -o jsonpath='{.status.atProvider.configurableField}')

if [[ "${READY}" != "True" ]]; then
  echo "FAIL: resource is not Ready before deletion (status: ${READY})"
  exit 1
fi
echo "PASS: resource is Ready before deletion"

if [[ "${SPEC_VALUE}" != "${STATUS_VALUE}" ]]; then
  echo "FAIL: spec (${SPEC_VALUE}) != status (${STATUS_VALUE}) - update not propagated"
  exit 1
fi
echo "PASS: spec and status are in sync (${SPEC_VALUE})"
