import 'package:flutter_test/flutter_test.dart';
import 'package:nummo/core/utils/money_formatter.dart';

void main() {
  group('Currency Configuration & MoneyFormatter Tests', () {
    setUp(() {
      MoneyFormatter.setCurrency(CurrencyConfig.defaultCurrency);
    });

    tearDown(() {
      MoneyFormatter.setCurrency(CurrencyConfig.defaultCurrency);
    });

    test('CurrencyConfig defaults to INR (₹, en_IN)', () {
      expect(CurrencyConfig.defaultCurrency.code, 'INR');
      expect(CurrencyConfig.defaultCurrency.symbol, '₹');
      expect(CurrencyConfig.defaultCurrency.locale, 'en_IN');
      expect(MoneyFormatter.currencySymbol, '₹');
      expect(MoneyFormatter.currencyCode, 'INR');
    });

    test('CurrencyConfig.fromCodeOrSymbol resolves various currencies safely', () {
      expect(CurrencyConfig.fromCodeOrSymbol('USD').symbol, '\$');
      expect(CurrencyConfig.fromCodeOrSymbol('\$').code, 'USD');
      expect(CurrencyConfig.fromCodeOrSymbol('EUR').symbol, '€');
      expect(CurrencyConfig.fromCodeOrSymbol('€').code, 'EUR');
      expect(CurrencyConfig.fromCodeOrSymbol('GBP').symbol, '£');
      expect(CurrencyConfig.fromCodeOrSymbol('AED').code, 'AED');
      expect(CurrencyConfig.fromCodeOrSymbol('JPY').symbol, '¥');
      expect(CurrencyConfig.fromCodeOrSymbol(null).code, 'INR');
      expect(CurrencyConfig.fromCodeOrSymbol('').code, 'INR');
      expect(CurrencyConfig.fromCodeOrSymbol('UNKNOWN_XYZ').code, 'INR');
    });

    test('MoneyFormatter formats amounts correctly when currency changes', () {
      MoneyFormatter.setCurrencyByCode('USD');
      expect(MoneyFormatter.currencySymbol, '\$');
      expect(MoneyFormatter.format(1500.50), '\$1,500.50');
      expect(MoneyFormatter.format(1500.50, showSign: true, isCredit: true), '+\$1,500.50');
      expect(MoneyFormatter.format(-200.0), '-\$200.00');

      MoneyFormatter.setCurrencyByCode('EUR');
      expect(MoneyFormatter.currencySymbol, '€');
      expect(MoneyFormatter.format(50), contains('€'));

      MoneyFormatter.setCurrencyByCode('GBP');
      expect(MoneyFormatter.currencySymbol, '£');
      expect(MoneyFormatter.format(100), contains('£'));
    });

    test('MoneyFormatter privacy masking respects dynamic currency', () {
      MoneyFormatter.setCurrencyByCode('USD');
      expect(MoneyFormatter.format(100, isMasked: true), '\$ XXXXXX');
      expect(MoneyFormatter.format(100, isMasked: true, showSign: true, isCredit: true), '+\$ XXXXXX');
      expect(MoneyFormatter.format(100, isMasked: true, showSign: true, isCredit: false), '-\$ XXXXXX');
    });

    test('MoneyFormatter formatCompact respects dynamic currency', () {
      MoneyFormatter.setCurrencyByCode('USD');
      expect(MoneyFormatter.formatCompact(1500), '\$1.5K');
      expect(MoneyFormatter.formatCompact(-1500), '-\$1.5K');
      expect(MoneyFormatter.formatCompact(100, isMasked: true), 'XXXXXX');
    });
  });
}
