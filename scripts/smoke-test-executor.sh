#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
template="${repo_root}/templates/executor.xml"
image="${EXECUTOR_SMOKE_IMAGE:-$(xmllint --xpath 'string(/Container/Repository)' "${template}")}"
host_port="${EXECUTOR_SMOKE_PORT:-14788}"
container="executor-unraid-smoke-${GITHUB_RUN_ID:-$$}"
data_dir="$(mktemp -d)"

cleanup() {
  docker rm --force "${container}" >/dev/null 2>&1 || true
  rm -rf -- "${data_dir}"
}
trap cleanup EXIT

start_container() {
  docker run --detach \
    --name "${container}" \
    --restart=no \
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
    if curl --fail --silent --show-error \
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

[[ "$(docker inspect --format '{{.HostConfig.Privileged}}' "${container}")" == "false" ]]
[[ "$(docker inspect --format '{{.HostConfig.NetworkMode}}' "${container}")" == "default" ]]
[[ "$(docker inspect --format '{{(index .NetworkSettings.Ports "4788/tcp" 0).HostIp}}' "${container}")" == "127.0.0.1" ]]
[[ "$(docker inspect --format '{{range .Mounts}}{{if eq .Destination "/data"}}{{.RW}}{{end}}{{end}}' "${container}")" == "true" ]]
[[ -s "${data_dir}/data.db" ]]
[[ -s "${data_dir}/secret.key" ]]
[[ -s "${data_dir}/auth-secret.key" ]]

secret_sha="$(sha256sum "${data_dir}/secret.key" | awk '{print $1}')"
auth_sha="$(sha256sum "${data_dir}/auth-secret.key" | awk '{print $1}')"

docker stop --time 10 "${container}" >/dev/null
exit_code="$(docker inspect --format '{{.State.ExitCode}}' "${container}")"
oom_killed="$(docker inspect --format '{{.State.OOMKilled}}' "${container}")"
[[ "${exit_code}" == "0" || "${exit_code}" == "130" || "${exit_code}" == "143" ]]
[[ "${oom_killed}" == "false" ]]
docker rm "${container}" >/dev/null

start_container
wait_for_health

[[ "$(sha256sum "${data_dir}/secret.key" | awk '{print $1}')" == "${secret_sha}" ]]
[[ "$(sha256sum "${data_dir}/auth-secret.key" | awk '{print $1}')" == "${auth_sha}" ]]

echo "Executor container smoke test passed"
