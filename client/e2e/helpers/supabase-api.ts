// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import { expect } from '@playwright/test';

import { E2E_TIMEOUT } from './timeouts';

const SUPABASE_URL =
  process.env.SUPABASE_URL ?? 'https://tvwpoxxcqwphryvuyqzu.supabase.co';

const ANON_KEY =
  process.env.SUPABASE_ANON_KEY ??
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR2d3BveHhjcXdwaHJ5dnV5cXp1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIxNTkzODAsImV4cCI6MjA5NzczNTM4MH0.u85Ze5hAtZp6P-3-LSrb0QM2nSG1cfM1I6hddCov0_M';

export type PeerMessage = {
  id: string;
  body: string;
  author_id?: string;
  sender_id?: string;
  recipient_profile_id?: string;
  peer_profile_id?: string;
  created_at?: string;
  content_type?: string;
  media_url?: string | null;
  delivered_at?: string | null;
  read_at?: string | null;
  logical_message_id?: string;
};

export function peerAuthorId(message: PeerMessage): string {
  return message.author_id ?? message.sender_id ?? '';
}

export type SupabaseSession = {
  accessToken: string;
  userId: string;
};

export async function loginSupabase(
  email: string,
  password: string,
): Promise<SupabaseSession> {
  const res = await fetch(
    `${SUPABASE_URL}/auth/v1/token?grant_type=password`,
    {
      method: 'POST',
      headers: {
        apikey: ANON_KEY,
        Authorization: `Bearer ${ANON_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ email, password }),
    },
  );
  if (!res.ok) {
    throw new Error(`login Supabase fallito (${res.status}): ${await res.text()}`);
  }
  const json = (await res.json()) as {
    access_token: string;
    user: { id: string };
  };
  return { accessToken: json.access_token, userId: json.user.id };
}

export async function listPeerMessages(
  accessToken: string,
  peerProfileId: string,
  limit = 100,
): Promise<PeerMessage[]> {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/list_peer_messages`, {
    method: 'POST',
    headers: {
      apikey: ANON_KEY,
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      p_peer_profile_id: peerProfileId,
      p_limit: limit,
    }),
  });
  if (!res.ok) {
    throw new Error(
      `list_peer_messages fallito (${res.status}): ${await res.text()}`,
    );
  }
  return (await res.json()) as PeerMessage[];
}

export type WaitForDbMessageOptions = {
  viewerEmail: string;
  viewerPassword: string;
  peerProfileId: string;
  body: string;
  expectedSenderId: string;
  contentType?: string;
  timeoutMs?: number;
};

/** Attende che un messaggio compaia in DB (RPC list_peer_messages lato destinatario o mittente). */
export async function waitForMessageInDb(
  options: WaitForDbMessageOptions,
): Promise<PeerMessage> {
  const deadline = Date.now() + (options.timeoutMs ?? E2E_TIMEOUT.db);
  const session = await loginSupabase(
    options.viewerEmail,
    options.viewerPassword,
  );
  let lastBodies: string[] = [];

  while (Date.now() < deadline) {
    const messages = await listPeerMessages(
      session.accessToken,
      options.peerProfileId,
    );
    lastBodies = messages.map((m) => m.body);
    const token = options.body.match(/\d{8,}/)?.[0] ?? options.body;
    const match = messages.find(
      (m) =>
        (m.body === options.body || m.body.includes(token)) &&
        (options.contentType == null ||
          m.content_type === options.contentType),
    );
    if (match) {
      expect(
        peerAuthorId(match),
        `author_id DB per "${options.body}"`,
      ).toBe(options.expectedSenderId);
      return match;
    }
    await new Promise((r) => setTimeout(r, 500));
  }

  throw new Error(
    `messaggio "${options.body}" assente su DB (viewer=${options.viewerEmail}, peer=${options.peerProfileId}). Ultimi body: ${JSON.stringify(lastBodies.slice(-8))}`,
  );
}

/** Verifica bidirezionale: mittente e destinatario vedono lo stesso messaggio su DB. */
export async function expectMessagePersistedBothSides(options: {
  body: string;
  senderUserId: string;
  recipientUserId: string;
  senderEmail: string;
  senderPassword: string;
  recipientEmail: string;
  recipientPassword: string;
  contentType?: string;
}) {
  const contentType = options.contentType ?? 'text';
  await waitForMessageInDb({
    viewerEmail: options.senderEmail,
    viewerPassword: options.senderPassword,
    peerProfileId: options.recipientUserId,
    body: options.body,
    expectedSenderId: options.senderUserId,
    contentType,
  });
  await waitForMessageInDb({
    viewerEmail: options.recipientEmail,
    viewerPassword: options.recipientPassword,
    peerProfileId: options.senderUserId,
    body: options.body,
    expectedSenderId: options.senderUserId,
    contentType,
  });
}
