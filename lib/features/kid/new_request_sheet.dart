import 'package:flutter/material.dart';
import '../../core/money.dart';

typedef RequestSubmit = Future<void> Function({
  required int amountCents, required String reason, required DateTime date, String? note,
});

class NewRequestSheet extends StatefulWidget {
  final RequestSubmit onSubmit;
  const NewRequestSheet({super.key, required this.onSubmit});
  @override
  State<NewRequestSheet> createState() => _NewRequestSheetState();
}

class _NewRequestSheetState extends State<NewRequestSheet> {
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  final _note = TextEditingController();
  DateTime _date = DateTime.now();
  bool _askingFor = true;
  bool _busy = false;
  String? _error;

  int? get _cents {
    final parsed = parseDollarsToCents(_amount.text);
    if (parsed == null || parsed <= 0) return null;
    return _askingFor ? parsed : -parsed;
  }

  bool get _valid => _cents != null && _reason.text.trim().isNotEmpty;

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(
          amountCents: _cents!, reason: _reason.text.trim(), date: _date,
          note: _note.text.trim().isEmpty ? null : _note.text.trim());
      if (mounted) Navigator.of(context).maybePop();
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not send: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 24, right: 24, top: 24,
          bottom: 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Ask Mom & Dad 💌', style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Ask for money')),
            ButtonSegment(value: false, label: Text('Spend Money')),
          ],
          selected: {_askingFor},
          onSelectionChanged: (s) => setState(() => _askingFor = s.first),
        ),
        TextField(
            key: const Key('reqAmount'), controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Amount', prefixText: r'$')),
        TextField(
            key: const Key('reqReason'), controller: _reason,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'What for?')),
        TextField(
            key: const Key('reqNote'), controller: _note,
            decoration: const InputDecoration(labelText: 'Note (optional)')),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.event),
            label: Text(formatDate(_date)),
            onPressed: () async {
              final picked = await showDatePicker(context: context, initialDate: _date,
                  firstDate: DateTime(2015), lastDate: DateTime(2100));
              if (picked != null) setState(() => _date = picked);
            },
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
            onPressed: _valid && !_busy ? _submit : null, child: const Text('Send request 🚀')),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13)),
        ],
      ]),
    );
  }
}
