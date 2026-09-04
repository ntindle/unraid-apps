#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
template="${repo_root}/templates/executor.xml"
profile="${repo_root}/ca_profile.xml"
icon="${repo_root}/images/executor.png"

command -v xmllint >/dev/null || {
  echo "xmllint is required" >&2
  exit 1
}

command -v file >/dev/null || {
  echo "file is required" >&2
  exit 1
}

xmllint --noout "${template}" "${profile}"

[[ -s "${icon}" ]] || {
  echo "missing images/executor.png" >&2
  exit 1
}

icon_description="$(file -b "${icon}")"
[[ "${icon_description}" == "PNG image data, 2048 x 2048, 8-bit/color RGBA,"* ]] || {
  echo "images/executor.png must remain the verified 2048x2048 RGBA upstream PNG" >&2
  exit 1
}

icon_sha="$(sha256sum "${icon}" | awk '{print $1}')"
[[ "${icon_sha}" == "b397f102f789c00365cc7910be4f1b297bef7fcacd6592b7f66f227f3388cfc8" ]]

repository="$(xmllint --xpath 'string(/Container/Repository)' "${template}")"
network="$(xmllint --xpath 'string(/Container/Network)' "${template}")"
privileged="$(xmllint --xpath 'string(/Container/Privileged)' "${template}")"
web_port="$(xmllint --xpath 'string(/Container/Config[@Name="Web UI and MCP Port"]/@Target)' "${template}")"
data_target="$(xmllint --xpath 'string(/Container/Config[@Name="App Data"]/@Target)' "${template}")"
data_default="$(xmllint --xpath 'string(/Container/Config[@Name="App Data"]/@Default)' "${template}")"
web_base_target="$(xmllint --xpath 'string(/Container/Config[@Name="Web Base URL"]/@Target)' "${template}")"
web_base_required="$(xmllint --xpath 'string(/Container/Config[@Name="Web Base URL"]/@Required)' "${template}")"
local_network_target="$(xmllint --xpath 'string(/Container/Config[@Name="Allow Local Network"]/@Target)' "${template}")"
local_network_default="$(xmllint --xpath 'string(/Container/Config[@Name="Allow Local Network"])' "${template}")"
stdio_target="$(xmllint --xpath 'string(/Container/Config[@Name="Allow Stdio MCP"]/@Target)' "${template}")"
stdio_default="$(xmllint --xpath 'string(/Container/Config[@Name="Allow Stdio MCP"])' "${template}")"
analytics_target="$(xmllint --xpath 'string(/Container/Config[@Name="Disable Anonymous Analytics"]/@Target)' "${template}")"
analytics_default="$(xmllint --xpath 'string(/Container/Config[@Name="Disable Anonymous Analytics"])' "${template}")"
profile_text="$(xmllint --xpath 'string(/CommunityApplications/Profile)' "${profile}")"
template_url="$(xmllint --xpath 'string(/Container/TemplateURL)' "${template}")"
support_url="$(xmllint --xpath 'string(/Container/Support)' "${template}")"
profile_forum="$(xmllint --xpath 'string(/CommunityApplications/Forum)' "${profile}")"
beta="$(xmllint --xpath 'string(/Container/Beta)' "${template}")"
extra_params="$(xmllint --xpath 'string(/Container/ExtraParams)' "${template}")"

[[ "${repository}" == "ghcr.io/usefulsoftwareco/executor-selfhost:latest" ]]
[[ "${network}" == "bridge" ]]
[[ "${privileged}" == "false" ]]
[[ "${web_port}" == "4788" ]]
[[ "${data_target}" == "/data" ]]
[[ "${data_default}" == "/mnt/user/appdata/executor" ]]
[[ "${web_base_target}" == "EXECUTOR_WEB_BASE_URL" ]]
[[ "${web_base_required}" == "true" ]]
[[ "${local_network_target}" == "EXECUTOR_ALLOW_LOCAL_NETWORK" ]]
[[ "${local_network_default}" == "false" ]]
[[ "${stdio_target}" == "EXECUTOR_ALLOW_STDIO_MCP" ]]
[[ "${stdio_default}" == "false" ]]
[[ "${analytics_target}" == "EXECUTOR_DISABLE_ANALYTICS" ]]
[[ "${analytics_default}" == "false" ]]
[[ -n "${profile_text}" ]]
[[ "${template_url}" == "https://raw.githubusercontent.com/ntindle/executor-unraid/main/templates/executor.xml" ]]
[[ "${support_url}" == "https://github.com/ntindle/executor-unraid/issues" ]]
[[ "${profile_forum}" == "${support_url}" ]]
[[ "${beta}" == "true" ]]
[[ "${extra_params}" == "--restart=unless-stopped --log-driver json-file --log-opt max-size=10m --log-opt max-file=3" ]]

if grep -R -E "REPLACE_WITH_|YOUR_GITHUB_USERNAME|YOUR_REPO_NAME|change-me|BEGIN (RSA|OPENSSH|EC) PRIVATE KEY" \
  "${template}" "${profile}" "${repo_root}/README.md" \
  "${repo_root}/CONTRIBUTING.md" "${repo_root}/SECURITY.md" \
  "${repo_root}/BRANDING.md" "${repo_root}/THIRD_PARTY_NOTICES.md" \
  "${repo_root}/docs" "${repo_root}/.github"; then
  echo "public files contain a placeholder or secret-like value" >&2
  exit 1
fi

echo "Executor Unraid template validation passed"
