// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import { createClient, type SupabaseClient } from "jsr:@supabase/supabase-js@2";
import webpush from "web-push";

type PushPayload = {
  recipient_user_id: string;
  recipient_display_name?: string;
  recipient_username?: string | null;
  peer_profile_id: string;
  peer_display_name: string;
  preview_text: string;
  logical_message_id: string;
  content_type?: string;
};

type PushRuntimeConfig = {
  vapidPublicKey: string;
  vapidPrivateKey: string;
  vapidSubject: string;
  dispatchSecret: string;
};

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

async function resolvePushConfig(
  supabase: SupabaseClient,
): Promise<PushRuntimeConfig> {
  let vapidPublicKey = Deno.env.get("VAPID_PUBLIC_KEY") ?? "";
  let vapidPrivateKey = Deno.env.get("VAPID_PRIVATE_KEY") ?? "";
  let vapidSubject = Deno.env.get("VAPID_SUBJECT") ?? "mailto:push@alfred.app";
  let dispatchSecret = Deno.env.get("PUSH_DISPATCH_SECRET") ?? "";

  if (
    !vapidPublicKey ||
    !vapidPrivateKey ||
    !dispatchSecret
  ) {
    const { data, error } = await supabase.rpc("internal_push_dispatch_config");
    if (!error && data && typeof data === "object") {
      const row = data as Record<string, string | null>;
      vapidPublicKey = vapidPublicKey || row.vapid_public_key || "";
      vapidPrivateKey = vapidPrivateKey || row.vapid_private_key || "";
      vapidSubject = row.vapid_subject || vapidSubject;
      dispatchSecret = dispatchSecret || row.dispatch_secret || "";
    }
  }

  return { vapidPublicKey, vapidPrivateKey, vapidSubject, dispatchSecret };
}

function unauthorized(): Response {
  return new Response(JSON.stringify({ error: "unauthorized" }), {
    status: 401,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("method not allowed", { status: 405 });
  }

  if (!supabaseUrl || !serviceRoleKey) {
    return new Response(JSON.stringify({ error: "push not configured" }), {
      status: 503,
      headers: { "Content-Type": "application/json" },
    });
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey);
  const { vapidPublicKey, vapidPrivateKey, vapidSubject, dispatchSecret } =
    await resolvePushConfig(supabase);

  if (dispatchSecret) {
    const headerSecret = req.headers.get("X-Push-Dispatch-Secret");
    if (headerSecret !== dispatchSecret) {
      return unauthorized();
    }
  }

  let payload: PushPayload;
  try {
    payload = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "invalid json" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (
    !payload.recipient_user_id ||
    !payload.peer_profile_id ||
    !payload.logical_message_id
  ) {
    return new Response(JSON.stringify({ error: "missing fields" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (!vapidPublicKey || !vapidPrivateKey) {
    return new Response(JSON.stringify({ error: "push not configured" }), {
      status: 503,
      headers: { "Content-Type": "application/json" },
    });
  }

  webpush.setVapidDetails(vapidSubject, vapidPublicKey, vapidPrivateKey);

  const { data: subscriptions, error } = await supabase
    .from("push_subscriptions")
    .select("id, endpoint, p256dh_key, auth_key")
    .eq("user_id", payload.recipient_user_id);

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  const notification = JSON.stringify({
    recipientUserId: payload.recipient_user_id,
    recipientDisplayName: payload.recipient_display_name ?? null,
    recipientUsername: payload.recipient_username ?? null,
    peerProfileId: payload.peer_profile_id,
    peerDisplayName: payload.peer_display_name,
    previewText: payload.preview_text,
    logicalMessageId: payload.logical_message_id,
    contentType: payload.content_type ?? "text",
  });

  let sent = 0;
  const staleEndpoints = new Set<string>();

  for (const sub of subscriptions ?? []) {
    try {
      await webpush.sendNotification(
        {
          endpoint: sub.endpoint,
          keys: {
            p256dh: sub.p256dh_key,
            auth: sub.auth_key,
          },
        },
        notification,
        { TTL: 3600 },
      );
      sent += 1;
    } catch (err) {
      const statusCode = (err as { statusCode?: number }).statusCode;
      if (statusCode === 404 || statusCode === 410) {
        staleEndpoints.add(sub.endpoint);
      }
    }
  }

  for (const endpoint of staleEndpoints) {
    await supabase.from("push_subscriptions").delete().eq("endpoint", endpoint);
  }

  return new Response(JSON.stringify({ sent, stale: staleEndpoints.size }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
