# The fixed base contains only the reviewed OS/launcher, not a server executable.
FROM ghcr.io/ntindle/unraid-apps/supermemory@sha256:efdeed9b785d07923b550453dba2cc5324d2050e0cdf67e167a10ca68c3a2cc2 AS source
ARG FORK_COMMIT
ARG SOURCE_SHA256
RUN test -n "$FORK_COMMIT" && test -n "$SOURCE_SHA256" \
    && curl --fail --silent --show-error --location --retry 3 \
       "https://codeload.github.com/ntindle/supermemory/tar.gz/${FORK_COMMIT}" -o /tmp/source.tar.gz \
    && printf '%s  /tmp/source.tar.gz\n' "$SOURCE_SHA256" | sha256sum --check --status \
    && mkdir /source \
    && tar -xzf /tmp/source.tar.gz --strip-components=1 -C /source

FROM ghcr.io/ntindle/unraid-apps/supermemory@sha256:efdeed9b785d07923b550453dba2cc5324d2050e0cdf67e167a10ca68c3a2cc2
ARG VCS_REF
ARG RELEASE_VERSION
ARG FORK_COMMIT
LABEL org.opencontainers.image.source="https://github.com/ntindle/unraid-apps" \
      org.opencontainers.image.revision="$VCS_REF" \
      org.opencontainers.image.version="$RELEASE_VERSION" \
      org.opencontainers.image.description="ntindle Supermemory edition with external PostgreSQL and durable ingestion" \
      ai.supermemory.fork-revision="$FORK_COMMIT"
COPY --from=source /source/patches/postgres/*.mjs /opt/factory/postgres/
COPY --from=source /source/patches/postgres/pins.json /source/patches/postgres/launch.sh /source/patches/postgres/LICENSE /opt/factory/postgres/
COPY release.json install.mjs /opt/factory/
COPY --chmod=0755 entrypoint.sh server.sh /opt/factory/
RUN test "$(sha256sum /usr/local/bin/entrypoint.sh | cut -d ' ' -f 1)" = 1b69adbb3acbc0c0e16603242101c17480c62e56aa24c444f5a667ec1a59c7a2
ENV SUPERMEMORY_VERSION=0.0.8 \
    SUPERMEMORY_HIDE_API_KEY_IN_LOGS=1 \
    SUPERMEMORY_DISABLE_TELEMETRY=1 \
    FACTORY_SUPERMEMORY_DATABASE_URL_FILE=/data/store/postgres-url
STOPSIGNAL SIGTERM
ENTRYPOINT ["/opt/factory/entrypoint.sh"]
