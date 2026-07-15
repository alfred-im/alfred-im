// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import '../models/push_conversation_key.dart';

/// Deep link tap notifica: `#push-chat/{recipientUserId}/{peerProfileId}`.
class PushDeepLink {
  const PushDeepLink._();

  static const fragmentPrefix = 'push-chat/';

  static PushConversationKey? tryParseFragment(String? fragment) {
    var raw = (fragment ?? '').trim();
    if (raw.startsWith('/')) {
      raw = raw.substring(1);
    }
    if (!raw.startsWith(fragmentPrefix)) return null;

    final rest = raw.substring(fragmentPrefix.length);
    final slash = rest.indexOf('/');
    if (slash <= 0 || slash >= rest.length - 1) return null;

    return PushConversationKey.tryFromPayload({
      'recipientUserId': rest.substring(0, slash),
      'peerProfileId': rest.substring(slash + 1),
    });
  }

  static String hashFor(PushConversationKey conversation) =>
      '#$fragmentPrefix${conversation.ownerUserId}/${conversation.peerProfileId}';
}
