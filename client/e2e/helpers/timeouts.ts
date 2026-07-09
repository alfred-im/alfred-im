/**
 * Timeout e2e — tetti bassi: login demo sano ≈ 5–15s.
 * Se un passo supera questi limiti, qualcosa non va (fail fast).
 */
export const E2E_TIMEOUT = {
  boot: 20_000,
  auth: 15_000,
  ui: 8_000,
  message: 15_000,
  db: 12_000,
} as const;

/** Intervalli poll Playwright (ms) — controlli ravvicinati all'inizio. */
export const E2E_POLL = [200, 300, 500, 1000] as const;
