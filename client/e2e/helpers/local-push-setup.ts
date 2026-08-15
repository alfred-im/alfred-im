// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import { execSync } from 'node:child_process';

import { expect, type Page } from '@playwright/test';

import {
  LOCAL_VAPID_PRIVATE_KEY,
  LOCAL_VAPID_PUBLIC_KEY,
  LOCAL_VAPID_SUBJECT,
} from '../fixtures/vapid-local';
import { E2E_POLL, E2E_TIMEOUT } from './timeouts';
import { isLocalSupabaseStack } from './local-auth';

const SUPABASE_URL =
  process.env.SUPABASE_URL ?? 'http://127.0.0.1:54321';

const ANON_KEY =
  process.env.SUPABASE_ANON_KEY ??
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';

export type PushPayload = {
  recipient_user_id: string;
  peer_profile_id: string;
  peer_display_name: string;
  preview_text: string;
  logical_message_id: string;
  content_type?: string;
};

export type SendMessageResult = {
  logical_message_id: string;
  archive_user_id: string;
};

/** Configura push_settings sul DB locale (VAPID + URL Edge Functions). */
export function configureLocalPushSettings(): void {
  const dbUrl = process.env.DATABASE_URL ?? process.env.DB_URL;
  if (!dbUrl) {
    throw new Error(
      'DATABASE_URL/DB_URL mancante — eval $(supabase status -o env)',
    );
  }

  const functionsBase =
    process.env.LOCAL_FUNCTIONS_BASE_URL ?? 'http://kong:8000/functions/v1';

  const sql =
    `UPDATE alfred_delivery.push_settings SET ` +
    `functions_base_url = '${functionsBase.replace(/'/g, "''")}', ` +
    `vapid_public_key = '${LOCAL_VAPID_PUBLIC_KEY}', ` +
    `vapid_private_key = '${LOCAL_VAPID_PRIVATE_KEY}', ` +
    `vapid_subject = '${LOCAL_VAPID_SUBJECT}', ` +
    `dispatch_secret = NULL, enabled = true WHERE singleton = true;`;

  execSync(
    `docker exec -i supabase_db_alfred psql -U postgres -d postgres -v ON_ERROR_STOP=1 -c ${JSON.stringify(sql)}`,
    { stdio: 'pipe' },
  );
}

function insertAllowlistLocalSql(recipientUserId: string, allowedProfileId: string) {
  const sql =
    `INSERT INTO public.reception_allowlist (archive_user_id, allowed_profile_id) ` +
    `VALUES ('${recipientUserId}', '${allowedProfileId}') ` +
    `ON CONFLICT (archive_user_id, allowed_profile_id) DO NOTHING;`;
  execSync(
    `docker exec -i supabase_db_alfred psql -U postgres -d postgres -v ON_ERROR_STOP=1 -c ${JSON.stringify(sql)}`,
    { stdio: 'pipe' },
  );
}

/** Enum + bucket per media — stack locale a volte fermo a migrazioni vecchie. */
export function configureLocalMailboxSchema(): void {
  if (!isLocalSupabaseStack()) return;
  const sql =
    `ALTER TYPE public.message_content_type ADD VALUE IF NOT EXISTS 'image'; ` +
    `ALTER TYPE public.message_content_type ADD VALUE IF NOT EXISTS 'video'; ` +
    `UPDATE storage.buckets SET file_size_limit = 52428800, allowed_mime_types = ARRAY[` +
    `'image/gif','image/jpeg','image/png','image/webp','audio/webm','video/mp4','video/webm'` +
    `]::text[] WHERE id = 'chat-media';`;
  execSync(
    `docker exec -i supabase_db_alfred psql -U postgres -d postgres -v ON_ERROR_STOP=1 -c ${JSON.stringify(sql)}`,
    { stdio: 'pipe' },
  );
}

/** Allinea bucket chat-media locale alle migrazioni (image/jpeg, png, …). */
export function configureLocalChatMediaBucket(): void {
  configureLocalMailboxSchema();
}

