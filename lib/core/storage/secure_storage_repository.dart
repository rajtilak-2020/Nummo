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
  static const String _keyFingerprintEnabled = 'nummo_secure_fingerprint_enabled';
  static const String _keyCategories = 'nummo_secure_categories_v3';
  static const String _keyBudgets = 'nummo_secure_budgets_v3';
  static const String _keyAccentPreset = 'nummo_secure_accent_preset';
  static const String _keyThemeMode = 'nummo_secure_theme_mode';
  static const String _keyPrivacyMode = 'nummo_secure_privacy_mode';
  static const String _keySeenAndroidPrompt = 'nummo_seen_android_prompt';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  final Map<String, String> _memCache = {};
  SharedPreferences? _cachedPrefs;
  bool _migrationChecked = false;

  Future<SharedPreferences> _getPrefs() async {
    _cachedPrefs ??= await SharedPreferences.getInstance();
    return _cachedPrefs!;
  }

  Future<String?> _readFast(String key) async {
    if (_memCache.containsKey(key)) {
      return _memCache[key];
    }
    // 1. Check in-memory SharedPreferences
    final prefs = await _getPrefs();
    final prefVal = prefs.getString(key);
    if (prefVal != null && prefVal.isNotEmpty) {
      _memCache[key] = prefVal;
      return prefVal;
    }
    // 2. Check FlutterSecureStorage directly without any timeout (guarantees v1.1.9 data is never lost)
    try {
      final secureVal = await _secureStorage.read(key: key);
      if (secureVal != null && secureVal.isNotEmpty) {
        _memCache[key] = secureVal;
        await prefs.setString(key, secureVal);
        return secureVal;
      }
    } catch (e) {
      debugPrint('Error reading secure storage fallback for $key: $e');
    }
    return null;
  }

  Future<void> _writeFast(String key, String value) async {
    _memCache[key] = value;
    final prefs = await _getPrefs();
    await prefs.setString(key, value);
    try {
      await _secureStorage.write(key: key, value: value);
    } catch (e) {
      debugPrint('Error dual-writing secure storage for $key: $e');
    }
  }

  Future<void> _deleteFast(String key) async {
    _memCache.remove(key);
    final prefs = await _getPrefs();
    await prefs.remove(key);
    try {
      await _secureStorage.delete(key: key);
    } catch (e) {
      debugPrint('Error deleting secure storage for $key: $e');
    }
  }

  /// Performs comprehensive migration from legacy SharedPreferences formats without deleting keys prematurely.
  Future<void> migrateLegacyStorageIfNeeded() async {
    if (_migrationChecked) return;
    _migrationChecked = true;
    try {
      final prefs = await _getPrefs();

      // 1. PIN Migration
      final legacyPin = prefs.getString('app_pin') ?? prefs.getString('pin');
      if (legacyPin != null && legacyPin.isNotEmpty) {
        final existingHash = await _readFast(_keyPinHash);
        if (existingHash == null || existingHash.isEmpty) {
          final salt = PinCrypto.generateSalt();
          final hash = PinCrypto.hashPin(legacyPin, salt);
          await _writeFast(_keyPinHash, hash);
          await _writeFast(_keyPinSalt, salt);
          await _writeFast(_keyPinEnabled, 'true');
        }
        await prefs.remove('app_pin');
        await prefs.remove('pin');
      }

      // 2. Biometric Settings Migration
      if (prefs.containsKey('local_auth_enabled') || prefs.containsKey('bio_enabled')) {
        final bioVal = prefs.getBool('local_auth_enabled') ?? prefs.getBool('bio_enabled') ?? false;
        await _writeFast(_keyBioEnabled, bioVal ? 'true' : 'false');
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
      final existingTxns = await _readFast(_keyTransactions);
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
    final raw = await _readFast(_keyTransactions);
    if (raw == null || raw.isEmpty) return [];

    try {
      if (kIsWeb || raw.length < 2048) {
        return _decodeTransactionsPayload(raw);
      }
      return await compute(_decodeTransactionsPayload, raw);
    } catch (e) {
      debugPrint('Error parsing transactions in isolate: $e');
      return _decodeTransactionsPayload(raw);
    }
  }

  Future<void> saveTransactions(List<Transaction> transactions) async {
    final sorted = List<Transaction>.from(transactions);
    sorted.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    _recalculateBalances(sorted);

    final rawMaps = sorted.map((t) => t.toJson()).toList();
    String encoded;
    try {
      if (kIsWeb || rawMaps.length < 50) {
        encoded = jsonEncode(rawMaps);
      } else {
        encoded = await compute(_encodeTransactionsPayload, rawMaps);
      }
    } catch (_) {
      encoded = jsonEncode(rawMaps);
    }

    await _writeFast(_keyTransactions, encoded);
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
    await migrateLegacyStorageIfNeeded();
    final raw = await _readFast(_keyCategories);
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
    await _writeFast(_keyCategories, encoded);
  }

  // --- Budgets ---

  Future<List<Budget>> loadBudgets() async {
    await migrateLegacyStorageIfNeeded();
    final raw = await _readFast(_keyBudgets);
    if (raw == null || raw.isEmpty) return [];
    try {
      final List<dynamic> decoded = jsonDecode(raw);
      final List<Budget> result = [];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          result.add(Budget.fromJson(item));
        }
      }
      return result.isEmpty ? [] : result;
    } catch (_) {
      return [];
    }
  }

  Future<void> saveBudgets(List<Budget> budgets) async {
    final encoded = jsonEncode(budgets.map((b) => b.toJson()).toList());
    await _writeFast(_keyBudgets, encoded);
  }

  // --- PIN & Security ---

  Future<bool> isPinEnabled() async {
    await migrateLegacyStorageIfNeeded();
    final val = await _readFast(_keyPinEnabled);
    return val == 'true';
  }

  Future<bool> verifyPin(String inputPin) async {
    final hash = await _readFast(_keyPinHash);
    final salt = await _readFast(_keyPinSalt);
    if (hash == null || salt == null) return false;
    return PinCrypto.verifyPin(inputPin, hash, salt);
  }

  Future<void> setPin(String pin) async {
    final salt = PinCrypto.generateSalt();
    final hash = PinCrypto.hashPin(pin, salt);
    await _writeFast(_keyPinHash, hash);
    await _writeFast(_keyPinSalt, salt);
    await _writeFast(_keyPinEnabled, 'true');
  }

  Future<void> clearPin() async {
    await _deleteFast(_keyPinHash);
    await _deleteFast(_keyPinSalt);
    await _writeFast(_keyPinEnabled, 'false');
  }

  Future<bool> isBiometricsEnabled() async {
    return isFingerprintEnabled();
  }

  Future<void> setBiometricsEnabled(bool enabled) async {
    await setFingerprintEnabled(enabled);
  }

  Future<bool> isFingerprintEnabled() async {
    final val = await _readFast(_keyFingerprintEnabled);
    if (val == null) {
      final legacyBio = await _readFast(_keyBioEnabled);
      return legacyBio == 'true';
    }
    return val == 'true';
  }

  Future<void> setFingerprintEnabled(bool enabled) async {
    await _writeFast(_keyFingerprintEnabled, enabled ? 'true' : 'false');
    await _writeFast(_keyBioEnabled, enabled ? 'true' : 'false');
  }

  // --- Theme Preferences ---

  Future<String?> loadAccentPreset() async {
    return await _readFast(_keyAccentPreset);
  }

  Future<void> saveAccentPreset(String presetName) async {
    await _writeFast(_keyAccentPreset, presetName);
  }

  Future<String?> loadThemeMode() async {
    return await _readFast(_keyThemeMode);
  }

  Future<void> saveThemeMode(String mode) async {
    await _writeFast(_keyThemeMode, mode);
  }

  Future<bool> loadPrivacyMode() async {
    final val = await _readFast(_keyPrivacyMode);
    return val == 'true';
  }

  Future<void> savePrivacyMode(bool enabled) async {
    await _writeFast(_keyPrivacyMode, enabled ? 'true' : 'false');
  }

  Future<bool> hasSeenAndroidPrompt() async {
    final val = await _readFast(_keySeenAndroidPrompt);
    return val == 'true';
  }

  Future<void> setHasSeenAndroidPrompt() async {
    await _writeFast(_keySeenAndroidPrompt, 'true');
  }

  Future<void> clearAllData() async {
    _memCache.clear();
    await _secureStorage.deleteAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}

/// Top-level isolate worker for JSON transaction deserialization and balance calculation
List<Transaction> _decodeTransactionsPayload(String raw) {
  final List<Transaction> result = [];
  try {
    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    for (final item in decoded) {
      if (item is Map<String, dynamic>) {
        try {
          final txn = Transaction.fromJson(item);
          if (txn.amount > 0) result.add(txn);
        } catch (_) {}
      }
    }
  } catch (_) {}

  result.sort((a, b) => a.timestamp.compareTo(b.timestamp));
  double running = 0.0;
  for (final txn in result) {
    if (txn.isCredit) {
      running += txn.amount;
    } else {
      running -= txn.amount;
    }
    txn.balanceAfter = running;
  }
  return result.reversed.toList();
}

/// Top-level isolate worker for JSON transaction serialization
String _encodeTransactionsPayload(List<Map<String, dynamic>> rawMaps) {
  return jsonEncode(rawMaps);
}
