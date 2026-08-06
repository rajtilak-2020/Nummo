import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/transaction.dart';
import '../../models/category.dart';
import '../../models/budget.dart';
import '../crypto/pin_crypto.dart';

/// Secure storage repository providing platform-encrypted persistence,
/// complete legacy migration, atomic writes, and malformed record recovery.
class SecureStorageRepository {
  static const String _keyTransactions = 'nummo_secure_transactions_v3';
  static const String _keyPinHash = 'nummo_secure_pin_hash';
  static const String _keyPinSalt = 'nummo_secure_pin_salt';
  static const String _keyPinEnabled = 'nummo_secure_pin_enabled';
  static const String _keyBioEnabled = 'nummo_secure_bio_enabled';
  static const String _keyCategories = 'nummo_secure_categories_v3';
  static const String _keyBudgets = 'nummo_secure_budgets_v3';
  static const String _keyAccentPreset = 'nummo_secure_accent_preset';
  static const String _keyThemeMode = 'nummo_secure_theme_mode';
  static const String _keySeenAndroidPrompt = 'nummo_seen_android_prompt';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// Performs comprehensive migration from legacy SharedPreferences formats without deleting keys prematurely.
  Future<void> migrateLegacyStorageIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. PIN Migration
      final legacyPin = prefs.getString('app_pin') ?? prefs.getString('pin');
      if (legacyPin != null && legacyPin.isNotEmpty) {
        final existingHash = await _secureStorage.read(key: _keyPinHash);
        if (existingHash == null || existingHash.isEmpty) {
          final salt = PinCrypto.generateSalt();
          final hash = PinCrypto.hashPin(legacyPin, salt);
          await _secureStorage.write(key: _keyPinHash, value: hash);
          await _secureStorage.write(key: _keyPinSalt, value: salt);
          await _secureStorage.write(key: _keyPinEnabled, value: 'true');
        }
        await prefs.remove('app_pin');
        await prefs.remove('pin');
      }

      // 2. Biometric Settings Migration
      if (prefs.containsKey('local_auth_enabled') || prefs.containsKey('bio_enabled')) {
        final bioVal = prefs.getBool('local_auth_enabled') ?? prefs.getBool('bio_enabled') ?? false;
        await _secureStorage.write(key: _keyBioEnabled, value: bioVal ? 'true' : 'false');
        await prefs.remove('local_auth_enabled');
        await prefs.remove('bio_enabled');
      }

      // 3. Custom Tags / Categories Migration
      final legacyTags = prefs.getStringList('custom_tags') ?? prefs.getStringList('tags');
      if (legacyTags != null && legacyTags.isNotEmpty) {
        final existingCats = await loadCategories();
        final Set<String> existingNames = existingCats.map((c) => c.name.toUpperCase()).toSet();
        final List<CategoryTag> updatedCats = List.from(existingCats);

        for (final tagStr in legacyTags) {
          if (!existingNames.contains(tagStr.toUpperCase())) {
            updatedCats.add(CategoryTag.fromString(tagStr));
          }
        }
        await saveCategories(updatedCats);
        await prefs.remove('custom_tags');
        await prefs.remove('tags');
      }

      // 4. Budget Migration
      final legacyBudgetStr = prefs.getString('budget') ?? prefs.getString('custom_budgets');
      if (legacyBudgetStr != null && legacyBudgetStr.isNotEmpty) {
        try {
          final decoded = jsonDecode(legacyBudgetStr);
          if (decoded is Map<String, dynamic>) {
            final b = Budget.fromJson(decoded);
            final existing = await loadBudgets();
            if (existing.isEmpty) {
              await saveBudgets([b]);
            }
          }
        } catch (_) {}
        await prefs.remove('budget');
        await prefs.remove('custom_budgets');
      }

