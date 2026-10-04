# Third-party notices

The templates deploy other projects' applications. Their names and artwork are used only to
identify the software a template installs; no template here is affiliated with or endorsed by
the project it deploys. This repository's MIT License covers the templates, launcher scripts and
documentation; it grants no rights in those names or that artwork.

The two icons copied from other projects come from MIT-licensed repositories. Each is used under
its copyright notice below and the MIT permission notice, which is word for word the one in
[`LICENSE`](LICENSE).

## CLIProxyAPI

The CLIProxyAPI template deploys the [ntindle fork](https://github.com/ntindle/CLIProxyAPI) of
[`router-for-me/CLIProxyAPI`](https://github.com/router-for-me/CLIProxyAPI) and does not
redistribute its binaries. CLIProxyAPI is licensed under the MIT License. Its upstream license
identifies:

```text
Copyright (c) 2025-2005.9 Luis Pater
Copyright (c) 2025.9-present Router-For.ME
```

[`images/cliproxyapi.png`](images/cliproxyapi.png) is the logo of the upstream management
console, [`router-for-me/Cli-Proxy-API-Management-Center`](https://github.com/router-for-me/Cli-Proxy-API-Management-Center)
(MIT License), cropped to a square and scaled to 512x512. The source file was `logo.jpg`, Git
blob `f701a6c2268cd3a7b22e63487f13778b6e9ca4af`. That repository's license identifies:

```text
Copyright (c) 2026 Router-For.ME
```

## Executor

The Executor template deploys the upstream
[`UsefulSoftwareCo/executor`](https://github.com/UsefulSoftwareCo/executor) project, maintained
by Useful Software Co., and does not redistribute its application binaries. Executor is licensed
under the MIT License. Its upstream license identifies:

```text
Copyright (c) 2026 Rhys Sullivan
```

[`images/executor.png`](images/executor.png) is copied from `assets/executor-icon.png` in the
upstream repository to give the Unraid listing a stable visual asset. The source object was Git
blob `a7cc57de9f1992625720221a1004d4d023fcc5b4`, and the copied PNG has SHA-256
`b397f102f789c00365cc7910be4f1b297bef7fcacd6592b7f66f227f3388cfc8`.

## Supermemory

The Supermemory template and launcher image deploy `supermemory-server`, published by
Supermemory at <https://github.com/supermemoryai/supermemory/releases>. This repository and its
image do not redistribute that binary: the launcher downloads it from Supermemory's releases
onto the user's own server. Its use is governed by Supermemory's license; the server prints its
license notice at startup.

`ghcr.io/ntindle/unraid-apps/supermemory` is built from `debian:bookworm-slim` with the Debian
packages `ca-certificates`, `curl` and `nginx-light`, each under its own license as recorded in
`/usr/share/doc/*/copyright` inside the image.

[`images/supermemory.png`](images/supermemory.png) is original artwork made for this
repository and is covered by its MIT License. It is not Supermemory's logo.
