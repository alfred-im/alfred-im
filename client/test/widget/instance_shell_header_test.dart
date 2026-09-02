// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:alfred_client/models/instance_settings.dart';
import 'package:alfred_client/runtime/instance_runtime.dart';
import 'package:alfred_client/theme/alfred_colors.dart';
import 'package:alfred_client/widgets/instance_shell_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(InstanceRuntime.resetForTest);

  testWidgets('InstanceShellHeader shows display name when wordmark absent',
      (tester) async {
    InstanceRuntime.overrideForTest(
      InstanceRuntime(
        settings: const InstanceSettings(
          displayName: 'Garden Chat',
          imServerId: 'garden.example',
        ),
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: InstanceShellHeader(
            titleStyle: TextStyle(
              color: AlfredColors.textOnDark,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Garden Chat'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('InstanceShellHeader shows wordmark image when configured',
      (tester) async {
    InstanceRuntime.overrideForTest(
      InstanceRuntime(
        settings: const InstanceSettings(
          displayName: 'Garden Chat',
          imServerId: 'garden.example',
          branding: InstanceBrandingAssets(
            wordmarkUrl: 'https://cdn.example/wordmark.png',
          ),
        ),
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: InstanceShellHeader(
            titleStyle: TextStyle(
              color: AlfredColors.textOnDark,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Garden Chat'), findsNothing);
    expect(
      find.bySemanticsLabel('Garden Chat'),
      findsOneWidget,
    );
  });
}
