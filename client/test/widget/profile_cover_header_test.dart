// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alfred_client/models/profile_summary.dart';
import 'package:alfred_client/widgets/profile_cover_header.dart';

void main() {
  testWidgets('ProfileCoverHeader compact falls back without cover', (tester) async {
    const profile = ProfileSummary(
      id: 'u1',
      username: 'alice',
      displayName: 'Alice',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProfileCoverHeader(
            profile: profile,
            presentation: ProfileCoverPresentation.compact,
          ),
        ),
      ),
    );

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('@alice'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });
}
