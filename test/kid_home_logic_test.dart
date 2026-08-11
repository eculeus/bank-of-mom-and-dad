import 'package:flutter_test/flutter_test.dart';
import 'package:bank_of_mom_and_dad/features/kid/kid_home_logic.dart';

void main() {
  final now = DateTime(2026, 8, 10, 12, 0);
  group('shouldCelebrate', () {
    test('never seen → celebrate', () => expect(shouldCelebrate(null, now), true));
    test('seen 2h ago → celebrate',
        () => expect(shouldCelebrate(now.subtract(const Duration(hours: 2)), now), true));
    test('seen exactly 1h ago → celebrate',
        () => expect(shouldCelebrate(now.subtract(const Duration(hours: 1)), now), true));
    test('seen 5 min ago → quiet',
        () => expect(shouldCelebrate(now.subtract(const Duration(minutes: 5)), now), false));
  });
  group('isNewTransaction', () {
    final seen = DateTime(2026, 8, 10, 9, 0);
    test('created after last seen → new',
        () => expect(isNewTransaction(seen.add(const Duration(minutes: 1)), seen), true));
    test('created before last seen → old',
        () => expect(isNewTransaction(seen.subtract(const Duration(minutes: 1)), seen), false));
    test('no prev seen → not highlighted', () =>
        expect(isNewTransaction(DateTime(2026, 8, 10), null), false));
    test('no createdAt → not highlighted', () => expect(isNewTransaction(null, seen), false));
  });
}
