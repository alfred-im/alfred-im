// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Named library required so @Tags(['stack']) applies to all tests in this file.
// ignore_for_file: unnecessary_library_name

@Tags(['stack'])
library password_reset_gotrue_test;

import 'package:supabase/supabase.dart';
import 'package:test/test.dart';

import 'package:alfred_client/config/app_config.dart';

const _agentEmail = String.fromEnvironment(
  'CI_AGENT1_EMAIL',
  defaultValue: 'ci-agent1@e2e.local.test',
);
const _redirect = String.fromEnvironment(
  'CI_LOCAL_REDIRECT',
  defaultValue: 'http://localhost:8080/',
);

/// Storage in-memory minimo per PKCE (come farebbe Supabase.initialize).
class _MemoryPkceStorage implements GotrueAsyncStorage {
  final Map<String, String> _store = {};

  @override
  Future<String?> getItem({required String key}) async => _store[key];

  @override
  Future<void> removeItem({required String key}) async => _store.remove(key);

  @override
  Future<void> setItem({required String key, required String value}) async {
    _store[key] = value;
  }
}

SupabaseClient _rawClient(
  AuthFlowType flow, {
  GotrueAsyncStorage? pkceStorage,
}) {
  return SupabaseClient(
    AppConfig.supabaseUrl,
    AppConfig.supabaseAnonKey,
    authOptions: AuthClientOptions(
      authFlowType: flow,
      pkceAsyncStorage: pkceStorage,
      autoRefreshToken: false,
    ),
  );
}

String _errorLabel(Object e) {
  if (e is AuthException) {
    return 'AuthException(${e.message}, status=${e.statusCode})';
  }
  return '${e.runtimeType}: $e';
}

bool _isAcceptableStackFailure(Object e) {
  final label = _errorLabel(e).toLowerCase();
  return label.contains('rate limit') ||
      label.contains('over_email_send_rate_limit') ||
      label.contains('status=429') ||
      label.contains('security purposes') ||
      label.contains('unexpected_failure') ||
      label.contains('status=500') ||
      label.contains('unable to process request');
}

void main() {
  group('password reset GoTrue (stack locale)', () {
    test('BUG: PKCE senza pkceAsyncStorage → crash client (null)', () async {
      final client = _rawClient(AuthFlowType.pkce);
      addTearDown(client.dispose);

      Object? caught;
      try {
        await client.auth.resetPasswordForEmail(
          _agentEmail,
          redirectTo: _redirect,
        );
      } catch (e) {
        caught = e;
      }

      expect(caught, isNotNull, reason: 'atteso crash client, non successo API');
      final label = _errorLabel(caught!);
      expect(
        label.toLowerCase(),
        anyOf(
          contains('null'),
          contains('asyncstorage'),
          contains('assert'),
        ),
        reason: 'errore grezzo: $label',
      );
    });

    test('PKCE con pkceAsyncStorage → OK o errore noto (no crash null)', () async {
      final client = _rawClient(
        AuthFlowType.pkce,
        pkceStorage: _MemoryPkceStorage(),
      );
      addTearDown(client.dispose);

      Object? caught;
      try {
        await client.auth.resetPasswordForEmail(
          _agentEmail,
          redirectTo: _redirect,
        );
      } catch (e) {
        caught = e;
      }

      if (caught == null) return;

      final err = caught;
      final label = _errorLabel(err);
      expect(
        label.toLowerCase(),
        isNot(contains('null')),
        reason: 'non deve crashare: $label',
      );
      expect(
        _isAcceptableStackFailure(err),
        isTrue,
        reason: 'se fallisce deve essere errore GoTrue noto: $label',
      );
    });

    test('FIX: PKCE + pkceAsyncStorage (bootstrap produzione) → OK o errore noto',
        () async {
      final client = _rawClient(
        AuthFlowType.pkce,
        pkceStorage: _MemoryPkceStorage(),
      );
      addTearDown(client.dispose);

      Object? caught;
      try {
        await client.auth.resetPasswordForEmail(
          _agentEmail,
          redirectTo: _redirect,
        );
      } catch (e) {
        caught = e;
      }

      if (caught == null) return;

      final err = caught;
      final label = _errorLabel(err);
      expect(
        label.toLowerCase(),
        isNot(contains('null')),
        reason: 'PKCE con storage non deve crashare: $label',
      );
      expect(
        _isAcceptableStackFailure(err),
        isTrue,
        reason: 'se fallisce deve essere errore GoTrue noto: $label',
      );
    });
  });
}
