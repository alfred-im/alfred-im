import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/open_account.dart';

/// Persistenza account aperti e focus UI.
class AccountStorageService {
  static const _accountsKey = 'alfred_saved_accounts';
  static const _focusUserIdKey = 'alfred_focus_user_id';

  Future<void>? _writeChain;

  Future<SharedPreferences> _prefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (kIsWeb) {
      await prefs.reload();
    }
    return prefs;
  }

  Future<List<OpenAccount>> loadAccounts() async {
    final prefs = await _prefs();
    final raw = prefs.getString(_accountsKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => OpenAccount.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<String?> loadFocusUserId() async {
    final prefs = await _prefs();
    return prefs.getString(_focusUserIdKey);
  }

  Future<void> saveFocusUserId(String? userId) async {
    final prefs = await _prefs();
    if (userId == null) {
      await prefs.remove(_focusUserIdKey);
      return;
    }
    await prefs.setString(_focusUserIdKey, userId);
  }

  /// Sostituisce l'intera lista (scrittura atomica).
  ///
  /// **Runtime**: non usare nel flusso multi-account — preferire [upsertAccount] /
  /// [removeAccount]. Ammesso solo in test che verificano il round-trip del metodo.
  Future<void> saveAllAccounts(List<OpenAccount> accounts) async {
    await _serializedWrite(() async {
      await _saveAccounts(accounts);
    });
  }

  Future<void> upsertAccount(OpenAccount account) async {
    await _serializedWrite(() async {
      final accounts = await loadAccounts();
      final updated = [
        account,
        ...accounts.where((a) => a.userId != account.userId),
      ];
      await _saveAccounts(updated);
    });
  }

  Future<void> removeAccount(String userId) async {
    await _serializedWrite(() async {
      final accounts = await loadAccounts();
      await _saveAccounts(accounts.where((a) => a.userId != userId).toList());
    });
  }

  Future<void> _saveAccounts(List<OpenAccount> accounts) async {
    final prefs = await _prefs();
    if (accounts.isEmpty) {
      await prefs.remove(_accountsKey);
      return;
    }
    final encoded = jsonEncode(accounts.map((a) => a.toJson()).toList());
    await prefs.setString(_accountsKey, encoded);
  }

  Future<void> _serializedWrite(Future<void> Function() action) async {
    final waitFor = _writeChain ?? Future<void>.value();
    final done = Completer<void>();
    _writeChain = done.future;
    await waitFor;
    try {
      await action();
    } finally {
      done.complete();
    }
  }
}
