// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:alfred_client/machines/shareable-link/shareable_link_adapters.dart';
import 'package:alfred_client/machines/shareable-link/shareable_link_effects.dart';
import 'package:alfred_client/machines/shareable-link/shareable_link_machine.dart';
import 'package:alfred_client/models/profile_summary.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingShareableLinkEffects implements ShareableLinkEffects {
  @override
  bool sessionReady = true;
  @override
  bool hasOpenAccounts = true;
  @override
  String? focusedUserId = 'user-a';
  ProfileSummary? profileToReturn;
  int openChatCount = 0;
  int overlayCount = 0;
  String? lastUsername;

  @override
  Future<ProfileSummary?> findProfileByUsername(String localUsername) async {
    lastUsername = localUsername;
    return profileToReturn;
  }

  @override
  Future<bool> openSharedChat({
    required String accountUserId,
    required String peerProfileId,
  }) async {
    openChatCount++;
    return true;
  }

  @override
  Future<void> showProfileOverlay(ProfileSummary profile) async {
    overlayCount++;
  }
}

ProfileSummary _profile(String id, String username) => ProfileSummary(
      id: id,
      username: username,
      displayName: username,
    );

void main() {
  group('ShareableLinkMachine', () {
    test('ResolveSharedLink valido → pending', () {
      final effects = _RecordingShareableLinkEffects();
      final machine = ShareableLinkMachine(effects);
      final adapters = ShareableLinkAdapters(machine);

      adapters.onFragmentChanged('mario');

      expect(machine.state, ShareableLinkState.pending);
      expect(machine.target?.address, 'mario');
    });

    test('session not ready → target resta in coda', () async {
      final effects = _RecordingShareableLinkEffects()..sessionReady = false;
      final machine = ShareableLinkMachine(effects);
      final adapters = ShareableLinkAdapters(machine);

      adapters.onFragmentChanged('mario/chat');
      await adapters.onHandleRequested();

      expect(machine.state, ShareableLinkState.pending);
      expect(effects.openChatCount, 0);
    });

    test('focus senza sessione GoTrue → target resta in coda', () async {
      final effects = _RecordingShareableLinkEffects()
        ..focusedUserId = null;
      final machine = ShareableLinkMachine(effects);
      final adapters = ShareableLinkAdapters(machine);

      adapters.onFragmentChanged('mario/chat');
      await adapters.onHandleRequested();

      expect(machine.state, ShareableLinkState.pending);
      expect(effects.openChatCount, 0);
    });

    test('chat link → OpenSharedChat via effetti', () async {
      final effects = _RecordingShareableLinkEffects()
        ..profileToReturn = _profile('peer-b', 'mario');
      final machine = ShareableLinkMachine(effects);
      final adapters = ShareableLinkAdapters(machine);

      adapters.onFragmentChanged('mario/chat');
      await adapters.onHandleRequested();

      expect(effects.openChatCount, 1);
      expect(machine.state, ShareableLinkState.idle);
      expect(machine.target, isNull);
    });

    test('profile link → overlay profilo', () async {
      final effects = _RecordingShareableLinkEffects()
        ..profileToReturn = _profile('peer-b', 'mario');
      final machine = ShareableLinkMachine(effects);
      final adapters = ShareableLinkAdapters(machine);

      adapters.onFragmentChanged('mario');
      await adapters.onHandleRequested();

      expect(effects.overlayCount, 1);
      expect(effects.openChatCount, 0);
    });

    test('profilo assente → invalid', () async {
      final effects = _RecordingShareableLinkEffects();
      final machine = ShareableLinkMachine(effects);
      final adapters = ShareableLinkAdapters(machine);

      adapters.onFragmentChanged('unknown');
      await adapters.onHandleRequested();

      expect(machine.state, ShareableLinkState.invalid);
    });

    test('self peer → ignorato', () async {
      final effects = _RecordingShareableLinkEffects()
        ..profileToReturn = _profile('user-a', 'mario');
      final machine = ShareableLinkMachine(effects);
      final adapters = ShareableLinkAdapters(machine);

      adapters.onFragmentChanged('mario/chat');
      await adapters.onHandleRequested();

      expect(effects.openChatCount, 0);
      expect(machine.state, ShareableLinkState.idle);
    });

    test('DismissSharedLinkNotFound → idle', () async {
      final effects = _RecordingShareableLinkEffects();
      final machine = ShareableLinkMachine(effects);
      final adapters = ShareableLinkAdapters(machine);

      adapters.onFragmentChanged('unknown');
      await adapters.onHandleRequested();
      expect(machine.state, ShareableLinkState.invalid);

      adapters.onDismissNotFound();
      expect(machine.state, ShareableLinkState.idle);
      expect(machine.target, isNull);
    });
  });
}
