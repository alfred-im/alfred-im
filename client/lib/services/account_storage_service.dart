import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/saved_account.dart';

/// Persistenza account Alfred multi-sessione (stile Thunderbird).
class AccountStorageService {
  static const _storageKey = 'alfred_saved_accounts';

  Future<List<SavedAccount>> loadAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => SavedAccount.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> upsertAccount(SavedAccount account) async {
    final accounts = await loadAccounts();
    final updated = [
      account,
      ...accounts.where((a) => a.userId != account.userId),
    ];
    await _save(updated);
  }

  Future<void> removeAccount(String userId) async {
    final accounts = await loadAccounts();
    await _save(accounts.where((a) => a.userId != userId).toList());
  }

  Future<void> _save(List<SavedAccount> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(accounts.map((a) => a.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }
}
