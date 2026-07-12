// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';

import 'package:alfred_client/utils/auth_redirect_url.dart';

void main() {
  test('resolve returns GitHub Pages default off-web', () {
    expect(AuthRedirectUrl.resolve(), AuthRedirectUrl.githubPagesDefault);
  });

  group('resolveForOrigin', () {
    test('GitHub Pages origin → githubPagesDefault', () {
      expect(
        AuthRedirectUrl.resolveForOrigin(
          Uri.parse('https://alfred-im.github.io/alfred-im/'),
        ),
        AuthRedirectUrl.githubPagesDefault,
      );
    });

    test('GitHub Pages without trailing slash → githubPagesDefault', () {
      expect(
        AuthRedirectUrl.resolveForOrigin(
          Uri.parse('https://alfred-im.github.io/alfred-im'),
        ),
        AuthRedirectUrl.githubPagesDefault,
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
          Uri.parse('http://127.0.0.1:8080/alfred-im/'),
        ),
        'http://127.0.0.1:8080/alfred-im/',
      );
    });

    test('host non locale → githubPagesDefault', () {
      expect(
        AuthRedirectUrl.resolveForOrigin(
          Uri.parse('https://preview.example.com/app/'),
        ),
        AuthRedirectUrl.githubPagesDefault,
      );
    });
  });
}
