#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
package="${repo_root}/supermemory/postgres-image"
image="${1:-supermemory-postgres:test}"
read_field() { bun -e 'console.log((await Bun.file(process.argv[1]).json())[process.argv[2]])' "${package}/release.json" "$1"; }
docker build \
  --build-arg "FORK_COMMIT=$(read_field forkCommit)" \
  --build-arg "SOURCE_SHA256=$(read_field sourceArchiveSha256)" \
  --build-arg "RELEASE_VERSION=$(read_field version)" \
  --build-arg "VCS_REF=$(git -C "${repo_root}" rev-parse HEAD)" \
  --tag "${image}" "${package}"
