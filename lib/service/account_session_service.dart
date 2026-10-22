import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:passbook/model/mem_info_model.dart';
import 'package:passbook/model/saved_account.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccountSessionService {
  static const String savedAccountsKey = 'saved_accounts';
  static const String activeAccountIdKey = 'active_account_id';
  static const String _sessionPrefix = 'account_session_';

  AccountSessionService._internal();
  static final AccountSessionService _instance = AccountSessionService._internal();
  factory AccountSessionService() => _instance;

  Future<SharedPreferences> get _prefs async =>
      SharedPreferences.getInstance();

  String _sessionKey(String accountId) => '$_sessionPrefix$accountId';

  Future<void> migrateLegacySessionIfNeeded() async {
    final prefs = await _prefs;
    final rawList = prefs.getString(savedAccountsKey);
    if (rawList != null && rawList.isNotEmpty) return;

    final userInfoString = prefs.getString('user_info');
    if (userInfoString == null) return;

    try {
      final user = MemInfoModel.fromJsonString(userInfoString);
      final token =
          prefs.getString('milk_passbook_auth_token') ?? user.authtoken ?? '';
      await _persistSession(user, token);
      final id = SavedAccount.idFor(user);
      await prefs.setString(savedAccountsKey, jsonEncode([SavedAccount.fromUser(user).toJson()]));
      await prefs.setString(activeAccountIdKey, id);
    } catch (e) {
      debugPrint('AccountSessionService migrate failed: $e');
    }
  }

  Future<List<SavedAccount>> getSavedAccounts() async {
    final prefs = await _prefs;
    final raw = prefs.getString(savedAccountsKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((item) => SavedAccount.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (e) {
      debugPrint('AccountSessionService getSavedAccounts failed: $e');
      return [];
    }
  }

  Future<String?> getActiveAccountId() async {
    final prefs = await _prefs;
    return prefs.getString(activeAccountIdKey);
  }

  Future<({MemInfoModel user, String token})?> loadSession(String accountId) async {
    final prefs = await _prefs;
    final raw = prefs.getString(_sessionKey(accountId));
    if (raw == null) return null;

    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final user = MemInfoModel.fromJson(
        Map<String, dynamic>.from(data['userInfo'] as Map),
      );
      final token = data['token'] as String? ?? user.authtoken ?? '';
      return (user: user, token: token);
    } catch (e) {
      debugPrint('AccountSessionService loadSession failed: $e');
      return null;
    }
  }

  Future<void> saveAccount(
    MemInfoModel user,
    String token, {
    bool setActive = true,
  }) async {
    await _persistSession(user, token);

    final prefs = await _prefs;
    final id = SavedAccount.idFor(user);
    final accounts = await getSavedAccounts();
    final updated = [...accounts.where((a) => a.id != id), SavedAccount.fromUser(user)];

    await prefs.setString(
      savedAccountsKey,
      jsonEncode(updated.map((a) => a.toJson()).toList()),
    );

    if (setActive) {
      await prefs.setString(activeAccountIdKey, id);
      await prefs.setString('milk_passbook_auth_token', token);
      await prefs.setString('user_info', jsonEncode(user.toJson()));
    }
  }

  Future<bool> switchToAccount(String accountId) async {
    final session = await loadSession(accountId);
    if (session == null) return false;

    final prefs = await _prefs;
    await prefs.setString('milk_passbook_auth_token', session.token);
    await prefs.setString('user_info', jsonEncode(session.user.toJson()));
    await prefs.setString(activeAccountIdKey, accountId);
    return true;
  }

  Future<void> removeAccount(String accountId) async {
    final prefs = await _prefs;
    final accounts = await getSavedAccounts();
    final updated = accounts.where((a) => a.id != accountId).toList();

    await prefs.remove(_sessionKey(accountId));

    if (updated.isEmpty) {
      await prefs.remove(savedAccountsKey);
      await prefs.remove(activeAccountIdKey);
      return;
    }

    await prefs.setString(
      savedAccountsKey,
      jsonEncode(updated.map((a) => a.toJson()).toList()),
    );

    final activeId = prefs.getString(activeAccountIdKey);
    if (activeId == accountId) {
      await prefs.setString(activeAccountIdKey, updated.first.id);
    }
  }

  Future<void> clearAll() async {
    final prefs = await _prefs;
    final accounts = await getSavedAccounts();
    for (final account in accounts) {
      await prefs.remove(_sessionKey(account.id));
    }
    await prefs.remove(savedAccountsKey);
    await prefs.remove(activeAccountIdKey);
  }

  Future<void> _persistSession(MemInfoModel user, String token) async {
    final prefs = await _prefs;
    final id = SavedAccount.idFor(user);
    await prefs.setString(
      _sessionKey(id),
      jsonEncode({
        'token': token,
        'userInfo': user.toJson(),
      }),
    );
  }
}
