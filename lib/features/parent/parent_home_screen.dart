import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';
import 'kid_detail_screen.dart';
import 'manage_family_screen.dart';
import 'recurring_screen.dart';
import 'requests_screen.dart';

Future<void> submitTransaction(String familyId, {
  required String kidMemberId, required int amountCents, required String reason,
  required DateTime date, String? note, String? existingTxId,
}) {
  final col = FirebaseFirestore.instance.collection('families/$familyId/transactions');
  if (existingTxId != null) {
    // firestore.rules pins source/createdByUid/kidMemberId on update — only send
    // the user-editable fields so edits to request-sourced transactions still pass.
    return col.doc(existingTxId).update({
      'amountCents': amountCents, 'reason': reason,
      'date': Timestamp.fromDate(date), 'note': note,
      'editedAt': FieldValue.serverTimestamp(),
    });
  }
  return col.add({
    'kidMemberId': kidMemberId, 'amountCents': amountCents, 'reason': reason,
    'date': Timestamp.fromDate(date), 'note': note, 'source': 'parent',
    'requestId': null, 'createdByUid': FirebaseAuth.instance.currentUser!.uid,
    'createdAt': FieldValue.serverTimestamp(),
  });
}

class ParentHomeScreen extends ConsumerWidget {
  final String familyId;
  const ParentHomeScreen({super.key, required this.familyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUser = ref.watch(appUserProvider).value;
    final membersAsync = ref.watch(membersProvider(familyId));
    final kids = ref.watch(kidsProvider(familyId));
    final pending = ref.watch(pendingRequestsProvider(familyId)).value ?? const [];
    final familyName = appUser?.families[familyId]?.familyName ?? 'Family';
    final otherFamilies = (appUser?.families ?? {}).entries
        .where((e) => e.key != familyId && e.value.status != 'deleted').toList();

    return Scaffold(
      appBar: AppBar(
        title: otherFamilies.isEmpty
            ? Text(familyName)
            : PopupMenuButton<String>(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(familyName), const Icon(Icons.arrow_drop_down),
                ]),
                onSelected: (fid) => FirebaseFirestore.instance
                    .doc('users/${appUser!.uid}').update({'activeFamilyId': fid}),
                itemBuilder: (_) => [
                  for (final e in (appUser?.families ?? {}).entries)
                    if (e.value.status != 'deleted')
                      PopupMenuItem(value: e.key, child: Text(e.value.familyName)),
                ],
              ),
        actions: [
          IconButton(
            icon: const Icon(Icons.event_repeat),
            tooltip: 'Recurring',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => RecurringScreen(familyId: familyId))),
          ),
          IconButton(
            icon: Badge(
              isLabelVisible: pending.isNotEmpty,
              label: Text('${pending.length}'),
              child: const Icon(Icons.inbox),
            ),
            tooltip: 'Requests',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => RequestsScreen(familyId: familyId))),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ManageFamilyScreen(familyId: familyId))),
          ),
        ],
      ),
      body: membersAsync.isLoading && !membersAsync.hasValue
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          for (final kid in kids)
            Card(
              margin: const EdgeInsets.only(bottom: 14),
              child: InkWell(
                borderRadius: BorderRadius.circular(26),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => KidDetailScreen(familyId: familyId, kid: kid))),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: kidColors[kid.colorIndex % kidColors.length],
                      child: Text(kid.displayName.characters.first,
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(kid.displayName,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                        if (kid.status == 'invited')
                          const Text('Invited — not joined yet', style: TextStyle(fontSize: 12)),
                        if (kid.status == 'disabled')
                          const Text('Disabled', style: TextStyle(fontSize: 12, color: Colors.red)),
                      ]),
                    ),
                    Text(formatCents(kid.balanceCents),
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: kid.balanceCents < 0 ? kMoneyDown : kMoneyUp)),
                  ]),
                ),
              ),
            ),
          if (kids.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: Text('Tap a kid to add or subtract money 💰',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            ),
          if (kids.isEmpty)
            const Padding(padding: EdgeInsets.all(48),
                child: Center(child: Text('No kids yet — add them in settings ⚙️'))),
        ],
      ),
    );
  }
}