export function addReceptionAllowlist(options: {
  recipientUserId: string;
  allowedProfileId: string;
  recipientAccessToken: string;
}): Promise<void> {
  if (isLocalSupabaseStack() && process.env.SUPABASE_SERVICE_ROLE_KEY) {
    insertAllowlistLocalSql(options.recipientUserId, options.allowedProfileId);
    return Promise.resolve();
  }

  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  const authToken = serviceKey ?? options.recipientAccessToken;
  const apiKey = serviceKey ?? ANON_KEY;

  return fetch(`${SUPABASE_URL}/rest/v1/reception_allowlist`, {
    method: 'POST',
    headers: {
      apikey: apiKey,
      Authorization: `Bearer ${authToken}`,
      'Content-Type': 'application/json',
      Prefer: 'resolution=ignore-duplicates',
    },
    body: JSON.stringify({
      archive_user_id: options.recipientUserId,
      allowed_profile_id: options.allowedProfileId,
    }),
  }).then(async (res) => {
    if (!res.ok && res.status !== 409) {
      throw new Error(
        `reception_allowlist insert failed (${res.status}): ${await res.text()}`,
      );
    }
  });
}

export async function sendMessageToProfile(options: {
  senderAccessToken: string;
  recipientProfileId: string;
  body: string;
  clientMessageId: string;
}): Promise<SendMessageResult> {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/send_message_to_profile`, {
    method: 'POST',
    headers: {
      apikey: ANON_KEY,
      Authorization: `Bearer ${options.senderAccessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      p_recipient_profile_id: options.recipientProfileId,
      p_body: options.body,
      p_client_message_id: options.clientMessageId,
      p_content_type: 'text',
    }),
  });
  if (!res.ok) {
    throw new Error(
      `send_message_to_profile failed (${res.status}): ${await res.text()}`,
    );
  }
  const json = (await res.json()) as {
    logical_message_id: string;
    archive_user_id: string;
  };
  return {
    logical_message_id: json.logical_message_id,
    archive_user_id: json.archive_user_id,
  };
}

export async function invokeSendPush(
  payload: PushPayload,
  dispatchSecret?: string | null,
): Promise<{ sent: number }> {
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
  };
  if (dispatchSecret) {
    headers['X-Push-Dispatch-Secret'] = dispatchSecret;
  }

  const res = await fetch(`${SUPABASE_URL}/functions/v1/send-push`, {
    method: 'POST',
    headers,
    body: JSON.stringify(payload),
  });
  if (!res.ok) {
    throw new Error(
      `send-push failed (${res.status}): ${await res.text()}`,
    );
  }
  return (await res.json()) as { sent: number };
}

export async function installPushReceivedListener(page: Page): Promise<void> {
  await page.addInitScript(() => {
    const w = window as unknown as {
      __alfredPushReceived: Record<string, unknown>[];
    };
    w.__alfredPushReceived = [];
    navigator.serviceWorker.addEventListener('message', (event) => {
      try {
        const raw = event.data;
        const data =
          typeof raw === 'string'
            ? (JSON.parse(raw) as {
                type?: string;
                payload?: Record<string, unknown>;
              })
            : (raw as { type?: string; payload?: Record<string, unknown> });
        if (data?.type === 'alfred_push_received' && data.payload) {
          w.__alfredPushReceived.push(data.payload);
        }
      } catch {
        // ignore malformed messages
      }
    });
  });
}

export async function readPushReceived(
  page: Page,
): Promise<Record<string, unknown>[]> {
  return page.evaluate(() => {
    const w = window as unknown as {
      __alfredPushReceived?: Record<string, unknown>[];
    };
    return w.__alfredPushReceived ?? [];
  });
}

export async function waitForPushReceived(
  page: Page,
  options: { previewText: string; timeoutMs?: number },
): Promise<Record<string, unknown>> {
  let match: Record<string, unknown> | undefined;
  await expect
    .poll(
      async () => {
        const items = await readPushReceived(page);
        match = items.find(
          (p) => p.previewText === options.previewText,
        ) as Record<string, unknown> | undefined;
        return match != null;
      },
      {
        timeout: options.timeoutMs ?? E2E_TIMEOUT.message,
        intervals: [...E2E_POLL],
      },
    )
    .toBe(true);
  return match!;
}
