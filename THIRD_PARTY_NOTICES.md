# Third-party notices

## Supermemory

The Supermemory template and launcher image deploy `supermemory-server`, published by
Supermemory at <https://github.com/supermemoryai/supermemory/releases>. This repository and its
image do not redistribute that binary: the launcher downloads it from Supermemory's releases
onto the user's own server. Its use is governed by Supermemory's license; the server prints its
license notice at startup.

The Supermemory name is used only to identify the application. This template is not affiliated
with or endorsed by Supermemory.

## Launcher image

`ghcr.io/ntindle/unraid-apps/supermemory` is built from `debian:bookworm-slim` with the Debian
packages `ca-certificates`, `curl` and `nginx-light`, each under its own license as recorded in
`/usr/share/doc/*/copyright` inside the image.

## Icons

[`images/supermemory.png`](images/supermemory.png) is original artwork made for this
repository and is covered by its MIT License. It is not Supermemory's logo.
