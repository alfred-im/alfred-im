import 'package:alfred_client/models/contact.dart';
import 'package:alfred_client/services/compose_service.dart';
import 'package:alfred_client/services/profile_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late ComposeService composeService;

  setUp(() {
    composeService = ComposeService(
      profileService: ProfileService(
        SupabaseClient(
          'http://127.0.0.1',
          'test-anon-key',
          authOptions: const FlutterAuthClientOptions(
            localStorage: EmptyLocalStorage(),
            autoRefreshToken: false,
          ),
        ),
      ),
    );
  });

  // spec: PROM-PERSONAL-CONTACTS-006
  group('ComposeService.peerFromContact', () {
    test('maps internal contact to ChatPeer', () {
      final peer = composeService.peerFromContact(
        Contact(
          id: 'c1',
          ownerId: 'owner',
          protocol: ContactProtocol.internal,
          linkedProfileId: 'peer-1',
          displayName: 'Alice',
          avatarUrl: 'https://example.com/a.jpg',
          createdAt: DateTime.utc(2026, 6, 28),
        ),
      );

      expect(peer.profileId, 'peer-1');
      expect(peer.displayName, 'Alice');
    });

    test('rejects external contact (scope attuale)', () {
      expect(
        () => composeService.peerFromContact(
          Contact(
            id: 'c2',
            ownerId: 'owner',
            protocol: ContactProtocol.xmpp,
            externalAddress: 'alice@xmpp.example',
            displayName: 'Alice XMPP',
            createdAt: DateTime.utc(2026, 6, 28),
          ),
        ),
        throwsA(
          predicate<StateError>(
            (e) => e.message.contains('Indirizzo esterno non ancora supportato'),
          ),
        ),
      );
    });
  });
}
