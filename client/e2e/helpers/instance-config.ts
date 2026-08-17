// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import { execSync } from 'node:child_process';

import { expect } from '@playwright/test';

import { loginSupabase } from './supabase-api';
import { E2E_TIMEOUT } from './timeouts';

const SUPABASE_URL =
  process.env.SUPABASE_URL ?? 'http://127.0.0.1:54321';
const ANON_KEY =
  process.env.SUPABASE_ANON_KEY ??
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';

function runPsqlScalar(sql: string): string {
  return execSync(
    `docker exec -i supabase_db_alfred psql -U postgres -d postgres -t -A -c ${JSON.stringify(sql)}`,
    { encoding: 'utf8' },
  ).trim();
}

function runPsqlJson<T>(sql: string): T {
  const raw = runPsqlScalar(sql);
  if (!raw) {
    throw new Error(`psql empty result for: ${sql}`);
  }
  return JSON.parse(raw) as T;
}

/** Promuove un profilo locale a `profile_kind = owner` (setup e2e). */
export function promoteProfileToOwner(userId: string): void {
  const sql =
    `UPDATE public.profiles ` +
    `SET profile_kind = 'owner', updated_at = now() ` +
    `WHERE id = '${userId}';`;
  execSync(
    `docker exec -i supabase_db_alfred psql -U postgres -d postgres -v ON_ERROR_STOP=1 -c ${JSON.stringify(sql)}`,
    { stdio: 'pipe' },
  );
}

export type InstanceConfigExpectation = {
  displayName: string;
  imServerId: string;
  logoUrl: string;
  themeColor: string;
  privacyUrl: string;
  termsUrl: string;
  supportUrl: string;
};

export function readInstanceConfigFromDb(): InstanceConfigExpectation {
  const displayName = runPsqlScalar(
    `SELECT coalesce(value #>> '{}', '') FROM public.instance_config WHERE key = 'instance.display_name';`,
  );
  const imServerId = runPsqlScalar(
    `SELECT coalesce(value #>> '{}', '') FROM public.instance_config WHERE key = 'instance.im_server_id';`,
  );
  const branding = runPsqlJson<{ logo_url?: string; theme_color?: string }>(
    `SELECT coalesce(value, '{}'::jsonb)::text FROM public.instance_config WHERE key = 'instance.branding';`,
  );
  const legal = runPsqlJson<{
    privacy_url?: string;
    terms_url?: string;
    support_url?: string;
  }>(
    `SELECT coalesce(value, '{}'::jsonb)::text FROM public.instance_config WHERE key = 'instance.legal';`,
  );

  return {
    displayName,
    imServerId,
    logoUrl: branding.logo_url ?? '',
    themeColor: branding.theme_color ?? '',
    privacyUrl: legal.privacy_url ?? '',
    termsUrl: legal.terms_url ?? '',
    supportUrl: legal.support_url ?? '',
  };
}

export async function expectInstanceConfigInDb(
  expected: InstanceConfigExpectation,
): Promise<void> {
  await expect
    .poll(() => readInstanceConfigFromDb(), {
      timeout: E2E_TIMEOUT.db,
    })
    .toEqual(expected);
}

export async function readInstanceBootstrapViaRpc(
  email: string,
  password: string,
): Promise<InstanceConfigExpectation> {
  const session = await loginSupabase(email, password);
  const res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/get_instance_bootstrap`, {
    method: 'POST',
    headers: {
      apikey: ANON_KEY,
      Authorization: `Bearer ${session.accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({}),
  });
  if (!res.ok) {
    throw new Error(
      `get_instance_bootstrap fallito (${res.status}): ${await res.text()}`,
    );
  }
  const raw = (await res.json()) as Record<string, unknown>;
  const branding =
    raw['instance.branding'] as { logo_url?: string; theme_color?: string } | undefined;
  const legal = raw['instance.legal'] as {
    privacy_url?: string;
    terms_url?: string;
    support_url?: string;
  } | undefined;

  return {
    displayName: String(raw['instance.display_name'] ?? ''),
    imServerId: String(raw['instance.im_server_id'] ?? ''),
    logoUrl: branding?.logo_url ?? '',
    themeColor: branding?.theme_color ?? '',
    privacyUrl: legal?.privacy_url ?? '',
    termsUrl: legal?.terms_url ?? '',
    supportUrl: legal?.support_url ?? '',
  };
}

export async function expectInstanceBootstrapViaRpc(
  email: string,
  password: string,
  expected: InstanceConfigExpectation,
): Promise<void> {
  await expect
    .poll(() => readInstanceBootstrapViaRpc(email, password), {
      timeout: E2E_TIMEOUT.db,
    })
    .toEqual(expected);
}
