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

  testWidgets('ProfileCoverHeader compact edgeToEdge skips rounded card clip',
      (tester) async {
    const profile = ProfileSummary(
      id: 'u1',
      username: 'alice',
      displayName: 'Alice',
      coverUrl: 'https://example.com/cover.jpg',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProfileCoverHeader(
            profile: profile,
            presentation: ProfileCoverPresentation.compact,
            edgeToEdge: true,
          ),
        ),
      ),
    );

    expect(find.byType(ClipRRect), findsNothing);
    expect(find.text('Alice'), findsOneWidget);
  });

  testWidgets('ProfileCoverHeader immersive places close and share on opposite sides',
      (tester) async {
    const profile = ProfileSummary(
      id: 'u1',
      username: 'bob',
      displayName: 'Bob',
      coverUrl: 'https://example.com/cover.jpg',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileCoverHeader(
            profile: profile,
            heroStyle: ProfileCoverHeroStyle.immersive,
            overlayTopStart: const Icon(Icons.close, key: Key('close')),
            overlayTopEnd: const Icon(Icons.share, key: Key('share')),
          ),
        ),
      ),
    );

    final closeRect = tester.getRect(find.byKey(const Key('close')));
    final shareRect = tester.getRect(find.byKey(const Key('share')));
    expect(closeRect.left, lessThan(shareRect.left));
    expect(shareRect.right, greaterThan(closeRect.right));
  });
}
