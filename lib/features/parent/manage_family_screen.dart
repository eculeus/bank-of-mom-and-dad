import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/models.dart';
import '../../state/providers.dart';
import '../auth/create_family_screen.dart';

class ManageFamilyScreen extends ConsumerWidget {
  final String familyId;
  const ManageFamilyScreen({super.key, required this.familyId});

  Future<void> _addMember(BuildContext context, String role, List<Member> existing) async {
    await showDialog(
      context: context,
      builder: (_) => AddMemberDialog(
        role: role,
        onAdd: (name, email) async {
          final used = existing.map((m) => m.colorIndex).toSet();
          var color = -1;
          for (var i = 0; i < 6; i++) {
            if (!used.contains(i)) {
              color = i;
              break;
            }
          }
          if (color == -1) color = existing.length % 6;
          await FirebaseFirestore.instance
              .collection('families/$familyId/members')
              .add({
            'email': email.toLowerCase(), 'uid': null, 'role': role,
            'displayName': name, 'status': 'invited', 'isOwner': false,
            'balanceCents': 0, 'colorIndex': color, 'lastSeenAt': null,
            'createdAt': FieldValue.serverTimestamp(), 'joinedAt': null,
          });
        },
      ),
    );
  }

  Future<void> _renameFamily(BuildContext context, String currentName) async {
    await showDialog(
      context: context,
      builder: (_) => RenameFamilyDialog(
        currentName: currentName,
        onRename: (newName) async {
          try {
            await FirebaseFirestore.instance
                .doc('families/$familyId')
                .update({'name': newName.trim()});
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Could not rename family. Please try again.')),
              );
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(membersProvider(familyId)).value ?? const <Member>[];
    final visible = members.where((m) => m.status != 'deleted').toList()
      ..sort((a, b) => '${a.role}${a.displayName}'.compareTo('${b.role}${b.displayName}'));
    final familyName = ref.watch(appUserProvider).value?.families[familyId]?.familyName ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Manage family')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final m in visible)
            ListTile(
              leading: Text(m.role == 'parent' ? '🧑‍🚀' : '🦄',
                  style: const TextStyle(fontSize: 28)),
              title: Text('${m.displayName}${m.isOwner ? ' (owner)' : ''}'),
              subtitle: Text('${m.email} · ${m.status}'),
              trailing: m.role == 'kid'
                  ? PopupMenuButton<String>(
                      onSelected: (action) async {
                        if (action == 'disable') {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (dCtx) => AlertDialog(
                              title: Text('Disable ${m.displayName}?'),
                              content: const Text(
                                  'They can still see their history but cannot make requests. You can re-enable anytime.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
                                FilledButton(onPressed: () => Navigator.pop(dCtx, true), child: const Text('Disable')),
                              ],
                            ),
                          );
                          if (ok == true) {
                            try {
                              await FirebaseFirestore.instance
                                  .doc('families/$familyId/members/${m.id}')
                                  .update({'status': 'disabled'});
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Could not update status. Please try again.')),
                                );
                              }
                            }
                          }
                        } else if (action == 'enable') {
                          try {
                            await FirebaseFirestore.instance
                                .doc('families/$familyId/members/${m.id}')
                                .update({'status': m.uid == null ? 'invited' : 'active'});
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Could not update status. Please try again.')),
                              );
                            }
                          }
                        }
                      },
                      itemBuilder: (_) => [
                        if (m.status != 'disabled')
                          const PopupMenuItem(value: 'disable', child: Text('Disable')),
                        if (m.status == 'disabled')
                          const PopupMenuItem(value: 'enable', child: Text('Re-enable')),
                      ],
                    )
                  : null,
            ),
          const Divider(height: 32),
          Row(children: [
            Expanded(
                child: OutlinedButton.icon(
                    icon: const Icon(Icons.child_care), label: const Text('Add kid'),
                    onPressed: () => _addMember(context, 'kid', visible))),
            const SizedBox(width: 12),
            Expanded(
                child: OutlinedButton.icon(
                    icon: const Icon(Icons.escalator_warning), label: const Text('Add co-parent'),
                    onPressed: () => _addMember(context, 'parent', visible))),
          ]),
          const Divider(height: 32),
          Text('Family', style: Theme.of(context).textTheme.titleMedium),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(familyName),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _renameFamily(context, familyName),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.add_home),
            label: const Text('Create another family'),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CreateFamilyScreen())),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
            onPressed: () async {
              await ref.read(authServiceProvider).signOut();
            },
          ),
          const Divider(height: 48),
          Text('Danger zone', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade700),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (dCtx) => AlertDialog(
                  title: const Text('Delete your account?'),
                  content: const Text(
                      'If you are the family owner, all kid accounts will be disabled. '
                      'Transaction history is kept forever. This cannot be undone.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
                    FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
                        onPressed: () => Navigator.pop(dCtx, true),
                        child: const Text('Delete forever')),
                  ],
                ),
              );
              if (ok == true) {
                try {
                  await ref.read(functionsServiceProvider).deleteAccount();
                  await ref.read(authServiceProvider).signOut();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not delete your account. Please try again.')),
                    );
                  }
                }
              }
            },
            child: const Text('Delete my account'),
          ),
        ],
      ),
    );
  }
}

class AddMemberDialog extends StatefulWidget {
  final String role;
  final Future<void> Function(String name, String email) onAdd;
  const AddMemberDialog({super.key, required this.role, required this.onAdd});
  @override
  State<AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<AddMemberDialog> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  bool _busy = false;
  String? _error;

  bool get _valid => _name.text.trim().isNotEmpty && _email.text.contains('@');

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.role == 'kid' ? 'Add a kid' : 'Add a co-parent'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(key: const Key('memberName'), controller: _name,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Name')),
        TextField(key: const Key('memberEmail'), controller: _email,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Google account email')),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!, style: TextStyle(color: Colors.red.shade700)),
          ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: _valid && !_busy
              ? () async {
                  setState(() { _busy = true; _error = null; });
                  try {
                    await widget.onAdd(_name.text.trim(), _email.text.trim());
                    if (context.mounted) Navigator.of(context).maybePop();
                  } catch (e) {
                    if (mounted) setState(() => _error = 'Could not add. Please try again.');
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                }
              : null,
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class RenameFamilyDialog extends StatefulWidget {
  final String currentName;
  final Future<void> Function(String newName) onRename;
  const RenameFamilyDialog({super.key, required this.currentName, required this.onRename});
  @override
  State<RenameFamilyDialog> createState() => _RenameFamilyDialogState();
}

class _RenameFamilyDialogState extends State<RenameFamilyDialog> {
  late final _name = TextEditingController(text: widget.currentName);
  bool _busy = false;

  bool get _valid =>
      _name.text.trim().isNotEmpty && _name.text.trim() != widget.currentName;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename family'),
      content: TextField(
        key: const Key('familyNameField'),
        controller: _name,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(labelText: 'Family name'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: _valid && !_busy
              ? () async {
                  setState(() => _busy = true);
                  await widget.onRename(_name.text.trim());
                  if (context.mounted) Navigator.of(context).maybePop();
                }
              : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
