import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/providers.dart';

class RecurringScreen extends ConsumerWidget {
  final String familyId;
  const RecurringScreen({super.key, required this.familyId});

  Member? _kidById(List<Member> kids, String id) {
    for (final k in kids) {
      if (k.id == id) return k;
    }
    return null;
  }

  Future<void> _confirmDelete(BuildContext context, String recId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete recurring entry?'),
        content: const Text(
            'Delete this recurring entry? Future occurrences stop; past requests/transactions are kept.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await FirebaseFirestore.instance.doc('families/$familyId/recurring/$recId').delete();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not delete: $e')));
      }
    }
  }

  void _openAddSheet(BuildContext context, List<Member> kids) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _AddRecurringSheet(familyId: familyId, kids: kids),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recurring = ref.watch(recurringProvider(familyId));
    final kids = ref.watch(kidsProvider(familyId));

    return Scaffold(
      appBar: AppBar(title: const Text('Recurring')),
      body: recurring.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load recurring entries: $e')),
        data: (entries) {
          if (entries.isEmpty) {
            return const Center(child: Text('No recurring entries yet — add an allowance! 🔁'));
          }
          final grouped = <String, List<(String, Map<String, dynamic>)>>{};
          for (final e in entries) {
            final kidId = e.$2['kidMemberId'] as String? ?? '';
            grouped.putIfAbsent(kidId, () => []).add(e);
          }
          final kidIds = grouped.keys.toList()
            ..sort((a, b) =>
                (_kidById(kids, a)?.displayName ?? 'Unknown')
                    .compareTo(_kidById(kids, b)?.displayName ?? 'Unknown'));

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              for (final kidId in kidIds) ...[
                _KidHeader(kid: _kidById(kids, kidId)),
                for (final entry in grouped[kidId]!)
                  RecurringTile(
                    data: entry.$2,
                    kidName: _kidById(kids, kidId)?.displayName ?? 'Unknown',
                    onDelete: () => _confirmDelete(context, entry.$1),
                  ),
                const SizedBox(height: 8),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add recurring'),
        onPressed: kids.isEmpty ? null : () => _openAddSheet(context, kids),
      ),
    );
  }
}

class _KidHeader extends StatelessWidget {
  final Member? kid;
  const _KidHeader({required this.kid});

  @override
  Widget build(BuildContext context) {
    final name = kid?.displayName ?? 'Unknown';
    final color = kidColors[(kid?.colorIndex ?? 0) % kidColors.length];
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Row(children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: color,
          child: Text(name.isEmpty ? '?' : name.characters.first,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        ),
        const SizedBox(width: 10),
        Text(name,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

/// Pure display widget for a single recurring template — no Firestore/Riverpod
/// dependency so it can be unit-tested directly.
class RecurringTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final String kidName;
  final VoidCallback? onDelete;
  const RecurringTile({super.key, required this.data, required this.kidName, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final amountCents = (data['amountCents'] as num).toInt();
    final interval = data['interval'] as String;
    final reason = data['reason'] as String;
    final nextDueAt = (data['nextDueAt'] as Timestamp).toDate();
    final dateLabel = formatDate(nextDueAt);

    return Semantics(
      label: '$kidName: $reason',
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(reason,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Chip(
                    label: Text(interval == 'weekly' ? 'Weekly' : 'Monthly'),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  Text('Next: $dateLabel', style: Theme.of(context).textTheme.bodySmall),
                ]),
              ]),
            ),
            Text(formatCentsSigned(amountCents),
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: amountCents < 0 ? Colors.red.shade700 : Colors.green.shade800)),
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: onDelete),
          ]),
        ),
      ),
    );
  }
}

class _AddRecurringSheet extends StatefulWidget {
  final String familyId;
  final List<Member> kids;
  const _AddRecurringSheet({required this.familyId, required this.kids});

  @override
  State<_AddRecurringSheet> createState() => _AddRecurringSheetState();
}

class _AddRecurringSheetState extends State<_AddRecurringSheet> {
  String? _kidId;
  bool _deposit = true;
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  final _note = TextEditingController();
  String _interval = 'weekly';
  late DateTime _dueDate = DateTime.now().add(const Duration(days: 1));
  bool _busy = false;
  String? _error;

  int? get _cents {
    final parsed = parseDollarsToCents(_amount.text);
    if (parsed == null || parsed <= 0) return null;
    return _deposit ? parsed : -parsed;
  }

  bool get _valid => _kidId != null && _cents != null && _reason.text.trim().isNotEmpty;

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final due = DateTime(_dueDate.year, _dueDate.month, _dueDate.day, 9);
      await FirebaseFirestore.instance.collection('families/${widget.familyId}/recurring').add({
        'kidMemberId': _kidId,
        'amountCents': _cents,
        'reason': _reason.text.trim(),
        'note': _note.text.trim().isEmpty ? null : _note.text.trim(),
        'interval': _interval,
        'nextDueAt': Timestamp.fromDate(due),
        'active': true,
        'createdByUid': FirebaseAuth.instance.currentUser!.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.of(context).maybePop();
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not save: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 24, right: 24, top: 24, bottom: 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('New recurring entry',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        Wrap(spacing: 8, children: [
          for (final kid in widget.kids)
            ChoiceChip(
              label: Text(kid.displayName),
              selected: _kidId == kid.id,
              selectedColor: kidColors[kid.colorIndex % kidColors.length].withValues(alpha: 0.3),
              onSelected: (_) => setState(() => _kidId = kid.id),
            ),
        ]),
        const SizedBox(height: 16),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Deposit'), icon: Icon(Icons.add)),
            ButtonSegment(value: false, label: Text('Deduct'), icon: Icon(Icons.remove)),
          ],
          selected: {_deposit},
          onSelectionChanged: (s) => setState(() => _deposit = s.first),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('amount'), controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: 'Amount', prefixText: r'$'),
        ),
        TextField(
          key: const Key('reason'), controller: _reason,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: 'Reason'),
        ),
        const SizedBox(height: 16),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'weekly', label: Text('Weekly')),
            ButtonSegment(value: 'monthly', label: Text('Monthly')),
          ],
          selected: {_interval},
          onSelectionChanged: (s) => setState(() => _interval = s.first),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.event),
            label: Text('First due: ${formatDate(_dueDate)}'),
            onPressed: () async {
              final picked = await showDatePicker(
                  context: context,
                  initialDate: _dueDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2100));
              if (picked != null) setState(() => _dueDate = picked);
            },
          ),
        ),
        TextField(
          key: const Key('note'), controller: _note,
          decoration: const InputDecoration(labelText: 'Note (optional)'),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _valid && !_busy ? _save : null,
          child: const Text('Save'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13)),
        ],
      ]),
    );
  }
}
