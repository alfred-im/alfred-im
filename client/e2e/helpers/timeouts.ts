// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

/**
 * Timeout e2e — fail fast: stack sano ≈ pochi secondi per passo.
 */
export const E2E_TIMEOUT = {
  boot: 12_000,
  auth: 10_000,
  ui: 6_000,
  message: 10_000,
  db: 8_000,
} as const;

/** Intervalli poll Playwright (ms) — controlli ravvicinati all'inizio. */
export const E2E_POLL = [200, 300, 500, 1000] as const;
