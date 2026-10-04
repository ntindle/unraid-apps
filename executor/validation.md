# Validation record

## Non-root image — 2026-10-04

Upstream PR [#2000](https://github.com/UsefulSoftwareCo/executor/pull/2000)
(merged 2026-09-15) moved the runtime to `distroless:nonroot` with
`USER 65532:65532`; only the image's own `/data` belongs to that user. No
`1.6.9` image was published, so the first image with the change is `1.6.10`,
which became `latest` on 2026-09-18:

- Upstream version `1.6.10`, revision
  `3890d6f5e5efd1530f0dba0fe23ada95a39caf86`, multi-platform digest
  `sha256:b9e001775d3eb7d662d347c8f7054333c78c1a4fd97cb5a86dc1d1d1406093b9`
- Image user `65532:65532`; `1.6.8`
  (`sha256:200315d519a8c19685de05e88aa9a3cf1e1cb9869a2b0aecf604f6ebf47c6ea1`)
  ran as root

With a bind-mounted data directory the container cannot write, the first start
fails with `EACCES: permission denied, open '/data/secret.key'`. That is what
Unraid gives it: dockerMan creates a missing App Data path owned by `99:100`
with mode `0755`. The daily smoke test failed this way from 2026-09-19.

The template now runs the container as `99:100`. The smoke test creates its
data directory the way Unraid does, runs the image as the template's `--user`,
and checks that the generated keys belong to that user. Unraid does not apply
template changes to existing containers, so a container added earlier needs
`--user 99:100` added to its Extra Parameters by hand. Data written by `1.6.8`
or earlier is owned by root and needs `chown -R 99:100` before the first start
of a newer image.

## Initial contract review — 2026-09-04

The initial template was derived from the upstream `v1.6.7` release and the
current files under `apps/host-selfhost` in
[`UsefulSoftwareCo/executor`](https://github.com/UsefulSoftwareCo/executor).

Verified upstream contract:

- Template image: `ghcr.io/usefulsoftwareco/executor-selfhost:latest`
- Validated resolution: upstream version `1.6.7`, revision
  `fff7ed68553c9d249966103b74c7ed4218fe45b1`, multi-platform digest
  `sha256:c8dd83a5dba8ac992dfe1ded4aa65ae4e7f52ec31fddbe2af5b49ffebe5bbfa7`
- Platforms: `linux/amd64` and `linux/arm64`
- Container bind address: `0.0.0.0`
- Container port: `4788`
- Health endpoint: `/api/health`
- Streamable HTTP MCP endpoint: `/mcp`
- Persistent data directory: `/data`
- Image-provided health check: 30-second interval, 5-second timeout, 20-second
  start period, 5 retries
- Image license label: MIT
- Privileged mode, host networking, Docker socket, and arbitrary host-share
  mounts are not required

The template tracks the upstream stable `latest` channel, uses bridge
networking, publishes only port `4788`, and maps one appdata path to `/data`.
The canonical web origin is
required instead of allowing the image's localhost fallback to produce invalid
OAuth and browser-authentication links on an Unraid host.

An isolated `linux/amd64` Docker smoke test reached both HTTP 200 at
`/api/health` and Docker `healthy`, generated `data.db`, `secret.key`, and
`auth-secret.key`, and stopped in about 0.46 seconds with `OOMKilled=false`.
The upstream Bun runtime reports exit code `130` for this handled signal path;
the smoke harness therefore accepts normal signal exits `130`/`143` as well as
`0`, while still rejecting OOM kills and timeouts. Container recreation against
the same data directory must preserve both generated key hashes.

## Remaining live acceptance gates

Before removing the template's beta marker or submitting it to Community
Applications:

- Recreate the exact public XML fields through current Unraid Docker Authoring
  Mode; Unraid 7.2 exposes no visible raw-template URL importer.
- Confirm every field survives save and reopen.
- Start the exact template on an isolated host port and appdata path.
- Confirm the image becomes healthy and `/api/health` returns success.
- Complete first-account setup and verify that later users require invites.
- Connect one remote MCP client through `/mcp` and exercise an allow, approval,
  and block policy.
- Recreate the container against the same appdata and confirm accounts,
  connections, policies, and generated keys persist.
- Stop through the native Unraid UI and confirm a clean exit without an OOM kill.
- Run Community Applications Validate and Scan on the exact public commit.
