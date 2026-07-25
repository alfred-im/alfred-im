// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import { execSync } from 'node:child_process';

import { expect } from '@playwright/test';

import {
  listPeerMessages,
  loginSupabase,
  peerAuthorId,
  type PeerMessage,
  waitForMessageInDb,
} from './supabase-api';
import { E2E_POLL, E2E_TIMEOUT } from './timeouts';

async function fetchImageRowsForOwner(
  ownerUserId: string,
  peerUserId: string,
): Promise<PeerMessage[]> {
  const sql =
    `SELECT coalesce(json_agg(row_to_json(t)), '[]'::json) FROM (` +
    `SELECT id, body, author_id, content_type, media_url, delivered_at, read_at ` +
    `FROM public.messages ` +
    `WHERE owner_id = '${ownerUserId}' AND peer_profile_id = '${peerUserId}' AND content_type = 'image' ` +
    `ORDER BY created_at DESC LIMIT 20` +
    `) t;`;
  const raw = execSync(
    `docker exec -i supabase_db_alfred psql -U postgres -d postgres -t -A -c ${JSON.stringify(sql)}`,
    { encoding: 'utf8' },
  ).trim();
  if (!raw) return [];
  return JSON.parse(raw) as PeerMessage[];
}

export type AccountCredentials = {
  email: string;
  password: string;
  userId: string;
};

/** Messaggio in archivio mittente e destinatario (gate backend). */
export async function expectMessagePersistedBothSides(options: {
  body: string;
  sender: AccountCredentials;
  recipient: AccountCredentials;
  contentType?: string;
}) {
  const contentType = options.contentType ?? 'text';
  const senderRow = await waitForMessageInDb({
    viewerEmail: options.sender.email,
    viewerPassword: options.sender.password,
    peerProfileId: options.recipient.userId,
    body: options.body,
    expectedSenderId: options.sender.userId,
    contentType,
  });
  await waitForMessageInDb({
    viewerEmail: options.recipient.email,
    viewerPassword: options.recipient.password,
    peerProfileId: options.sender.userId,
    body: options.body,
    expectedSenderId: options.sender.userId,
    contentType,
  });
  return senderRow;
}

/** Attende read_at sulla copia mittente (spunta blu backend). */
export async function waitForSenderReadAt(options: {
  sender: AccountCredentials;
  peerUserId: string;
  body?: string;
  contentType?: string;
  timeoutMs?: number;
}): Promise<PeerMessage> {
  const deadline = Date.now() + (options.timeoutMs ?? E2E_TIMEOUT.db * 3);
  const session = await loginSupabase(
    options.sender.email,
    options.sender.password,
  );

  while (Date.now() < deadline) {
    const messages = await listPeerMessages(
      session.accessToken,
      options.peerUserId,
    );
    const token = options.body?.match(/\d{8,}/)?.[0] ?? options.body;
    const row = messages.find((m) => {
      if (peerAuthorId(m) !== options.sender.userId || m.read_at == null) {
        return false;
      }
      if (options.contentType === 'image') {
        return m.content_type === 'image' && (m.media_url?.length ?? 0) > 0;
      }
      return (
        options.body != null &&
        (m.body === options.body || m.body.includes(token ?? ''))
      );
    });
    if (row) return row;
    await new Promise((r) => setTimeout(r, 500));
  }

  const last = await listPeerMessages(session.accessToken, options.peerUserId);
  throw new Error(
    `read_at assente su copia mittente per "${options.body}" (peer=${options.peerUserId}). Ultimi: ${JSON.stringify(last.slice(-4).map((m) => ({ body: m.body, read_at: m.read_at, content_type: m.content_type })))}`,
  );
}

/** Attende messaggio immagine con media_url valorizzato. */
export async function waitForImageMessageInDb(options: {
  viewer: AccountCredentials;
  peerUserId: string;
  expectedSenderId: string;
  caption?: string;
  timeoutMs?: number;
}): Promise<PeerMessage> {
  const deadline = Date.now() + (options.timeoutMs ?? E2E_TIMEOUT.db * 6);

  while (Date.now() < deadline) {
    const messages = await fetchImageRowsForOwner(
      options.viewer.userId,
      options.peerUserId,
    );
    const row = messages.find(
      (m) =>
        peerAuthorId(m) === options.expectedSenderId &&
        m.content_type === 'image' &&
        (m.media_url?.length ?? 0) > 0,
    );
    if (row) return row;
    await new Promise((r) => setTimeout(r, 500));
  }

  throw new Error(
    `messaggio image assente (viewer=${options.viewer.email}, peer=${options.peerUserId})`,
  );
}

export async function expectImagePersistedBothSides(options: {
  sender: AccountCredentials;
  recipient: AccountCredentials;
  caption?: string;
}) {
  await waitForImageMessageInDb({
    viewer: options.sender,
    peerUserId: options.recipient.userId,
    expectedSenderId: options.sender.userId,
    caption: options.caption,
  });
  await waitForImageMessageInDb({
    viewer: options.recipient,
    peerUserId: options.sender.userId,
    expectedSenderId: options.sender.userId,
    caption: options.caption,
  });
}

/** Poll backend finché delivered_at è valorizzato (doppia spunta grigia). */
export async function waitForSenderDeliveredAt(options: {
  sender: AccountCredentials;
  peerUserId: string;
  body: string;
}): Promise<PeerMessage> {
  await expect
    .poll(
      async () => {
        const session = await loginSupabase(
          options.sender.email,
          options.sender.password,
        );
        const messages = await listPeerMessages(
          session.accessToken,
          options.peerUserId,
        );
        const token = options.body.match(/\d{8,}/)?.[0] ?? options.body;
        const row = messages.find(
          (m) =>
            (m.body === options.body || m.body.includes(token)) &&
            peerAuthorId(m) === options.sender.userId,
        );
        return row?.delivered_at != null;
      },
      { timeout: E2E_TIMEOUT.db * 2, intervals: [...E2E_POLL] },
    )
    .toBe(true);

  const session = await loginSupabase(
    options.sender.email,
    options.sender.password,
  );
  const messages = await listPeerMessages(
    session.accessToken,
    options.peerUserId,
  );
  return messages.find(
    (m) => {
      const token = options.body.match(/\d{8,}/)?.[0] ?? options.body;
      return (
        (m.body === options.body || m.body.includes(token)) &&
        peerAuthorId(m) === options.sender.userId
      );
    },
  )!;
}
