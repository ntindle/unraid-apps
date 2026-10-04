# Unraid apps

Unofficial Unraid templates maintained by ntindle. Each app has a template in
[`templates/`](templates), an icon in [`images/`](images) and, when it needs its own image, a
folder with the image source and its documentation.

| App | Template | Image | Docs |
| --- | --- | --- | --- |
| Supermemory | [`templates/supermemory.xml`](templates/supermemory.xml) | `ghcr.io/ntindle/unraid-apps/supermemory:latest` | [`supermemory/README.md`](supermemory/README.md) |

Two more templates live in their own repositories:
[CLIProxyAPI](https://github.com/ntindle/cliproxyapi-unraid) and
[Executor](https://github.com/ntindle/executor-unraid).

## Install an app

1. Copy the app's template to `/boot/config/plugins/dockerMan/templates-user/my-<Name>.xml` on
   the Unraid server, where `<Name>` is the `<Name>` inside the template.
2. In **Docker → Add Container**, pick it from the template list.
3. Fill in the fields the app's documentation calls for and select **Apply**.

## Checks

```bash
scripts/validate.sh
```

checks every template, the profile and the icons. Each app with its own image also has a smoke
test that boots the image and checks the container contract:

```bash
scripts/smoke-test-supermemory.sh
```

CI runs both on every push and publishes an app's image only after its smoke test passes.

## Support

Open an issue at <https://github.com/ntindle/unraid-apps/issues>. Do not include API keys,
passwords or the contents of an App Data path.

## License

The templates, launcher scripts and documentation are licensed under the [MIT License](LICENSE).
The applications they deploy have their own licenses; see
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).
