// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

/**
 * Auth e2e solo su stack locale (supabase start) — nessun account utente sul live.
 */

export function isLocalSupabaseStack(): boolean {
  const url = process.env.SUPABASE_URL ?? '';
  return url.includes('localhost') || url.includes('127.0.0.1');
}

export type LocalE2eUser = {
  email: string;
  password: string;
  username: string;
  userId: string;
};

export async function createLocalConfirmedUser(
  label: string,
  options?: { profileKind?: 'user' | 'group' },
): Promise<LocalE2eUser> {
  const supabaseUrl =
    process.env.SUPABASE_URL ?? 'http://127.0.0.1:54321';
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!serviceKey) {
    throw new Error(
      'SUPABASE_SERVICE_ROLE_KEY mancante — eseguire: eval $(supabase status -o env)',
    );
  }

  const stamp = Date.now().toString().slice(-8);
  const username = `e2e${label}${stamp}`;
  const email = `${username}@e2e.local.test`;
  const password = 'E2eLocalPass123!';

  const res = await fetch(`${supabaseUrl}/auth/v1/admin/users`, {
    method: 'POST',
    headers: {
      apikey: serviceKey,
      Authorization: `Bearer ${serviceKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      email,
      password,
      email_confirm: true,
      user_metadata: {
        username,
        display_name: `E2E ${label}`,
        ...(options?.profileKind === 'group'
          ? { profile_kind: 'group' }
          : {}),
      },
    }),
  });

  if (!res.ok) {
    throw new Error(
      `createLocalConfirmedUser fallito (${res.status}): ${await res.text()}`,
    );
  }

  const json = (await res.json()) as { id: string };
  return {
    email,
    password,
    username,
    userId: json.id,
  };
}
