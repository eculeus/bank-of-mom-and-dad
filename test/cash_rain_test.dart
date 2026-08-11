import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bank_of_mom_and_dad/widgets/cash_rain.dart';

void main() {
  testWidgets('CashRain plays a burst without throwing', (tester) async {
    final controller = CashRainController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Stack(children: [
          const SizedBox.expand(),
          CashRain(controller: controller),
        ]),
      ),
    ));
    expect(tester.takeException(), isNull);

    controller.burst();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump(const Duration(seconds: 2)); // past the ~3s burst duration

    expect(tester.takeException(), isNull);
  });
}
