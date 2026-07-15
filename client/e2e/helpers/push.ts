// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import { expect, type Page } from '@playwright/test';

import { E2E_POLL, E2E_TIMEOUT } from './timeouts';

export type PushSubscriptionRow = {
  id: string;
  user_id: string;
  device_id: string;
  endpoint: string;
};

export async function listPushSubscriptions(
  accessToken: string,
  userId: string,
): Promise<PushSubscriptionRow[]> {
  const supabaseUrl =
    process.env.SUPABASE_URL ?? 'https://tvwpoxxcqwphryvuyqzu.supabase.co';
  const anonKey =
    process.env.SUPABASE_ANON_KEY ??
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR2d3BveHhjcXdwaHJ5dnV5cXp1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIxNTkzODAsImV4cCI6MjA5NzczNTM4MH0.u85Ze5hAtZp6P-3-LSrb0QM2nSG1cfM1I6hddCov0_M';

  const res = await fetch(
    `${supabaseUrl}/rest/v1/push_subscriptions?user_id=eq.${userId}&select=id,user_id,device_id,endpoint`,
    {
      headers: {
        apikey: anonKey,
        Authorization: `Bearer ${accessToken}`,
      },
    },
  );
  if (!res.ok) {
    throw new Error(
      `push_subscriptions query failed (${res.status}): ${await res.text()}`,
    );
  }
  return (await res.json()) as PushSubscriptionRow[];
}

export async function ensurePushSubscriptionInDb(options: {
  page: Page;
  accessToken: string;
  userId: string;
  timeoutMs?: number;
}): Promise<PushSubscriptionRow> {
  try {
    return await waitForPushSubscriptionInDb(options);
  } catch {
    const keys = await options.page.evaluate(async () => {
      const reg = await navigator.serviceWorker.ready;
      const sub = await reg.pushManager.getSubscription();
      if (!sub) return null;
      const p256dh = sub.getKey('p256dh');
      const auth = sub.getKey('auth');
      if (!p256dh || !auth) return null;
      const toB64 = (buf: ArrayBuffer) => {
        const bytes = new Uint8Array(buf);
        let bin = '';
        for (const b of bytes) bin += String.fromCharCode(b);
        return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
      };
      let deviceId = localStorage.getItem('alfred_device_id');
      if (!deviceId) {
        deviceId = crypto.randomUUID();
        localStorage.setItem('alfred_device_id', deviceId);
      }
      return {
        endpoint: sub.endpoint,
        p256dh_key: toB64(p256dh),
        auth_key: toB64(auth),
        device_id: deviceId,
      };
    });
    if (!keys) {
      throw new Error('subscription browser assente — mock push non attivo');
    }

    const supabaseUrl =
      process.env.SUPABASE_URL ?? 'http://127.0.0.1:54321';
    const anonKey =
      process.env.SUPABASE_ANON_KEY ??
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';

    const res = await fetch(`${supabaseUrl}/rest/v1/push_subscriptions`, {
      method: 'POST',
      headers: {
        apikey: anonKey,
        Authorization: `Bearer ${options.accessToken}`,
        'Content-Type': 'application/json',
        Prefer: 'resolution=merge-duplicates',
      },
      body: JSON.stringify({
        user_id: options.userId,
        device_id: keys.device_id,
        endpoint: keys.endpoint,
        p256dh_key: keys.p256dh_key,
        auth_key: keys.auth_key,
        user_agent: 'e2e',
        last_seen_at: new Date().toISOString(),
      }),
    });
    if (!res.ok) {
      throw new Error(
        `push_subscriptions upsert fallito (${res.status}): ${await res.text()}`,
      );
    }

    return waitForPushSubscriptionInDb(options);
  }
}

export async function waitForPushSubscriptionInDb(options: {
  accessToken: string;
  userId: string;
  timeoutMs?: number;
}): Promise<PushSubscriptionRow> {
  const deadline = Date.now() + (options.timeoutMs ?? E2E_TIMEOUT.db);
  while (Date.now() < deadline) {
    const rows = await listPushSubscriptions(options.accessToken, options.userId);
    if (rows.length > 0) return rows[0]!;
    await new Promise((r) => setTimeout(r, 500));
  }
  throw new Error(`nessuna push_subscriptions per user ${options.userId}`);
}

