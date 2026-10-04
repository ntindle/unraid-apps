# Launcher image for Supermemory's self-hosted server.
#
# The server binary is not part of this image. The entrypoint downloads the release named by
# SUPERMEMORY_VERSION from Supermemory's GitHub releases into the data volume on first start,
# checks its SHA-256, and runs it as an unprivileged user behind a small nginx host guard.
FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install --yes --no-install-recommends ca-certificates curl nginx-light \
    && rm -rf /var/lib/apt/lists/*

COPY checksums.txt /usr/local/share/supermemory/checksums.txt
COPY --chmod=0755 entrypoint.sh /usr/local/bin/entrypoint.sh

ENV SUPERMEMORY_VERSION=0.0.8 \
    PORT=6767 \
    PUID=99 \
    PGID=100 \
    SUPERMEMORY_HOST_GUARD=on

VOLUME /data
EXPOSE 6767

# The first start downloads the server (about 300 MB) before it listens.
HEALTHCHECK --interval=30s --timeout=5s --start-period=10m --retries=3 \
    CMD curl --fail --silent --show-error --output /dev/null "http://127.0.0.1:${PORT}/" || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
