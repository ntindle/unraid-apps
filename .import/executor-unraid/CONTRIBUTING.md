# Contributing

Changes should remain at the Unraid deployment-template layer. Product bugs and
feature requests belong in the upstream Executor repository.

Before opening a pull request:

1. Confirm `:latest` resolves to the intended stable release for `linux/amd64`
   and `linux/arm64`, and record its digest.
2. Run `scripts/validate.ps1` on Windows and `scripts/validate.sh` on Linux.
3. Run `scripts/smoke-test.sh` where Docker is available.
4. Review the diff for credentials, host-specific addresses, and unsafe mounts.
5. Update the template's `<Changes>` entry and `docs/validation.md` when the
   pinned image changes.

Never commit appdata, generated keys, database files, browser sessions, or
container logs that may contain secrets.
