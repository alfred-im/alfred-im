import '../models/chat_peer.dart';
import '../models/contact.dart';
import '../models/profile_summary.dart';
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
        return ChatPeer.fromProfile(
          profile: profile,
          address: profile.username,
        );
    }
  }

  ChatPeer peerFromContact(Contact contact) {
    if (contact.protocol == ContactProtocol.internal) {
      final profileId = contact.linkedProfileId;
      if (profileId == null) {
        throw StateError('Contatto interno non valido');
      }
      return ChatPeer.fromProfile(
        profile: ProfileSummary(
          id: profileId,
          displayName: contact.displayName,
          avatarUrl: contact.avatarUrl,
        ),
        address: contact.displayName,
      );
    }

    final externalAddress = contact.externalAddress;
    if (externalAddress == null || externalAddress.trim().isEmpty) {
      throw StateError('Contatto esterno non valido');
    }
    throw StateError('Indirizzo esterno non ancora supportato');
  }
}
