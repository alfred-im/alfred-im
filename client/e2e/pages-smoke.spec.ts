// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import { test, expect } from '@playwright/test';

import { BASE_URL } from './helpers/multi-account';
import { isLocalSupabaseStack } from './helpers/local-auth';

test('stack locale mostra la schermata di login Alfred', async ({ page }) => {
  test.skip(!isLocalSupabaseStack(), 'richiede stack Supabase locale');
  test.skip(
    !(process.env.ALFRED_BASE_URL ?? BASE_URL).match(/localhost|127\.0\.0\.1/),
    'richiede ALFRED_BASE_URL locale',
  );

  const errors: string[] = [];
  page.on('pageerror', (err) => errors.push(err.message));

  await page.goto(BASE_URL, {
    waitUntil: 'networkidle',
    timeout: 90_000,
  });

  await expect(page.getByText('Accedi ad Alfred')).toBeVisible({
    timeout: 30_000,
  });
  await expect(page.getByRole('button', { name: 'Accedi' })).toBeVisible();

  expect(errors, `errori JS: ${errors.join('; ')}`).toEqual([]);
});
