// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:alfred_client/machines/multi-account/multi_account_adapters.dart';
import 'package:alfred_client/machines/multi-account/multi_account_effects.dart';
import 'package:alfred_client/machines/multi-account/multi_account_machine.dart';
import 'package:alfred_client/models/profile_summary.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingEffects implements MultiAccountEffects {
  @override
  bool hasOpenAccounts = false;
  @override
  bool hasFocusedSession = false;
  String? lastFocusUserId;
  int focusCalls = 0;
  int reconnectCalls = 0;
  int closeCalls = 0;
  bool focusShouldThrow = false;
  @override
  String? focusUserId = 'user-a';

  @override
  Future<ManifestBootstrap> loadManifestBootstrap() async {
    return ManifestBootstrap(
      openAccountUserIds: hasOpenAccounts ? const ['user-a'] : const [],
      persistedFocusUserId: hasOpenAccounts ? 'user-a' : null,
    );
  }

  @override
  Future<void> executeFocus(String accountUserId) async {
    focusCalls++;
    lastFocusUserId = accountUserId;
    if (focusShouldThrow) {
      focusUserId = 'user-a';
      throw StateError('focus failed');
    }
    focusUserId = accountUserId;
  }

  @override
  Future<void> reconnectFocusedSession(String focusUserId) async {
    reconnectCalls++;
    lastFocusUserId = focusUserId;
  }

  @override
  Future<String> openAccountWithPassword({
    required String email,
    required String password,
  }) async {
    hasOpenAccounts = true;
    hasFocusedSession = true;
    return 'user-new';
  }

  @override
  Future<String> openAccountWithSignUp({
    required String email,
    required String password,
    required String username,
    required String displayName,
    ProfileKind profileKind = ProfileKind.user,
  }) async {
    hasOpenAccounts = true;
    hasFocusedSession = true;
    return 'user-new';
  }

  @override
  Future<CloseAccountResult> closeAccount(String accountUserId) async {
    closeCalls++;
    hasOpenAccounts = false;
    hasFocusedSession = false;
    return const CloseAccountResult(
      wasLastAccount: true,
      wasFocused: true,
      remainingUserIds: [],
    );
  }
}

