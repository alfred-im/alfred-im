// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import { expect, type Page } from '@playwright/test';

import { enableFlutterAccessibility } from './flutter-a11y';
import type { InstanceConfigExpectation } from './instance-config';
import {
  closeDrawerIfOpen,
  fillFlutterTextField,
} from './multi-account';
import { E2E_POLL, E2E_TIMEOUT } from './timeouts';

async function clickFlutterAriaLabel(
  page: Page,
  ariaLabel: string,
): Promise<boolean> {
  return page.evaluate((label) => {
    const nodes = Array.from(document.querySelectorAll('[aria-label]'));
    const target = nodes.find(
      (node) => node.getAttribute('aria-label') === label,
    ) as HTMLElement | null;
    if (!target) return false;
    target.click();
    return true;
  }, ariaLabel);
}

async function isInstanceConfigScreenOpen(page: Page): Promise<boolean> {
  await enableFlutterAccessibility(page);
  const onScreen = await page
    .getByRole('heading', { name: /^Configurazione / })
    .isVisible()
    .catch(() => false);
  const saveReady = await page
    .getByRole('button', { name: 'Salva configurazione', exact: true })
    .isVisible()
    .catch(() => false);
  return onScreen || saveReady;
}

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
  await closeDrawerIfOpen(page);
  await enableFlutterAccessibility(page);

  const configButton = page.getByRole('button', {
    name: 'Configurazione server',
    exact: true,
  });
  const saveButton = page.getByRole('button', {
    name: 'Salva configurazione',
    exact: true,
  });

  await expect
    .poll(
      async () => {
        if (await isInstanceConfigScreenOpen(page)) {
          return true;
        }
        await closeDrawerIfOpen(page);
        await enableFlutterAccessibility(page);
        await configButton
          .click({ force: true, timeout: 2_000 })
          .catch(() => {});
        if (!(await isInstanceConfigScreenOpen(page))) {
          await clickFlutterAriaLabel(page, 'Configurazione server');
        }
        if (!(await isInstanceConfigScreenOpen(page))) {
          const search = page.getByRole('button', { name: 'Cerca messaggi' });
          const box = await search.boundingBox({ timeout: 2_000 }).catch(() => null);
          if (box) {
            await page.mouse.click(
              box.x + box.width + 28,
              box.y + box.height / 2,
            );
          }
        }
        return isInstanceConfigScreenOpen(page);
      },
      { timeout: E2E_TIMEOUT.auth, intervals: [...E2E_POLL, 1200] },
    )
    .toBe(true);

  await expect
    .poll(
      async () => {
        await enableFlutterAccessibility(page);
        return saveButton.isVisible().catch(() => false);
      },
      { timeout: E2E_TIMEOUT.auth, intervals: [...E2E_POLL, 1200] },
    )
    .toBe(true);
  await saveButton.scrollIntoViewIfNeeded({ timeout: E2E_TIMEOUT.ui });
}

export async function clickSaveInstanceConfig(page: Page): Promise<void> {
  await enableFlutterAccessibility(page);
  const saveButton = page.getByRole('button', {
    name: 'Salva configurazione',
    exact: true,
  });
  await expect(saveButton).toBeVisible({ timeout: E2E_TIMEOUT.ui });
  await saveButton.scrollIntoViewIfNeeded({ timeout: E2E_TIMEOUT.ui });
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
