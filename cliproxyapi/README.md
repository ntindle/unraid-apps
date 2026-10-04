# CLIProxyAPI for Unraid

An unofficial Unraid template for the
[ntindle fork](https://github.com/ntindle/CLIProxyAPI) of
[CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI).

CLIProxyAPI puts Claude Code, Codex and the Muse CLI behind one endpoint on your own server. You
sign your Claude, ChatGPT and Meta accounts in once; the proxy spreads requests across them, keeps
each session on one account, and shows every account's quota and reset times in a web console.

This folder documents the template, [`templates/cliproxyapi.xml`](../templates/cliproxyapi.xml).
It is deployment metadata only; the application lives in the fork.

## What the template deploys

- Image: `ghcr.io/ntindle/cliproxyapi:latest`
- Port `8317`: the API, the Responses WebSocket and the web console at `/management.html`
- Persistent state: `/data`, mapped to `/mnt/user/appdata/cliproxyapi`
- Network mode: bridge. Privileged mode: off.

The first start writes `/data/config.yaml` with the fork's features on:

| Feature | Setting |
| --- | --- |
| Use the account whose weekly quota resets soonest first | `routing.strategy: "fill-first"`, `routing.fill-first-order: "soonest-reset"` |
| Keep a session on the account it started on | `routing.session-affinity: true` |
| Codex subscriptions over the Responses WebSocket | `oauth.providers.codex.websockets: true` |
| Pick up new Claude and Codex models from the provider | `upstream.claude.live-models`, `oauth.providers.codex.live-models` |
| Claude Code sees Claude models, Codex sees Codex models | `client.native-model-lists: true` |
| Logs page, usage feed, plugin pages in the console | `observability.*`, `plugins.enabled: true` |

After the first start the file belongs to the proxy and its console; the image never rewrites it.

## Install

1. In **Docker → Add Container**, enter the fields below, or copy
   [`templates/cliproxyapi.xml`](../templates/cliproxyapi.xml) to
   `/boot/config/plugins/dockerMan/templates-user/my-CLIProxyAPI.xml` and pick it from the
   template list.
2. Set **Management Password** before the first start. Without it the web console is disabled.
3. Start the container and wait for it to report healthy.

| Field | Value |
| --- | --- |
| Name | `CLIProxyAPI` |
| Repository | `ghcr.io/ntindle/cliproxyapi:latest` |
| Network Type | `Bridge` |
| WebUI | `http://[IP]:[PORT:8317]/management.html` |
| Port | host `8317` to container `8317/tcp` |
| App Data | `/mnt/user/appdata/cliproxyapi` to `/data`, read/write |
| Management Password | `MANAGEMENT_PASSWORD`, required |
| Client API Keys | `CLIPROXY_API_KEYS`, optional; read only when `config.yaml` is first created |
| Extra Parameters | `--restart=unless-stopped --log-driver json-file --log-opt max-size=10m --log-opt max-file=3` |

## Sign accounts in

Open the WebUI, enter the Management Password, and go to **OAuth Login**.

1. Choose **Claude** or **Codex** and open the sign-in link in a browser where that account is
   signed in.
2. After you approve, the browser lands on a `http://localhost:54545/...` (Claude) or
   `http://localhost:1455/...` (Codex) address that does not load, because the proxy runs on your
   server and not on the machine with the browser. Copy the full address from the address bar.
3. Paste it into **Callback URL** on the OAuth Login page and select **Submit Callback URL**
   within five minutes.

Repeat for each account. **Quota Management** then shows every account's usage and reset times.

## Connect clients

The client API key is in the console under **Config**, or in `access.api-keys` in
`/mnt/user/appdata/cliproxyapi/config.yaml`. Replace `PROXY_URL` with the address clients reach
the proxy at, for example `http://<server-ip>:8317` or a Tailscale HTTPS address.

Claude Code, in `~/.claude/settings.json`:

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "PROXY_URL",
    "ANTHROPIC_AUTH_TOKEN": "CLIENT_API_KEY",
    "CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY": "1"
  }
}
```

Codex, in `~/.codex/config.toml`:

```toml
model_provider = "cliproxyapi"

[model_providers.cliproxyapi]
name = "OpenAI"
base_url = "PROXY_URL/v1"
model_catalog_url = "PROXY_URL/v1/models"
experimental_bearer_token = "CLIENT_API_KEY"
wire_api = "responses"
requires_openai_auth = true
supports_websockets = true

[features]
api_key_model_discovery = true
```

`supports_websockets = true` is what makes Codex open a WebSocket to the proxy, and the proxy
then talks to ChatGPT over a WebSocket too.

Muse, in `~/.config/muse/settings.json`:

```json
{
  "endpoint_transport": {
    "base_url": "PROXY_URL/v1",
    "auth": "bearer"
  }
}
```

Muse only sends its key to an endpoint pinned in `settings.json`; passing `--base-url` is not
enough. Store the key with `muse auth set --api-key-stdin`, which reads it from standard input, or
set it in the `META_API_KEY` environment variable.

### One key per tool

The proxy translates between protocols, so any client API key can reach every signed-in account:
Codex could run on a Claude subscription and the other way round. To keep each tool on its own
provider, give each one its own key and tie the key's prefix to a provider in `config.yaml`:

```yaml
access:
  api-keys:
    - "sk-claude-<random>"
    - "sk-codex-<random>"
    - "sk-muse-<random>"

client:
  key-scopes:
    - key-prefix: "sk-claude-"
      providers: ["claude"]
    - key-prefix: "sk-codex-"
      providers: ["codex"]
    - key-prefix: "sk-muse-"
      providers: ["meta"]
```

A key with a scope only lists that provider's models, and a request for any other model is
answered `400 model_not_found`. A key that matches no entry is unrestricted, so remove the key the
container generated on first start once every tool has its own.
[FORK.md](https://github.com/ntindle/CLIProxyAPI/blob/main/FORK.md#key-scopes) has the details.

## Tailscale

The port is plain HTTP. To reach it over your tailnet with HTTPS, either run
`tailscale serve --bg --https=8317 http://127.0.0.1:8317` on the Unraid host, or turn on
**Use Tailscale** in the container settings with Serve pointed at port `8317`.

## Updates

The template tracks `:latest`, so Unraid sees a new image digest on its regular update check and
offers **apply update**. The fork merges the latest upstream release every Monday and publishes
a new image when the merge is clean.

Updating the image never touches `config.yaml` or the signed-in accounts.

## Backups

Back up the whole App Data path. `auths/` holds the OAuth credentials of every signed-in
account, and `config.yaml` holds the client API keys.

## Security

- Keep port `8317` on a trusted LAN or a VPN such as Tailscale. Do not expose it to the internet.
- Anyone with the Management Password can read every account's credentials through the console.
- Anyone with a client API key can spend the quota of every signed-in account.
- Use only accounts you own, and check each provider's terms before routing a subscription
  through a proxy.

## Support

- Template issues: <https://github.com/ntindle/unraid-apps/issues>
- Fork: <https://github.com/ntindle/CLIProxyAPI> (see `FORK.md` for what it adds)
- Upstream documentation: <https://help.router-for.me/>

## License

The template and its documentation are licensed under the [MIT License](../LICENSE). CLIProxyAPI
is also MIT-licensed; see [`THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md).
