// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import '../models/chat_peer.dart';
import '../models/contact.dart';
import '../utils/compose_address.dart';
import 'profile_service.dart';

class ComposeService {
  ComposeService({required this.profileService});

  final ProfileService profileService;

  Future<ChatPeer> resolveAddress(String raw) async {
    final parsed = parseComposeAddress(raw);
    switch (parsed.kind) {
      case ComposeAddressKind.invalid:
        throw StateError('Inserisci uno username o un indirizzo user@server');
      case ComposeAddressKind.externalServer:
      case ComposeAddressKind.internalUsername:
        final normalized = parsed.normalized;
        final summaries =
            await profileService.fetchSummariesByAddresses([normalized]);
        if (summaries.isNotEmpty) {
          return ChatPeer.fromProfile(
            peerAddress: normalized,
            profile: summaries.first,
          );
        }
        if (parsed.kind == ComposeAddressKind.internalUsername) {
          final peer = await profileService.findPeerByUsername(normalized);
          if (peer != null) return peer;
          throw StateError('Utente non trovato');
        }
        return ChatPeer.fromAddress(normalized);
    }
  }

  ChatPeer peerFromContact(Contact contact) {
    return ChatPeer.fromAddress(contact.address);
  }
}
