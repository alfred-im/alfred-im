#!/usr/bin/env bash
# Copyright (C) 2026 im.alfred
#
# SPDX-License-Identifier: GPL-3.0-or-later

# Compatibilità: flusso-reale → release snake (unico e2e gate).
exec bash "$(dirname "$0")/test.sh" e2e "$@"
