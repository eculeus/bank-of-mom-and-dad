import 'package:flutter/material.dart';
import '../core/money.dart';

/// A bank-statement style section header separating transactions by month.
class MonthHeader extends StatelessWidget {
  final String label;
  const MonthHeader({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: Color(0x991E1B39), // kBrandInk @ 60%
        ),
      ),
    );
  }
}

/// Builds a flat list of [MonthHeader] + item widgets from date-descending
/// transactions. [item] renders one transaction; a header is inserted each
/// time the calendar month changes.
List<Widget> groupByMonth<T>({
  required List<T> items,
  required DateTime Function(T) dateOf,
  required Widget Function(T) item,
}) {
  final out = <Widget>[];
  int? lastKey;
  for (final t in items) {
    final d = dateOf(t);
    final key = monthKey(d);
    if (key != lastKey) {
      lastKey = key;
      out.add(MonthHeader(label: formatMonthHeader(d)));
    }
    out.add(item(t));
  }
  return out;
}
