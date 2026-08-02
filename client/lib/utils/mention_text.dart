// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'auth_identity.dart';

/// `@username` in body messaggio — solo rendering (PROM-MESSAGE-MENTION).
///
/// Non matcha `@` dentro email (`mario@gmail.com`) né prefissi invalidi (`@bad-name`).
final RegExp mentionTokenPattern = RegExp(
  r'(?<![a-zA-Z0-9_.])@([a-z0-9_]{3,32})(?=[\s.,!?;:)\]]|$|@)',
  caseSensitive: false,
);

class MentionMatch {
  const MentionMatch({
    required this.start,
    required this.end,
    required this.username,
    required this.fullText,
  });

  final int start;
  final int end;
  final String username;
  final String fullText;
}

List<MentionMatch> findMentionMatches(String text) {
  final matches = <MentionMatch>[];
  for (final match in mentionTokenPattern.allMatches(text)) {
    final username = AuthIdentity.normalizeUsername(match.group(1)!);
    if (!AuthIdentity.isValidUsername(username)) continue;
    matches.add(
      MentionMatch(
        start: match.start,
        end: match.end,
        username: username,
        fullText: match.group(0)!,
      ),
    );
  }
  return matches;
}

/// Mittente: no link sul proprio username nell'own message; altri lettori sì.
bool shouldLinkMention({
  required String username,
  required bool isMine,
  required String? viewerUsername,
}) {
  if (!AuthIdentity.isValidUsername(username)) return false;
  if (isMine && viewerUsername != null) {
    final viewer = AuthIdentity.normalizeUsername(viewerUsername);
    if (username == viewer) return false;
  }
  return true;
}
