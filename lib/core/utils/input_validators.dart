/// Helper methods for strict input validation, financial bounds checking, and string sanitization.
class InputValidators {
  static const double maxAmount = 100000000000.0; // 100 Billion max

  /// Validates and parses a raw financial input string.
  /// Returns null if invalid, negative, or infinite/NaN/out of bounds.
  static double? parseAndValidateAmount(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed.contains('-')) return null;
    final cleaned = trimmed.replaceAll(',', '').replaceAll(RegExp(r'[^\d.]'), '');
    if (cleaned.isEmpty) return null;
    final val = double.tryParse(cleaned);
    if (val == null || !val.isFinite || val.isNaN || val <= 0 || val > maxAmount) {
      return null;
    }
    return val;
  }

  /// Normalizes and caps a transaction note string.
  static String sanitizeNote(String? raw, {String? defaultNote}) {
    if (raw != null) {
      final trimmed = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (trimmed.isNotEmpty && trimmed.toLowerCase() != 'untitled') {
        if (trimmed.length > 100) return trimmed.substring(0, 100);
        return trimmed;
      }
    }
    if (defaultNote != null && defaultNote.trim().isNotEmpty) {
      return defaultNote.trim();
    }
    return 'Untitled';
  }

  /// Normalizes category tag name.
  static String sanitizeTag(String? raw) {
    if (raw == null) return 'OTHER';
    final trimmed = raw.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9_\-\s]'), '');
    if (trimmed.isEmpty) return 'OTHER';
    if (trimmed.length > 30) return trimmed.substring(0, 30);
    return trimmed;
  }
}
