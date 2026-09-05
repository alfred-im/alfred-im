// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import { createLocalConfirmedUser, type LocalE2eUser } from './local-auth';
import {
  addReceptionAllowlist,
  configureLocalChatMediaBucket,
} from './local-push-setup';
import { loginSupabase } from './supabase-api';

export type SnakeCast = {
  stamp: string;
  e1: LocalE2eUser;
  e2: LocalE2eUser;
  e3: LocalE2eUser;
  e4: LocalE2eUser;
  group: LocalE2eUser;
  session1: Awaited<ReturnType<typeof loginSupabase>>;
  session2: Awaited<ReturnType<typeof loginSupabase>>;
  session3: Awaited<ReturnType<typeof loginSupabase>>;
  session4: Awaited<ReturnType<typeof loginSupabase>>;
};

/** Cast fisso release — 4 user + gruppo; allowlist come photo-resume. */
export async function createSnakeCast(stamp: string): Promise<SnakeCast> {
  configureLocalChatMediaBucket();
  const e1 = await createLocalConfirmedUser(`s1${stamp}`);
  const e2 = await createLocalConfirmedUser(`s2${stamp}`);
  const e3 = await createLocalConfirmedUser(`s3${stamp}`);
  const e4 = await createLocalConfirmedUser(`s4${stamp}`);
  const group = await createLocalConfirmedUser(`sg${stamp}`, {
    profileKind: 'group',
  });

  const session1 = await loginSupabase(e1.email, e1.password);
  const session2 = await loginSupabase(e2.email, e2.password);
  const session3 = await loginSupabase(e3.email, e3.password);
  const session4 = await loginSupabase(e4.email, e4.password);

  for (const other of [e2, e3, e4, group]) {
    await addReceptionAllowlist({
      recipientUserId: e1.userId,
      allowedProfileId: other.userId,
      recipientAccessToken: session1.accessToken,
    });
    const sessionOther = await loginSupabase(other.email, other.password);
    await addReceptionAllowlist({
      recipientUserId: other.userId,
      allowedProfileId: e1.userId,
      recipientAccessToken: sessionOther.accessToken,
    });
  }

  await addReceptionAllowlist({
    recipientUserId: e2.userId,
    allowedProfileId: e1.userId,
    recipientAccessToken: session2.accessToken,
  });
  await addReceptionAllowlist({
    recipientUserId: e1.userId,
    allowedProfileId: e2.userId,
    recipientAccessToken: session1.accessToken,
  });

  return {
    stamp,
    e1,
    e2,
    e3,
    e4,
    group,
    session1,
    session2,
    session3,
    session4,
  };
}

export function snakeManifestOrder(cast: SnakeCast): LocalE2eUser[] {
  return [cast.e1, cast.e2, cast.e3, cast.e4, cast.group];
}
