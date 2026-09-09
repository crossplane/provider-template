#!/usr/bin/env bash
set -euo pipefail

echo "Waiting for provider to become healthy..."
${KUBECTL} wait provider.pkg provider-template \
  --for=condition=Healthy \
  --timeout=180s

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "Creating ProviderConfig and credentials from examples..."
${KUBECTL} apply -f "${PROJECT_ROOT}/examples/provider/config.yaml"

echo "Setup complete."
