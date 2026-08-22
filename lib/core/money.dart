import 'package:intl/intl.dart';

final NumberFormat _currency = NumberFormat.currency(locale: 'en_US', symbol: r'$');

String formatCents(int cents) => _currency.format(cents / 100);

String formatCentsSigned(int cents) =>
    cents < 0 ? '−${formatCents(-cents)}' : '+${formatCents(cents)}';

String formatDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

final DateFormat _monthHeader = DateFormat('MMMM y'); // "August 2026"
final DateFormat _txDay = DateFormat('EEE, MMM d'); // "Wed, Aug 28"

String formatMonthHeader(DateTime d) => _monthHeader.format(d);
String formatTxDay(DateTime d) => _txDay.format(d);

/// Stable key for grouping transactions by calendar month.
int monthKey(DateTime d) => d.year * 12 + d.month;

int? parseDollarsToCents(String raw) {
  var s = raw
      .trim()
      .replaceAll(r'$', '')
      .replaceAll(',', '')
      .replaceAll('−', '-');
  if (s.isEmpty) return null;
  final negative = s.startsWith('-');
  if (negative) s = s.substring(1);
  final m = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(s);
  if (m == null) return null;
  final cents =
      int.parse(m.group(1)!) * 100 + int.parse((m.group(2) ?? '0').padRight(2, '0'));
  return negative ? -cents : cents;
}