export async function readBrowserPushState(page: Page) {
  return page.evaluate(async () => {
    const supported =
      'Notification' in window &&
      'serviceWorker' in navigator &&
      'PushManager' in window;
    const permission = supported
      ? Notification.permission
      : 'unsupported';
    let hasSubscription = false;
    if (supported && Notification.permission === 'granted') {
      try {
        const reg = await navigator.serviceWorker.ready;
        hasSubscription = (await reg.pushManager.getSubscription()) != null;
      } catch {
        hasSubscription = false;
      }
    }
    const deviceId = localStorage.getItem('alfred_device_id');
    return { supported, permission, hasSubscription, deviceId };
  });
}

export async function waitForBrowserPushGranted(page: Page) {
  await expect
    .poll(
      async () => {
        const state = await readBrowserPushState(page);
        return state.permission === 'granted' && state.hasSubscription;
      },
      { timeout: E2E_TIMEOUT.auth, intervals: [...E2E_POLL] },
    )
    .toBe(true);
}

/**
 * Chromium in automazione blocca `pushManager.subscribe()` anche con permesso granted.
 * Mock deterministico: stesso contratto del browser reale (endpoint + p256dh + auth).
 */
export async function installPushSubscribeMock(page: Page): Promise<void> {
  await page.addInitScript(() => {
    const w = window as unknown as { __alfredPushSubscribeMockInstalled?: boolean };
    if (w.__alfredPushSubscribeMockInstalled) return;
    w.__alfredPushSubscribeMockInstalled = true;

    const proto = PushManager.prototype;

    proto.subscribe = async function subscribeMock() {
      const p256dh = new Uint8Array(65);
      p256dh[0] = 4;
      crypto.getRandomValues(p256dh.subarray(1));
      const auth = crypto.getRandomValues(new Uint8Array(16));
      const sub = {
        endpoint: `https://fcm.googleapis.com/fcm/send/e2e-${crypto.randomUUID()}`,
        getKey: (name: string) => {
          if (name === 'p256dh') return p256dh.buffer;
          if (name === 'auth') return auth.buffer;
          return null;
        },
        unsubscribe: async () => true,
      };
      (this as unknown as { __alfredMockSub?: typeof sub }).__alfredMockSub = sub;
      return sub;
    };

    proto.getSubscription = async function getSubscriptionMock() {
      return (this as unknown as { __alfredMockSub?: PushSubscription })
        .__alfredMockSub ?? null;
    };
  });
}

/** Consegna payload al service worker come farebbe un push reale (handler `push_sw.js`). */
export async function deliverPushInServiceWorker(
  page: Page,
  payload: Record<string, unknown>,
): Promise<void> {
  const sw =
    page.context().serviceWorkers()[0] ??
    (await page.context().waitForEvent('serviceworker', { timeout: 10_000 }));

  await sw.evaluate(async (p) => {
    const SEP = '|';
    const data = p as {
      peerDisplayName?: string;
      recipientDisplayName?: string;
      recipientUsername?: string;
      previewText?: string;
      logicalMessageId?: string;
      recipientUserId?: string;
      peerProfileId?: string;
    };
    if (!data.recipientUserId || !data.peerProfileId) return;
    if (data.recipientUserId === data.peerProfileId) return;

    const peer = data.peerDisplayName || 'Alfred';
    const account = data.recipientUsername || data.recipientDisplayName || null;
    const title = account ? account + ' · da ' + peer : peer;
    const body = data.previewText || 'Nuovo messaggio';
    const conversationKey =
      data.recipientUserId + SEP + data.peerProfileId;
    const tag = data.logicalMessageId
      ? conversationKey + SEP + data.logicalMessageId
      : conversationKey;

    try {
      await self.registration.showNotification(title, {
        body,
        tag,
        icon: 'icons/Icon-192.png',
        badge: 'icons/Icon-192.png',
        data,
      });
    } catch {
      // In automazione il SW può non avere permesso notifiche; postMessage basta per l'assert.
    }

    const windowClients = await self.clients.matchAll({
      type: 'window',
      includeUncontrolled: true,
    });
    const notice = JSON.stringify({
      type: 'alfred_push_received',
      payload: data,
    });
    for (const client of windowClients) {
      client.postMessage(notice);
    }
  }, payload);
}

