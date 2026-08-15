// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';

import 'package:alfred_client/config/deploy_config.dart';
import 'package:alfred_client/utils/auth_redirect_url.dart';

void main() {
  tearDown(DeployConfig.resetForTest);

  test('resolve uses deploy publicBaseUrl off-web', () {
    DeployConfig.overrideForTest(
      DeployConfig(
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'anon',
        publicBaseUrl: 'https://demo.example/app/',
      ),
    );
    expect(AuthRedirectUrl.resolve(), 'https://demo.example/app/');
  });

  group('resolveForOrigin', () {
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

    test('host non locale → publicBaseUrl da deploy', () {
      DeployConfig.overrideForTest(
        DeployConfig(
          supabaseUrl: 'https://example.supabase.co',
          supabaseAnonKey: 'anon',
          publicBaseUrl: 'https://mygarden.example/',
        ),
      );
      expect(
        AuthRedirectUrl.resolveForOrigin(
          Uri.parse('https://preview.example.com/app/'),
        ),
        'https://mygarden.example/',
      );
    });

    test('host non locale senza deploy → origine corrente', () {
      expect(
        AuthRedirectUrl.resolveForOrigin(
          Uri.parse('https://preview.example.com/app/'),
        ),
        'https://preview.example.com/app/',
      );
    });
  });
}
