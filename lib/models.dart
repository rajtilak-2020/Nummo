class Transaction {
  final String id;
  final double amount;
  final bool isCredit;
  final String note;
  final DateTime timestamp;
  double balanceAfter;
  final String? tag;

  Transaction({
    required this.id,
    required this.amount,
    required this.isCredit,
    required this.note,
    required this.timestamp,
    this.balanceAfter = 0.0,
    this.tag,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'isCredit': isCredit,
        'note': note,
        'timestamp': timestamp.toIso8601String(),
        'balanceAfter': balanceAfter,
        'tag': tag,
      };

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
        id: json['id'] as String,
        amount: (json['amount'] as num).toDouble(),
        isCredit: json['isCredit'] as bool,
        note: json['note'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        balanceAfter: (json['balanceAfter'] as num?)?.toDouble() ?? 0.0,
        tag: json['tag'] as String?,
      );
}