void main() {
  group('MultiAccountMachine resolveFocusUserId', () {
    test('empty manifest → null', () {
      expect(
        MultiAccountMachine.resolveFocusUserId(
          openAccountUserIds: const [],
          persistedFocusUserId: 'user-a',
        ),
        isNull,
      );
    });

    test('valid persisted focus → persisted', () {
      expect(
        MultiAccountMachine.resolveFocusUserId(
          openAccountUserIds: const ['user-a', 'user-b'],
          persistedFocusUserId: 'user-b',
        ),
        'user-b',
      );
    });

    test('stale persisted focus → first account', () {
      expect(
        MultiAccountMachine.resolveFocusUserId(
          openAccountUserIds: const ['user-a', 'user-b'],
          persistedFocusUserId: 'missing',
        ),
        'user-a',
      );
    });
  });

  group('MultiAccountMachine ManifestLoaded', () {
    test('manifest empty → NoOpenAccounts', () async {
      final machine = MultiAccountMachine();
      await machine.send(
        const ManifestLoaded(
          openAccountUserIds: [],
          persistedFocusUserId: null,
        ),
      );
      expect(machine.focusState, MultiAccountFocusState.noOpenAccounts);
      expect(machine.focusUserId, isNull);
    });

    test('manifest + session → FocusedWithSession', () async {
      final machine = MultiAccountMachine();
      await machine.send(
        const ManifestLoaded(
          openAccountUserIds: ['user-a'],
          persistedFocusUserId: 'user-a',
        ),
      );
      await machine.send(
        const FocusActivationCompleted(hasFocusedSession: true),
      );
      expect(machine.focusState, MultiAccountFocusState.focusedWithSession);
      expect(machine.focusUserId, 'user-a');
    });

    test('manifest without session → FocusedAwaitingSession', () async {
      final machine = MultiAccountMachine();
      await machine.send(
        const ManifestLoaded(
          openAccountUserIds: ['user-a'],
          persistedFocusUserId: 'user-a',
        ),
      );
      await machine.send(
        const FocusActivationCompleted(hasFocusedSession: false),
      );
      expect(machine.focusState, MultiAccountFocusState.focusedAwaitingSession);
      expect(machine.focusUserId, 'user-a');
    });
  });

  group('MultiAccountMachine AccountOpened', () {
    test('from NoOpenAccounts with session → FocusedWithSession', () async {
      final machine = MultiAccountMachine();
      await machine.send(
        const AccountOpened(accountUserId: 'user-a', sessionReady: true),
      );
      expect(machine.focusState, MultiAccountFocusState.focusedWithSession);
      expect(machine.focusUserId, 'user-a');
    });

    test('from NoOpenAccounts without session → HasOpenAccounts', () async {
      final machine = MultiAccountMachine();
      await machine.send(
        const AccountOpened(accountUserId: 'user-a', sessionReady: false),
      );
      expect(machine.focusState, MultiAccountFocusState.hasOpenAccounts);
      expect(machine.focusUserId, 'user-a');
    });
  });

  group('MultiAccountMachine FocusAccount', () {
    test('from FocusedWithSession → FocusSwitching → FocusedWithSession', () async {
      final effects = _RecordingEffects()..hasFocusedSession = true;
      final machine = MultiAccountMachine(effects: effects)
        ..send(
          const ManifestLoaded(
            openAccountUserIds: ['user-a'],
            persistedFocusUserId: 'user-a',
          ),
        );
      await machine.send(
        const FocusActivationCompleted(hasFocusedSession: true),
      );

      final future = machine.send(const FocusAccount('user-b'));
      expect(machine.focusState, MultiAccountFocusState.focusSwitching);
      expect(machine.focusUserId, 'user-b');
      await future;

      expect(machine.focusState, MultiAccountFocusState.focusedWithSession);
      expect(effects.lastFocusUserId, 'user-b');
    });

    test('restore failed → FocusedAwaitingSession', () async {
      final effects = _RecordingEffects()
        ..hasOpenAccounts = true
        ..hasFocusedSession = false;
      final machine = MultiAccountMachine(effects: effects)
        ..send(
          const ManifestLoaded(
            openAccountUserIds: ['user-a'],
            persistedFocusUserId: 'user-a',
          ),
        );
      await machine.send(
        const FocusActivationCompleted(hasFocusedSession: true),
      );

      await machine.send(const FocusAccount('user-b'));
      expect(machine.focusState, MultiAccountFocusState.focusedAwaitingSession);
      expect(machine.focusUserId, 'user-b');
    });

    test('ignored from NoOpenAccounts', () async {
      final effects = _RecordingEffects();
      final machine = MultiAccountMachine(effects: effects);

      await machine.send(const FocusAccount('user-a'));

      expect(machine.focusState, MultiAccountFocusState.noOpenAccounts);
      expect(machine.focusUserId, isNull);
      expect(effects.focusCalls, 0);
    });

    test('from HasOpenAccounts → FocusedWithSession on success', () async {
      final effects = _RecordingEffects()
        ..hasOpenAccounts = true
        ..hasFocusedSession = true;
      final machine = MultiAccountMachine(effects: effects)
        ..send(const AccountOpened(accountUserId: 'user-a', sessionReady: false));

      await machine.send(const FocusAccount('user-a'));
      expect(machine.focusState, MultiAccountFocusState.focusedWithSession);
    });

    test('focus error → FocusedAwaitingSession, not stuck switching', () async {
      final effects = _RecordingEffects()
        ..hasOpenAccounts = true
        ..hasFocusedSession = false
        ..focusShouldThrow = true;
      final machine = MultiAccountMachine(effects: effects)
        ..send(
          const ManifestLoaded(
            openAccountUserIds: ['user-a'],
            persistedFocusUserId: 'user-a',
          ),
        );
      await machine.send(
        const FocusActivationCompleted(hasFocusedSession: true),
      );

      await expectLater(
        machine.send(const FocusAccount('user-b')),
        throwsStateError,
      );
      expect(machine.focusState, MultiAccountFocusState.focusedAwaitingSession);
      expect(machine.focusUserId, 'user-a');
    });
  });

  group('MultiAccountMachine ReconnectFocusedSession', () {
    test('from FocusedAwaitingSession with session → FocusedWithSession', () async {
      final effects = _RecordingEffects()..hasOpenAccounts = true;
      final machine = MultiAccountMachine(effects: effects)
        ..send(
          const ManifestLoaded(
            openAccountUserIds: ['user-a'],
            persistedFocusUserId: 'user-a',
          ),
        );
      await machine.send(
        const FocusActivationCompleted(hasFocusedSession: false),
      );

      effects.hasFocusedSession = true;
      await machine.send(const ReconnectFocusedSession());

      expect(effects.reconnectCalls, 1);
      expect(effects.lastFocusUserId, 'user-a');
      expect(machine.focusState, MultiAccountFocusState.focusedWithSession);
    });

    test('ignored outside FocusedAwaitingSession', () async {
      final effects = _RecordingEffects();
      final machine = MultiAccountMachine(effects: effects)
        ..send(
          const ManifestLoaded(
            openAccountUserIds: ['user-a'],
            persistedFocusUserId: 'user-a',
          ),
        );
      await machine.send(
        const FocusActivationCompleted(hasFocusedSession: true),
      );

      await machine.send(const ReconnectFocusedSession());
      expect(effects.reconnectCalls, 0);
      expect(machine.focusState, MultiAccountFocusState.focusedWithSession);
    });
  });

  group('MultiAccountMachine AccountClosed', () {
    test('last account → NoOpenAccounts', () async {
      final machine = MultiAccountMachine()
        ..send(
          const ManifestLoaded(
            openAccountUserIds: ['user-a'],
            persistedFocusUserId: 'user-a',
          ),
        );
      await machine.send(
        const FocusActivationCompleted(hasFocusedSession: true),
      );

      await machine.send(
        const AccountClosed(wasLastAccount: true, sessionReady: false),
      );
      expect(machine.focusState, MultiAccountFocusState.noOpenAccounts);
      expect(machine.focusUserId, isNull);
    });

    test('non-last with session → FocusedWithSession', () async {
      final machine = MultiAccountMachine()
        ..send(
          const ManifestLoaded(
            openAccountUserIds: ['user-a'],
            persistedFocusUserId: 'user-a',
          ),
        );
      await machine.send(
        const FocusActivationCompleted(hasFocusedSession: true),
      );

      await machine.send(
        const AccountClosed(wasLastAccount: false, sessionReady: true),
      );
      expect(machine.focusState, MultiAccountFocusState.focusedWithSession);
    });

    test('non-last without session → FocusedAwaitingSession', () async {
      final machine = MultiAccountMachine()
        ..send(
          const ManifestLoaded(
            openAccountUserIds: ['user-a'],
            persistedFocusUserId: 'user-a',
          ),
        );
      await machine.send(
        const FocusActivationCompleted(hasFocusedSession: true),
      );

      await machine.send(
        const AccountClosed(wasLastAccount: false, sessionReady: false),
      );
      expect(machine.focusState, MultiAccountFocusState.focusedAwaitingSession);
    });
  });

  group('MultiAccountMachine OpenAccount commands', () {
    test('OpenAccountWithPassword → FocusedWithSession', () async {
      final effects = _RecordingEffects();
      final machine = MultiAccountMachine(effects: effects);

      await machine.send(
        const OpenAccountWithPassword(email: 'a@b.com', password: 'secret'),
      );

      expect(machine.focusState, MultiAccountFocusState.focusedWithSession);
      expect(machine.focusUserId, 'user-new');
    });

    test('OpenAccountWithSignUp → FocusedWithSession', () async {
      final effects = _RecordingEffects();
      final machine = MultiAccountMachine(effects: effects);

      await machine.send(
        const OpenAccountWithSignUp(
          email: 'a@b.com',
          password: 'secret',
          username: 'alice',
          displayName: 'Alice',
        ),
      );

      expect(machine.focusState, MultiAccountFocusState.focusedWithSession);
      expect(machine.focusUserId, 'user-new');
    });
  });

  group('MultiAccountAdapters bootstrapManifest', () {
    test('loads manifest and sets machine focus', () async {
      final effects = _RecordingEffects()
        ..hasOpenAccounts = true
        ..hasFocusedSession = false;
      final machine = MultiAccountMachine(effects: effects);
      final adapters = MultiAccountAdapters(machine, effects: effects);

      await adapters.bootstrapManifest();

      expect(machine.focusUserId, 'user-a');
      expect(machine.focusState, MultiAccountFocusState.focusedAwaitingSession);
      expect(effects.focusCalls, 1);
    });
  });
}
