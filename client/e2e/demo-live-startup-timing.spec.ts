// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

/**
 * Cronometra avvio demo live (alfred-im-web.fly.dev).
 * Diagnostica: non richiede auth locale.
 *
 * Run:
 *   cd client && npx playwright test e2e/demo-live-startup-timing.spec.ts --reporter=line
 */
import { test, expect, chromium, type Page } from '@playwright/test';

const DEMO_URL = process.env.ALFRED_BASE_URL ?? 'https://alfred-im-web.fly.dev/';

type ResourceSummary = {
  name: string;
  durationMs: number;
  transferSize: number;
  encodedBodySize: number;
  decodedBodySize: number;
  fromCache: boolean;
};

type StartupMetrics = {
  label: string;
  navigations: number;
  navigationUrls: string[];
  splashVisibleMs: number | null;
  splashHiddenMs: number | null;
  domContentLoadedMs: number | null;
  loadEventMs: number | null;
  flutterInteractableMs: number | null;
  resources: ResourceSummary[];
  totalTransferBytes: number;
};

async function measureStartup(page: Page, label: string): Promise<StartupMetrics> {
  let navigations = 0;
  const navigationUrls: string[] = [];
  page.on('framenavigated', (frame) => {
    if (frame === page.mainFrame()) {
      navigations += 1;
      navigationUrls.push(frame.url());
    }
  });

  const t0 = Date.now();

  await page.goto(DEMO_URL, { waitUntil: 'commit' });

  const splashVisibleMs = await page
    .waitForSelector('#alfred-boot-splash', { state: 'visible', timeout: 15_000 })
    .then(() => Date.now() - t0)
    .catch(() => null);

  const splashHiddenMs = await page
    .waitForSelector('#alfred-boot-splash', { state: 'hidden', timeout: 120_000 })
    .then(() => Date.now() - t0)
    .catch(async () => {
      // Fallback: splash removed from DOM
      await page.waitForFunction(
        () => document.getElementById('alfred-boot-splash') == null,
        { timeout: 120_000 },
      );
      return Date.now() - t0;
    });

  const perf = await page.evaluate(() => {
    const nav = performance.getEntriesByType('navigation')[0] as
      | PerformanceNavigationTiming
      | undefined;
    const resources = performance.getEntriesByType('resource') as PerformanceResourceTiming[];
    return {
      domContentLoadedMs: nav?.domContentLoadedEventEnd ?? null,
      loadEventMs: nav?.loadEventEnd ?? null,
      resources: resources.map((r) => ({
        name: r.name,
        durationMs: Math.round(r.duration),
        transferSize: r.transferSize,
        encodedBodySize: r.encodedBodySize,
        decodedBodySize: r.decodedBodySize,
        fromCache: r.transferSize === 0 && r.decodedBodySize > 0,
      })),
    };
  });

  const flutterInteractableMs = await page
    .waitForFunction(
      () => {
        const splash = document.getElementById('alfred-boot-splash');
        if (splash && splash.checkVisibility()) return false;
        // Flutter canvas or semantics root present
        const flutter = document.querySelector('flt-glass-pane, flt-semantics-host');
        if (flutter) return true;
        // Auth / placeholder text
        const body = document.body?.innerText ?? '';
        return (
          body.includes('Nessun account') ||
          body.includes('Accedi') ||
          body.includes('Registrati') ||
          body.includes('Email')
        );
      },
      { timeout: 120_000 },
    )
    .then(() => Date.now() - t0)
    .catch(() => null);

  const keyPatterns = [
    'main.dart.js',
    'flutter_bootstrap.js',
    'flutter_service_worker.js',
    'config.json',
    'canvaskit',
    'gstatic.com/flutter-canvaskit',
  ];

  const resources = perf.resources
    .filter((r) => keyPatterns.some((p) => r.name.includes(p)))
    .sort((a, b) => b.durationMs - a.durationMs);

  const totalTransferBytes = perf.resources.reduce((sum, r) => sum + r.transferSize, 0);

  return {
    label,
    navigations,
    navigationUrls,
    splashVisibleMs,
    splashHiddenMs,
    domContentLoadedMs: perf.domContentLoadedMs
      ? Math.round(perf.domContentLoadedMs)
      : null,
    loadEventMs: perf.loadEventMs ? Math.round(perf.loadEventMs) : null,
    flutterInteractableMs,
    resources,
    totalTransferBytes,
  };
}

