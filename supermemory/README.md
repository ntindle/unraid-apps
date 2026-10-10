# Supermemory for Unraid

An unofficial Unraid template and launcher image for
[Supermemory's self-hosted server](https://supermemory.ai/docs/self-hosting/overview).

It gives your coding agents one memory store on your own server. Clients send it what they
learn; the server extracts memories with the LLM you configure, embeds them locally, and serves
them back through the Supermemory API.

## What the template deploys

- Image: `ghcr.io/ntindle/unraid-apps/supermemory:latest`
- Port `6767`: the Supermemory API
- Port `6769`: the web console, only when **Console Password** is set
- Persistent state: `/data`, mapped to `/mnt/user/appdata/supermemory`
- Network mode: bridge. Privileged mode: off.

The image is a launcher. It does not contain Supermemory's server. On the first start the
entrypoint downloads the `supermemory-server` release named by **Server Version** from
[Supermemory's GitHub releases](https://github.com/supermemoryai/supermemory/releases) into
`/data/bin`, checks it against the SHA-256 pinned in the image, and runs it as user `99:100`.
Every later start re-checks the file and reuses it.

| Path in App Data | Contents |
| --- | --- |
| `bin/` | The downloaded server, about 300 MB per version |
| `store/` | The encrypted database, the embedding model, the workflow engine's state |
| `store/api-key` | The API key clients send |
| `store/machine-key` | The key that unlocks the database |

## Install

1. Copy [`templates/supermemory.xml`](../templates/supermemory.xml) to
   `/boot/config/plugins/dockerMan/templates-user/my-Supermemory.xml` and pick it in
   **Docker → Add Container**.
2. Set one LLM provider (see below).
3. Start the container. The first start downloads the server and takes a minute or two; the
   container reports healthy once the API answers.
4. Read the API key:

   ```bash
   cat /mnt/user/appdata/supermemory/store/api-key
   ```

## LLM provider

The server needs one LLM to turn what clients send into memories. Without one the container
exits with an error.

| Provider | Fields |
| --- | --- |
| OpenAI | **LLM API Key** |
| An OpenAI-compatible endpoint | **LLM Base URL** (its `/v1` address), **LLM API Key**, **LLM Model** |
| Anthropic | **Anthropic API Key** |
| Gemini | **Gemini API Key** |

An OpenAI-compatible endpoint must serve `/chat/completions` with tool calls. From inside the
container, a service on the Unraid host is at `http://172.17.0.1:<port>`.

Only a Gemini key lets the server read images, video and scanned PDFs. Text works with every
provider.

Embeddings run inside the container with `Xenova/bge-base-en-v1.5`, an English model. The
server downloads it the first time a document is added. The embedding model cannot be changed
once the database holds data.

## Connect clients

Clients need the server's address, `http://<server-ip>:6767`, and the API key.

| Client | Address setting | Key setting |
| --- | --- | --- |
| [Claude Code plugin](https://github.com/supermemoryai/claude-supermemory) | `SUPERMEMORY_API_URL` | `SUPERMEMORY_CC_API_KEY` |
| [Codex plugin](https://github.com/supermemoryai/codex-supermemory) | `SUPERMEMORY_API_URL` | `SUPERMEMORY_CODEX_API_KEY` |
| [Muse Code plugin](https://github.com/supermemoryai/muse-supermemory) | `SUPERMEMORY_API_URL` | `SUPERMEMORY_MUSE_API_KEY` |
| [OpenCode plugin](https://github.com/supermemoryai/opencode-supermemory) | `SUPERMEMORY_API_URL` | `SUPERMEMORY_API_KEY` |
| [OpenClaw plugin](https://github.com/supermemoryai/openclaw-supermemory) | `SUPERMEMORY_BASE_URL` | `SUPERMEMORY_OPENCLAW_API_KEY` |
| [Hermes plugin](https://github.com/supermemoryai/hermes-supermemory) | `SUPERMEMORY_BASE_URL` | `SUPERMEMORY_API_KEY` |
| Supermemory SDKs | `baseURL` (TypeScript), `base_url` (Python) | `apiKey`, `api_key` |

With curl:

```bash
curl http://<server-ip>:6767/v3/documents \
  -H "Authorization: Bearer $SUPERMEMORY_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"content": "The backup job runs at 03:00.", "containerTag": "notes"}'
```

```bash
curl http://<server-ip>:6767/v4/search \
  -H "Authorization: Bearer $SUPERMEMORY_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"q": "when does the backup run", "containerTag": "notes"}'
```

A document moves through `queued`, `extracting`, `chunking`, `embedding` and `indexing` before
it is `done`, which takes one to two minutes.

## Web console

The server ships a web console at `/#memory` that lists documents and draws the memory graph.
It sends no API key, so it only works for requests the server treats as local.

Set **Console Password** to turn on port `6769`. It asks for user `admin` and that password,
then forwards to the server as a local request, so the console works from a browser and the
**WebUI** button in Unraid opens it. Anyone who signs in can read and change every stored
memory. With the password empty, nothing listens on `6769`.

## What this build does not do

- The server's license notice limits it to 10,000 documents.
- It has one API key and one organization. Separate clients by container tag.
- It has no connectors (Google Drive, Notion, Gmail, OneDrive) and no MCP endpoint. The extra
  search tools some plugins reach through Supermemory's hosted MCP server are not available.

## Host guard

The server skips its API key for any request whose `Host` header names the loopback address
(`localhost`, `127.0.0.1`, `[::1]`). A client on the network can send that header, so a
published port would be open to anyone who can reach it.

The launcher puts nginx on port `6767` and runs the server on an internal port. nginx forwards
every request with a fixed, non-loopback `Host`, so every API request needs the key. Set
**Host Guard** to `off` to get the server's own behaviour back.

The guard covers the published port. Other containers on the same Docker network can still
reach the server's internal port, `16767`, directly.

## Updates

**Server Version** selects the `supermemory-server` release. The image pins the SHA-256 of the
versions listed in [`checksums.txt`](checksums.txt). For any other version the launcher reads
the checksum published with that release; set `SUPERMEMORY_SHA256` to pin it yourself.

Back up App Data before changing the version. An older server may not read a database a newer
one has written.

The template tracks `:latest` of the launcher image, so Unraid offers **apply update** when the
launcher changes. Updating it does not change the server version or touch App Data.

## Memory

The server holds its whole database in memory, and that memory never shrinks. It pauses
ingestion while its memory use is more than a limit above what it used at startup, and resumes
only when use falls back under. As the database grows, use stays above the limit and the pause
becomes permanent. Version 0.0.8 then loses memories rather than delaying them: text sent to a
session whose document is still waiting is acknowledged and dropped, and documents left waiting
are marked failed after a few retries.

**Ingest Memory Limit** (`SUPERMEMORY_EMBEDDING_RAM_LIMIT`) sets that limit. The server's own
default is `1gb`, which a busy store outgrows within days; the template sets `4gb`. Accepted values
look like `4gb`, `8gb` or `512mb`; anything else silently falls back to `1gb`. The container log
shows the value in effect at startup:

```text
[ingest] memory limit 4.0 GB above baseline (1.8 GB) · 2 concurrent
```

A stalled server logs this repeatedly:

```text
[ingest] 0 running · 234 queued · paused — 1.0 GB / 1.0 GB ingest memory, waiting for it to drop
```

To recover, stop the container with time to save (`docker stop -t 120 Supermemory`), raise the
limit, and start it again. A restart alone also clears the pause, until the database grows by
about the limit again.

## Stopping the container

The server keeps its database in memory and writes it to `store/data` within about a minute of
a change, and once more when it is stopped. A stop that is cut short, a kill or
a power loss loses whatever was written since the last save.

Unraid stops a container with its own **Docker stop timeout** (Settings → Docker, 10 seconds
by default), whatever the template asks for. The save takes longer as the database grows, so
raise that setting if the container log shows `Snapshot` times close to it.

## Backups

Back up the whole App Data path. `store/` holds the database and the `machine-key` that unlocks
it; one without the other is not recoverable.

## Security

- Keep port `6767` on a trusted LAN or a VPN such as Tailscale. Do not expose it to the
  internet.
- Anyone with the API key can read and change every stored memory.
- App Data holds every memory and both keys. Treat it as a secret.
- The server prints its API key in the container log at every start. Treat the log as secret
  too, and filter that line out when sharing log output.
- The LLM provider receives the content clients send.
