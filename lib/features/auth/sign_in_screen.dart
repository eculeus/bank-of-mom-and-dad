import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/emulators.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});
  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;

  Future<void> _run(Future<void> Function() fn) async {
    setState(() { _busy = true; _error = null; });
    try {
      await fn();
    } catch (e) {
      setState(() => _error = 'Sign-in failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.read(authServiceProvider);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.55), radius: 1.15,
            colors: [Color(0xFFEDEFFE), kBrandBg],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 104, height: 104,
                      decoration: BoxDecoration(
                        gradient: kBrandGradient,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: kBrandIndigo.withValues(alpha: 0.42),
                            blurRadius: 30, offset: const Offset(0, 14)),
                        ],
                      ),
                      child: Center(
                        child: Text('\$',
                            style: GoogleFonts.fredoka(
                                color: Colors.white, fontSize: 58, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text('Bank of Mom & Dad',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text('Allowance, made simple.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(color: kBrandInk.withValues(alpha: 0.6))),
                  const SizedBox(height: 36),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: kBrandInk,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      elevation: 6,
                      shadowColor: kBrandIndigo.withValues(alpha: 0.28),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    onPressed: _busy ? null : () => _run(auth.signInWithGoogle),
                    icon: const Icon(Icons.login, color: kBrandIndigo),
                    label: const Text('Continue with Google'),
                  ),
                  if (kTestMode) ...[
                    const Divider(height: 48),
                    TextField(controller: _email,
                        decoration: const InputDecoration(labelText: 'Test email')),
                    const SizedBox(height: 8),
                    TextField(controller: _password, obscureText: true,
                        decoration: const InputDecoration(labelText: 'Test password')),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => _run(() => auth.signInWithTestAccount(
                              _email.text.trim(), _password.text)),
                      child: const Text('Test sign in'),
                    ),
                  ],
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(_error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: kMoneyDown)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
