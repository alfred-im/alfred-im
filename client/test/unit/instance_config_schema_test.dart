// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:alfred_client/models/instance_config_schema.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('InstanceConfigSchema exposes exactly eleven editable fields', () {
    final fieldIds = InstanceConfigSchema.sections
        .expand((section) => section.fields)
        .map((field) => field.id)
        .toList();

    expect(fieldIds, [
      'display_name',
      'im_server_id',
      'short_name',
      'description',
      'theme_color',
      'background_color',
      'logo',
      'wordmark',
      'favicon',
      'privacy_url',
      'terms_url',
      'support_url',
    ]);
  });

  test('InstanceConfigSchema allows only four top-level DB keys', () {
    expect(InstanceConfigSchema.allowedTopLevelKeys, {
      'instance.display_name',
      'instance.im_server_id',
      'instance.branding',
      'instance.legal',
    });
  });
}
