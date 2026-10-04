# Unraid apps

Unofficial Unraid templates maintained by ntindle. Each app has a template in
[`templates/`](templates), an icon in [`images/`](images) and a folder with its documentation
and, when it needs its own image, the image source.

| App | What it is | Template | Image | Docs |
| --- | --- | --- | --- | --- |
| CLIProxyAPI | Puts Claude Code, Codex and Muse behind one endpoint, spread across your own subscription accounts | [`templates/cliproxyapi.xml`](templates/cliproxyapi.xml) | `ghcr.io/ntindle/cliproxyapi:latest` ([fork](https://github.com/ntindle/CLIProxyAPI)) | [`cliproxyapi/README.md`](cliproxyapi/README.md) |
| Executor | MCP gateway: one endpoint for MCP, OpenAPI and GraphQL integrations, credentials and tool policies held centrally | [`templates/executor.xml`](templates/executor.xml) | `ghcr.io/usefulsoftwareco/executor-selfhost:latest` (official) | [`executor/README.md`](executor/README.md) |
| Supermemory | One memory store for your coding agents | [`templates/supermemory.xml`](templates/supermemory.xml) | `ghcr.io/ntindle/unraid-apps/supermemory:latest` (built here) | [`supermemory/README.md`](supermemory/README.md) |

CLIProxyAPI and Executor used to live in their own repositories, `ntindle/cliproxyapi-unraid`
and `ntindle/executor-unraid`. Their history is part of this repository's; the old repositories
are archived.

## Install an app

1. Copy the app's template to `/boot/config/plugins/dockerMan/templates-user/my-<Name>.xml` on
   the Unraid server, where `<Name>` is the `<Name>` inside the template.
2. In **Docker → Add Container**, pick it from the template list.
3. Fill in the fields the app's documentation calls for and select **Apply**.

## Checks

```bash
scripts/validate.sh
```

checks every template, the profile and the icons, and each template's container contract. Each
app also has a smoke test that boots its image the way the template runs it:

```bash
scripts/smoke-test-cliproxyapi.sh
scripts/smoke-test-executor.sh
scripts/smoke-test-supermemory.sh
```

CI runs all of them on every push and pull request, and daily so a broken upstream `:latest`
image shows up. It publishes an image built here only after its smoke test passes.

## Upstream updates

How each app follows its upstream. Nothing here changes a running server: an install picks up a
new image only when **apply update** is pressed on Unraid's Docker tab.

| App | Upstream | How it follows |
| --- | --- | --- |
| CLIProxyAPI | [router-for-me/CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI) releases | The [fork](https://github.com/ntindle/CLIProxyAPI) merges the latest release weekly, checks it and publishes `:latest`; a conflict opens an issue there |
| Executor | the official image's `:latest` | Unraid sees each new digest directly; CI's daily run smoke-tests it |
| Supermemory | [supermemory-server releases](https://github.com/supermemoryai/supermemory/releases) | The daily [Upstream](.github/workflows/upstream.yml) workflow boots each new stable release in the smoke test and opens a pull request with the result; `scripts/bump-supermemory.sh <version>` does the same change by hand |

An installed Supermemory keeps its **Server Version** in its own template, so a merged version
change reaches it only when that field is edited; see
[`supermemory/README.md`](supermemory/README.md#updates).

## Support

Open an issue at <https://github.com/ntindle/unraid-apps/issues>. Do not include API keys,
passwords or the contents of an App Data path.

## License

The templates, launcher scripts and documentation are licensed under the [MIT License](LICENSE).
The applications they deploy have their own licenses; see
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).
