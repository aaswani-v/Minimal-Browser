/// Reusable dialog helpers used across the browser.
///
/// Each function shows a styled AlertDialog and invokes the appropriate
/// callback when the user confirms. Dialogs are extracted here to keep
/// the BrowserScreen state class lean and focused on orchestration.
import 'package:flutter/material.dart';
import 'package:myapp/models/quick_ai_link.dart';
import 'package:myapp/models/note.dart';

/// Shows a dialog to add a new to-do task.
///
/// Calls [onAdd] with the entered text when the user confirms.
void showAddTodoDialog(BuildContext context, void Function(String) onAdd) {
  final TextEditingController textController = TextEditingController();
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title:
          const Text('Add a new task', style: TextStyle(color: Colors.white)),
      content: TextField(
        controller: textController,
        autofocus: true,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          hintText: 'Your task...',
          hintStyle: TextStyle(color: Colors.grey),
        ),
        onSubmitted: (value) {
          onAdd(value);
          Navigator.of(context).pop();
        },
      ),
      actions: [
        TextButton(
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          child: const Text('Add'),
          onPressed: () {
            onAdd(textController.text);
            Navigator.of(context).pop();
          },
        ),
      ],
    ),
  );
}

/// Shows a dialog to add a new AI tool shortcut.
///
/// Calls [onAdd] with (name, url) when the user confirms.
void showAddAIDialog(
    BuildContext context, void Function(String name, String url) onAdd) {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController urlController = TextEditingController();
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title:
          const Text('Add AI Tool', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Name (e.g., Perplexity)',
              hintStyle: TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: urlController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'URL (e.g., perplexity.ai)',
              hintStyle: TextStyle(color: Colors.grey),
            ),
            onSubmitted: (value) {
              onAdd(nameController.text, value);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          child: const Text('Add'),
          onPressed: () {
            onAdd(nameController.text, urlController.text);
            Navigator.of(context).pop();
          },
        ),
      ],
    ),
  );
}

/// Shows a dialog to add a new favourite / bookmarked website.
///
/// Calls [onAdd] with (title, url) when the user confirms.
void showAddFavouriteDialog(
    BuildContext context, void Function(String title, String url) onAdd) {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController urlController = TextEditingController();
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title:
          const Text('Add Favourite', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: titleController,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Title (e.g., Google)',
              hintStyle: TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: urlController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'URL (e.g., google.com)',
              hintStyle: TextStyle(color: Colors.grey),
            ),
            onSubmitted: (value) {
              onAdd(titleController.text, value);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          child: const Text('Add'),
          onPressed: () {
            onAdd(titleController.text, urlController.text);
            Navigator.of(context).pop();
          },
        ),
      ],
    ),
  );
}

/// Shows a search/URL input dialog.
///
/// Calls [onSearch] with the entered query or URL when the user confirms.
void showSearchDialog(BuildContext context, void Function(String) onSearch) {
  final TextEditingController textController = TextEditingController();
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: const Text('Search or Type URL',
          style: TextStyle(color: Colors.white)),
      content: TextField(
        controller: textController,
        autofocus: true,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          hintText: 'e.g., google.com',
          hintStyle: TextStyle(color: Colors.grey),
        ),
        onSubmitted: (value) {
          onSearch(value);
          Navigator.of(context).pop();
        },
      ),
      actions: [
        TextButton(
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          child: const Text('Go'),
          onPressed: () {
            onSearch(textController.text);
            Navigator.of(context).pop();
          },
        ),
      ],
    ),
  );
}

/// Shows a dialog listing all saved AI tools for the user to pick one.
///
/// Calls [onLoadUrl] with the selected tool's URL.
void showChatAIDialog(BuildContext context, List<QuickAILink> quickAILinks,
    void Function(String) onLoadUrl) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title:
          const Text('Choose AI Tool', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: quickAILinks.length,
          itemBuilder: (context, index) {
            final aiLink = quickAILinks[index];
            return ListTile(
              leading: Image.network(aiLink.iconUrl,
                  width: 24,
                  height: 24,
                  errorBuilder: (c, e, s) =>
                      const Icon(Icons.computer)),
              title: Text(aiLink.name,
                  style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.of(context).pop();
                onLoadUrl(aiLink.url);
              },
            );
          },
        ),
      ),
    ),
  );
}

/// Shows a dialog for writing or editing a quick note.
///
/// Pre-populates with the first note's content if [notes] is not empty.
/// Calls [onSave] with the note text when the user confirms.
void showQuickNoteDialog(
    BuildContext context, List<Note> notes, void Function(String) onSave) {
  final TextEditingController textController = TextEditingController(
      text: notes.isNotEmpty ? notes.first.content : '');
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title:
          const Text('Quick Note', style: TextStyle(color: Colors.white)),
      content: TextField(
        controller: textController,
        autofocus: true,
        maxLines: 5,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          hintText: 'Your note...',
          hintStyle: TextStyle(color: Colors.grey),
        ),
      ),
      actions: [
        TextButton(
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          child: const Text('Save'),
          onPressed: () {
            onSave(textController.text);
            Navigator.of(context).pop();
          },
        ),
      ],
    ),
  );
}
