#!/usr/bin/env bash
# Moves the Supermemory app to another supermemory-server release: the image's default version,
# the template's Server Version, and the SHA-256 the image pins for it, taken from the
# release's own manifest.json.
#
#   scripts/bump-supermemory.sh 0.0.9
#
# Older pins stay in checksums.txt, so an install that keeps an older Server Version still
# verifies against a pinned value. Run scripts/validate.sh afterwards.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dockerfile="${repo_root}/supermemory/Dockerfile"
checksums="${repo_root}/supermemory/checksums.txt"
template="${repo_root}/templates/supermemory.xml"
releases="https://github.com/supermemoryai/supermemory/releases/download"

fail() {
  echo "$*" >&2
  exit 1
}

version="${1:-}"
[[ "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "usage: $0 <version>, e.g. 0.0.9"
command -v jq >/dev/null || fail "jq is required"

current="$(sed -n 's/^ENV SUPERMEMORY_VERSION=\([^ ]*\).*/\1/p' "${dockerfile}")"
[[ -n "${current}" ]] || fail "no ENV SUPERMEMORY_VERSION in supermemory/Dockerfile"
[[ "${current}" != "${version}" ]] || fail "already on ${version}"

manifest="$(curl --fail --silent --location "${releases}/server-v${version}/manifest.json")" \
  || fail "supermemory-server ${version} has no release with a manifest.json"
[[ "$(jq -r '.version' <<<"${manifest}")" == "${version}" ]] \
  || fail "manifest.json of server-v${version} names another version"

pins=()
for platform in linux-x64 linux-arm64; do
  sum="$(jq -r --arg p "${platform}" '.platforms[$p].checksum // empty' <<<"${manifest}")"
  [[ "${sum}" =~ ^[0-9a-f]{64}$ ]] || fail "manifest.json of server-v${version} has no ${platform} checksum"
  pins+=("${version} ${platform} ${sum}")
done

sed -i "s/^ENV SUPERMEMORY_VERSION=${current//./\\.} /ENV SUPERMEMORY_VERSION=${version} /" "${dockerfile}"
sed -i "/Name=\"Server Version\"/{s/Default=\"${current//./\\.}\"/Default=\"${version}\"/;s/>${current//./\\.}<\/Config>/>${version}<\/Config>/}" "${template}"
grep -v "^${version//./\\.} " "${checksums}" > "${checksums}.new" || true
printf '%s\n' "${pins[@]}" >> "${checksums}.new"
mv "${checksums}.new" "${checksums}"

[[ "$(sed -n 's/^ENV SUPERMEMORY_VERSION=\([^ ]*\).*/\1/p' "${dockerfile}")" == "${version}" ]] \
  || fail "could not update supermemory/Dockerfile"
grep -q "Name=\"Server Version\"[^>]*Default=\"${version//./\\.}\"[^>]*>${version//./\\.}</Config>" "${template}" \
  || fail "could not update the template's Server Version"

echo "supermemory-server ${current} -> ${version}"
