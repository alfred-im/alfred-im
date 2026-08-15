// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';

import 'package:alfred_client/models/instance_settings.dart';

void main() {
  test('InstanceSettings.fromBootstrapJson reads core keys', () {
    final settings = InstanceSettings.fromBootstrapJson({
      'instance.display_name': 'MyGarden',
      'instance.im_server_id': 'mygarden.example',
      'instance.branding': {
        'logo_url': 'https://cdn.example/logo.png',
        'theme_color': '#336699',
      },
      'instance.legal': {
        'privacy_url': 'https://example/privacy',
      },
    });

    expect(settings.displayName, 'MyGarden');
    expect(settings.imServerId, 'mygarden.example');
    expect(settings.branding.logoUrl, 'https://cdn.example/logo.png');
    expect(settings.legal.privacyUrl, 'https://example/privacy');
    expect(settings.legal.hasAny, isTrue);
  });

  test('InstanceSettings falls back when keys missing', () {
    final settings = InstanceSettings.fromBootstrapJson(const {});
    expect(settings.displayName, 'Messaging');
    expect(settings.imServerId, 'localhost');
    expect(settings.legal.hasAny, isFalse);
  });
}