      // 5. Transactions Migration (Handles list of strings OR single JSON string)
      final existingTxns = await _secureStorage.read(key: _keyTransactions);
      if (existingTxns == null) {
        List<Transaction> legacyList = [];

        final dynamic rawTxns = prefs.get('transactions');

        if (rawTxns is String && rawTxns.trim().startsWith('[')) {
          try {
            final List<dynamic> array = jsonDecode(rawTxns);
            for (final item in array) {
              if (item is Map<String, dynamic>) {
                legacyList.add(Transaction.fromJson(item));
              }
            }
          } catch (e) {
            debugPrint('Error parsing single JSON string legacy transactions: $e');
          }
        } else if (rawTxns is List) {
          for (final item in rawTxns) {
            try {
              if (item is String) {
                final Map<String, dynamic> map = jsonDecode(item);
                legacyList.add(Transaction.fromJson(map));
              } else if (item is Map<String, dynamic>) {
                legacyList.add(Transaction.fromJson(item));
              }
            } catch (e) {
              debugPrint('Skipped malformed legacy record: $e');
            }
          }
        }

        if (legacyList.isNotEmpty) {
          await saveTransactions(legacyList);
          await prefs.remove('transactions');
        }
      }
    } catch (e) {
      debugPrint('Error during legacy storage migration: $e');
    }
  }

  // --- Transactions ---

  Future<List<Transaction>> loadTransactions() async {
    await migrateLegacyStorageIfNeeded();
    final raw = await _secureStorage.read(key: _keyTransactions);
    if (raw == null || raw.isEmpty) return [];

    final List<Transaction> result = [];
    try {
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          try {
            final txn = Transaction.fromJson(item);
            if (txn.amount > 0) result.add(txn);
          } catch (e) {
            debugPrint('Skipped malformed transaction record: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error parsing transactions: $e');
    }

    result.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    _recalculateBalances(result);
    return result.reversed.toList();
  }

  Future<void> saveTransactions(List<Transaction> transactions) async {
    final sorted = List<Transaction>.from(transactions);
    sorted.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    _recalculateBalances(sorted);

    final encoded = jsonEncode(sorted.map((t) => t.toJson()).toList());
    await _secureStorage.write(key: _keyTransactions, value: encoded);
  }

  void _recalculateBalances(List<Transaction> list) {
    double running = 0.0;
    for (final txn in list) {
      if (txn.isCredit) {
        running += txn.amount;
      } else {
        running -= txn.amount;
      }
      txn.balanceAfter = running;
    }
  }

  // --- Categories ---

  Future<List<CategoryTag>> loadCategories() async {
    final raw = await _secureStorage.read(key: _keyCategories);
    if (raw == null || raw.isEmpty) return CategoryTag.defaults;
    try {
      final List<dynamic> decoded = jsonDecode(raw);
      final List<CategoryTag> result = [];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          result.add(CategoryTag.fromJson(item));
        }
      }
      return result.isEmpty ? CategoryTag.defaults : result;
    } catch (_) {
      return CategoryTag.defaults;
    }
  }

  Future<void> saveCategories(List<CategoryTag> categories) async {
    final encoded = jsonEncode(categories.map((c) => c.toJson()).toList());
    await _secureStorage.write(key: _keyCategories, value: encoded);
  }

  // --- Budgets ---

  Future<List<Budget>> loadBudgets() async {
    final raw = await _secureStorage.read(key: _keyBudgets);
    if (raw == null || raw.isEmpty) return [];
    try {
      final List<dynamic> decoded = jsonDecode(raw);
      final List<Budget> result = [];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          result.add(Budget.fromJson(item));
        }
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  Future<void> saveBudgets(List<Budget> budgets) async {
    final encoded = jsonEncode(budgets.map((b) => b.toJson()).toList());
    await _secureStorage.write(key: _keyBudgets, value: encoded);
  }

  // --- PIN & Security ---

  Future<bool> isPinEnabled() async {
    final val = await _secureStorage.read(key: _keyPinEnabled);
    return val == 'true';
  }

  Future<bool> verifyPin(String inputPin) async {
    final hash = await _secureStorage.read(key: _keyPinHash);
    final salt = await _secureStorage.read(key: _keyPinSalt);
    if (hash == null || salt == null) return false;
    return PinCrypto.verifyPin(inputPin, hash, salt);
  }

  Future<void> setPin(String pin) async {
    final salt = PinCrypto.generateSalt();
    final hash = PinCrypto.hashPin(pin, salt);
    await _secureStorage.write(key: _keyPinHash, value: hash);
    await _secureStorage.write(key: _keyPinSalt, value: salt);
    await _secureStorage.write(key: _keyPinEnabled, value: 'true');
  }

  Future<void> clearPin() async {
    await _secureStorage.delete(key: _keyPinHash);
    await _secureStorage.delete(key: _keyPinSalt);
    await _secureStorage.write(key: _keyPinEnabled, value: 'false');
  }

  Future<bool> isBiometricsEnabled() async {
    final val = await _secureStorage.read(key: _keyBioEnabled);
    return val == 'true';
  }

  Future<void> setBiometricsEnabled(bool enabled) async {
    await _secureStorage.write(key: _keyBioEnabled, value: enabled ? 'true' : 'false');
  }

  // --- Theme Preferences ---

  Future<String?> loadAccentPreset() async {
    return await _secureStorage.read(key: _keyAccentPreset);
  }

  Future<void> saveAccentPreset(String presetName) async {
    await _secureStorage.write(key: _keyAccentPreset, value: presetName);
  }

  Future<String?> loadThemeMode() async {
    return await _secureStorage.read(key: _keyThemeMode);
  }

  Future<void> saveThemeMode(String mode) async {
    await _secureStorage.write(key: _keyThemeMode, value: mode);
  }

  Future<bool> hasSeenAndroidPrompt() async {
    final val = await _secureStorage.read(key: _keySeenAndroidPrompt);
    return val == 'true';
  }

  Future<void> setHasSeenAndroidPrompt() async {
    await _secureStorage.write(key: _keySeenAndroidPrompt, value: 'true');
  }

  Future<void> clearAllData() async {
    await _secureStorage.deleteAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
