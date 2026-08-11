import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Increment-to-trigger controller for [CashRain].
///
/// Call [burst] whenever a shower of falling cash emoji should play.
/// [CashRain] just watches this value change — it doesn't care what the
/// number itself is, only that it's different from last time.
class CashRainController extends ValueNotifier<int> {
  CashRainController() : super(0);

  void burst() => value++;
}

/// Overlay that rains falling 💵💰🪙 emoji every time [controller]'s value
/// changes. Place it as a sibling inside a [Stack] alongside the content it
/// should celebrate over — it fills that Stack via [Positioned.fill] and
/// ignores touches so it never blocks interaction underneath it.
class CashRain extends StatefulWidget {
  final ValueListenable<int> controller;
  const CashRain({super.key, required this.controller});

  @override
  State<CashRain> createState() => _CashRainState();
}

class _CashRainState extends State<CashRain> with SingleTickerProviderStateMixin {
  static const _burstDuration = Duration(seconds: 3);
  static const _emojis = ['💵', '💰', '🪙'];

  late final AnimationController _ticker =
      AnimationController(vsync: this, duration: _burstDuration)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed && mounted) {
            setState(() => _particles = const []);
          }
        });
  final _rng = Random();
  List<_CashParticle> _particles = const [];
  late int _lastValue = widget.controller.value;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant CashRain oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _lastValue = widget.controller.value;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _ticker.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    final value = widget.controller.value;
    if (value == _lastValue) return;
    _lastValue = value;
    _startBurst();
  }

  void _startBurst() {
    final count = 25 + _rng.nextInt(16); // 25..40 particles
    setState(() {
      _particles = List.generate(count, (_) => _CashParticle.random(_rng, _emojis));
    });
    _ticker
      ..stop()
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _ticker,
          builder: (context, _) => LayoutBuilder(
            builder: (context, constraints) => Stack(
              children: [
                for (final p in _particles) p.build(constraints.biggest, _ticker.value),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One falling coin/bill. All timing/position/motion is derived from a
/// handful of random numbers picked once at burst time, then evaluated
/// against the shared [AnimationController]'s `t` (0..1) each frame — so a
/// whole burst of 25-40 particles rides a single ticker instead of each
/// owning its own.
@immutable
class _CashParticle {
  final String emoji;
  final double startX; // fraction of width, 0..1
  final double delay; // fraction of burst duration before the fall starts
  final double fallFraction; // fraction of burst duration spent falling
  final double swayAmplitude; // px of horizontal drift
  final double swayFrequency; // sine cycles over the fall
  final double rotationTurns; // signed full turns over the fall
  final double size;

  const _CashParticle({
    required this.emoji, required this.startX, required this.delay,
    required this.fallFraction, required this.swayAmplitude,
    required this.swayFrequency, required this.rotationTurns, required this.size,
  });

  factory _CashParticle.random(Random rng, List<String> emojis) {
    final delay = rng.nextDouble() * 0.4;
    return _CashParticle(
      emoji: emojis[rng.nextInt(emojis.length)],
      startX: rng.nextDouble(),
      delay: delay,
      // Scaled so (delay + fallFraction) never exceeds 1 — every particle
      // finishes its fall before the burst ends.
      fallFraction: (1 - delay) * (0.6 + rng.nextDouble() * 0.4),
      swayAmplitude: 8 + rng.nextDouble() * 20,
      swayFrequency: 0.5 + rng.nextDouble() * 2,
      rotationTurns: (rng.nextBool() ? 1 : -1) * (0.3 + rng.nextDouble()),
      size: 20 + rng.nextDouble() * 14,
    );
  }

  Widget build(Size area, double t) {
    if (t < delay || area.isEmpty) return const SizedBox.shrink();
    final localT = ((t - delay) / fallFraction).clamp(0.0, 1.0).toDouble();
    final top = -size + localT * (area.height + size * 2);
    final sway = sin(localT * swayFrequency * 2 * pi) * swayAmplitude;
    final left =
        (startX * area.width + sway).clamp(0.0, max(area.width - size, 0.0)).toDouble();
    final opacity =
        localT > 0.85 ? (1 - (localT - 0.85) / 0.15).clamp(0.0, 1.0).toDouble() : 1.0;
    return Positioned(
      top: top,
      left: left,
      child: Opacity(
        opacity: opacity,
        child: Transform.rotate(
          angle: localT * rotationTurns * 2 * pi,
          child: Text(emoji, style: TextStyle(fontSize: size)),
        ),
      ),
    );
  }
}
