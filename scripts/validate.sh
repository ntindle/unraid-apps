#!/usr/bin/env bash
# Checks that every template, the profile and the icons are well formed, that each template
# points at this repository's own files, that each template still describes the container
# contract of its image, and that nothing published carries a secret.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
raw_base="https://raw.githubusercontent.com/ntindle/unraid-apps/main"
support="https://github.com/ntindle/unraid-apps/issues"
profile="${repo_root}/ca_profile.xml"
log_params="--log-driver json-file --log-opt max-size=10m --log-opt max-file=3"

for tool in xmllint file sha256sum; do
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

# Reads from whichever template is current.
value() { xmllint --xpath "string($1)" "${template}"; }

xmllint --noout "${profile}"
profile_text="$(xmllint --xpath 'string(/CommunityApplications/Profile)' "${profile}")"
[[ -n "${profile_text//[[:space:]]/}" ]] || fail "ca_profile.xml has no profile text"
expect "profile forum" "$(xmllint --xpath 'string(/CommunityApplications/Forum)' "${profile}")" "${support}"

shopt -s nullglob
templates=("${repo_root}"/templates/*.xml)
((${#templates[@]} > 0)) || fail "no templates found"
published=("${repo_root}/templates" "${profile}" "${repo_root}"/*.md "${repo_root}/.github")

for template in "${templates[@]}"; do
  app="$(basename "${template}" .xml)"
  icon="${repo_root}/images/${app}.png"

  xmllint --noout "${template}"
  [[ -n "$(value /Container/Name)" ]] || fail "${app}: no Name"
  [[ -n "$(value /Container/Repository)" ]] || fail "${app}: no Repository"
  [[ -n "$(value /Container/Overview)" ]] || fail "${app}: no Overview"
  expect "${app} privileged" "$(value /Container/Privileged)" "false"
  expect "${app} template url" "$(value /Container/TemplateURL)" "${raw_base}/templates/${app}.xml"
  expect "${app} icon url" "$(value /Container/Icon)" "${raw_base}/images/${app}.png"
  expect "${app} readme url" "$(value /Container/ReadMe)" "${raw_base}/${app}/README.md"
  expect "${app} support url" "$(value /Container/Support)" "${support}"
  [[ -s "${repo_root}/${app}/README.md" ]] || fail "missing ${app}/README.md"
  published+=("${repo_root}/${app}")

  [[ -s "${icon}" ]] || fail "missing images/${app}.png"
  icon_description="$(file -b "${icon}")"
  if [[ ! "${icon_description}" =~ ^PNG\ image\ data,\ ([0-9]+)\ x\ ([0-9]+), ]] \
    || [[ "${BASH_REMATCH[1]}" != "${BASH_REMATCH[2]}" ]]; then
    fail "images/${app}.png must be a square PNG, got: ${icon_description}"
  fi

  # A masked field is a secret, so the published template must leave it empty. Whitespace counts:
  # Unraid would pre-fill the field with it and never prompt for the real value.
  expect "${app} masked fields with a value" \
    "$(xmllint --xpath 'count(/Container/Config[@Mask="true"][string-length(.) > 0])' "${template}")" "0"

  duplicate_targets="$(xmllint --xpath '/Container/Config/@Target' "${template}" 2>/dev/null \
    | grep -o 'Target="[^"]*"' | sort | uniq -d || true)"
  [[ -z "${duplicate_targets}" ]] || fail "${app}: duplicate Config targets: ${duplicate_targets//$'\n'/ }"
done

template="${repo_root}/templates/supermemory.xml"
expect "supermemory repository" "$(value /Container/Repository)" "ghcr.io/ntindle/unraid-apps/supermemory:latest"
expect "supermemory network" "$(value /Container/Network)" "bridge"
expect "supermemory port target" "$(value '/Container/Config[@Name="API Port"]/@Target')" "6767"
expect "supermemory data target" "$(value '/Container/Config[@Name="App Data"]/@Target')" "/data"
expect "supermemory data default" "$(value '/Container/Config[@Name="App Data"]/@Default')" "/mnt/user/appdata/supermemory"
expect "supermemory key target" "$(value '/Container/Config[@Name="LLM API Key"]/@Target')" "OPENAI_API_KEY"
expect "supermemory key masked" "$(value '/Container/Config[@Name="LLM API Key"]/@Mask')" "true"
expect "supermemory guard value" "$(value '/Container/Config[@Name="Host Guard"]')" "on"
expect "supermemory ingest limit target" "$(value '/Container/Config[@Name="Ingest Memory Limit"]/@Target')" "SUPERMEMORY_EMBEDDING_RAM_LIMIT"
expect "supermemory ingest limit value" "$(value '/Container/Config[@Name="Ingest Memory Limit"]')" "4gb"

# The version the template offers must be the one the image defaults to and has pinned.
template_version="$(value '/Container/Config[@Name="Server Version"]')"
image_version="$(sed -n 's/^ENV SUPERMEMORY_VERSION=\([^ ]*\).*/\1/p' "${repo_root}/supermemory/Dockerfile")"
expect "supermemory version" "${template_version}" "${image_version}"
grep -Eq "^${template_version//./\\.} linux-x64 [0-9a-f]{64}\$" "${repo_root}/supermemory/checksums.txt" \
  || fail "supermemory/checksums.txt does not pin ${template_version} linux-x64"

template="${repo_root}/templates/cliproxyapi.xml"
expect "cliproxyapi repository" "$(value /Container/Repository)" "ghcr.io/ntindle/cliproxyapi:latest"
expect "cliproxyapi network" "$(value /Container/Network)" "bridge"
expect "cliproxyapi web ui" "$(value /Container/WebUI)" "http://[IP]:[PORT:8317]/management.html"
expect "cliproxyapi extra params" "$(value /Container/ExtraParams)" "--restart=unless-stopped ${log_params}"
expect "cliproxyapi port target" "$(value '/Container/Config[@Name="API and Web UI Port"]/@Target')" "8317"
expect "cliproxyapi port mode" "$(value '/Container/Config[@Name="API and Web UI Port"]/@Mode')" "tcp"
expect "cliproxyapi data target" "$(value '/Container/Config[@Name="App Data"]/@Target')" "/data"
expect "cliproxyapi data default" "$(value '/Container/Config[@Name="App Data"]/@Default')" "/mnt/user/appdata/cliproxyapi"
expect "cliproxyapi data mode" "$(value '/Container/Config[@Name="App Data"]/@Mode')" "rw"
expect "cliproxyapi password target" "$(value '/Container/Config[@Name="Management Password"]/@Target')" "MANAGEMENT_PASSWORD"
expect "cliproxyapi password required" "$(value '/Container/Config[@Name="Management Password"]/@Required')" "true"
expect "cliproxyapi password masked" "$(value '/Container/Config[@Name="Management Password"]/@Mask')" "true"
expect "cliproxyapi keys target" "$(value '/Container/Config[@Name="Client API Keys"]/@Target')" "CLIPROXY_API_KEYS"
expect "cliproxyapi keys masked" "$(value '/Container/Config[@Name="Client API Keys"]/@Mask')" "true"
expect "cliproxyapi health target" "$(value '/Container/Config[@Name="Health Check"]/@Target')" "CLIPROXY_HEALTHCHECK"
expect "cliproxyapi health value" "$(value '/Container/Config[@Name="Health Check"]')" "on"

template="${repo_root}/templates/executor.xml"
expect "executor repository" "$(value /Container/Repository)" "ghcr.io/usefulsoftwareco/executor-selfhost:latest"
expect "executor network" "$(value /Container/Network)" "bridge"
expect "executor beta" "$(value /Container/Beta)" "true"
expect "executor extra params" "$(value /Container/ExtraParams)" "--restart=unless-stopped --user 99:100 ${log_params}"
expect "executor port target" "$(value '/Container/Config[@Name="Web UI and MCP Port"]/@Target')" "4788"
expect "executor data target" "$(value '/Container/Config[@Name="App Data"]/@Target')" "/data"
expect "executor data default" "$(value '/Container/Config[@Name="App Data"]/@Default')" "/mnt/user/appdata/executor"
expect "executor web base target" "$(value '/Container/Config[@Name="Web Base URL"]/@Target')" "EXECUTOR_WEB_BASE_URL"
expect "executor web base required" "$(value '/Container/Config[@Name="Web Base URL"]/@Required')" "true"
expect "executor local network target" "$(value '/Container/Config[@Name="Allow Local Network"]/@Target')" "EXECUTOR_ALLOW_LOCAL_NETWORK"
expect "executor local network value" "$(value '/Container/Config[@Name="Allow Local Network"]')" "false"
expect "executor stdio target" "$(value '/Container/Config[@Name="Allow Stdio MCP"]/@Target')" "EXECUTOR_ALLOW_STDIO_MCP"
expect "executor stdio value" "$(value '/Container/Config[@Name="Allow Stdio MCP"]')" "false"
expect "executor analytics target" "$(value '/Container/Config[@Name="Disable Anonymous Analytics"]/@Target')" "EXECUTOR_DISABLE_ANALYTICS"
expect "executor analytics value" "$(value '/Container/Config[@Name="Disable Anonymous Analytics"]')" "false"
# The icon is upstream's file, unmodified; THIRD_PARTY_NOTICES.md records where it came from.
expect "executor icon sha256" "$(sha256sum "${repo_root}/images/executor.png" | awk '{print $1}')" \
  "b397f102f789c00365cc7910be4f1b297bef7fcacd6592b7f66f227f3388cfc8"

# The published files must not carry a placeholder, a host-specific address or a secret.
if grep -R -n -I -E "REPLACE_WITH_|YOUR_GITHUB_USERNAME|YOUR_REPO_NAME|change-me|sk-[a-z]+-[0-9a-f]{8}|sm_[A-Za-z0-9]{20}|\.ts\.net|192\.168\.[0-9]+\.[0-9]{2,3}|BEGIN (RSA|OPENSSH|EC) PRIVATE KEY" \
  "${published[@]}"; then
  fail "published files contain a placeholder, a host-specific address or a secret-like value"
fi

echo "validated ${#templates[@]} template(s)"
