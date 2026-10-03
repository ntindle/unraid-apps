#!/usr/bin/env bash
# Checks that the template, the profile and the icon are well formed and that the template
# still describes the container contract of the fork image.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
template="${repo_root}/templates/cliproxyapi.xml"
profile="${repo_root}/ca_profile.xml"
icon="${repo_root}/images/cliproxyapi.png"

for tool in xmllint file; do
  command -v "${tool}" >/dev/null || {
    echo "${tool} is required" >&2
    exit 1
  }
done

xmllint --noout "${template}" "${profile}"

[[ -s "${icon}" ]] || {
  echo "missing images/cliproxyapi.png" >&2
  exit 1
}
icon_description="$(file -b "${icon}")"
[[ "${icon_description}" == "PNG image data, 512 x 512,"* ]] || {
  echo "images/cliproxyapi.png must be a 512x512 PNG, got: ${icon_description}" >&2
  exit 1
}

value() {
  xmllint --xpath "string($1)" "${template}"
}

expect() {
  local label="$1" actual="$2" expected="$3"
  if [[ "${actual}" != "${expected}" ]]; then
    echo "${label}: expected '${expected}', got '${actual}'" >&2
    exit 1
  fi
}

expect "repository" "$(value /Container/Repository)" "ghcr.io/ntindle/cliproxyapi:latest"
expect "network" "$(value /Container/Network)" "bridge"
expect "privileged" "$(value /Container/Privileged)" "false"
expect "web ui" "$(value /Container/WebUI)" "http://[IP]:[PORT:8317]/management.html"
expect "template url" "$(value /Container/TemplateURL)" "https://raw.githubusercontent.com/ntindle/cliproxyapi-unraid/main/templates/cliproxyapi.xml"
expect "icon url" "$(value /Container/Icon)" "https://raw.githubusercontent.com/ntindle/cliproxyapi-unraid/main/images/cliproxyapi.png"
expect "support url" "$(value /Container/Support)" "https://github.com/ntindle/cliproxyapi-unraid/issues"
expect "profile forum" "$(xmllint --xpath 'string(/CommunityApplications/Forum)' "${profile}")" "$(value /Container/Support)"
expect "extra params" "$(value /Container/ExtraParams)" "--restart=unless-stopped --log-driver json-file --log-opt max-size=10m --log-opt max-file=3"

expect "port target" "$(value '/Container/Config[@Name="API and Web UI Port"]/@Target')" "8317"
expect "port mode" "$(value '/Container/Config[@Name="API and Web UI Port"]/@Mode')" "tcp"
expect "data target" "$(value '/Container/Config[@Name="App Data"]/@Target')" "/data"
expect "data default" "$(value '/Container/Config[@Name="App Data"]/@Default')" "/mnt/user/appdata/cliproxyapi"
expect "data mode" "$(value '/Container/Config[@Name="App Data"]/@Mode')" "rw"
expect "password target" "$(value '/Container/Config[@Name="Management Password"]/@Target')" "MANAGEMENT_PASSWORD"
expect "password required" "$(value '/Container/Config[@Name="Management Password"]/@Required')" "true"
expect "password masked" "$(value '/Container/Config[@Name="Management Password"]/@Mask')" "true"
expect "password value" "$(value '/Container/Config[@Name="Management Password"]')" ""
expect "keys target" "$(value '/Container/Config[@Name="Client API Keys"]/@Target')" "CLIPROXY_API_KEYS"
expect "keys masked" "$(value '/Container/Config[@Name="Client API Keys"]/@Mask')" "true"
expect "keys value" "$(value '/Container/Config[@Name="Client API Keys"]')" ""
expect "health target" "$(value '/Container/Config[@Name="Health Check"]/@Target')" "CLIPROXY_HEALTHCHECK"
expect "health value" "$(value '/Container/Config[@Name="Health Check"]')" "on"

[[ -n "$(xmllint --xpath 'string(/CommunityApplications/Profile)' "${profile}")" ]] || {
  echo "ca_profile.xml has no profile text" >&2
  exit 1
}

# The published files must not carry a placeholder, a host-specific address or a secret.
if grep -R -n -E "REPLACE_WITH_|change-me|sk-cpa-[0-9a-f]{8}|\.ts\.net|192\.168\.[0-9]+\.[0-9]{2,3}|BEGIN (RSA|OPENSSH|EC) PRIVATE KEY" \
  "${template}" "${profile}" "${repo_root}/README.md" "${repo_root}/SECURITY.md" \
  "${repo_root}/THIRD_PARTY_NOTICES.md" "${repo_root}/.github"; then
  echo "published files contain a placeholder, a host-specific address or a secret-like value" >&2
  exit 1
fi

echo "CLIProxyAPI Unraid template validation passed"
