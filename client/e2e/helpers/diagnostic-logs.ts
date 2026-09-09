// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import type { Page, TestInfo } from '@playwright/test';
import * as fs from 'node:fs';

import { isSnakeVerbose, snakeLog } from './snake-log';

/**
 * Raccoglie righe `[alfred]` dalla console browser (richiede build con
 * `ALFRED_DIAGNOSTIC_LOG=true`, es. `scripts/run-push-e2e-local.sh`).
 * In modalità verbose stampa ogni riga in tempo reale.
 */
export function attachDiagnosticLogCollector(page: Page): string[] {
  const logs: string[] = [];
  page.on('console', (msg) => {
    const text = msg.text();
    if (!text.includes('[alfred]')) return;
    logs.push(text);
    if (isSnakeVerbose()) {
      snakeLog('alfred', text);
    }
  });
  return logs;
}

/** Console browser, errori pagina e richieste fallite — streaming in tempo reale. */
export function attachVerboseBrowserLogging(page: Page): void {
  if (!isSnakeVerbose()) return;

  page.on('console', (msg) => {
    const type = msg.type();
    const text = msg.text();
    if (text.includes('[alfred]')) return;
    if (type === 'error' || type === 'warning') {
      snakeLog('browser', `[${type}] ${text}`);
    }
  });

  page.on('pageerror', (err) => {
    snakeLog('pageerror', err.message, { stack: err.stack?.split('\n')[0] });
  });

  page.on('requestfailed', (req) => {
    snakeLog('network', 'request failed', {
      method: req.method(),
      url: req.url(),
      error: req.failure()?.errorText ?? 'unknown',
    });
  });

  page.on('framenavigated', (frame) => {
    if (frame === page.mainFrame()) {
      snakeLog('nav', frame.url());
    }
  });
}

/** Testo da appendere ai messaggi `expect` quando il test fallisce. */
export function formatDiagnosticLogsFooter(logs: string[]): string {
  if (logs.length === 0) {
    return '(nessun log [alfred] — build senza ALFRED_DIAGNOSTIC_LOG?)';
  }
  return `log diagnostici:\n${logs.join('\n')}`;
}

/** Stampa il dump in stdout se il test non è passato. */
export function dumpDiagnosticLogsOnFailure(
  logs: string[],
  testInfo: TestInfo,
): void {
  if (testInfo.status === 'passed') return;
  if (logs.length === 0) {
    snakeLog('alfred', '(nessun log [alfred] raccolto)');
    return;
  }
  emitDiagnosticBlock(testInfo.title, logs);
}

function emitDiagnosticBlock(title: string, logs: string[]): void {
  const body = `[snake] === ALFRED DIAGNOSTIC LOGS (${title}) ===\n${logs.join('\n')}\n`;
  fs.writeSync(1, body);
}
