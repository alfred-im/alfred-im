// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

/* Alfred Web Push service worker — VAPID notifications */

const PENDING_OPEN_CHAT_KEY = 'alfred_pending_open_chat';
const PUSH_KEY_SEPARATOR = '|';
const PUSH_CHAT_FRAGMENT_PREFIX = 'push-chat/';

/** Soppressione in RAM (localStorage non disponibile nel service worker). */
let suppressionState = null;

/** Chiave univoca push: account destinatario + peer (mai solo peer). */
function pushConversationKey(ownerUserId, peerProfileId) {
  return ownerUserId + PUSH_KEY_SEPARATOR + peerProfileId;
}

function tryParsePushConversation(payload) {
  if (!payload) return null;
  const owner = payload.recipientUserId || payload.recipient_user_id;
  const peer = payload.peerProfileId || payload.peer_profile_id;
  if (!owner || !peer || owner === peer) return null;
  return {
    ownerUserId: owner,
    peerProfileId: peer,
    canonicalKey: pushConversationKey(owner, peer),
  };
}

function pushNotificationTag(payload) {
  const conversation = tryParsePushConversation(payload);
  if (!conversation) return undefined;
  if (payload.logicalMessageId || payload.logical_message_id) {
    const logical =
      payload.logicalMessageId || payload.logical_message_id;
    return (
      conversation.canonicalKey + PUSH_KEY_SEPARATOR + logical
    );
  }
  return conversation.canonicalKey;
}

function applySuppressionState(state) {
  suppressionState = state;
}

function shouldSuppress(data) {
  const conversation = tryParsePushConversation(data);
  if (!conversation) return false;
  const state = suppressionState;
  if (!state || !state.appVisible) return false;
  return (
    state.focusUserId === conversation.ownerUserId &&
    state.activePeerProfileId === conversation.peerProfileId
  );
}

function formatNotificationTitle(payload) {
  const peer = payload.peerDisplayName || payload.peer_display_name || 'Alfred';
  const account =
    payload.recipientUsername ||
    payload.recipient_username ||
    payload.recipientDisplayName ||
    payload.recipient_display_name ||
    null;
  if (account) {
    return account + ' · da ' + peer;
  }
  return peer;
}

function pushOpenChatUrl(conversation) {
  return (
    './#' +
    PUSH_CHAT_FRAGMENT_PREFIX +
    conversation.ownerUserId +
    '/' +
    conversation.peerProfileId
  );
}

function parseClientMessage(raw) {
  if (raw == null) return null;
  if (typeof raw === 'string') {
    try {
      return JSON.parse(raw);
    } catch (_) {
      return null;
    }
  }
  if (typeof raw === 'object') return raw;
  return null;
}

self.addEventListener('message', (event) => {
  const data = parseClientMessage(event.data);
  if (!data || !data.type) return;

  if (data.type === 'alfred_push_suppression') {
    applySuppressionState({
      focusUserId: data.focusUserId ?? null,
      activePeerProfileId: data.activePeerProfileId ?? null,
      appVisible: !!data.appVisible,
    });
  }
});

self.addEventListener('push', (event) => {
  if (!event.data) return;

  let payload;
  try {
    payload = event.data.json();
  } catch (_) {
    return;
  }

  if (shouldSuppress(payload)) {
    return;
  }

  const conversation = tryParsePushConversation(payload);
  if (!conversation) return;

  const title = formatNotificationTitle(payload);
  const body = payload.previewText || payload.preview_text || 'Nuovo messaggio';
  const tag = pushNotificationTag(payload);

  event.waitUntil(
    (async () => {
      await self.registration.showNotification(title, {
        body,
        tag,
        icon: 'icons/Icon-192.png',
        badge: 'icons/Icon-192.png',
        data: payload,
      });

      const windowClients = await self.clients.matchAll({
        type: 'window',
        includeUncontrolled: true,
      });
      const notice = JSON.stringify({
        type: 'alfred_push_received',
        payload,
      });
      for (const client of windowClients) {
        client.postMessage(notice);
      }
    })(),
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const data = event.notification.data || {};
  const conversation = tryParsePushConversation(data);
  if (!conversation) return;

  const openChatMessage = JSON.stringify({
    type: 'open_chat',
    recipientUserId: conversation.ownerUserId,
    peerProfileId: conversation.peerProfileId,
  });
  const launchUrl = pushOpenChatUrl(conversation);

  event.waitUntil(
    (async () => {
      const clients = await self.clients.matchAll({
        type: 'window',
        includeUncontrolled: true,
      });

      for (const client of clients) {
        client.postMessage(openChatMessage);
        if ('focus' in client) {
          await client.focus();
        }
        return;
      }

      await self.clients.openWindow(launchUrl);
    })(),
  );
});
