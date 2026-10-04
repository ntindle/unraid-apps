# Security policy

## Reporting a problem

Use this repository's private security-advisory flow for vulnerabilities in
the Unraid template or its documentation. Report vulnerabilities in Executor
itself to the upstream project through
<https://github.com/UsefulSoftwareCo/executor/security>.

Do not include passwords, API keys, OAuth tokens, cookies, invite links, the
contents of `/data`, or unredacted container logs in a public issue.

## Deployment boundary

The template does not grant privileged mode, mount the Docker socket, or mount
arbitrary Unraid shares. It exposes only TCP port `4788` and the persistent
`/data` path.

The defaults keep sandboxed private-network access and stdio MCP execution
disabled. Enabling either setting deliberately expands what configured
workflows can reach or execute and should be paired with appropriately narrow
Executor policies.
