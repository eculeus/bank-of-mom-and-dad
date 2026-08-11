import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/providers.dart';

class CreateFamilyScreen extends ConsumerStatefulWidget {
  const CreateFamilyScreen({super.key});
  @override
  ConsumerState<CreateFamilyScreen> createState() => _CreateFamilyScreenState();
}

class _KidRow {
  final name = TextEditingController();
  final email = TextEditingController();
}

class _CreateFamilyScreenState extends ConsumerState<CreateFamilyScreen> {
  final _name = TextEditingController();
  final _kids = [_KidRow()];
  final _coParent = TextEditingController();
  bool _busy = false;
  String? _error;

  bool get _valid =>
      _name.text.trim().isNotEmpty &&
      _kids.every((k) =>
          (k.name.text.trim().isEmpty && k.email.text.trim().isEmpty) ||
          (k.name.text.trim().isNotEmpty && k.email.text.contains('@')));

  Future<void> _submit() async {
    setState(() { _busy = true; _error = null; });
    try {
      final kids = _kids
          .where((k) => k.name.text.trim().isNotEmpty)
          .map((k) => {'name': k.name.text.trim(), 'email': k.email.text.trim()})
          .toList();
      final co = _coParent.text.trim();
      await ref.read(functionsServiceProvider).createFamily(
          name: _name.text.trim(), kids: kids, coParents: co.isEmpty ? [] : [co]);
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      setState(() => _error = 'Could not create family: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create your family')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            key: const Key('familyName'),
            controller: _name,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
                labelText: 'Family name', hintText: 'e.g. Smith Family Bank'),
          ),
          const SizedBox(height: 24),
          Text('Kids', style: Theme.of(context).textTheme.titleMedium),
          for (final (i, kid) in _kids.indexed)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(children: [
                Expanded(
                    child: TextField(
                        key: Key('kidName$i'), controller: kid.name,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(labelText: 'Name'))),
                const SizedBox(width: 8),
                Expanded(
                    flex: 2,
                    child: TextField(
                        key: Key('kidEmail$i'), controller: kid.email,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(labelText: 'Email'))),
              ]),
            ),
          TextButton.icon(
            onPressed: () => setState(() => _kids.add(_KidRow())),
            icon: const Icon(Icons.add), label: const Text('Add another kid'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _coParent,
            decoration: const InputDecoration(
                labelText: 'Co-parent email (optional)'),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _valid && !_busy ? _submit : null,
            child: _busy
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Create family'),
          ),
          if (_error != null)
            Padding(padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}
