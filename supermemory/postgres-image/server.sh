#!/usr/bin/env bash
set -euo pipefail
original="$1"
shift
mkdir -p /data/postgres/releases
# Concurrent/restarted containers must never see a half-built bundle.
exec 9>/data/postgres/.install.lock
flock --exclusive 9
bundle=$(BUN_BE_BUN=1 "$original" /opt/factory/install.mjs "$original")
flock --unlock 9
exec 9>&-
export FACTORY_SUPERMEMORY_RUNTIME="file://${bundle}/runtime.mjs"
exec "$bundle/bin/supermemory-server-0.0.8-postgres" "$@"
