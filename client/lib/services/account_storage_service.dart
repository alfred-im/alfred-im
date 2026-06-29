import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/open_account.dart';

/// Persistenza account aperti e focus UI.
class AccountStorageService {
  static const _accountsKey = 'alfred_saved_accounts';
  static const _focusUserIdKey = 'alfred_focus_user_id';

  Future<List<OpenAccount>> loadAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_accountsKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => OpenAccount.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<String?> loadFocusUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_focusUserIdKey);
  }

  Future<void> saveFocusUserId(String? userId) async {
    final prefs = await SharedPreferences.getInstance();
    if (userId == null) {
      await prefs.remove(_focusUserIdKey);
      return;
    }
    await prefs.setString(_focusUserIdKey, userId);
  }

  Future<void> upsertAccount(OpenAccount account) async {
    final accounts = await loadAccounts();
    final updated = [
      account,
      ...accounts.where((a) => a.userId != account.userId),
    ];
    await _saveAccounts(updated);
  }

  Future<void> removeAccount(String userId) async {
    final accounts = await loadAccounts();
    await _saveAccounts(accounts.where((a) => a.userId != userId).toList());
  }

  Future<void> _saveAccounts(List<OpenAccount> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(accounts.map((a) => a.toJson()).toList());
    await prefs.setString(_accountsKey, encoded);
  }
}
