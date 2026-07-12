// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import { test, expect } from '@playwright/test';

test('GitHub Pages mostra la schermata di login Alfred', async ({ page }) => {
  const errors: string[] = [];
  page.on('pageerror', (err) => errors.push(err.message));

  await page.goto('https://alfred-im.github.io/alfred-im/', {
    waitUntil: 'networkidle',
    timeout: 90_000,
  });

  await expect(page.getByText('Accedi ad Alfred')).toBeVisible({
    timeout: 30_000,
  });
  await expect(page.getByRole('button', { name: 'Accedi' })).toBeVisible();

  expect(errors, `errori JS: ${errors.join('; ')}`).toEqual([]);
});
