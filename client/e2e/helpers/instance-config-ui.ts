// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import { expect, type Page } from '@playwright/test';

import { enableFlutterAccessibility } from './flutter-a11y';
import type { InstanceConfigExpectation } from './instance-config';
import { fillFlutterTextField } from './multi-account';
import { E2E_TIMEOUT } from './timeouts';

const FIELD_LABELS = {
  displayName: 'Nome visualizzato',
  imServerId: 'ID server IM',
  shortName: 'Nome breve',
  description: 'Descrizione',
  themeColor: 'Colore tema',
  backgroundColor: 'Colore sfondo',
  privacyUrl: 'Privacy',
  termsUrl: 'Termini',
  supportUrl: 'Supporto',
} as const;

export async function expectConfigButtonVisible(
  page: Page,
  visible: boolean,
): Promise<void> {
  const configButton = page.getByRole('button', {
    name: 'Configurazione server',
    exact: true,
  });
  await expect
    .poll(
      async () => {
        await enableFlutterAccessibility(page);
        return configButton.isVisible().catch(() => false);
      },
      { timeout: E2E_TIMEOUT.auth, intervals: [300, 500, 800] },
    )
    .toBe(visible);
}

export async function openInstanceConfigScreen(page: Page): Promise<void> {
  await expectConfigButtonVisible(page, true);
  await page
    .getByRole('button', { name: 'Configurazione server', exact: true })
    .click();
  const saveButton = page.getByRole('button', {
    name: 'Salva configurazione',
    exact: true,
  });
  await saveButton.scrollIntoViewIfNeeded();
  await expect(saveButton).toBeVisible({ timeout: E2E_TIMEOUT.ui });
}

export async function clickSaveInstanceConfig(page: Page): Promise<void> {
  const saveButton = page.getByRole('button', {
    name: 'Salva configurazione',
    exact: true,
  });
  await saveButton.scrollIntoViewIfNeeded();
  await saveButton.click();
}

export async function closeInstanceConfigScreen(page: Page): Promise<void> {
  await enableFlutterAccessibility(page);
  const back = page.getByRole('button', { name: 'Back', exact: true });
  if (await back.isVisible({ timeout: 1_500 }).catch(() => false)) {
    await back.click({ timeout: E2E_TIMEOUT.ui });
    await page.waitForTimeout(300);
  }
}

export async function fillInstanceConfigForm(
  page: Page,
  values: InstanceConfigExpectation,
): Promise<void> {
  await fillFlutterTextField(
    page,
    page.getByRole('textbox', { name: FIELD_LABELS.displayName, exact: true }),
    values.displayName,
  );
  await fillFlutterTextField(
    page,
    page.getByRole('textbox', { name: FIELD_LABELS.imServerId, exact: true }),
    values.imServerId,
  );
  await fillFlutterTextField(
    page,
    page.getByRole('textbox', { name: FIELD_LABELS.shortName, exact: true }),
    values.shortName,
  );
  await fillFlutterTextField(
    page,
    page.getByRole('textbox', { name: FIELD_LABELS.description, exact: true }),
    values.description,
  );
  await fillFlutterTextField(
    page,
    page.getByRole('textbox', { name: FIELD_LABELS.themeColor, exact: true }),
    values.themeColor,
  );
  await fillFlutterTextField(
    page,
    page.getByRole('textbox', {
      name: FIELD_LABELS.backgroundColor,
      exact: true,
    }),
    values.backgroundColor,
  );
  await fillFlutterTextField(
    page,
    page.getByRole('textbox', { name: FIELD_LABELS.privacyUrl, exact: true }),
    values.privacyUrl,
  );
  await fillFlutterTextField(
    page,
    page.getByRole('textbox', { name: FIELD_LABELS.termsUrl, exact: true }),
    values.termsUrl,
  );
  await fillFlutterTextField(
    page,
    page.getByRole('textbox', { name: FIELD_LABELS.supportUrl, exact: true }),
    values.supportUrl,
  );
}

export async function expectInstanceConfigScreenLoaded(
  page: Page,
  displayName: string,
): Promise<void> {
  await expect(
    page.getByRole('heading', {
      name: new RegExp(
        `Configurazione ${displayName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}`,
      ),
    }),
  ).toBeVisible({ timeout: E2E_TIMEOUT.ui });
}

export async function expectInstanceConfigSavedToast(page: Page): Promise<void> {
  await expect(
    page.getByText('Configurazione salvata', { exact: true }).first(),
  ).toBeVisible({ timeout: E2E_TIMEOUT.ui });
}

export async function expectNoOwnerRequiredError(page: Page): Promise<void> {
  await expect(page.getByText('owner required')).not.toBeVisible({
    timeout: 1_000,
  });
}
