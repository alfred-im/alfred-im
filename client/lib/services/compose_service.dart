import '../models/chat_peer.dart';
import '../models/contact.dart';
import '../utils/compose_address.dart';
import 'profile_service.dart';

class ComposeService {
  ComposeService({ProfileService? profileService})
      : _profileService = profileService ?? ProfileService();

  final ProfileService _profileService;

  Future<ChatPeer> resolveAddress(String raw) async {
    final parsed = parseComposeAddress(raw);
    switch (parsed.kind) {
      case ComposeAddressKind.invalid:
        throw StateError('Inserisci uno username o un indirizzo user@server');
      case ComposeAddressKind.externalServer:
        throw StateError('Indirizzo esterno non ancora supportato');
      case ComposeAddressKind.internalUsername:
        final profile =
            await _profileService.findByUsername(parsed.normalized);
        if (profile == null) {
          throw StateError('Utente non trovato');
        }
        return ChatPeer.internal(
          address: profile.username,
          displayName: profile.displayName,
          profileId: profile.id,
          avatarUrl: profile.avatarUrl,
          pronouns: profile.pronouns,
        );
    }
  }

  ChatPeer peerFromContact(Contact contact) {
    if (contact.protocol == ContactProtocol.internal) {
      final profileId = contact.linkedProfileId;
      if (profileId == null) {
        throw StateError('Contatto interno non valido');
      }
      return ChatPeer.internal(
        address: contact.displayName,
        displayName: contact.displayName,
        profileId: profileId,
        avatarUrl: contact.avatarUrl,
      );
    }

    final externalAddress = contact.externalAddress;
    if (externalAddress == null || externalAddress.trim().isEmpty) {
      throw StateError('Contatto esterno non valido');
    }
    throw StateError('Indirizzo esterno non ancora supportato');
  }
}
