import 'package:web/web.dart' as web;

({bool isIOS, bool isStandalone}) probePlatform() {
  final ua = web.window.navigator.userAgent;
  final isIOS = ua.contains('iPhone') || ua.contains('iPad');
  final standalone = web.window.matchMedia('(display-mode: standalone)').matches;
  return (isIOS: isIOS, isStandalone: standalone);
}
