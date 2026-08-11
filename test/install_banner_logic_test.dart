import 'package:flutter_test/flutter_test.dart';
import 'package:bank_of_mom_and_dad/widgets/install_banner.dart';

void main() {
  test('banner only for iOS browser tab', () {
    expect(shouldShowInstallBanner(isIOS: true, isStandalone: false), true);
    expect(shouldShowInstallBanner(isIOS: true, isStandalone: true), false);
    expect(shouldShowInstallBanner(isIOS: false, isStandalone: false), false);
  });
}
