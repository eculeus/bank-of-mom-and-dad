import 'package:intl/intl.dart';

final NumberFormat _currency = NumberFormat.currency(locale: 'en_US', symbol: r'$');

String formatCents(int cents) => _currency.format(cents / 100);

String formatCentsSigned(int cents) =>
    cents < 0 ? '−${formatCents(-cents)}' : '+${formatCents(cents)}';

String formatDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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
