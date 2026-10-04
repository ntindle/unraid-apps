#!/usr/bin/env bash
# Boots the Supermemory launcher image the way the template runs it and checks the container
# contract: it refuses to start without a provider, downloads and verifies the server on first
# start, requires the API key for every API request, runs unprivileged, and keeps its state
# when the container is recreated.
#
# SUPERMEMORY_SMOKE_IMAGE     image to test; built from supermemory/ when unset
# SUPERMEMORY_SMOKE_PORT      host port to publish (default 16799)
# SUPERMEMORY_SMOKE_DATA_DIR  data directory to use; it must be empty and is removed afterwards
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
image="${SUPERMEMORY_SMOKE_IMAGE:-}"
host_port="${SUPERMEMORY_SMOKE_PORT:-16799}"
container="supermemory-smoke-${GITHUB_RUN_ID:-$$}"
data_dir="${SUPERMEMORY_SMOKE_DATA_DIR:-$(mktemp -d)}"
base="http://127.0.0.1:${host_port}"

if [[ -z "${image}" ]]; then
  image="supermemory-smoke:local"
  docker build --quiet --tag "${image}" "${repo_root}/supermemory" >/dev/null
fi
mkdir -p "${data_dir}"

cleanup() {
  docker rm --force "${container}" >/dev/null 2>&1 || true
  # The container writes the data directory as another user.
  docker run --rm --volume "${data_dir}:/data" --entrypoint sh "${image}" -c 'rm -rf /data/* /data/.[!.]*' >/dev/null 2>&1 || true
  rm -rf -- "${data_dir}" 2>/dev/null || true
}
trap cleanup EXIT

fail() {
  echo "FAIL: $*" >&2
  docker logs --tail 60 "${container}" 2>&1 | sed -E 's/sm_[A-Za-z0-9_-]{8,}/sm_<hidden>/g' >&2 || true
  exit 1
}

assert_equal() {
  local actual="$1" expected="$2" label="$3"
  [[ "${actual}" == "${expected}" ]] || fail "${label}: expected ${expected}, got ${actual}"
  echo "ok: ${label}"
}

start_container() {
  # A graceful stop is what lets the server write its database; a kill loses recent writes.
  docker stop --time 60 "${container}" >/dev/null 2>&1 || true
  docker rm --force "${container}" >/dev/null 2>&1 || true
  docker run --detach \
    --name "${container}" \
    --restart=no \
    --publish "127.0.0.1:${host_port}:6767" \
    --volume "${data_dir}:/data" \
    --env OPENAI_API_KEY=smoke-test-not-a-real-key \
    --env SUPERMEMORY_DISABLE_TELEMETRY=1 \
    "$@" "${image}" >/dev/null
}

wait_healthy() {
  local state
  for _ in $(seq 1 200); do
    state="$(docker inspect --format '{{.State.Status}} {{.State.Health.Status}}' "${container}" 2>/dev/null || true)"
    case "${state}" in
      "running healthy") return 0 ;;
      "exited "* | "dead "*) fail "the container stopped before it became healthy" ;;
    esac
    sleep 3
  done
  fail "the container did not become healthy within 10 minutes"
}

status() {
  curl --silent --output /dev/null --write-out '%{http_code}' --max-time 20 "$@"
}

list_documents() {
  status --request POST "${base}/v3/documents/list" \
    --header 'Content-Type: application/json' --data '{"page":1,"limit":1}' "$@"
}

# Without a provider the launcher must stop before it downloads anything.
if output="$(docker run --rm --volume "${data_dir}:/data" "${image}" 2>&1)"; then
  fail "the container started without an LLM provider"
fi
[[ "${output}" == *"no LLM provider is configured"* ]] || fail "unexpected error without a provider: ${output}"
echo "ok: refuses to start without an LLM provider"

start_container
wait_healthy
# Read the log into a variable first: grep -q on a pipe makes docker fail under pipefail.
logs="$(docker logs "${container}" 2>&1)"
[[ "${logs}" == *"installed /data/bin/supermemory-server-"* ]] \
  || fail "the first start did not install the server"
echo "ok: first start downloaded and verified the server"

api_key="$(docker exec "${container}" cat /data/store/api-key)"
[[ "${api_key}" == sm_* ]] || fail "no API key in /data/store/api-key"

assert_equal "$(status "${base}/")" "200" "health endpoint answers"
assert_equal "$(list_documents)" "401" "no key is rejected"
assert_equal "$(list_documents --header 'Host: localhost')" "401" "no key with a loopback Host header is rejected"
assert_equal "$(list_documents --header 'Authorization: Bearer sm_wrong')" "401" "wrong key is rejected"
assert_equal "$(list_documents --header "Authorization: Bearer ${api_key}")" "200" "the API key is accepted"
assert_equal "$(docker exec "${container}" stat -c '%u:%g' /data/store)" "99:100" "state is owned by 99:100"
assert_equal "$(docker exec "${container}" stat -c '%u' /proc/1)" "99" "the server runs as user 99"

start_container
wait_healthy
logs="$(docker logs "${container}" 2>&1)"
[[ "${logs}" != *"downloading supermemory-server"* ]] \
  || fail "the server was downloaded again after the container was recreated"
echo "ok: the downloaded server is reused"
[[ "$(docker exec "${container}" cat /data/store/api-key)" == "${api_key}" ]] \
  || fail "the API key changed when the container was recreated, so the database was not kept"
echo "ok: the database and API key survive a recreate"

# With the guard off the image shows the server's own behaviour. If this starts failing after
# a version bump, the server has stopped trusting the Host header and the guard can go.
start_container --env SUPERMEMORY_HOST_GUARD=off
wait_healthy
assert_equal "$(list_documents)" "200" "guard off: a loopback Host header skips the key"

echo "Supermemory smoke test passed"
