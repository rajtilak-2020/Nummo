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

class TagHelper {
  static const Map<String, List<String>> emojiCategories = {
    'Food & Drink': ['🍔', '🍕', '☕', '🍺', '🍜', '🍣', '🍦', '🍩', '🥑', '🍷'],
    'Shopping': ['🛍️', '🛒', '👕', '👟', '💄', '💍', '🎁', '📱', '💻', '🎧'],
    'Travel & Transport': ['✈️', '🚗', '⛽', '🚖', '🚆', '🚲', '🏖️', '🏨', '🎟️', '🗺️'],
    'Bills & Utilities': ['📄', '💡', '💧', '⚡', '📶', '🏠', '🔑', '🛠️', '📺', '🧾'],
    'Finance & Growth': ['💰', '📈', '💳', '🏦', '💎', '💵', '🪙', '📊', '💼', '🎯'],
    'Health & Lifestyle': ['🏥', '💊', '🏋️', '🧘', '⚽', '🎮', '🎓', '🐾', '🍿', '🎨'],
  };

  static const List<String> availableEmojis = [
    '🍔', '🍕', '☕', '🍺', '🛍️', '✈️', '🚗', '⛽',
    '📦', '📄', '🎬', '🏥', '🛒', '💰', '📈', '🎮',
    '💡', '📱', '🏋️', '🎓', '🐾', '🏠', '🎁', '⚡',
  ];

  static const Map<String, String> defaultTagEmojis = {
    'FOOD': '🍔',
    'SHOPPING': '🛍️',
    'TRAVEL': '✈️',
    'OTHERS': '📦',
  };

  static const List<String> defaultTags = [
    '🍔 FOOD',
    '🛍️ SHOPPING',
    '✈️ TRAVEL',
    '📦 OTHERS',
  ];

  static String getCleanName(String fullTag) {
    final trimmed = fullTag.trim();
    // Remove leading emoji if present
    final regex = RegExp(
        r'^[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{1F600}-\u{1F64F}\u{1F680}-\u{1F6FF}\u{1F1E6}-\u{1F1FF}\s]+',
        unicode: true);
    final clean = trimmed.replaceFirst(regex, '').trim();
    return clean.isEmpty ? trimmed : clean;
  }

  static String getEmoji(String fullTag) {
    final trimmed = fullTag.trim();
    if (trimmed.isEmpty) return '';
    final firstChar = trimmed.split(' ').first;
    final regex = RegExp(
        r'^[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{1F600}-\u{1F64F}\u{1F680}-\u{1F6FF}\u{1F1E6}-\u{1F1FF}]',
        unicode: true);
    if (regex.hasMatch(firstChar)) {
      return firstChar;
    }
    final clean = getCleanName(trimmed).toUpperCase();
    if (defaultTagEmojis.containsKey(clean)) {
      return defaultTagEmojis[clean]!;
    }
    return '';
  }

  static String formatTag(String name, String emoji) {
    final clean = getCleanName(name).toUpperCase();
    final trimmedEmoji = emoji.trim();
    if (trimmedEmoji.isEmpty) {
      return clean;
    }
    return '$trimmedEmoji $clean';
  }
}
