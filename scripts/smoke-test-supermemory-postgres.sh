#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
image="${SUPERMEMORY_POSTGRES_IMAGE:-supermemory-postgres:test}"
if [[ -z "${SUPERMEMORY_POSTGRES_IMAGE:-}" ]]; then "${repo_root}/scripts/build-supermemory-postgres.sh" "${image}"; fi
bun "${repo_root}/supermemory/postgres-image/smoke.mjs" "${image}"
