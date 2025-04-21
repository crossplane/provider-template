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

git rm -r apis/sample
git rm -r internal/controller/mytype

REPLACE_FILES='./* ./.github :!build/** :!go.* :!hack/**'
# shellcheck disable=SC2086
git grep -l 'template' -- ${REPLACE_FILES} | xargs sed -i.bak "s/template/${ProviderNameLower}/g"
# shellcheck disable=SC2086
git grep -l 'Template' -- ${REPLACE_FILES} | xargs sed -i.bak "s/Template/${ProviderNameUpper}/g"
# We need to be careful while replacing "template" keyword in go.mod as it could tamper
# some imported packages under require section.
sed -i.bak "s/provider-template/provider-${ProviderNameLower}/g" go.mod

# Clean up the .bak files created by sed
git clean -fd

git mv "apis/template.go" "apis/${ProviderNameLower}.go"
git mv "internal/controller/template.go" "internal/controller/${ProviderNameLower}.go"
git mv "cluster/images/provider-template" "cluster/images/provider-${ProviderNameLower}"
