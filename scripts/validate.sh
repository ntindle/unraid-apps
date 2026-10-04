#!/usr/bin/env bash
# Checks that every template, the profile and the icons are well formed, that each template
# points at this repository's own files, and that nothing published carries a secret.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
raw_base="https://raw.githubusercontent.com/ntindle/unraid-apps/main"
support="https://github.com/ntindle/unraid-apps/issues"
profile="${repo_root}/ca_profile.xml"

for tool in xmllint file; do
  command -v "${tool}" >/dev/null || {
    echo "${tool} is required" >&2
    exit 1
  }
done

fail() {
  echo "$*" >&2
  exit 1
}

expect() {
  local label="$1" actual="$2" expected="$3"
  [[ "${actual}" == "${expected}" ]] || fail "${label}: expected '${expected}', got '${actual}'"
}

xmllint --noout "${profile}"
[[ -n "$(xmllint --xpath 'string(/CommunityApplications/Profile)' "${profile}")" ]] \
  || fail "ca_profile.xml has no profile text"
expect "profile forum" "$(xmllint --xpath 'string(/CommunityApplications/Forum)' "${profile}")" "${support}"

shopt -s nullglob
templates=("${repo_root}"/templates/*.xml)
((${#templates[@]} > 0)) || fail "no templates found"

for template in "${templates[@]}"; do
  app="$(basename "${template}" .xml)"
  icon="${repo_root}/images/${app}.png"
  value() { xmllint --xpath "string($1)" "${template}"; }

  xmllint --noout "${template}"
  [[ -n "$(value /Container/Name)" ]] || fail "${app}: no Name"
  [[ -n "$(value /Container/Repository)" ]] || fail "${app}: no Repository"
  [[ -n "$(value /Container/Overview)" ]] || fail "${app}: no Overview"
  expect "${app} privileged" "$(value /Container/Privileged)" "false"
  expect "${app} template url" "$(value /Container/TemplateURL)" "${raw_base}/templates/${app}.xml"
  expect "${app} icon url" "$(value /Container/Icon)" "${raw_base}/images/${app}.png"
  expect "${app} support url" "$(value /Container/Support)" "${support}"

  [[ -s "${icon}" ]] || fail "missing images/${app}.png"
  icon_description="$(file -b "${icon}")"
  [[ "${icon_description}" == "PNG image data, 512 x 512,"* ]] \
    || fail "images/${app}.png must be a 512x512 PNG, got: ${icon_description}"

  # A masked field is a secret, so the published template must leave it empty.
  masked_values="$(xmllint --xpath '/Container/Config[@Mask="true"]/text()' "${template}" 2>/dev/null || true)"
  [[ -z "${masked_values//[[:space:]]/}" ]] || fail "${app}: a masked field has a value"
done

template="${repo_root}/templates/supermemory.xml"
value() { xmllint --xpath "string($1)" "${template}"; }
expect "supermemory repository" "$(value /Container/Repository)" "ghcr.io/ntindle/unraid-apps/supermemory:latest"
expect "supermemory network" "$(value /Container/Network)" "bridge"
expect "supermemory port target" "$(value '/Container/Config[@Name="API Port"]/@Target')" "6767"
expect "supermemory data target" "$(value '/Container/Config[@Name="App Data"]/@Target')" "/data"
expect "supermemory data default" "$(value '/Container/Config[@Name="App Data"]/@Default')" "/mnt/user/appdata/supermemory"
expect "supermemory key target" "$(value '/Container/Config[@Name="LLM API Key"]/@Target')" "OPENAI_API_KEY"
expect "supermemory key masked" "$(value '/Container/Config[@Name="LLM API Key"]/@Mask')" "true"
expect "supermemory guard value" "$(value '/Container/Config[@Name="Host Guard"]')" "on"

# The version the template offers must be the one the image defaults to and has pinned.
template_version="$(value '/Container/Config[@Name="Server Version"]')"
image_version="$(sed -n 's/^ENV SUPERMEMORY_VERSION=\([^ ]*\).*/\1/p' "${repo_root}/supermemory/Dockerfile")"
expect "supermemory version" "${template_version}" "${image_version}"
grep -Eq "^${template_version//./\\.} linux-x64 [0-9a-f]{64}\$" "${repo_root}/supermemory/checksums.txt" \
  || fail "supermemory/checksums.txt does not pin ${template_version} linux-x64"

# The published files must not carry a placeholder, a host-specific address or a secret.
if grep -R -n -I -E "REPLACE_WITH_|change-me|sk-[a-z]+-[0-9a-f]{8}|sm_[A-Za-z0-9]{20}|\.ts\.net|192\.168\.[0-9]+\.[0-9]{2,3}|BEGIN (RSA|OPENSSH|EC) PRIVATE KEY" \
  "${repo_root}/templates" "${profile}" "${repo_root}"/*.md "${repo_root}/supermemory" "${repo_root}/.github"; then
  fail "published files contain a placeholder, a host-specific address or a secret-like value"
fi

echo "validated ${#templates[@]} template(s)"
