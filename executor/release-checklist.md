# Release checklist

## Repository and image

- [ ] Repository is public and the default branch is `main`.
- [ ] Root MIT license, `ca_profile.xml`, template XML, and icon are present.
- [ ] `scripts/validate.sh`, shell syntax, ShellCheck, and the runtime smoke test
      pass on the exact release commit.
- [ ] The `latest` image resolves to the intended stable Executor release and
      exists for `linux/amd64` and `linux/arm64`; record its digest for rollback.
- [ ] Public project, support, registry, readme, template, and icon URLs return
      successfully when signed out.

## Unraid acceptance

- [ ] Recreate the exact template fields in current Docker Authoring Mode; the
      Unraid 7.2 form has no visible raw-template URL importer.
- [ ] Confirm bridge networking, non-privileged mode, host/container port,
      appdata target, and environment variables survive save and reopen.
- [ ] Start with an isolated host port and appdata path; confirm healthy state.
- [ ] Complete browser first-run with the exact configured Web Base URL.
- [ ] Confirm first-account ownership and invite-only subsequent signup.
- [ ] Connect a remote MCP client and verify allow, approval, and block policies.
- [ ] Recreate against the same appdata and verify state and keys persist.
- [ ] Stop through the native Unraid UI and confirm a clean exit.
- [ ] Confirm no array, parity, pool, share, flash, or unrelated container state
      was modified during validation.

## Community Applications

- [ ] Review the rendered listing, beta marker, icon, settings, descriptions,
      support links, and category.
- [ ] Run **Validate** and then **Scan** at <https://ca.unraid.net/submit> after
      the final XML change.
- [ ] Resolve duplicate/provenance findings from the live CA feed.
- [ ] Submit the exact tested commit for moderator review.
- [ ] Record the submission reference, image digest, commit, and date.
