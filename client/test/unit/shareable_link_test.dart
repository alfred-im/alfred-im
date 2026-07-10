import 'package:alfred_client/models/profile_summary.dart';
import 'package:alfred_client/utils/shareable_link.dart';
import 'package:flutter_test/flutter_test.dart';

// spec: PROM-SHAREABLE-LINK-001, 002, 030
void main() {
  group('parseShareableFragment', () {
    test('profile with bare username', () {
      final target = parseShareableFragment('test2');
      expect(target?.address, 'test2');
      expect(target?.kind, ShareableLinkKind.profile);
    });

    test('chat suffix', () {
      final target = parseShareableFragment('test2/chat');
      expect(target?.address, 'test2');
      expect(target?.kind, ShareableLinkKind.chat);
    });

    test('username@local server', () {
      final target = parseShareableFragment('mario@alfred.app/chat');
      expect(target?.address, 'mario@alfred.app');
      expect(target?.kind, ShareableLinkKind.chat);
    });

    test('empty fragment', () {
      expect(parseShareableFragment(null), isNull);
      expect(parseShareableFragment(''), isNull);
      expect(parseShareableFragment('   '), isNull);
    });

    test('invalid address', () {
      expect(parseShareableFragment('!!'), isNull);
    });

    test('external server not resolvable on this instance', () {
      expect(parseShareableFragment('mario@dominio.it'), isNull);
    });
  });

  group('resolveShareableAddress', () {
    test('bare username', () {
      final resolution = resolveShareableAddress('Mario_Rossi');
      expect(resolution?.localUsername, 'mario_rossi');
      expect(resolution?.normalizedAddress, 'mario_rossi');
    });

    test('local server suffix', () {
      final resolution = resolveShareableAddress('mario@alfred.app');
      expect(resolution?.localUsername, 'mario');
    });

    test('remote server rejected', () {
      expect(resolveShareableAddress('mario@dominio.it'), isNull);
    });
  });

  group('canonicalShareableAddress', () {
    test('uses lowercase username', () {
      const profile = ProfileSummary(
        id: 'id',
        displayName: 'Mario',
        username: 'Mario_Rossi',
      );
      expect(canonicalShareableAddress(profile), 'mario_rossi');
    });

    test('throws without username', () {
      const profile = ProfileSummary(
        id: 'id',
        displayName: 'Mario',
      );
      expect(() => canonicalShareableAddress(profile), throwsStateError);
    });
  });

  group('buildShareableProfileUrl', () {
    test('includes hash fragment', () {
      final url = buildShareableProfileUrl('test2');
      expect(url, contains('#test2'));
      expect(url, isNot(contains('/chat')));
    });
  });

  group('profileForSharing', () {
    test('uses manifest username when profile lacks it', () {
      const profile = ProfileSummary(
        id: 'id',
        displayName: 'Mario',
      );
      final enriched = profileForSharing(profile, fallbackUsername: 'mario');
      expect(enriched.username, 'mario');
      expect(enriched.shareableProfileUrl, contains('#mario'));
    });
  });
}
