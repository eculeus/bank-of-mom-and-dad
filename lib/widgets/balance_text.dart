import 'package:flutter/material.dart';
import '../core/money.dart';
import '../core/theme.dart';

class BalanceText extends StatelessWidget {
  final int cents;
  final bool celebrate;
  final Color? color;
  const BalanceText({super.key, required this.cents, required this.celebrate, this.color});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.displayLarge?.copyWith(
        fontWeight: FontWeight.w900,
        color: color ?? (cents < 0 ? kMoneyDown : kMoneyUp));
    if (!celebrate) return Text(formatCents(cents), style: style);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        final bounce = 1 + 0.12 * (t < 0.85 ? 0 : (1 - (t - 0.85) / 0.15 - 0.5).abs() * -2 + 1);
        return Transform.scale(
          scale: bounce.clamp(1.0, 1.12),
          child: Text(formatCents((cents * t).round()), style: style),
        );
      },
    );
  }
}
