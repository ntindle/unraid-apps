#!/usr/bin/env bash
# Boots the image named in the template the way the template runs it and checks the container
# contract: first-run configuration, health, authentication, the web console, and that the
# configuration survives the container being recreated.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
template="${repo_root}/templates/cliproxyapi.xml"
image="${CLIPROXYAPI_SMOKE_IMAGE:-$(xmllint --xpath 'string(/Container/Repository)' "${template}")}"
host_port="${CLIPROXYAPI_SMOKE_PORT:-18317}"
container="cliproxyapi-smoke-${GITHUB_RUN_ID:-$$}"
data_dir="$(mktemp -d)"
management_password="smoke-$(head -c 12 /dev/urandom | od -An -tx1 | tr -d ' \n')"
client_key="sk-smoke-$(head -c 12 /dev/urandom | od -An -tx1 | tr -d ' \n')"
base="http://127.0.0.1:${host_port}"

cleanup() {
  docker rm --force "${container}" >/dev/null 2>&1 || true
  # The container writes the data directory as root.
  docker run --rm --volume "${data_dir}:/data" --entrypoint sh "${image}" -c 'rm -rf /data/* /data/.[!.]*' >/dev/null 2>&1 || true
  rm -rf -- "${data_dir}" 2>/dev/null || true
}
trap cleanup EXIT

assert_equal() {
  local actual="$1" expected="$2" label="$3"
  if [[ "${actual}" != "${expected}" ]]; then
    echo "${label}: expected ${expected}, got ${actual}" >&2
    return 1
  fi
}

status() {
  curl --silent --output /dev/null --write-out '%{http_code}' "$@"
}

start_container() {
  docker run --detach \
    --name "${container}" \
    --restart=no \
    --publish "127.0.0.1:${host_port}:8317" \
    --volume "${data_dir}:/data" \
    --env "MANAGEMENT_PASSWORD=${management_password}" \
    --env "CLIPROXY_API_KEYS=${client_key}" \
    --log-driver json-file \
    --log-opt max-size=10m \
    --log-opt max-file=3 \
    "${image}" >/dev/null
}

wait_for_health() {
  for _ in $(seq 1 60); do
    if [[ "$(docker inspect --format '{{.State.Health.Status}}' "${container}" 2>/dev/null)" == "healthy" ]]; then
      return 0
    fi
    sleep 2
  done
  docker logs "${container}" >&2
  return 1
}

config_value() {
  docker exec "${container}" sh -c "grep -c -- '$1' /data/config.yaml" 2>/dev/null || true
}

start_container
wait_for_health

assert_equal "$(docker inspect --format '{{.HostConfig.Privileged}}' "${container}")" "false" "privileged mode"
assert_equal "$(docker inspect --format '{{.HostConfig.NetworkMode}}' "${container}")" "bridge" "network mode"

assert_equal "$(status "${base}/healthz")" "200" "health endpoint"
assert_equal "$(status "${base}/v1/models")" "401" "models without a key"
assert_equal "$(status --header "Authorization: Bearer ${client_key}" "${base}/v1/models")" "200" "models with the client key"
assert_equal "$(status --header "x-api-key: ${client_key}" --header "anthropic-version: 2023-06-01" "${base}/v1/models")" "200" "Anthropic model list"
assert_equal "$(status --header "Authorization: Bearer ${client_key}" "${base}/v1/models?client_version=0.157.0")" "200" "Codex model catalog"
assert_equal "$(status "${base}/v8/management/config")" "401" "management without the password"
assert_equal "$(status --header "Authorization: Bearer ${management_password}" "${base}/v8/management/config")" "200" "management with the password"
assert_equal "$(status "${base}/management.html")" "200" "web console"

for setting in 'fill-first-order: "soonest-reset"' 'session-affinity: true' 'websockets: true' 'native-model-lists: true' 'live-models: true'; do
  if [[ "$(config_value "${setting}")" == "0" || -z "$(config_value "${setting}")" ]]; then
    echo "first-run config.yaml is missing: ${setting}" >&2
    exit 1
  fi
done
assert_equal "$(config_value "${client_key}")" "1" "client key written to config.yaml"

config_hash="$(docker exec "${container}" sh -c 'sha256sum /data/config.yaml' | awk '{print $1}')"

docker stop --time 10 "${container}" >/dev/null
assert_equal "$(docker inspect --format '{{.State.OOMKilled}}' "${container}")" "false" "OOM-killed state"
docker rm "${container}" >/dev/null

start_container
wait_for_health
assert_equal "$(docker exec "${container}" sh -c 'sha256sum /data/config.yaml' | awk '{print $1}')" "${config_hash}" "config.yaml after the container was recreated"
assert_equal "$(status --header "Authorization: Bearer ${client_key}" "${base}/v1/models")" "200" "client key after the container was recreated"

echo "CLIProxyAPI container smoke test passed"
