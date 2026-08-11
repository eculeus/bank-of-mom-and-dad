import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/providers.dart';
import '../../widgets/balance_text.dart';
import '../../widgets/cash_rain.dart';
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
  late final _cashRain = CashRainController();

  @override
  void dispose() {
    _cashRain.dispose();
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
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      drawer: _ProfileDrawer(member: member),
      body: IndexedStack(
        index: _tab,
        children: [
          _MoneyTab(
            familyId: widget.familyId,
            member: member,
            prevSeenAt: _prevSeenAt,
            celebrate: _celebrate,
            cashRain: _cashRain,
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

class _ProfileDrawer extends ConsumerWidget {
  final Member member;
  const _ProfileDrawer({required this.member});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = FirebaseAuth.instance.currentUser?.email;
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Row(children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: kidColors[member.colorIndex % kidColors.length],
                  child: Text(member.displayName.characters.first,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(member.displayName,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      if (email != null)
                        Text(email, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ]),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign out'),
              onTap: () {
                Navigator.of(context).pop();
                ref.read(authServiceProvider).signOut();
              },
            ),
          ],
        ),
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
  final CashRainController cashRain;
  const _MoneyTab({required this.familyId, required this.member, required this.prevSeenAt,
      required this.celebrate, required this.disabled, required this.cashRain});

  @override
  ConsumerState<_MoneyTab> createState() => _MoneyTabState();
}

class _MoneyTabState extends ConsumerState<_MoneyTab> {
  bool _celebrateFired = false;
  bool _seenTxIdsInitialized = false;
  final Set<String> _seenTxIds = {};

  @override
  Widget build(BuildContext context) {
    final txsAsync = ref.watch(kidTransactionsProvider(
        (familyId: widget.familyId, kidMemberId: widget.member.id)));
    final txs = txsAsync.value ?? const <BankTransaction>[];

    // (a) Celebrate on open: fires once per screen visit whenever the kid
    // has been away for a while, regardless of whether anything landed.
    if (widget.celebrate && !_celebrateFired) {
      _celebrateFired = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.cashRain.burst());
    }

    // (b) Live arrivals: the first (possibly already-populated) snapshot is
    // just the baseline — no burst for history the kid already knows about.
    // Any transaction id that shows up afterward is new and rains.
    if (txs.isNotEmpty && !_seenTxIdsInitialized) {
      _seenTxIdsInitialized = true;
      _seenTxIds.addAll(txs.map((t) => t.id));
    } else if (_seenTxIdsInitialized) {
      final newIds = txs.map((t) => t.id).where((id) => !_seenTxIds.contains(id)).toList();
      if (newIds.isNotEmpty) {
        _seenTxIds.addAll(newIds);
        WidgetsBinding.instance.addPostFrameCallback((_) => widget.cashRain.burst());
      }
    }

    return Stack(alignment: Alignment.topCenter, children: [
      ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
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
        ],
      ),
      CashRain(controller: widget.cashRain),
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
