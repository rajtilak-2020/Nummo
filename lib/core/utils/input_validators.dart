/// Helper methods for strict input validation, financial bounds checking, and string sanitization.
class InputValidators {
  static const double maxAmount = 100000000000.0; // 100 Billion max

  /// Validates and parses a raw financial input string.
  /// Returns null if invalid or infinite/NaN/negative.
  static double? parseAndValidateAmount(String raw) {
    final cleaned = raw.trim().replaceAll(',', '').replaceAll('₹', '');
    if (cleaned.isEmpty) return null;
    final val = double.tryParse(cleaned);
    if (val == null || !val.isFinite || val.isNaN || val <= 0 || val > maxAmount) {
      return null;
    }
    return val;
  }

  /// Normalizes and caps a transaction note string.
  static String sanitizeNote(String? raw) {
    if (raw == null) return 'Untitled';
    final trimmed = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.isEmpty) return 'Untitled';
    if (trimmed.length > 100) return trimmed.substring(0, 100);
    return trimmed;
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
