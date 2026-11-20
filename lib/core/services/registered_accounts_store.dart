import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chronicles.dart';

/// Non-secret profile metadata for accounts used on this phone.
///
/// No password or token is stored here. The active session stays in
/// [AuthSessionStore]'s encrypted bundle; this registry only powers the
/// "registered on this phone" picker on the login screen.
class RegisteredAccount {
  final String id;
  final String email;
  final String penName;
  final String displayName;
  final String? profileImageUrl;
  final DateTime lastUsedAt;

  const RegisteredAccount({
    required this.id,
    required this.email,
    required this.penName,
    required this.displayName,
    this.profileImageUrl,
    required this.lastUsedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'penName': penName,
        'displayName': displayName,
        'profileImageUrl': profileImageUrl,
        'lastUsedAt': lastUsedAt.toIso8601String(),
      };

  factory RegisteredAccount.fromJson(Map<String, dynamic> json) {
    return RegisteredAccount(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      penName: json['penName']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
      profileImageUrl: json['profileImageUrl']?.toString(),
      lastUsedAt:
          DateTime.tryParse(json['lastUsedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class RegisteredAccountsStore {
  RegisteredAccountsStore._();

  static final RegisteredAccountsStore instance = RegisteredAccountsStore._();

  static const String _key = 'whispr_registered_accounts_v1';

  Future<List<RegisteredAccount>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final accounts = <RegisteredAccount>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final account =
            RegisteredAccount.fromJson(Map<String, dynamic>.from(item));
        if (account.id.isNotEmpty || account.email.isNotEmpty) {
          accounts.add(account);
        }
      }
      accounts.sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));
      return accounts;
    } catch (e) {
      return const [];
    }
  }

  /// Adds or refreshes an account. De-duplicates by id, then by email, so
  /// signing in twice from different devices still leaves one row per user.
  Future<void> upsert(Creator creator) async {
    final email = creator.email.trim().toLowerCase();
    if (creator.id.isEmpty && email.isEmpty) return;

    final accounts = await load();
    final index = accounts.indexWhere((account) =>
        (creator.id.isNotEmpty && account.id == creator.id) ||
        (email.isNotEmpty && account.email.trim().toLowerCase() == email));

    final entry = RegisteredAccount(
      id: creator.id,
      email: creator.email,
      penName: creator.penName,
      displayName: creator.displayName,
      profileImageUrl: creator.profileImageUrl,
      lastUsedAt: DateTime.now(),
    );
    if (index >= 0) {
      accounts[index] = entry;
    } else {
      accounts.add(entry);
    }
    await _write(accounts);
  }

  /// "Forget this account" only removes the picker entry. It never signs
  /// anyone out or touches the active encrypted session.
  Future<void> remove(String id) async {
    final accounts = await load();
    accounts.removeWhere((account) => account.id == id);
    await _write(accounts);
  }

  Future<void> _write(List<RegisteredAccount> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(accounts.map((account) => account.toJson()).toList()),
    );
  }
}

final registeredAccountsProvider =
    FutureProvider.autoDispose<List<RegisteredAccount>>((ref) async {
  return RegisteredAccountsStore.instance.load();
});
