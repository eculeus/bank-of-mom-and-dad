import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money.dart';
import '../../models/models.dart';
import '../../state/providers.dart';
import '../../widgets/expandable_note.dart';
import 'new_request_sheet.dart';

class KidRequestsScreen extends ConsumerWidget {
  final String familyId;
  final String memberId;
  final bool disabled;
  const KidRequestsScreen({super.key, required this.familyId, required this.memberId, required this.disabled});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(myRequestsProvider((familyId: familyId, kidMemberId: memberId)));
    return Scaffold(
      body: requests.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load requests: $e')),
        data: (list) {
          final visible = list.where((r) => !r.hiddenByKid).toList();
          if (visible.isEmpty) {
            return const Center(child: Text('No requests yet — ask away! 💸'));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 96),
            children: [
              for (final req in visible)
                KidRequestTile(
                  request: req,
                  onHide: req.status == 'pending'
                      ? null
                      : () => FirebaseFirestore.instance
                          .doc('families/$familyId/requests/${req.id}')
                          .update({'hiddenByKid': true}),
                ),
            ],
          );
        },
      ),
      floatingActionButton: disabled
          ? null
          : FloatingActionButton.extended(
              icon: const Icon(Icons.send),
              label: const Text('Ask for money 💸'),
              onPressed: () => showModalBottomSheet(
                context: context, isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
                builder: (_) => NewRequestSheet(
                  onSubmit: ({required amountCents, required reason, required date, note}) =>
                      FirebaseFirestore.instance
                          .collection('families/$familyId/requests')
                          .add({
                    'kidMemberId': memberId, 'amountCents': amountCents, 'reason': reason,
                    'date': Timestamp.fromDate(date), 'note': note, 'status': 'pending',
                    'decidedByUid': null, 'hiddenByKid': false,
                    'createdAt': FieldValue.serverTimestamp(),
                  }),
                ),
              ),
            ),
    );
  }
}

const _statusColors = {
  'pending': Colors.amber,
  'approved': Colors.green,
  'denied': Colors.red,
};
const _statusEmoji = {'pending': '⏳', 'approved': '✅', 'denied': '❌'};

class KidRequestTile extends StatelessWidget {
  final MoneyRequest request;
  final VoidCallback? onHide;
  const KidRequestTile({super.key, required this.request, this.onHide});

  @override
  Widget build(BuildContext context) {
    final color = _statusColors[request.status] ?? Colors.grey;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Chip(
          label: Text('${_statusEmoji[request.status] ?? ''} ${request.status}'),
          backgroundColor: color.withValues(alpha: 0.15),
          side: BorderSide(color: color),
        ),
        title: Text(request.reason),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(formatDate(request.date)),
          if (request.note != null) ExpandableNote(text: request.note!),
        ]),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(formatCentsSigned(request.amountCents),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          if (onHide != null)
            IconButton(icon: const Icon(Icons.visibility_off), tooltip: 'Hide', onPressed: onHide),
        ]),
      ),
    );
  }
}