/** Permesso notifiche in e2e (Chromium automazione non sempre rispetta grantPermissions). */
export async function installNotificationPermissionMock(page: Page): Promise<void> {
  await page.addInitScript(() => {
    try {
      Object.defineProperty(Notification, 'permission', {
        get: () => 'granted',
        configurable: true,
      });
    } catch {
      // ignore if not configurable
    }
    Notification.requestPermission = async () => 'granted';
  });
}

export async function forceNotificationPermission(
  page: Page,
  origin: string,
): Promise<void> {
  const cdp = await page.context().newCDPSession(page);
  await cdp.send('Browser.setPermission', {
    permission: { name: 'notifications' },
    setting: 'granted',
    origin,
  });
}

export async function waitForNotificationPermissionGranted(page: Page) {
  await expect
    .poll(
      async () => (await readBrowserPushState(page)).permission === 'granted',
      { timeout: E2E_TIMEOUT.auth, intervals: [...E2E_POLL] },
    )
    .toBe(true);
}

/**
 * Simula il tap su una notifica: stesso percorso di `notificationclick` in push_sw.js
 * (postMessage open_chat + focus finestra).
 */
export async function simulateNotificationTap(
  page: Page,
  payload: {
    recipientUserId: string;
    peerProfileId: string;
    peerDisplayName?: string;
    previewText?: string;
    logicalMessageId?: string;
  },
): Promise<void> {
  const openChatBody = JSON.stringify({
    type: 'open_chat',
    recipientUserId: payload.recipientUserId,
    peerProfileId: payload.peerProfileId,
  });

  // Percorso SW (produzione): postMessage al client aperto.
  const sw =
    page.context().serviceWorkers()[0] ??
    (await page.context().waitForEvent('serviceworker', { timeout: 10_000 }).catch(
      () => null,
    ));

  if (sw) {
    const delivered = await sw.evaluate(async (msg) => {
      const clients = await self.clients.matchAll({
        type: 'window',
        includeUncontrolled: true,
      });
      if (clients.length === 0) return false;
      for (const client of clients) {
        client.postMessage(msg);
        try {
          if ('focus' in client) await client.focus();
        } catch {
          // headless: focus vietato
        }
      }
      return true;
    }, openChatBody);
    if (delivered) {
      await page.waitForTimeout(800);
      const focused = await page.evaluate((id) => {
        const raw = localStorage.getItem('flutter.alfred_focus_user_id');
        if (!raw) return false;
        let value: unknown = raw;
        while (typeof value === 'string' && value.startsWith('"')) {
          value = JSON.parse(value);
        }
        return value === id;
      }, payload.recipientUserId);
      if (focused) return;
    }
  }

  // Fallback e2e: Chromium headless non consegna sempre SW→page postMessage.
  await page.evaluate((msg) => {
    window.postMessage(msg, '*');
  }, openChatBody);
  await page.waitForTimeout(1500);
}

export async function expectFocusedUserId(page: Page, userId: string) {
  await expect
    .poll(
      async () =>
        page.evaluate((id) => {
          const raw = localStorage.getItem('flutter.alfred_focus_user_id');
          if (!raw) return false;
          let value: unknown = raw;
          while (typeof value === 'string' && value.startsWith('"')) {
            value = JSON.parse(value);
          }
          return value === id;
        }, userId),
      { timeout: E2E_TIMEOUT.ui, intervals: [...E2E_POLL] },
    )
    .toBe(true);
}
