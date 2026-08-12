import 'package:flutter/material.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../models/models.dart';

typedef TransactionSubmit = Future<void> Function({
  required String kidMemberId,
  required int amountCents,
  required String reason,
  required DateTime date,
  String? note,
});

class TransactionSheet extends StatefulWidget {
  final List<Member> kids;
  final Member? preselectedKid;
  final BankTransaction? existing;
  final TransactionSubmit onSubmit;
  const TransactionSheet({super.key, required this.kids, this.preselectedKid, this.existing, required this.onSubmit});

  @override
  State<TransactionSheet> createState() => _TransactionSheetState();
}

class _TransactionSheetState extends State<TransactionSheet> {
  String? _kidId;
  bool _deposit = true;
  late final _amount = TextEditingController(
      text: widget.existing == null ? '' : (widget.existing!.amountCents.abs() / 100).toStringAsFixed(2));
  late final _reason = TextEditingController(text: widget.existing?.reason ?? '');
  late final _note = TextEditingController(text: widget.existing?.note ?? '');
  late DateTime _date = widget.existing?.date ?? DateTime.now();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _kidId = widget.existing?.kidMemberId ??
        widget.preselectedKid?.id ??
        (widget.kids.length == 1 ? widget.kids.first.id : null);
    if (widget.existing != null) _deposit = widget.existing!.amountCents >= 0;
  }

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
      await widget.onSubmit(
        kidMemberId: _kidId!, amountCents: _cents!, reason: _reason.text.trim(),
        date: _date, note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      );
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
          left: 24, right: 24, top: 24,
          bottom: 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(widget.existing == null ? 'New transaction' : 'Edit transaction',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        // With a single kid the sheet is already scoped to them (opened from
        // their own screen), so the picker is redundant — hide it.
        if (widget.kids.length > 1) ...[
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
        ],
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
        TextField(
          key: const Key('note'), controller: _note,
          decoration: const InputDecoration(labelText: 'Note (optional)'),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.event),
            label: Text(formatDate(_date)),
            onPressed: () async {
              final picked = await showDatePicker(
                  context: context, initialDate: _date,
                  firstDate: DateTime(2015), lastDate: DateTime(2100));
              if (picked != null) setState(() => _date = picked);
            },
          ),
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
