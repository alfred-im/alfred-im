# Copyright (C) 2026 im.alfred
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Build context: repository root (fly deploy . --dockerfile client/deploy/fly/Dockerfile)

# syntax=docker/dockerfile:1

# Flutter 3.44.6 / Dart 3.12.2 — matches VM snapshot (see AGENTS.md).
# cirruslabs/flutter:3.44.0 ships Dart 3.12.0, below client/pubspec ^3.12.2.
FROM ghcr.io/adrianjagielak/flutter:3.44.6 AS build
WORKDIR /app/client

COPY client/pubspec.yaml client/pubspec.lock ./
RUN flutter pub get

COPY client/ ./

# Instance wiring (operators edit client/deploy/fly/config.json before deploy).
COPY client/deploy/fly/config.json web/config.json
COPY client/deploy/fly/manifest.json web/manifest.json

RUN flutter build web --release \
    --base-href / \
    --no-pub \
    --no-wasm-dry-run

RUN rm -rf build/web/canvaskit

FROM nginx:alpine AS runtime
RUN rm -f /etc/nginx/conf.d/default.conf
COPY client/deploy/fly/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/client/build/web /usr/share/nginx/html
EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]
