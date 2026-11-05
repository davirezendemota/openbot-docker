# OpenBot upstream + Tailscale sidecar binaries in one image.
# syntax=docker/dockerfile:1

ARG OPENBOT_IMAGE=ghcr.io/nightly-labs/openbot:0.57.0@sha256:84aadc0ce11beeadabfa1f17e4cc4d56bc27ed45f3ff9f3dbf7a6b3fe03471ef
ARG TAILSCALE_IMAGE=tailscale/tailscale:stable@sha256:ed6480b33c6eb67c9cbd203ed42b9fb57e361986725b6856def71b7a3d9e276c

FROM ${TAILSCALE_IMAGE} AS tailscale

FROM ${OPENBOT_IMAGE}

USER root

COPY --from=tailscale /usr/local/bin/tailscale /usr/local/bin/tailscaled /usr/local/bin/

RUN mkdir -p /var/lib/tailscale /var/run/tailscale \
    && chmod 755 /var/lib/tailscale /var/run/tailscale

COPY entrypoint.sh /usr/local/bin/openbot-entrypoint.sh
RUN chmod 755 /usr/local/bin/openbot-entrypoint.sh

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/openbot-entrypoint.sh"]
