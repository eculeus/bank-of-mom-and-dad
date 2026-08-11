import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money.dart';
import '../../models/models.dart';
import '../../state/providers.dart';
import '../../widgets/expandable_note.dart';

class RequestsScreen extends ConsumerWidget {
  final String familyId;
  const RequestsScreen({super.key, required this.familyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingRequestsProvider(familyId));
    final members = ref.watch(membersProvider(familyId)).value ?? const <Member>[];
    String nameOf(String memberId) =>
        members.where((m) => m.id == memberId).firstOrNull?.displayName ?? 'Unknown';
    return Scaffold(
      appBar: AppBar(title: const Text('Transaction requests')),
      body: pending.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load requests: $e')),
        data: (list) => list.isEmpty
            ? const Center(child: Text('🎉 No pending requests'))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final req in list)
                    RequestCard(
                      request: req,
                      kidName: nameOf(req.kidMemberId),
                      onDecide: (approve) async {
                        try {
                          await ref.read(functionsServiceProvider).decideRequest(
                              familyId: familyId, requestId: req.id, approve: approve);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed: $e')));
                          }
                        }
                      },
                    ),
                ],
              ),
      ),
    );
  }
}

class RequestCard extends StatefulWidget {
  final MoneyRequest request;
  final String kidName;
  final Future<void> Function(bool approve) onDecide;
  const RequestCard({super.key, required this.request, required this.kidName, required this.onDecide});

  @override
  State<RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<RequestCard> {
  bool _busy = false;

  Future<void> _decide(bool approve) async {
    setState(() => _busy = true);
    try {
      await widget.onDecide(approve);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.request;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(widget.kidName,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700))),
            Text(formatCentsSigned(req.amountCents),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                    color: req.amountCents < 0 ? Colors.red.shade700 : Colors.green.shade800)),
          ]),
          const SizedBox(height: 4),
          Text(req.reason),
          Text(formatDate(req.date), style: Theme.of(context).textTheme.bodySmall),
          if (req.note != null) ExpandableNote(text: req.note!),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: FilledButton(
                onPressed: _busy ? null : () => _decide(true),
                child: const Text('Approve'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: _busy ? null : () => _decide(false),
                child: const Text('Deny'),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
