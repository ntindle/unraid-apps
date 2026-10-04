#!/usr/bin/env bash
# Boots the image named in the template the way the template runs it, as the template's user on
# an App Data directory owned the way Unraid creates one, and checks the container contract:
# health, the generated keys, a clean stop, and that the keys survive the container being
# recreated.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
template="${repo_root}/templates/executor.xml"
image="${EXECUTOR_SMOKE_IMAGE:-$(xmllint --xpath 'string(/Container/Repository)' "${template}")}"
run_as="$(xmllint --xpath 'string(/Container/ExtraParams)' "${template}" | sed -n 's/.*--user \([^ ]*\).*/\1/p')"
host_port="${EXECUTOR_SMOKE_PORT:-14788}"
container="executor-smoke-${GITHUB_RUN_ID:-$$}"
work_dir="$(mktemp -d)"
data_dir="${work_dir}/data"
mkdir "${data_dir}"

# The image has no shell, so files the container owns are handled with its bun, as root.
as_root() {
  docker run --rm --user 0:0 --volume "${data_dir}:/data" --entrypoint bun "${image}" -e "$1"
}

cleanup() {
  docker rm --force "${container}" >/dev/null 2>&1 || true
  as_root 'const fs = require("node:fs"); for (const name of fs.readdirSync("/data")) fs.rmSync("/data/" + name, { recursive: true, force: true })' >/dev/null 2>&1 || true
  rm -rf -- "${work_dir}" 2>/dev/null || true
}
trap cleanup EXIT

[[ "${run_as}" =~ ^[0-9]+:[0-9]+$ ]] || {
  echo "templates/executor.xml must set --user <uid>:<gid> in ExtraParams, got '${run_as}'" >&2
  exit 1
}
# Unraid creates a missing App Data path owned by 99:100 with mode 0755.
as_root "const fs = require('node:fs'); fs.chownSync('/data', ${run_as%%:*}, ${run_as##*:}); fs.chmodSync('/data', 0o755)"

assert_equal() {
  local actual="$1"
  local expected="$2"
  local label="$3"
  if [[ "${actual}" != "${expected}" ]]; then
    echo "${label}: expected ${expected}, got ${actual}" >&2
    return 1
  fi
}

container_file_size() {
  local path="$1"
  docker exec "${container}" bun -e \
    'const file = Bun.file(process.argv[1]); console.log(file.size)' "${path}"
}

container_file_sha() {
  local path="$1"
  docker exec "${container}" bun -e \
    'import { createHash } from "node:crypto"; const bytes = await Bun.file(process.argv[1]).arrayBuffer(); console.log(createHash("sha256").update(new Uint8Array(bytes)).digest("hex"))' \
    "${path}"
}

require_container_file() {
  local path="$1"
  local size
  size="$(container_file_size "${path}")"
  if [[ ! "${size}" =~ ^[0-9]+$ || "${size}" == "0" ]]; then
    echo "required persistent file is missing or empty: ${path}" >&2
    return 1
  fi
}

start_container() {
  docker run --detach \
    --name "${container}" \
    --restart=no \
    --user "${run_as}" \
    --publish "127.0.0.1:${host_port}:4788" \
    --volume "${data_dir}:/data" \
    --env "EXECUTOR_WEB_BASE_URL=http://127.0.0.1:${host_port}" \
    --env EXECUTOR_ALLOW_LOCAL_NETWORK=false \
    --env EXECUTOR_ALLOW_STDIO_MCP=false \
    --env EXECUTOR_DISABLE_ANALYTICS=true \
    --log-driver json-file \
    --log-opt max-size=10m \
    --log-opt max-file=3 \
    "${image}" >/dev/null
}

wait_for_health() {
  for _ in $(seq 1 60); do
    if curl --fail --silent \
      "http://127.0.0.1:${host_port}/api/health" >/dev/null; then
      if [[ "$(docker inspect --format '{{.State.Health.Status}}' "${container}")" == "healthy" ]]; then
        return 0
      fi
    fi
    sleep 2
  done
  docker logs "${container}" >&2
  return 1
}

start_container
wait_for_health

assert_equal "$(docker inspect --format '{{.HostConfig.Privileged}}' "${container}")" "false" "privileged mode"
assert_equal "$(docker inspect --format '{{.Config.User}}' "${container}")" "${run_as}" "container user"
assert_equal "$(docker inspect --format '{{.HostConfig.NetworkMode}}' "${container}")" "bridge" "network mode"
assert_equal "$(docker inspect --format '{{(index .NetworkSettings.Ports "4788/tcp" 0).HostIp}}' "${container}")" "127.0.0.1" "published host IP"
assert_equal "$(docker inspect --format '{{range .Mounts}}{{if eq .Destination "/data"}}{{.RW}}{{end}}{{end}}' "${container}")" "true" "data mount read/write mode"
require_container_file "/data/data.db"
require_container_file "/data/secret.key"
require_container_file "/data/auth-secret.key"

assert_equal "$(docker exec "${container}" bun -e 'const s = require("node:fs").statSync("/data/secret.key"); console.log(s.uid + ":" + s.gid)')" "${run_as}" "secret.key owner"

secret_sha="$(container_file_sha "/data/secret.key")"
auth_sha="$(container_file_sha "/data/auth-secret.key")"

docker stop --time 10 "${container}" >/dev/null
exit_code="$(docker inspect --format '{{.State.ExitCode}}' "${container}")"
oom_killed="$(docker inspect --format '{{.State.OOMKilled}}' "${container}")"
if [[ "${exit_code}" != "0" && "${exit_code}" != "130" && "${exit_code}" != "143" ]]; then
  echo "stop exit code: expected 0, 130, or 143; got ${exit_code}" >&2
  exit 1
fi
assert_equal "${oom_killed}" "false" "OOM-killed state"
docker rm "${container}" >/dev/null

start_container
wait_for_health

assert_equal "$(container_file_sha "/data/secret.key")" "${secret_sha}" "secret.key hash after recreation"
assert_equal "$(container_file_sha "/data/auth-secret.key")" "${auth_sha}" "auth-secret.key hash after recreation"

echo "Executor container smoke test passed"
