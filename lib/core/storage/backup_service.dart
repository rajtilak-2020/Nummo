import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:crypto/crypto.dart';
import '../../models/transaction.dart';
import '../../models/category.dart';
import '../../models/budget.dart';

/// Backup Service for schema v3 JSON file import/export using Storage Access Framework & AES-GCM.
class BackupService {
  static const int exportVersion = 3;

  /// Creates a versioned nummo-backup-v3.json payload.
  static String createBackupPayload({
    required List<Transaction> transactions,
    required List<CategoryTag> categories,
    required List<Budget> budgets,
    required Map<String, String> preferences,
    String? passphrase,
  }) {
    final Map<String, dynamic> payloadMap = {
      'schemaVersion': exportVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'transactions': transactions.map((t) => t.toJson()).toList(),
      'categories': categories.map((c) => c.toJson()).toList(),
      'budgets': budgets.map((b) => b.toJson()).toList(),
      'preferences': preferences,
    };

    final rawJson = jsonEncode(payloadMap);
    if (passphrase == null || passphrase.trim().isEmpty) {
      return rawJson;
    }

    // Authenticated AES-GCM encryption with SHA256 derived key
    final keyBytes = sha256.convert(utf8.encode(passphrase.trim())).bytes;
    final key = enc.Key(Uint8List.fromList(keyBytes));
    final iv = enc.IV.fromSecureRandom(16);

    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
    final encrypted = encrypter.encrypt(rawJson, iv: iv);

    return jsonEncode({
      'encrypted': true,
      'version': exportVersion,
      'iv': iv.base64,
      'ciphertext': encrypted.base64,
    });
  }

  /// Parses and validates a backup string before writing to storage.
  static Map<String, dynamic>? parseAndValidateBackup({
    required String rawInput,
    String? passphrase,
  }) {
    try {
      String jsonText = rawInput;
      final dynamic decoded = jsonDecode(rawInput);

      if (decoded is Map<String, dynamic> && decoded['encrypted'] == true) {
        if (passphrase == null || passphrase.trim().isEmpty) {
          throw const FormatException('Passphrase required to decrypt backup payload');
        }
        final ivStr = decoded['iv'] as String;
        final cipherStr = decoded['ciphertext'] as String;

        final keyBytes = sha256.convert(utf8.encode(passphrase.trim())).bytes;
        final key = enc.Key(Uint8List.fromList(keyBytes));
        final iv = enc.IV.fromBase64(ivStr);

        final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
        jsonText = encrypter.decrypt(enc.Encrypted.fromBase64(cipherStr), iv: iv);
      }

      final Map<String, dynamic> data = jsonDecode(jsonText) as Map<String, dynamic>;
      if (!data.containsKey('transactions') || data['transactions'] is! List) {
        return null;
      }

      final List<Transaction> txns = [];
      for (final item in data['transactions'] as List) {
        if (item is Map<String, dynamic>) {
          try {
            final t = Transaction.fromJson(item);
            if (t.amount > 0) txns.add(t);
          } catch (_) {}
        }
      }

      final List<CategoryTag> categories = [];
      if (data['categories'] is List) {
        for (final item in data['categories'] as List) {
          if (item is Map<String, dynamic>) {
            try {
              categories.add(CategoryTag.fromJson(item));
            } catch (_) {}
          }
        }
      }

      final List<Budget> budgets = [];
      if (data['budgets'] is List) {
        for (final item in data['budgets'] as List) {
          if (item is Map<String, dynamic>) {
            try {
              budgets.add(Budget.fromJson(item));
            } catch (_) {}
          }
        }
      }

      final Map<String, String> prefs = {};
      if (data['preferences'] is Map) {
        (data['preferences'] as Map).forEach((k, v) {
          prefs[k.toString()] = v.toString();
        });
      }

      return {
        'transactions': txns,
        'categories': categories,
        'budgets': budgets,
        'preferences': prefs,
        'transactionCount': txns.length,
        'categoryCount': categories.length,
        'budgetCount': budgets.length,
      };
    } catch (e) {
      debugPrint('Backup validation error: $e');
      return null;
    }
  }
}
