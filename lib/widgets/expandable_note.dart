import 'package:flutter/material.dart';

class ExpandableNote extends StatefulWidget {
  final String text;
  final int trigger;
  const ExpandableNote({super.key, required this.text, this.trigger = 80});
  @override
  State<ExpandableNote> createState() => _ExpandableNoteState();
}

class _ExpandableNoteState extends State<ExpandableNote> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    final needsToggle = widget.text.length > widget.trigger;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.text,
          maxLines: _expanded ? null : 2,
          overflow: _expanded ? null : TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall),
      if (needsToggle)
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Text(_expanded ? 'less' : 'more',
              style: TextStyle(color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600, fontSize: 12)),
        ),
    ]);
  }
}
