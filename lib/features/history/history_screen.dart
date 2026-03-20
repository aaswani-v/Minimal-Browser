/// Browsing history screen with grouped date headers and swipe-to-delete.
///
/// Shows a blurred overlay listing all visited pages grouped by date
/// (Today, Yesterday, specific dates). Individual items can be swiped
/// to delete, and a "Clear All" button removes the entire history.
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:myapp/models/history_item.dart';
import 'package:myapp/widgets/glass_widget.dart';

class HistoryScreen extends StatelessWidget {
  /// Full list of history items, ordered most-recent first.
  final List<HistoryItem> history;

  /// Called to dismiss the history overlay.
  final VoidCallback onClose;

  /// Called when the user taps a history item to navigate to it.
  final ValueChanged<String> onLoadUrl;

  /// Called when a single history item is swiped away, with its index.
  final ValueChanged<int> onRemoveItem;

  /// Called when the user confirms "Clear All".
  final VoidCallback onClearAll;

  const HistoryScreen({
    super.key,
    required this.history,
    required this.onClose,
    required this.onLoadUrl,
    required this.onRemoveItem,
    required this.onClearAll,
  });

  /// Formats a date into a human-readable header (Today, Yesterday, or date).
  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) return 'Today';
    if (dateOnly == yesterday) return 'Yesterday';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  /// Formats a timestamp into 12-hour time (e.g. "2:30 PM").
  String _formatTime(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    // Group history items by date header
    final Map<String, List<MapEntry<int, HistoryItem>>> grouped = {};
    for (int i = 0; i < history.length; i++) {
      final header = _formatDateHeader(history[i].visitedAt);
      grouped.putIfAbsent(header, () => []);
      grouped[header]!.add(MapEntry(i, history[i]));
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Blurred backdrop
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onClose,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  color: Colors.black.withOpacity(0.60),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // --- Header row ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          // Back button
                          GestureDetector(
                            onTap: onClose,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.arrow_back,
                                  color: Colors.white, size: 20),
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Text(
                            'Browsing History',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      // Clear All button
                      if (history.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: const Color(0xFF1E1E1E),
                                title: const Text('Clear History',
                                    style: TextStyle(color: Colors.white)),
                                content: const Text(
                                    'Are you sure you want to clear all browsing history?',
                                    style:
                                        TextStyle(color: Colors.white70)),
                                actions: [
                                  TextButton(
                                    child: const Text('Cancel'),
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(),
                                  ),
                                  TextButton(
                                    child: const Text('Clear',
                                        style: TextStyle(
                                            color: Colors.redAccent)),
                                    onPressed: () {
                                      Navigator.of(ctx).pop();
                                      onClearAll();
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color:
                                      Colors.redAccent.withOpacity(0.3)),
                            ),
                            child: const Text(
                              'Clear All',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // --- History list ---
                  Expanded(
                    child: history.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.history,
                                    color: Colors.white.withOpacity(0.15),
                                    size: 64),
                                const SizedBox(height: 16),
                                Text(
                                  'No history yet',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.3),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Websites you visit will appear here',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.2),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: grouped.length,
                            itemBuilder: (context, sectionIndex) {
                              final dateHeader =
                                  grouped.keys.elementAt(sectionIndex);
                              final items = grouped[dateHeader]!;

                              return Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  // Date header
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        top: 12, bottom: 8),
                                    child: Text(
                                      dateHeader,
                                      style: TextStyle(
                                        color:
                                            Colors.white.withOpacity(0.5),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                  // History items for this date
                                  ...items.map((entry) {
                                    final globalIndex = entry.key;
                                    final item = entry.value;
                                    String host;
                                    try {
                                      host = Uri.parse(item.url)
                                          .host
                                          .replaceAll('www.', '');
                                    } catch (_) {
                                      host = item.url;
                                    }
                                    return Dismissible(
                                      key: ValueKey(
                                          '${item.url}_${item.visitedAt.millisecondsSinceEpoch}'),
                                      direction:
                                          DismissDirection.endToStart,
                                      background: Container(
                                        alignment:
                                            Alignment.centerRight,
                                        padding: const EdgeInsets.only(
                                            right: 20),
                                        margin: const EdgeInsets.only(
                                            bottom: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.redAccent
                                              .withOpacity(0.2),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.redAccent),
                                      ),
                                      onDismissed: (_) =>
                                          onRemoveItem(globalIndex),
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                            bottom: 8),
                                        child: GestureDetector(
                                          onTap: () =>
                                              onLoadUrl(item.url),
                                          child: GlassWidget(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.all(
                                                      14.0),
                                              child: Row(
                                                children: [
                                                  // Favicon
                                                  ClipRRect(
                                                    borderRadius:
                                                        BorderRadius
                                                            .circular(6),
                                                    child: Image.network(
                                                      item.iconUrl,
                                                      width: 28,
                                                      height: 28,
                                                      errorBuilder:
                                                          (c, e, s) =>
                                                              Container(
                                                        width: 28,
                                                        height: 28,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .white
                                                              .withOpacity(
                                                                  0.1),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      6),
                                                        ),
                                                        child: const Icon(
                                                            Icons.public,
                                                            size: 18,
                                                            color: Colors
                                                                .white54),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(
                                                      width: 14),
                                                  // Title and hostname
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          item.title,
                                                          style:
                                                              const TextStyle(
                                                            color: Colors
                                                                .white,
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w500,
                                                          ),
                                                          maxLines: 1,
                                                          overflow:
                                                              TextOverflow
                                                                  .ellipsis,
                                                        ),
                                                        const SizedBox(
                                                            height: 2),
                                                        Text(
                                                          host,
                                                          style:
                                                              TextStyle(
                                                            color: Colors
                                                                .white
                                                                .withOpacity(
                                                                    0.4),
                                                            fontSize: 12,
                                                          ),
                                                          maxLines: 1,
                                                          overflow:
                                                              TextOverflow
                                                                  .ellipsis,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(
                                                      width: 8),
                                                  // Timestamp
                                                  Text(
                                                    _formatTime(
                                                        item.visitedAt),
                                                    style: TextStyle(
                                                      color: Colors.white
                                                          .withOpacity(
                                                              0.3),
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
