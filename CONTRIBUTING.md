# Contributing

Changes stay at the Unraid layer: templates, icons, launcher images and their documentation.
Bugs and feature requests for an application belong in that application's own repository.

Before opening a pull request:

1. Run `scripts/validate.sh` (needs `xmllint`, `file` and `sha256sum`).
2. Run the smoke test of each app you changed, `scripts/smoke-test-<app>.sh`, where Docker is
   available.
3. Review the diff for credentials, host-specific addresses and unsafe mounts.
4. For Executor, when the upstream image a release was checked against changes, update the
   template's `<Changes>` entry and [`executor/validation.md`](executor/validation.md).

Never commit App Data, generated keys, database files, browser sessions, or container logs that
may contain secrets.

## Adding an app

1. `templates/<app>.xml`, with `TemplateURL`, `Icon`, `ReadMe` and `Support` pointing at this
   repository (`scripts/validate.sh` checks them).
2. `images/<app>.png`, a square PNG.
3. `<app>/README.md`, and the image source in the same folder if the app needs its own image.
4. `scripts/smoke-test-<app>.sh` and a job for it in `.github/workflows/ci.yml`.
5. A row in the README's table, and the app's sections in `SECURITY.md` and
   `THIRD_PARTY_NOTICES.md`.
