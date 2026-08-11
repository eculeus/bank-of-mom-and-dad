import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money.dart';
import '../../models/models.dart';
import '../../state/providers.dart';
import '../../widgets/balance_text.dart';
import '../../widgets/expandable_note.dart';
import 'kid_home_logic.dart';
import 'kid_requests_screen.dart';

class KidHomeScreen extends ConsumerStatefulWidget {
  final String familyId;
  final FamilyEntry entry;
  const KidHomeScreen({super.key, required this.familyId, required this.entry});

  @override
  ConsumerState<KidHomeScreen> createState() => _KidHomeScreenState();
}

class _KidHomeScreenState extends ConsumerState<KidHomeScreen> {
  DateTime? _prevSeenAt;
  bool _seenCaptured = false;
  bool _celebrate = false;
  int _tab = 0;
  late final _confetti = ConfettiController(duration: const Duration(seconds: 2));

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  void _captureSeen(Member member) {
    if (_seenCaptured) return;
    _seenCaptured = true;
    _prevSeenAt = member.lastSeenAt;
    _celebrate = shouldCelebrate(member.lastSeenAt, DateTime.now());
    if (member.status == 'active' || member.status == 'disabled') {
      FirebaseFirestore.instance
          .doc('families/${widget.familyId}/members/${member.id}')
          .update({'lastSeenAt': Timestamp.now()});
    }
  }

  @override
  Widget build(BuildContext context) {
    final memberAsync = ref.watch(
        memberProvider((familyId: widget.familyId, memberId: widget.entry.memberId)));
    final member = memberAsync.value;
    if (member == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    _captureSeen(member);
    final disabled = member.status == 'disabled';

    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          _MoneyTab(
            familyId: widget.familyId,
            member: member,
            prevSeenAt: _prevSeenAt,
            celebrate: _celebrate,
            confetti: _confetti,
            disabled: disabled,
          ),
          KidRequestsScreen(familyId: widget.familyId, memberId: member.id, disabled: disabled),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.savings), label: 'My Money'),
          NavigationDestination(icon: Icon(Icons.mail), label: 'Requests'),
        ],
      ),
    );
  }
}

class _MoneyTab extends ConsumerStatefulWidget {
  final String familyId;
  final Member member;
  final DateTime? prevSeenAt;
  final bool celebrate;
  final bool disabled;
  final ConfettiController confetti;
  const _MoneyTab({required this.familyId, required this.member, required this.prevSeenAt,
      required this.celebrate, required this.disabled, required this.confetti});

  @override
  ConsumerState<_MoneyTab> createState() => _MoneyTabState();
}

class _MoneyTabState extends ConsumerState<_MoneyTab> {
  bool _confettiFired = false;

  @override
  Widget build(BuildContext context) {
    final txsAsync = ref.watch(kidTransactionsProvider(
        (familyId: widget.familyId, kidMemberId: widget.member.id)));
    final txs = txsAsync.value ?? const <BankTransaction>[];
    final hasNewDeposit = txs.any((t) =>
        isNewTransaction(t.createdAt, widget.prevSeenAt) && t.amountCents > 0);
    if (widget.celebrate && hasNewDeposit && !_confettiFired) {
      _confettiFired = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.confetti.play());
    }

    return Stack(alignment: Alignment.topCenter, children: [
      ListView(
        padding: const EdgeInsets.fromLTRB(16, 48, 16, 32),
        children: [
          if (widget.disabled)
            MaterialBanner(
              backgroundColor: Colors.amber.shade100,
              content: const Text(
                  'Your account is inactive — talk to your parents, or delete your account.'),
              actions: [
                TextButton(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (dCtx) => AlertDialog(
                        title: const Text('Delete your account?'),
                        content: const Text(
                            'Your sign-in is removed. Your history stays with your family.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
                          FilledButton(onPressed: () => Navigator.pop(dCtx, true), child: const Text('Delete')),
                        ],
                      ),
                    );
                    if (ok == true) {
                      try {
                        await ref.read(functionsServiceProvider).deleteAccount();
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Could not delete account: $e')));
                        }
                      }
                    }
                  },
                  child: const Text('Delete account'),
                ),
              ],
            ),
          const SizedBox(height: 16),
          Center(
            child: Text('Hi ${widget.member.displayName}! 👋',
                style: Theme.of(context).textTheme.titleLarge),
          ),
          const SizedBox(height: 8),
          Center(child: BalanceText(cents: widget.member.balanceCents, celebrate: widget.celebrate)),
          const SizedBox(height: 32),
          Text('History', style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final tx in txs)
            _TxTile(tx: tx, highlight: isNewTransaction(tx.createdAt, widget.prevSeenAt)),
          if (txs.isEmpty && !txsAsync.isLoading)
            const Padding(padding: EdgeInsets.all(32),
                child: Center(child: Text('No transactions yet!'))),
          const SizedBox(height: 24),
          Center(
            child: TextButton.icon(
              icon: const Icon(Icons.logout, size: 16),
              label: const Text('Sign out'),
              onPressed: () => ref.read(authServiceProvider).signOut(),
            ),
          ),
        ],
      ),
      ConfettiWidget(
        confettiController: widget.confetti,
        blastDirection: pi / 2,
        emissionFrequency: 0.4,
        numberOfParticles: 24,
        shouldLoop: false,
      ),
    ]);
  }
}

class _TxTile extends StatelessWidget {
  final BankTransaction tx;
  final bool highlight;
  const _TxTile({required this.tx, required this.highlight});

  @override
  Widget build(BuildContext context) {
    final row = ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      title: Text(tx.reason),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(formatDate(tx.date)),
        if (tx.note != null) ExpandableNote(text: tx.note!),
      ]),
      trailing: Text(formatCentsSigned(tx.amountCents),
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
              color: tx.amountCents < 0 ? Colors.red.shade700 : Colors.green.shade800)),
    );
    if (!highlight) return row;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: 0),
      duration: const Duration(seconds: 3),
      curve: Curves.easeOut,
      builder: (context, t, child) => Container(
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.5 * t),
          borderRadius: BorderRadius.circular(12),
        ),
        child: child,
      ),
      child: row,
    );
  }
}
