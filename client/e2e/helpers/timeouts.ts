// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

/**
 * Timeout e2e — fail fast in locale; più margine in CI (Actions headless).
 */
const CI_SCALE = process.env.CI ? 2 : 1;

export const E2E_TIMEOUT = {
  boot: 12_000 * CI_SCALE,
  auth: process.env.CI ? 90_000 : 30_000,
  ui: 8_000 * CI_SCALE,
  message: 20_000 * CI_SCALE,
  db: 15_000 * CI_SCALE,
} as const;

/** Intervalli poll Playwright (ms) — controlli ravvicinati all'inizio. */
export const E2E_POLL = [200, 300, 500, 1000] as const;
