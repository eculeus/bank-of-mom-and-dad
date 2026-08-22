import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/providers.dart';
import '../../widgets/expandable_note.dart';
import '../../widgets/month_header.dart';
import 'parent_home_screen.dart' show submitTransaction;
import 'transaction_sheet.dart';

class KidDetailScreen extends ConsumerWidget {
  final String familyId;
  final Member kid;
  const KidDetailScreen({super.key, required this.familyId, required this.kid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txs = ref.watch(kidTransactionsProvider((familyId: familyId, kidMemberId: kid.id)));
    final liveKid = ref.watch(kidsProvider(familyId))
        .where((k) => k.id == kid.id).firstOrNull ?? kid;
    final myUid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(title: Text('${liveKid.displayName} — ${formatCents(liveKid.balanceCents)}')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kBrandIndigo,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.attach_money),
        // The transaction is scoped to this kid automatically — no picker.
        label: Text('Add / Subtract for ${liveKid.displayName}'),
        onPressed: () => showModalBottomSheet(
          context: context, isScrollControlled: true,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          builder: (_) => TransactionSheet(
            kids: [liveKid], preselectedKid: liveKid,
            onSubmit: ({required kidMemberId, required amountCents, required reason, required date, note}) =>
                submitTransaction(familyId, kidMemberId: kidMemberId, amountCents: amountCents,
                    reason: reason, date: date, note: note),
          ),
        ),
      ),
      body: txs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load history: $e')),
        data: (list) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: groupByMonth<BankTransaction>(
            items: list,
            dateOf: (t) => t.date,
            item: (tx) => ListTile(
              title: Text(tx.reason),
              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${formatTxDay(tx.date)}${tx.editedAtLabel}'),
                if (tx.note != null) ExpandableNote(text: tx.note!),
              ]),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(formatCentsSigned(tx.amountCents),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                        color: tx.amountCents < 0 ? kMoneyDown : kMoneyUp)),
                if (tx.createdByUid == myUid)
                  PopupMenuButton<String>(
                    onSelected: (action) async {
                      if (action == 'edit') {
                        showModalBottomSheet(
                          context: context, isScrollControlled: true,
                          builder: (_) => TransactionSheet(
                            kids: [liveKid], existing: tx,
                            onSubmit: ({required kidMemberId, required amountCents, required reason, required date, note}) =>
                                submitTransaction(familyId, kidMemberId: kidMemberId,
                                    amountCents: amountCents, reason: reason, date: date,
                                    note: note, existingTxId: tx.id),
                          ),
                        );
                      } else if (action == 'delete') {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (dCtx) => AlertDialog(
                            title: const Text('Delete transaction?'),
                            content: Text('${tx.reason} (${formatCentsSigned(tx.amountCents)})'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
                              FilledButton(onPressed: () => Navigator.pop(dCtx, true), child: const Text('Delete')),
                            ],
                          ),
                        );
                        if (ok == true) {
                          await FirebaseFirestore.instance
                              .doc('families/$familyId/transactions/${tx.id}').delete();
                        }
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
