import 'package:intl/intl.dart';

/// Configuration for Currency display (code, symbol, locale name)
class CurrencyConfig {
  final String code;
  final String symbol;
  final String name;
  final String locale;

  const CurrencyConfig({
    required this.code,
    required this.symbol,
    required this.name,
    required this.locale,
  });

  static const CurrencyConfig defaultCurrency = CurrencyConfig(
    code: 'INR',
    symbol: '₹',
    name: 'Indian Rupee (₹)',
    locale: 'en_IN',
  );

  static const List<CurrencyConfig> availableCurrencies = [
    CurrencyConfig(code: 'INR', symbol: '₹', name: 'Indian Rupee (₹)', locale: 'en_IN'),
    CurrencyConfig(code: 'USD', symbol: '\$', name: 'US Dollar (\$)', locale: 'en_US'),
    CurrencyConfig(code: 'EUR', symbol: '€', name: 'Euro (€)', locale: 'de_DE'),
    CurrencyConfig(code: 'GBP', symbol: '£', name: 'British Pound (£)', locale: 'en_GB'),
    CurrencyConfig(code: 'JPY', symbol: '¥', name: 'Japanese Yen (¥)', locale: 'ja_JP'),
    CurrencyConfig(code: 'AED', symbol: 'AED', name: 'UAE Dirham (AED)', locale: 'ar_AE'),
    CurrencyConfig(code: 'CAD', symbol: 'C\$', name: 'Canadian Dollar (C\$)', locale: 'en_CA'),
    CurrencyConfig(code: 'AUD', symbol: 'A\$', name: 'Australian Dollar (A\$)', locale: 'en_AU'),
    CurrencyConfig(code: 'CHF', symbol: 'CHF', name: 'Swiss Franc (CHF)', locale: 'de_CH'),
    CurrencyConfig(code: 'SGD', symbol: 'S\$', name: 'Singapore Dollar (S\$)', locale: 'en_SG'),
    CurrencyConfig(code: 'KRW', symbol: '₩', name: 'South Korean Won (₩)', locale: 'ko_KR'),
    CurrencyConfig(code: 'TRY', symbol: '₺', name: 'Turkish Lira (₺)', locale: 'tr_TR'),
    CurrencyConfig(code: 'BRL', symbol: 'R\$', name: 'Brazilian Real (R\$)', locale: 'pt_BR'),
    CurrencyConfig(code: 'PHP', symbol: '₱', name: 'Philippine Peso (₱)', locale: 'en_PH'),
    CurrencyConfig(code: 'VND', symbol: '₫', name: 'Vietnamese Dong (₫)', locale: 'vi_VN'),
    CurrencyConfig(code: 'THB', symbol: '฿', name: 'Thai Baht (฿)', locale: 'th_TH'),
    CurrencyConfig(code: 'SAR', symbol: 'SAR', name: 'Saudi Riyal (SAR)', locale: 'ar_SA'),
  ];

  static CurrencyConfig fromCodeOrSymbol(String? input) {
    if (input == null || input.trim().isEmpty) return defaultCurrency;
    final clean = input.trim().toUpperCase();
    for (final c in availableCurrencies) {
      if (c.code.toUpperCase() == clean || c.symbol.toUpperCase() == clean) {
        return c;
      }
    }
    return defaultCurrency;
  }
}

/// Formatter for monetary values using configurable currency and tabular monospace layout.
class MoneyFormatter {
  static CurrencyConfig _currentCurrency = CurrencyConfig.defaultCurrency;

  static NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: _currentCurrency.locale,
    symbol: _currentCurrency.symbol,
    decimalDigits: 2,
  );

  static NumberFormat _compactFormatter = NumberFormat.compactCurrency(
    locale: _currentCurrency.locale,
    symbol: _currentCurrency.symbol,
  );

  static CurrencyConfig get currentCurrency => _currentCurrency;
  static String get currencySymbol => _currentCurrency.symbol;
  static String get currencyCode => _currentCurrency.code;

  static void setCurrency(CurrencyConfig config) {
    _currentCurrency = config;
    _currencyFormatter = NumberFormat.currency(
      locale: config.locale,
      symbol: config.symbol,
      decimalDigits: 2,
    );
    _compactFormatter = NumberFormat.compactCurrency(
      locale: config.locale,
      symbol: config.symbol,
    );
  }

  static void setCurrencyByCode(String? codeOrSymbol) {
    setCurrency(CurrencyConfig.fromCodeOrSymbol(codeOrSymbol));
  }

  static String get masked => '$currencySymbol XXXXXX';
  static const String maskedShort = 'XXXXXX';

  /// Formats amount as `₹1,234.56` or `-₹1,234.56` with optional privacy masking.
  static String format(double amount, {bool showSign = false, bool isCredit = false, bool isMasked = false}) {
    if (isMasked) {
      if (showSign) {
        return isCredit ? '+$masked' : '-$masked';
      }
      return masked;
    }
    if (!amount.isFinite || amount.isNaN) return '${_currentCurrency.symbol}0.00';
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
    if (!amount.isFinite || amount.isNaN) return '${_currentCurrency.symbol}0';
    final isNegative = amount < 0;
    final formatted = _compactFormatter.format(amount.abs());
    return isNegative ? '-$formatted' : formatted;
  }
}
