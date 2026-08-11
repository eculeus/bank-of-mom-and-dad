import 'package:flutter_test/flutter_test.dart';
import 'package:bank_of_mom_and_dad/core/money.dart';

void main() {
  group('formatCents', () {
    test('zero', () => expect(formatCents(0), r'$0.00'));
    test('thousands grouping', () => expect(formatCents(123456700), r'$1,234,567.00'));
    test('negative', () => expect(formatCents(-13337), r'-$133.37'));
    test('sub-dollar', () => expect(formatCents(5), r'$0.05'));
  });

  group('formatCentsSigned', () {
    test('positive', () => expect(formatCentsSigned(500), r'+$5.00'));
    test('negative uses U+2212', () => expect(formatCentsSigned(-325), '−\$3.25'));
  });

  group('parseDollarsToCents', () {
    test('bare int', () => expect(parseDollarsToCents('30'), 3000));
    test('one decimal', () => expect(parseDollarsToCents('30.5'), 3050));
    test('symbol and commas', () => expect(parseDollarsToCents(r'$1,234.56'), 123456));
    test('negative with symbol', () => expect(parseDollarsToCents(r'-$133.37'), -13337));
    test('unicode minus', () => expect(parseDollarsToCents('−\$3.00'), -300));
    test('whitespace', () => expect(parseDollarsToCents(r'  $5 '), 500));
    test('three decimals invalid', () => expect(parseDollarsToCents('30.555'), null));
    test('garbage invalid', () => expect(parseDollarsToCents('abc'), null));
    test('empty invalid', () => expect(parseDollarsToCents(''), null));
  });
}
