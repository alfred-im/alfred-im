// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import { execSync } from 'node:child_process';

import { expect } from '@playwright/test';

import {
  isMessageFromSender,
  listPeerMessages,
  loginSupabase,
  type PeerMessage,
  waitForMessageInDb,
} from './supabase-api';
import { E2E_POLL, E2E_TIMEOUT } from './timeouts';

async function fetchImageRowsForArchiveUser(
  focusUserId: string,
  peerAddress: string,
): Promise<PeerMessage[]> {
  const safePeer = peerAddress.replace(/'/g, "''").toLowerCase();
  const sql =
    `SELECT coalesce(json_agg(row_to_json(t)), '[]'::json) FROM (` +
    `SELECT id, body, author_id, content_type, media_url, delivered_at, read_at ` +
    `FROM public.messages ` +
    `WHERE archive_user_id = '${focusUserId}' AND peer_address = '${safePeer}' AND content_type = 'image' ` +
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
  username: string;
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
    peerAddress: options.recipient.username,
    body: options.body,
    expectedSender: options.sender,
    contentType,
  });
  await waitForMessageInDb({
    viewerEmail: options.recipient.email,
    viewerPassword: options.recipient.password,
    peerAddress: options.sender.username,
    body: options.body,
    expectedSender: options.sender,
    contentType,
  });
  return senderRow;
}

/** Attende read_at sulla copia mittente (spunta blu backend). */
export async function waitForSenderReadAt(options: {
  sender: AccountCredentials;
  peerAddress: string;
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
      options.peerAddress,
    );
    const token = options.body?.match(/\d{8,}/)?.[0] ?? options.body;
    const row = messages.find((m) => {
      if (!isMessageFromSender(m, options.sender) || m.read_at == null) {
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

  const last = await listPeerMessages(session.accessToken, options.peerAddress);
  throw new Error(
    `read_at assente su copia mittente per "${options.body}" (peer=${options.peerAddress}). Ultimi: ${JSON.stringify(last.slice(-4).map((m) => ({ body: m.body, read_at: m.read_at, content_type: m.content_type })))}`,
  );
}

/** Attende messaggio immagine con media_url valorizzato. */
export async function waitForImageMessageInDb(options: {
  viewer: AccountCredentials;
  peerAddress: string;
  expectedSender: AccountCredentials;
  caption?: string;
  timeoutMs?: number;
}): Promise<PeerMessage> {
  const deadline = Date.now() + (options.timeoutMs ?? E2E_TIMEOUT.db * 10);

  while (Date.now() < deadline) {
    const messages = await fetchImageRowsForArchiveUser(
      options.viewer.userId,
      options.peerAddress,
    );
    const row = messages.find(
      (m) =>
        isMessageFromSender(m, options.expectedSender) &&
        m.content_type === 'image' &&
        (m.media_url?.length ?? 0) > 0,
    );
    if (row) return row;
    await new Promise((r) => setTimeout(r, 500));
  }

  throw new Error(
    `messaggio image assente (viewer=${options.viewer.email}, peer=${options.peerAddress})`,
  );
}

export async function expectImagePersistedBothSides(options: {
  sender: AccountCredentials;
  recipient: AccountCredentials;
  caption?: string;
}) {
  await waitForImageMessageInDb({
    viewer: options.sender,
    peerAddress: options.recipient.username,
    expectedSender: options.sender,
    caption: options.caption,
  });
  await waitForImageMessageInDb({
    viewer: options.recipient,
    peerAddress: options.sender.username,
    expectedSender: options.sender,
    caption: options.caption,
  });
}

/** Poll backend finché delivered_at è valorizzato (doppia spunta grigia). */
export async function waitForSenderDeliveredAt(options: {
  sender: AccountCredentials;
  peerAddress: string;
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
          options.peerAddress,
        );
        const token = options.body.match(/\d{8,}/)?.[0] ?? options.body;
        const row = messages.find(
          (m) =>
            (m.body === options.body || m.body.includes(token)) &&
            isMessageFromSender(m, options.sender),
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
    options.peerAddress,
  );
  return messages.find(
    (m) => {
      const token = options.body.match(/\d{8,}/)?.[0] ?? options.body;
      return (
        (m.body === options.body || m.body.includes(token)) &&
        isMessageFromSender(m, options.sender)
      );
    },
  )!;
}
