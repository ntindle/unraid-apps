# Native PostgreSQL release

`ghcr.io/ntindle/unraid-apps/supermemory:postgres` is our opt-in Supermemory
release channel. `:0.0.8-ntindle.1` identifies its first immutable release.
The standard `:latest` launcher and Community Applications template are separate.

The image packages the reviewed patch source from
[`ntindle/supermemory`](https://github.com/ntindle/supermemory/tree/main/patches/postgres).
It downloads the original, checksum-pinned upstream server on first boot and
installs the patched binary into App Data. It does not redistribute the upstream
executable. Upstream licensing and document limits still apply.

## Migrate an existing installation

Follow the fork's [migration procedure](https://github.com/ntindle/supermemory/blob/main/patches/postgres/README.md).
Stop the original server, keep a complete untouched backup, and migrate a separate
offline copy. The importer verifies every application table before binding the
database to the existing machine key. Provision the dedicated application role
with the supplied tool. Do not point the application at an empty database or
change its machine key.

Use PostgreSQL 17 with pgvector 0.8; the tested database image is pinned in
`release.json`. Store its data outside the application container. Put both
containers on a dedicated Docker network. The database needs no published port
after migration. Preserve `/data/store/machine-key`, `/data/store/api-key`, models,
uploads and workflow state in the application's separate persistent directory.

Write the application-role connection URL to `/data/store/postgres-url`, readable
only by user 99 (mode 0600). The default `FACTORY_SUPERMEMORY_DATABASE_URL_FILE` points
there. Keep credentials out of templates, command arguments and logs. Retain
the existing provider configuration, API/console ports and host guard. Remove any
older `/data/repair/launch.sh` entrypoint override: the image owns its entrypoint.

In Unraid, set the application Repository to the `:postgres` channel, map its new
App Data directory, and select the dedicated network. Give PostgreSQL its own
persistent data mount and password-file mount. Enable database autostart before
the application. Rebuild through Unraid so the saved templates reproduce both
containers. The application refuses missing credentials, an unbound database,
unsupported upstream versions and disabled host guard.

## Updates, backup and rollback

Unraid can track `:postgres`; record the pulled digest before applying an update.
Each image identifies its release in `/opt/factory/release.json` and `--version`.
The verified runtime is installed atomically in `/data/postgres/releases/` and
reused after restarts. The upstream Server Version remains `0.0.8`; our release
version identifies the PostgreSQL patches and packaging together.

Back up native PostgreSQL with `pg_dump` and retain the matching application keys
and local workflow state. Never copy a running PostgreSQL data directory as a
backup. For application rollback after cutover, use a compatible previous native
PostgreSQL image against the current database. Returning to the pre-migration
embedded backup discards later writes, so it requires a deliberate recovery plan.

## Build and verify

```bash
scripts/build-supermemory-postgres.sh supermemory-postgres:test
SUPERMEMORY_POSTGRES_IMAGE=supermemory-postgres:test scripts/smoke-test-supermemory-postgres.sh
```

The smoke test creates disposable synthetic data and an isolated PostgreSQL
container. It checks missing-configuration refusal, binary identity, native schema,
non-superuser access, authentication (including forged localhost), and persistence
across both container restarts. It does not call a real LLM. The fork's integration
tools separately cover ingestion, recall, concurrency and crash recovery against a
private migrated copy. CI publishes the exact image that passed the smoke test;
release tags cannot be overwritten. Bump `release.json` for each new release.
