# Security policy

## Reporting a problem

Use this repository's private security-advisory flow for vulnerabilities in the Unraid template
or its documentation. Report vulnerabilities in the proxy itself to
<https://github.com/ntindle/CLIProxyAPI/security> when they concern what the fork adds, and to
<https://github.com/router-for-me/CLIProxyAPI/security> otherwise.

Do not include passwords, API keys, OAuth tokens, the contents of `/data`, or unredacted
container logs in a public issue.

## Deployment boundary

The template does not grant privileged mode, mount the Docker socket, or mount arbitrary Unraid
shares. It exposes only TCP port `8317` and the persistent `/data` path.

`/data/auths` holds the OAuth credentials of every signed-in account and `/data/config.yaml`
holds the client API keys. The management password gives access to both through the web
console, and a client API key can spend the quota of every signed-in account. Keep the port on
a trusted LAN or VPN.
