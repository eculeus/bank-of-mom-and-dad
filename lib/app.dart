import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme.dart';
import 'features/auth/role_chooser_screen.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/kid/kid_home_screen.dart';
import 'features/parent/parent_home_screen.dart';
import 'services/messaging_service.dart';
import 'state/providers.dart';
import 'widgets/install_banner.dart';

final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class BankApp extends StatelessWidget {
  const BankApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bank of Mom & Dad',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      theme: buildBankTheme(),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final user = auth.value;
    if (auth.isLoading) return const _Splash();
    if (user == null) return const SignInScreen();
    final join = ref.watch(joinFamilyOnceProvider(user.uid));
    final appUser = ref.watch(appUserProvider);
    if (join.isLoading || appUser.isLoading) return const _Splash();
    final fam = ref.watch(activeFamilyProvider);
    if (fam == null) return const RoleChooserScreen();
    return _MessagingBootstrap(
      uid: user.uid,
      child: fam.entry.role == 'parent'
          ? ParentHomeScreen(familyId: fam.id)
          : KidHomeScreen(familyId: fam.id, entry: fam.entry),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) => const Scaffold(
      body: Center(child: Text('🏦', style: TextStyle(fontSize: 72))));
}

class _MessagingBootstrap extends StatefulWidget {
  final String uid;
  final Widget child;
  const _MessagingBootstrap({required this.uid, required this.child});
  @override
  State<_MessagingBootstrap> createState() => _MessagingBootstrapState();
}

class _MessagingBootstrapState extends State<_MessagingBootstrap> {
  static final _service = MessagingService();
  @override
  void initState() {
    super.initState();
    _service.init(widget.uid);
  }

  @override
  Widget build(BuildContext context) =>
      Column(children: [const InstallBanner(), Expanded(child: widget.child)]);
}
