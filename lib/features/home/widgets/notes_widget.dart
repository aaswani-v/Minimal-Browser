/// Quick-notes widget for the home screen.
///
/// Provides a persistent text field that auto-saves whenever the user types.
/// Uses a [TextEditingController] internally to avoid the "setState called
/// during build" error that can occur with inline controller creation.
import 'package:flutter/material.dart';
import 'package:myapp/models/note.dart';

class NotesWidget extends StatefulWidget {
  /// Current list of notes (only the first one is displayed).
  final List<Note> notes;

  /// Called whenever the note content changes (triggers a save).
  final ValueChanged<String> onNoteChanged;

  const NotesWidget({
    super.key,
    required this.notes,
    required this.onNoteChanged,
  });

  @override
  State<NotesWidget> createState() => _NotesWidgetState();
}

class _NotesWidgetState extends State<NotesWidget> {
  late TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(
        text: widget.notes.isNotEmpty ? widget.notes.first.content : '');
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant NotesWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newText =
        widget.notes.isNotEmpty ? widget.notes.first.content : '';
    if (_noteController.text != newText) {
      // Safely update without triggering a rebuild loop or moving the cursor.
      _noteController.value = _noteController.value.copyWith(text: newText);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Quick Notes',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 16)),
          const SizedBox(height: 8),
          Expanded(
            child: TextField(
              controller: _noteController,
              onChanged: widget.onNoteChanged,
              expands: true,
              maxLines: null,
              style: const TextStyle(color: Colors.white70),
              decoration: const InputDecoration(
                hintText: 'Tap to start writing...',
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.white54),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
