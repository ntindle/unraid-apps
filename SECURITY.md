# Security policy

## Reporting a problem

Use this repository's private security-advisory flow for vulnerabilities in a template, a
launcher image or the documentation. Report vulnerabilities in an application itself to its
own project.

Do not include passwords, API keys, the contents of an App Data path, or unredacted container
logs in a public issue.

## Deployment boundary

No template here grants privileged mode, mounts the Docker socket, or mounts arbitrary Unraid
shares. Each one publishes only the ports and the single App Data path its documentation lists.

## Supermemory

- The launcher downloads `supermemory-server` from Supermemory's GitHub releases at first start
  and refuses to run a file whose SHA-256 does not match. For the versions in
  [`supermemory/checksums.txt`](supermemory/checksums.txt) the expected value is pinned in the
  image; for other versions it is read from the release itself, which proves the download is
  intact, not who built it.
- The server skips its API key for requests that send a loopback `Host` header. The launcher's
  host guard closes this on the published port. Other containers on the same Docker network can
  still reach the server's internal port directly.
- App Data holds every stored memory, the API key and the database's key.
