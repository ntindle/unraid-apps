#!/usr/bin/env bash
set -euo pipefail
release=0.0.8-ntindle.1
if [[ "${1:-}" == --version ]]; then
  echo "Supermemory ${release} (upstream 0.0.8, external PostgreSQL)"
  exit 0
fi
[[ "${SUPERMEMORY_VERSION:-}" == 0.0.8 ]] || { echo '[factory] This release requires upstream 0.0.8' >&2; exit 1; }
[[ "${SUPERMEMORY_HOST_GUARD:-on}" == on ]] || { echo '[factory] The host guard is required for this release' >&2; exit 1; }
[[ -n "${FACTORY_SUPERMEMORY_DATABASE_URL_FILE:-}" && -s "$FACTORY_SUPERMEMORY_DATABASE_URL_FILE" ]] || { echo '[factory] The migrated PostgreSQL connection file is required' >&2; exit 1; }
upstream=/usr/local/bin/entrypoint.sh
actual=$(sha256sum "$upstream")
[[ "${actual%% *}" == 1b69adbb3acbc0c0e16603242101c17480c62e56aa24c444f5a667ec1a59c7a2 ]] || { echo '[factory] Unreviewed launcher' >&2; exit 1; }
export SUPERMEMORY_HIDE_API_KEY_IN_LOGS=1
export SUPERMEMORY_SHA256=87f32433d0179be80bb9d8a1bafbac65af4128324342a27ecb8bd1a77b5506f3
generated=$(mktemp /tmp/factory-launch.XXXXXXXX)
awk '
  /^exec "\$\{run_as\[@\]\}" "\$\{bin\}" "\$@"$/ {
    print "exec \"${run_as[@]}\" /opt/factory/server.sh \"${bin}\" \"$@\""
    found++; next
  }
  { print }
  END { if (found != 1) exit 42 }
' "$upstream" > "$generated"
echo "[factory] Supermemory ${release}; PostgreSQL persistence"
exec bash "$generated" "$@"
