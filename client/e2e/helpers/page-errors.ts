// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import type { Page } from '@playwright/test';

import { isSnakeVerbose, snakeLog } from './snake-log';

/** Errori Flutter noti in e2e headless durante switch account rapido (non assert UI). */
const BENIGN_PAGE_ERROR_PATTERNS = [
  /InboxController was used after being disposed/,
];

/**
 * Raccoglie `pageerror` non benigni per assert finale.
 * Restituisce l'array mutabile da passare a `expect(errors).toEqual([])`.
 */
export function attachPageErrorCollector(page: Page): string[] {
  const errors: string[] = [];
  page.on('pageerror', (err) => {
    const message = err.message;
    if (BENIGN_PAGE_ERROR_PATTERNS.some((re) => re.test(message))) {
      if (isSnakeVerbose()) {
        snakeLog('pageerror', `benign ignored: ${message}`);
      }
      return;
    }
    errors.push(message);
    if (isSnakeVerbose()) {
      snakeLog('pageerror', `collected: ${message}`);
    }
  });
  return errors;
}
