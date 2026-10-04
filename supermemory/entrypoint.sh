#!/usr/bin/env bash
# Downloads the supermemory-server release named by SUPERMEMORY_VERSION into /data/bin,
# verifies its SHA-256 on every start, and runs it as PUID:PGID with all state under /data.
set -euo pipefail

log() { echo "[launcher] $*"; }
die() {
  echo "[launcher] ERROR: $*" >&2
  exit 1
}

releases="https://github.com/supermemoryai/supermemory/releases/download"
checksums="/usr/local/share/supermemory/checksums.txt"
data="/data"

version="${SUPERMEMORY_VERSION:-}"
[[ "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$ ]] \
  || die "SUPERMEMORY_VERSION must be a release number such as 0.0.8, got '${version}'"

case "$(uname -m)" in
  x86_64 | amd64) platform="linux-x64" ;;
  aarch64 | arm64) platform="linux-arm64" ;;
  *) die "unsupported architecture: $(uname -m)" ;;
esac

# Without a terminal the server has no setup wizard, so the provider has to come from the
# environment.
provider=""
for name in OPENAI_API_KEY ANTHROPIC_API_KEY GEMINI_API_KEY GROQ_API_KEY WORKERS_AI_API_KEY GOOGLE_VERTEX_PROJECT_ID; do
  if [[ -n "${!name:-}" ]]; then
    provider="${name}"
    break
  fi
done
[[ -n "${provider}" ]] \
  || die "no LLM provider is configured. Set OPENAI_API_KEY (with OPENAI_BASE_URL for an OpenAI-compatible endpoint), ANTHROPIC_API_KEY, GEMINI_API_KEY or GROQ_API_KEY."

port_ok() { [[ "$1" =~ ^[0-9]+$ ]] && (($1 >= 1 && $1 <= 65535)); }
[[ "${PUID}" =~ ^[0-9]+$ && "${PGID}" =~ ^[0-9]+$ ]] || die "PUID and PGID must be numbers"
port_ok "${PORT}" || die "PORT must be a TCP port, got '${PORT}'"

asset="supermemory-server-${platform}"
bin_dir="${data}/bin"
bin="${bin_dir}/supermemory-server-${version}"
mkdir -p "${bin_dir}" "${data}/store" "${data}/home"

expected="${SUPERMEMORY_SHA256:-}"
if [[ -z "${expected}" ]]; then
  expected="$(awk -v v="${version}" -v p="${platform}" '$1 == v && $2 == p { print $3 }' "${checksums}")"
fi
if [[ -z "${expected}" ]]; then
  log "version ${version} is not pinned by this image; reading its checksum from the release"
  expected="$(curl --fail --silent --show-error --location "${releases}/server-v${version}/${asset}.sha256" | awk '{ print $1; exit }')" \
    || die "could not read the checksum of ${asset} ${version}"
fi
[[ "${expected}" =~ ^[0-9a-f]{64}$ ]] || die "the checksum for ${asset} ${version} is not a SHA-256"

checksum_ok() { [[ -f "$1" && "$(sha256sum "$1" | awk '{ print $1 }')" == "${expected}" ]]; }

if ! checksum_ok "${bin}"; then
  log "downloading supermemory-server ${version} (${platform}), about 300 MB"
  curl --fail --silent --show-error --location --retry 3 --output "${bin}.partial" \
    "${releases}/server-v${version}/${asset}" \
    || die "download of ${asset} ${version} failed"
  if ! checksum_ok "${bin}.partial"; then
    rm -f "${bin}.partial"
    die "checksum mismatch for ${asset} ${version}; nothing was installed"
  fi
  chmod 0755 "${bin}.partial"
  mv -f "${bin}.partial" "${bin}"
  log "installed ${bin}"
fi

run_as=()
if [[ "$(id -u)" == "0" && "${PUID}" != "0" ]]; then
  chown -R "${PUID}:${PGID}" "${data}"
  run_as=(setpriv --reuid "${PUID}" --regid "${PGID}" --clear-groups)
fi

# The server skips its API key for any request whose Host header names the loopback address,
# and a client on the network can send that header. The guard answers on the public port and
# forwards every request with a fixed, non-loopback Host, so the key is always required.
if [[ "${SUPERMEMORY_HOST_GUARD:-on}" != "off" ]]; then
  internal_port="${SUPERMEMORY_INTERNAL_PORT:-16767}"
  if ! port_ok "${internal_port}" || [[ "${internal_port}" == "${PORT}" ]]; then
    die "SUPERMEMORY_INTERNAL_PORT must be a TCP port other than PORT, got '${internal_port}'"
  fi
  guard_dir="/tmp/supermemory-guard"
  rm -rf "${guard_dir}"
  mkdir -p "${guard_dir}/tmp"
  cat >"${guard_dir}/nginx.conf" <<EOF
worker_processes 1;
pid ${guard_dir}/nginx.pid;
error_log stderr warn;
events { worker_connections 512; }
http {
  access_log off;
  server_tokens off;
  client_body_temp_path ${guard_dir}/tmp/body;
  proxy_temp_path ${guard_dir}/tmp/proxy;
  fastcgi_temp_path ${guard_dir}/tmp/fastcgi;
  uwsgi_temp_path ${guard_dir}/tmp/uwsgi;
  scgi_temp_path ${guard_dir}/tmp/scgi;
  client_max_body_size 0;
  map \$http_upgrade \$connection_upgrade {
    default upgrade;
    "" close;
  }
  server {
    listen ${PORT};
    location / {
      proxy_pass http://127.0.0.1:${internal_port};
      proxy_http_version 1.1;
      proxy_set_header Host supermemory.guard;
      proxy_set_header Upgrade \$http_upgrade;
      proxy_set_header Connection \$connection_upgrade;
      proxy_buffering off;
      proxy_request_buffering off;
      proxy_read_timeout 3600s;
      proxy_send_timeout 3600s;
    }
  }
}
EOF
  chown -R "${PUID}:${PGID}" "${guard_dir}"
  "${run_as[@]}" nginx -e stderr -c "${guard_dir}/nginx.conf" -t -q || die "the host guard configuration is invalid"
  "${run_as[@]}" nginx -e stderr -c "${guard_dir}/nginx.conf"
  log "host guard listening on port ${PORT}; the API key is required for every API request"
  export PORT="${internal_port}" SUPERMEMORY_PORT="${internal_port}"
else
  log "host guard is off: requests that send a loopback Host header skip the API key"
fi

export HOME="${data}/home"
export SUPERMEMORY_DATA_DIR="${data}/store"
# Upgrades happen by changing SUPERMEMORY_VERSION, not from inside the container.
export SUPERMEMORY_NO_UPDATE_CHECK="${SUPERMEMORY_NO_UPDATE_CHECK:-1}"
cd "${data}/store"

log "starting supermemory-server ${version} (provider from ${provider})"
exec "${run_as[@]}" "${bin}" "$@"