function printMetrics(m: StartupMetrics) {
  console.log(`\n=== ${m.label} ===`);
  console.log(`navigations: ${m.navigations}`);
  if (m.navigationUrls.length > 0) {
    console.log(`navigation urls: ${m.navigationUrls.join(' → ')}`);
  }
  console.log(`splash visible: ${m.splashVisibleMs} ms`);
  console.log(`splash hidden (flutter-first-frame): ${m.splashHiddenMs} ms`);
  console.log(`DOMContentLoaded: ${m.domContentLoadedMs} ms`);
  console.log(`load event: ${m.loadEventMs} ms`);
  console.log(`flutter interactable: ${m.flutterInteractableMs} ms`);
  console.log(`total transfer (all resources): ${(m.totalTransferBytes / 1024 / 1024).toFixed(2)} MB`);
  console.log('key resources:');
  for (const r of m.resources) {
    const cache = r.fromCache ? ' [disk cache]' : '';
    console.log(
      `  ${r.durationMs}ms  transfer=${(r.transferSize / 1024).toFixed(1)}KB` +
        `  decoded=${(r.decodedBodySize / 1024).toFixed(1)}KB  ${r.name.split('/').pop()}${cache}`,
    );
  }
}

test.describe('demo live startup timing', () => {
  test.setTimeout(300_000);

  test('cold then warm (same browser)', async () => {
    const browser = await chromium.launch({ headless: true });
    const context = await browser.newContext();
    const page = await context.newPage();

    const cold = await measureStartup(page, 'COLD (1ª navigazione, cache vuota)');
    printMetrics(cold);

    const warm = await measureStartup(page, 'WARM (2ª navigazione, stesso browser)');
    printMetrics(warm);

    await browser.close();

    expect(cold.splashHiddenMs).not.toBeNull();
    expect(warm.splashHiddenMs).not.toBeNull();

    if (cold.splashHiddenMs != null && warm.splashHiddenMs != null) {
      console.log(
        `\nΔ splash hidden: warm ${warm.splashHiddenMs - cold.splashHiddenMs} ms` +
          ` (${warm.splashHiddenMs < cold.splashHiddenMs ? 'più veloce' : 'più lento'})`,
      );
    }
    if (cold.totalTransferBytes > 0 && warm.totalTransferBytes >= 0) {
      const saved = cold.totalTransferBytes - warm.totalTransferBytes;
      console.log(
        `Δ transfer: warm risparmia ${(saved / 1024 / 1024).toFixed(2)} MB` +
          ` (cold ${(cold.totalTransferBytes / 1024 / 1024).toFixed(2)} MB → warm ${(warm.totalTransferBytes / 1024 / 1024).toFixed(2)} MB)`,
      );
    }
  });

  test('fresh context (simula nuovo tab con cache browser)', async () => {
    const browser = await chromium.launch({ headless: true });

    const ctx1 = await browser.newContext();
    const page1 = await ctx1.newPage();
    const first = await measureStartup(page1, 'TAB 1 (primo contesto)');
    printMetrics(first);
    await ctx1.close();

    const ctx2 = await browser.newContext();
    const page2 = await ctx2.newPage();
    const second = await measureStartup(page2, 'TAB 2 (nuovo contesto, cache HTTP condivisa)');
    printMetrics(second);
    await ctx2.close();

    await browser.close();

    if (first.splashHiddenMs != null && second.splashHiddenMs != null) {
      console.log(
        `\nΔ nuovo tab: ${second.splashHiddenMs - first.splashHiddenMs} ms vs primo tab` +
          ` (transfer tab2 ${(second.totalTransferBytes / 1024 / 1024).toFixed(2)} MB)`,
      );
    }
  });
});
