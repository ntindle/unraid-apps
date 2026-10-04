# Executor for Unraid

This folder documents an unofficial
[Unraid Community Applications](https://unraid.net/community/apps) template for
[Executor](https://github.com/UsefulSoftwareCo/executor), a self-hosted MCP
gateway for AI agents.

Executor gives MCP-compatible clients one endpoint for MCP, OpenAPI, and
GraphQL integrations. Credentials and per-tool allow, approval, or block
policies stay in the central Executor service instead of being copied into
every agent environment.

The template is deployment metadata only. It does not fork or modify
Executor, and it is not affiliated with or endorsed by Useful Software Co.

## What the template deploys

- Official image: `ghcr.io/usefulsoftwareco/executor-selfhost:latest`
- Web console: container port `4788`
- MCP endpoint: `/mcp`
- Persistent state: `/data`, mapped to `/mnt/user/appdata/executor`
- Network mode: bridge
- Privileged mode: disabled
- Runs as user `99:100`, which owns App Data on Unraid
- Private-network access from sandboxed code: disabled by default
- Stdio MCP command execution: disabled by default

The upstream image is distroless and does not contain an interactive shell.
Use the Unraid **Logs** action and the health endpoint for troubleshooting; the
container-console action is not expected to open a usable shell.

The image contains the API, web console, authentication, QuickJS execution,
and SQLite/libSQL persistence in one process. No external database, worker, or
proxy container is required.

## Install

Once accepted into Community Applications, open **Apps**, search for
**Executor**, review the settings, and select **Install**.

Before catalog acceptance, use **Docker → Add Container** and enter the same
contract manually:

| Field | Value |
| --- | --- |
| Name | `Executor` |
| Repository | `ghcr.io/usefulsoftwareco/executor-selfhost:latest` |
| Network Type | `Bridge` |
| WebUI | `http://[IP]:[PORT:4788]/` |
| Port | host `4788` to container `4788/tcp` |
| App Data | `/mnt/user/appdata/executor` to `/data`, read/write |
| Web Base URL | exact browser origin as `EXECUTOR_WEB_BASE_URL` |
| Extra Parameters | `--restart=unless-stopped --user 99:100 --log-driver json-file --log-opt max-size=10m --log-opt max-file=3` |

The canonical template remains available for review at
[`templates/executor.xml`](../templates/executor.xml). Current Unraid 7.2 Docker
Authoring Mode does not expose a raw-template URL importer, so the catalog is
the intended one-click distribution path.

Do not start the container until **Web Base URL** is set to the exact origin
you will open in the browser, including its scheme and any non-default port.
Examples:

```text
http://tower.local:4788
https://executor.example.com
```

The canonical address matters: Executor uses it for browser-origin checks,
OAuth callbacks, approval links, and other generated URLs. Optional aliases
can be listed under **Additional Trusted Origins**, but they do not replace the
canonical URL.

After the container becomes healthy, open the configured URL. The first person
to create an account becomes the owner. Open signup then closes; invite other
people with single-use links from the **Admin** page.

## Connect clients

Point every compatible client at the same Streamable HTTP MCP URL:

```text
https://executor.example.com/mcp
```

For a LAN-only deployment, replace the example domain with the exact host/IP
and port used as **Web Base URL**. Authorize each client separately rather than
copying one browser session between machines.

## Security choices

- Keep port `4788` limited to a trusted LAN or VPN. Use an authenticated TLS
  reverse proxy before exposing Executor outside that boundary.
- Leave **Allow Local Network** set to `false` unless sandboxed code must reach
  private services. Inbound connections from your clients do not require this
  setting.
- Leave **Allow Stdio MCP** set to `false` for a shared remote gateway. Turning
  it on permits configured commands to execute inside the Executor container.
- Treat `/mnt/user/appdata/executor` as sensitive. It contains the database,
  encrypted integration credentials, and the generated keys needed to decrypt
  them.
- Executor sends limited anonymous self-host usage events by default. Set
  **Disable Anonymous Analytics** to `true` if you want to opt out without also
  disabling its integrations-catalog fetch.

Executor's QuickJS runtime is a code-execution boundary for gateway workflows;
it is not a replacement for a disposable VM or OS-level sandbox.

## Backups and upgrades

Include the complete appdata directory in a regular backup. For a consistent
manual copy, stop the container first; do not copy only the SQLite file while
discarding the generated key files beside it.

The template follows the upstream stable `:latest` channel so Unraid can detect
new image digests and the Auto Update Applications plugin can apply them. The
last validated release and digest are recorded in
[`validation.md`](validation.md) to make rollback auditable.

Automatic application is still opt-in through your Unraid update policy. Run
the appdata backup before the container-update window so the database and both
generated key files are recoverable together.

### Containers added before 2026-10-04

Since 1.6.10 the image runs as a non-root user, and the template runs it as
`99:100`, the owner Unraid gives App Data. Unraid never carries a template
change into a container that already exists, so a container added from an
earlier version of this template, or by hand, still has no `--user`. It runs
as the image's own user, which cannot write App Data, and stops with
`EACCES: permission denied, open '/data/secret.key'`.

1. Stop the container and back up the appdata directory.
2. Only if the data was written by Executor 1.6.8 or earlier (it belongs to
   root), fix its ownership from the Unraid terminal:

   ```bash
   chown -R 99:100 /mnt/user/appdata/executor
   ```

3. **Docker → Executor → Edit**, add `--user 99:100` to **Extra Parameters**
   (Advanced View), and select **Apply**. Apply recreates and starts the
   container, so do step 2 first.

The image has no shell, so the ownership cannot be fixed from inside the
container.

## Support and provenance

- Template issues: <https://github.com/ntindle/unraid-apps/issues>
- Executor documentation: <https://executor.sh/docs/hosted/docker>
- Executor product issues: <https://github.com/UsefulSoftwareCo/executor/issues>
- Official image: <https://github.com/UsefulSoftwareCo/executor/pkgs/container/executor-selfhost>

When reporting a template issue, include the Unraid version, image tag,
container health state, and relevant logs with credentials and tokens removed.

## License

The template source and documentation are licensed under the
[MIT License](../LICENSE). Executor itself is also MIT-licensed. The Executor name
and icon remain assets of their upstream owner; see
[`THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md).
