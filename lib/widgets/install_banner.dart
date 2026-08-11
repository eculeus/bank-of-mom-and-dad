import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'install_banner_stub.dart'
    if (dart.library.js_interop) 'install_banner_web.dart';

bool shouldShowInstallBanner({required bool isIOS, required bool isStandalone}) =>
    isIOS && !isStandalone;

class InstallBanner extends StatefulWidget {
  const InstallBanner({super.key});
  @override
  State<InstallBanner> createState() => _InstallBannerState();
}

class _InstallBannerState extends State<InstallBanner> {
  bool _dismissed = false;

  bool get _applicable {
    if (!kIsWeb) return false;
    final p = probePlatform();
    return shouldShowInstallBanner(isIOS: p.isIOS, isStandalone: p.isStandalone);
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed || !_applicable) return const SizedBox.shrink();
    return Material(
      color: Colors.deepPurple.shade50,
      child: ListTile(
        leading: const Text('📲', style: TextStyle(fontSize: 28)),
        title: const Text('Install the app to get notifications!'),
        subtitle: const Text('Tap Share → Add to Home Screen'),
        trailing: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => setState(() => _dismissed = true)),
      ),
    );
  }
}
