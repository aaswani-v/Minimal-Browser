/// Quick AI access grid widget for the home screen.
///
/// Displays a grid of saved AI tool shortcuts (ChatGPT, Gemini, etc.)
/// with an "Add Tool" button at the end for adding custom links.
import 'package:flutter/material.dart';
import 'package:myapp/models/quick_ai_link.dart';

/// Main grid container showing all AI tool shortcuts.
class QuickAIAccessWidget extends StatelessWidget {
  /// List of saved AI tool links to display.
  final List<QuickAILink> quickAILinks;

  /// Called when an AI tool is tapped, with its URL.
  final ValueChanged<String> onLoadUrl;

  /// Called when the "Add Tool" button is tapped.
  final VoidCallback onAddAILink;

  const QuickAIAccessWidget({
    super.key,
    required this.quickAILinks,
    required this.onLoadUrl,
    required this.onAddAILink,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Quick AI Access',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 16)),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              // Extra item for the "Add" button
              itemCount: quickAILinks.length + 1,
              itemBuilder: (context, index) {
                // Last item is the "add" button
                if (index == quickAILinks.length) {
                  return QuickAIAddButton(onTap: onAddAILink);
                }
                final link = quickAILinks[index];
                return QuickAIButton(
                    link: link, onTap: () => onLoadUrl(link.url));
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual AI tool button with favicon and name.
class QuickAIButton extends StatelessWidget {
  /// The AI link data to display.
  final QuickAILink link;

  /// Called when this button is tapped.
  final VoidCallback onTap;

  const QuickAIButton({super.key, required this.link, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.network(
              link.iconUrl,
              width: 24,
              height: 24,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.computer, size: 24, color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: Text(
                link.name,
                style:
                    const TextStyle(color: Colors.white70, fontSize: 12),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Add Tool" button displayed at the end of the AI links grid.
class QuickAIAddButton extends StatelessWidget {
  /// Called when this button is tapped.
  final VoidCallback onTap;

  const QuickAIAddButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxHeight < 64 || constraints.maxWidth < 64;
          return Container(
            padding: EdgeInsets.all(compact ? 4 : 8),
            decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12.0),
                border:
                    Border.all(color: Colors.white.withOpacity(0.2))),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add,
                  color: Colors.white.withOpacity(0.7),
                  size: compact ? 16 : 24,
                ),
                if (!compact) ...[
                  const SizedBox(height: 8),
                  Text('Add Tool',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
