// Non-web platforms (and VM-based `flutter test`) never show the install
// banner and must not pull in `package:web`, which only compiles for web
// compile targets. See install_banner_web.dart for the real implementation.
({bool isIOS, bool isStandalone}) probePlatform() =>
    (isIOS: false, isStandalone: false);
