#!/usr/bin/env bash

# Copyright 2025 The Crossplane Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Please set ProviderNameLower & ProviderNameUpper environment variables before running this script.
# See: https://github.com/crossplane/terrajet/blob/main/docs/generating-a-provider.md
set -euo pipefail

ProviderNameUpper=${PROVIDER}
ProviderNameLower=$(echo "${PROVIDER}" | tr "[:upper:]" "[:lower:]")
DOMAIN="${DOMAIN:-crossplane.io}"

git rm -r apis/sample
git rm -r internal/controller/mytype
git rm -r examples/sample

REPLACE_FILES='./* ./.github ./.golangci.yml :!build/** :!go.* :!hack/** :!PROVIDER_CHECKLIST.md'
# shellcheck disable=SC2086
git grep -l 'template' -- ${REPLACE_FILES} | xargs sed -i.bak "s/template/${ProviderNameLower}/g"
# shellcheck disable=SC2086
git grep -l 'Template' -- ${REPLACE_FILES} | xargs sed -i.bak "s/Template/${ProviderNameUpper}/g"
# We need to be careful while replacing "template" keyword in go.mod as it could tamper
# some imported packages under require section.
sed -i.bak "s/provider-template/provider-${ProviderNameLower}/g" go.mod

# Retarget the API group domain. Match the provider's whole group string, not
# the bare domain: meta.crossplane.io and crossplane.io/external-name are
# Crossplane's own.
if [ "${DOMAIN}" != "crossplane.io" ]; then
	# shellcheck disable=SC2086
	group_files=$(git grep -l "${ProviderNameLower}\.crossplane\.io" -- ${REPLACE_FILES} || true)
	if [ -n "${group_files}" ]; then
		echo "${group_files}" |
			xargs sed -i.bak "s/${ProviderNameLower}\.crossplane\.io/${ProviderNameLower}.${DOMAIN}/g"
	fi
fi

# Clean up the .bak files created by sed
git clean -fd

git mv "apis/template.go" "apis/${ProviderNameLower}.go"
git mv "internal/controller/register.go" "internal/controller/${ProviderNameLower}.go"
git mv "cluster/images/provider-template" "cluster/images/provider-${ProviderNameLower}"

cat <<EOF

Your API groups are now ${ProviderNameLower}.${DOMAIN} (ProviderConfig) and
<group>.${ProviderNameLower}.${DOMAIN} (your types). provider.addtype reads that
suffix back out of apis/v1alpha1/register.go, so it needs no domain of its own.

Next steps (the tree does not compile yet):

  1. Register your new type's scheme in apis/${ProviderNameLower}.go
     (replace the apis/sample/v1alpha1 import and its AddToSchemes entry).
  2. Register your new controller in internal/controller/${ProviderNameLower}.go
     (replace the internal/controller/mytype import and its SetupGated entry).
     Run: make provider.addtype provider=${ProviderNameUpper} group=<group> kind=<kind>
     first if you haven't added a type yet.
  3. Add an example manifest under examples/<group>/ (examples/sample was removed).
  4. Run: make generate && go build ./... && go test ./...

See README.md for the exact edits.
EOF
