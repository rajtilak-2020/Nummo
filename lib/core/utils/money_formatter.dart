import 'package:intl/intl.dart';

/// Formatter for monetary values using Indian Rupee (₹) and tabular monospace layout.
class MoneyFormatter {
  static final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  static final NumberFormat _compactFormatter = NumberFormat.compactCurrency(
    locale: 'en_IN',
    symbol: '₹',
  );

  static const String masked = '₹ XXXXXX';
  static const String maskedShort = 'XXXXXX';

  /// Formats amount as `₹1,234.56` or `-₹1,234.56` with optional privacy masking.
  static String format(double amount, {bool showSign = false, bool isCredit = false, bool isMasked = false}) {
    if (isMasked) {
      if (showSign) {
        return isCredit ? '+$masked' : '-$masked';
      }
      return masked;
    }
    if (!amount.isFinite || amount.isNaN) return '₹0.00';
    final isNegative = amount < 0;
    final formatted = _currencyFormatter.format(amount.abs());
    if (showSign) {
      return isCredit ? '+$formatted' : '-$formatted';
    }
    return isNegative ? '-$formatted' : formatted;
  }

  /// Compact format for charts (e.g. ₹1.2K, -₹1K, ₹4.5L).
  static String formatCompact(double amount, {bool isMasked = false}) {
    if (isMasked) return maskedShort;
    if (!amount.isFinite || amount.isNaN) return '₹0';
    final isNegative = amount < 0;
    final formatted = _compactFormatter.format(amount.abs());
    return isNegative ? '-$formatted' : formatted;
  }
}
