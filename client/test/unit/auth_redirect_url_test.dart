import 'package:flutter_test/flutter_test.dart';

import 'package:alfred_client/utils/auth_redirect_url.dart';

void main() {
  test('resolve returns dev demo default off-web', () {
    expect(AuthRedirectUrl.resolve(), AuthRedirectUrl.devDemoDefault);
  });

  group('resolveForOrigin', () {
    test('GitHub Pages origin → devDemoDefault', () {
      expect(
        AuthRedirectUrl.resolveForOrigin(
          Uri.parse('https://alfred-im.github.io/XmppTest/'),
        ),
        AuthRedirectUrl.devDemoDefault,
      );
    });

    test('GitHub Pages without trailing slash → devDemoDefault', () {
      expect(
        AuthRedirectUrl.resolveForOrigin(
          Uri.parse('https://alfred-im.github.io/XmppTest'),
        ),
        AuthRedirectUrl.devDemoDefault,
      );
    });

    test('localhost dev → current origin with trailing slash', () {
      expect(
        AuthRedirectUrl.resolveForOrigin(
          Uri.parse('http://localhost:8080'),
        ),
        'http://localhost:8080/',
      );
    });

    test('127.0.0.1 dev → current origin', () {
      expect(
        AuthRedirectUrl.resolveForOrigin(
          Uri.parse('http://127.0.0.1:8080/XmppTest/'),
        ),
        'http://127.0.0.1:8080/XmppTest/',
      );
    });

    test('host non locale → devDemoDefault', () {
      expect(
        AuthRedirectUrl.resolveForOrigin(
          Uri.parse('https://preview.example.com/app/'),
        ),
        AuthRedirectUrl.devDemoDefault,
      );
    });
  });
}
