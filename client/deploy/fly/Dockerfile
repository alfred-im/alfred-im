# Copyright (C) 2026 im.alfred
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Build context: repository root (fly deploy . --dockerfile client/deploy/fly/Dockerfile)

# syntax=docker/dockerfile:1

# Flutter 3.44.6 / Dart 3.12.2 — matches VM snapshot (see AGENTS.md).
FROM ghcr.io/adrianjagielak/flutter:3.44.6 AS build
WORKDIR /app/client

COPY client/pubspec.yaml client/pubspec.lock ./
RUN flutter pub get

COPY client/ ./

# Instance wiring (operators edit client/deploy/fly/config.json before deploy).
COPY client/deploy/fly/config.json web/config.json

RUN flutter build web --release \
    --base-href / \
    --no-pub \
    --no-wasm-dry-run

RUN rm -rf build/web/canvaskit
# Shell entry points are rendered dynamically by the gateway sidecar.
RUN rm -f build/web/index.html build/web/manifest.json

FROM nginx:alpine AS runtime
RUN apk add --no-cache python3 py3-pip

RUN rm -f /etc/nginx/conf.d/default.conf
COPY client/deploy/gateway/requirements.txt /opt/gateway/requirements.txt
RUN pip3 install --no-cache-dir --break-system-packages -r /opt/gateway/requirements.txt
COPY client/deploy/fly/nginx.conf /etc/nginx/conf.d/default.conf
COPY client/deploy/fly/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
COPY client/deploy/gateway/ /opt/gateway/
COPY --from=build /app/client/build/web /usr/share/nginx/html
EXPOSE 8080
ENTRYPOINT ["/entrypoint.sh"]
