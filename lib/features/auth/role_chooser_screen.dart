import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/providers.dart';
import 'create_family_screen.dart';
import 'no_invite_screen.dart';

class RoleChooserScreen extends ConsumerStatefulWidget {
  const RoleChooserScreen({super.key});
  @override
  ConsumerState<RoleChooserScreen> createState() => _RoleChooserScreenState();
}

class _RoleChooserScreenState extends ConsumerState<RoleChooserScreen> {
  bool _checkingKid = false;

  Future<void> _kidTapped() async {
    setState(() => _checkingKid = true);
    try {
      await ref.read(functionsServiceProvider).joinFamily();
      ref.invalidate(appUserProvider);
      // Give the users-doc stream a beat; if AuthGate reroutes, this screen unmounts.
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      final fam = ref.read(activeFamilyProvider);
      if (fam == null) {
        final email = FirebaseAuth.instance.currentUser?.email ?? '';
        await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => NoInviteScreen(email: email)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not check your family: $e')));
    } finally {
      if (mounted) setState(() => _checkingKid = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Who are you?'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authServiceProvider).signOut(),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _RoleCard(
                emoji: '🧑‍🚀',
                label: "I'm a Parent",
                subtitle: 'Create your family bank',
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CreateFamilyScreen())),
              ),
              const SizedBox(height: 24),
              _RoleCard(
                emoji: '🦄',
                label: "I'm a Kid",
                subtitle: 'Join your family',
                busy: _checkingKid,
                onTap: _checkingKid ? null : _kidTapped,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String emoji, label, subtitle;
  final VoidCallback? onTap;
  final bool busy;
  const _RoleCard({required this.emoji, required this.label, required this.subtitle, this.onTap, this.busy = false});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(24),
          child: Row(children: [
            Text(emoji, style: const TextStyle(fontSize: 48)),
            const SizedBox(width: 20),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              ]),
            ),
            if (busy) const CircularProgressIndicator(),
          ]),
        ),
      ),
    );
  }
}
