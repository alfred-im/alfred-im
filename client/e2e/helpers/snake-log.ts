// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import { test } from '@playwright/test';

function snakeTimestamp(): string {
  const d = new Date();
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`;
}

/** Abilitato di default; disattivare con ALFRED_SNAKE_VERBOSE=0. */
export function isSnakeVerbose(): boolean {
  return process.env.ALFRED_SNAKE_VERBOSE !== '0';
}

/** Emesso nel worker; il reporter snake-stdio lo inoltra senza buffer. */
function emit(line: string): void {
  console.log(line);
}

let activeStep: { id: string; startedAt: number } | null = null;
let lastDedupLine = '';
let lastDedupAt = 0;

function emitMaybeDeduped(line: string): void {
  const now = Date.now();
  if (line === lastDedupLine && now - lastDedupAt < 250) {
    return;
  }
  lastDedupLine = line;
  lastDedupAt = now;
  emit(line);
}

/** Log libero — sempre visibile quando verbose è attivo. */
export function snakeLog(
  category: string,
  message: string,
  data?: Record<string, unknown>,
): void {
  if (!isSnakeVerbose()) return;
  const payload =
    data && Object.keys(data).length > 0 ? ` ${JSON.stringify(data)}` : '';
  emitMaybeDeduped(
    `[snake] ${snakeTimestamp()} · ${category} ${message}${payload}`,
  );
}

/** Inizio passo core; chiude automaticamente il passo precedente. */
export function snakeStep(stepId: string, detail?: string): void {
  finalizeActiveStep('next');
  activeStep = { id: stepId, startedAt: Date.now() };
  const suffix = detail ? ` detail=${detail}` : '';
  emit(`[snake] ${snakeTimestamp()} >>> BEGIN step=${stepId}${suffix}`);
}

export function snakeStepDone(stepId: string, detail?: string): void {
  const suffix = detail ? ` ${detail}` : '';
  emit(`[snake] ${snakeTimestamp()} <<< DONE step=${stepId}${suffix}`);
  if (activeStep?.id === stepId) {
    activeStep = null;
  }
}

export function snakeStepFail(
  stepId: string,
  detail: string,
  error?: unknown,
): void {
  const err =
    error instanceof Error ? error.message : error ? String(error) : '';
  emit(
    `[snake] ${snakeTimestamp()} !!! FAIL step=${stepId} ${detail}${err ? ` err=${err}` : ''}`,
  );
  if (activeStep?.id === stepId) {
    activeStep = null;
  }
}

/** Chiude l'ultimo passo aperto (fine serpente o teardown). */
export function snakeFinalize(reason = 'complete'): void {
  finalizeActiveStep(reason);
}

function finalizeActiveStep(reason: string): void {
  if (!activeStep) return;
  const elapsed = Date.now() - activeStep.startedAt;
  emit(
    `[snake] ${snakeTimestamp()} <<< DONE step=${activeStep.id} ${elapsed}ms (${reason})`,
  );
  activeStep = null;
}

export function snakeActiveStepId(): string | null {
  return activeStep?.id ?? null;
}

/** Passo async con log BEGIN/DONE/FAIL e `test.step` Playwright. */
export async function snakeStepAsync<T>(
  stepId: string,
  fn: () => Promise<T>,
  detail?: string,
): Promise<T> {
  const run = async (): Promise<T> => {
    snakeStep(stepId, detail);
    const started = Date.now();
    try {
      const result = await fn();
      snakeStepDone(stepId, `${Date.now() - started}ms`);
      return result;
    } catch (error) {
      snakeStepFail(stepId, `${Date.now() - started}ms`, error);
      throw error;
    }
  };
  if (isSnakeVerbose()) {
    return test.step(`snake:${stepId}`, run);
  }
  return run();
}

/** Banner iniziale — invocare all'avvio del serpente. */
export function snakeLogBanner(extra?: Record<string, unknown>): void {
  if (!isSnakeVerbose()) return;
  emit(`[snake] ${snakeTimestamp()} ═══ RELEASE SNAKE VERBOSE ═══`);
  snakeLog('env', 'configurazione', {
    ALFRED_BASE_URL: process.env.ALFRED_BASE_URL ?? '(default localhost:8080)',
    CI: process.env.CI ?? '0',
    ALFRED_SNAKE_VERBOSE: process.env.ALFRED_SNAKE_VERBOSE ?? '1',
    ...extra,
  });
}

/** Riepilogo al fallimento. */
export function snakeLogFailureSummary(
  title: string,
  extra?: Record<string, unknown>,
): void {
  emit(`[snake] ${snakeTimestamp()} ═══ RELEASE SNAKE FAILED ═══`);
  snakeLog('fail', title, {
    activeStep: snakeActiveStepId(),
    ...extra,
  });
}
