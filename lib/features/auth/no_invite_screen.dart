import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/providers.dart';

class NoInviteScreen extends ConsumerWidget {
  final String email;
  const NoInviteScreen({super.key, required this.email});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('🔍', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text('We could not find your family yet.',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('Ask your parent to add $email to the family!',
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () async {
                await ref.read(functionsServiceProvider).joinFamily();
                ref.invalidate(appUserProvider);
                if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
              },
              child: const Text('Check again'),
            ),
            TextButton(
              onPressed: () {
                ref.read(authServiceProvider).signOut();
                Navigator.of(context).popUntil((r) => r.isFirst);
              },
              child: const Text('Sign out'),
            ),
          ]),
        ),
      ),
    );
  }
}
