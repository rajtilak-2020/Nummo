import 'package:uuid/uuid.dart';

/// Versioned Transaction model supporting UUIDs and defensive deserialization.
class Transaction {
  static const int currentSchemaVersion = 2;

  final String id;
  final double amount;
  final bool isCredit; // true = Income (In), false = Expense (Out)
  final String note;
  final DateTime timestamp;
  final String? tag;
  final int schemaVersion;
  double balanceAfter;

  Transaction({
    String? id,
    required double amount,
    required this.isCredit,
    String? note,
    DateTime? timestamp,
    this.tag,
    this.schemaVersion = currentSchemaVersion,
    this.balanceAfter = 0.0,
  })  : id = (id != null && id.trim().isNotEmpty) ? id.trim() : const Uuid().v4(),
        amount = _sanitizeAmount(amount),
        note = _sanitizeNote(note),
        timestamp = timestamp ?? DateTime.now();

  static double _sanitizeAmount(double raw) {
    if (!raw.isFinite || raw.isNaN || raw <= 0) {
      return 0.0;
    }
    // Cap at sensible maximum (100 Billion)
    if (raw > 100000000000.0) {
      return 100000000000.0;
    }
    return raw;
  }

  static String _sanitizeNote(String? raw) {
    if (raw == null) return 'Untitled';
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 'Untitled';
    if (trimmed.length > 120) return trimmed.substring(0, 120);
    return trimmed;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'isCredit': isCredit,
      'note': note,
      'timestamp': timestamp.toIso8601String(),
      'tag': tag,
      'schemaVersion': schemaVersion,
      'balanceAfter': balanceAfter,
    };
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    final rawAmount = (json['amount'] as num?)?.toDouble() ?? 0.0;
    final isCredit = json['isCredit'] as bool? ?? false;
    final rawNote = json['note'] as String?;
    final tag = json['tag'] as String?;

    DateTime parsedDate;
    if (json['timestamp'] != null) {
      final raw = json['timestamp'];
      if (raw is int) {
        if (raw > 100000000000) {
          parsedDate = DateTime.fromMillisecondsSinceEpoch(raw);
        } else if (raw > 100000000) {
          parsedDate = DateTime.fromMillisecondsSinceEpoch(raw * 1000);
        } else {
          parsedDate = DateTime.tryParse(raw.toString()) ?? DateTime.now();
        }
      } else if (raw is String) {
        final str = raw.trim();
        final numericVal = int.tryParse(str);
        if (numericVal != null && numericVal > 100000000) {
          if (numericVal > 100000000000) {
            parsedDate = DateTime.fromMillisecondsSinceEpoch(numericVal);
          } else {
            parsedDate = DateTime.fromMillisecondsSinceEpoch(numericVal * 1000);
          }
        } else {
          parsedDate = DateTime.tryParse(str) ?? DateTime.now();
        }
      } else {
        parsedDate = DateTime.now();
      }
    } else {
      parsedDate = DateTime.now();
    }

    if (parsedDate.year < 2000 || parsedDate.year > 2100) {
      parsedDate = DateTime.now();
    }

    final rawId = json['id']?.toString();
    final schemaVersion = (json['schemaVersion'] as num?)?.toInt() ?? 1;
    final balanceAfter = (json['balanceAfter'] as num?)?.toDouble() ?? 0.0;

    return Transaction(
      id: rawId,
      amount: rawAmount,
      isCredit: isCredit,
      note: rawNote,
      timestamp: parsedDate,
      tag: tag,
      schemaVersion: schemaVersion,
      balanceAfter: balanceAfter,
    );
  }

  Transaction copyWith({
    String? id,
    double? amount,
    bool? isCredit,
    String? note,
    DateTime? timestamp,
    String? tag,
    double? balanceAfter,
  }) {
    return Transaction(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      isCredit: isCredit ?? this.isCredit,
      note: note ?? this.note,
      timestamp: timestamp ?? this.timestamp,
      tag: tag ?? this.tag,
      schemaVersion: schemaVersion,
      balanceAfter: balanceAfter ?? this.balanceAfter,
    );
  }
}
