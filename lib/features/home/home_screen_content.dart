/// Home screen content widget — the "new tab" page of the browser.
///
/// Displays a dashboard-style layout with:
/// - History and Minimalist mode toggle buttons
/// - Music player tile (YouTube Music integration)
/// - Quick Notes text editor
/// - To-Do list with add/toggle
/// - Quick AI Access grid
/// - Favourites grid
///
/// Supports a "minimalist mode" that hides all widgets for a clean look.
import 'package:flutter/material.dart';
import 'package:myapp/models/note.dart';
import 'package:myapp/models/todo_item.dart';
import 'package:myapp/models/favourite.dart';
import 'package:myapp/models/quick_ai_link.dart';
import 'package:myapp/widgets/glass_widget.dart';
import 'package:myapp/features/home/widgets/music_player_tile.dart';
import 'package:myapp/features/home/widgets/notes_widget.dart';
import 'package:myapp/features/home/widgets/todos_widget.dart';
import 'package:myapp/features/home/widgets/quick_ai_access_widget.dart';
import 'package:myapp/features/home/widgets/favourite_button.dart';

class HomeScreenContent extends StatelessWidget {
  final ScrollController scrollController;
  final List<Note> notes;
  final ValueChanged<String> onNoteChanged;
  final List<TodoItem> todos;
  final List<Favourite> favourites;
  final List<QuickAILink> quickAILinks;
  final VoidCallback onAddTodoTap;
  final ValueChanged<int> onToggleTodo;
  final ValueChanged<String> onLoadUrl;
  final VoidCallback onOpenMusic;
  final VoidCallback onAddAILink;
  final VoidCallback onAddFavouriteTap;
  final ValueChanged<Favourite> onRemoveFavourite;
  final bool isMinimalistMode;
  final VoidCallback onHistoryTap;
  final VoidCallback onToggleMinimalistMode;
  final String songTitle;
  final String songArtist;
  final String? songThumbnailUrl;
  final bool isPlaying;
  final VoidCallback onMusicPrevious;
  final VoidCallback onMusicPlayPause;
  final VoidCallback onMusicNext;

  const HomeScreenContent({
    super.key,
    required this.scrollController,
    required this.notes,
    required this.onNoteChanged,
    required this.todos,
    required this.favourites,
    required this.quickAILinks,
    required this.onAddTodoTap,
    required this.onToggleTodo,
    required this.onLoadUrl,
    required this.onOpenMusic,
    required this.onAddAILink,
    required this.onAddFavouriteTap,
    required this.onRemoveFavourite,
    required this.isMinimalistMode,
    required this.onHistoryTap,
    required this.onToggleMinimalistMode,
    required this.songTitle,
    required this.songArtist,
    required this.songThumbnailUrl,
    required this.isPlaying,
    required this.onMusicPrevious,
    required this.onMusicPlayPause,
    required this.onMusicNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: SingleChildScrollView(
        controller: scrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            // --- History + Minimalist mode toggle row ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // History button
                GestureDetector(
                  onTap: onHistoryTap,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF706C6C).withOpacity(0.10),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.18),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history,
                            color: Colors.white.withOpacity(0.7), size: 16),
                        const SizedBox(width: 6),
                        Text('History',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            )),
                      ],
                    ),
                  ),
                ),
                // Minimalist mode toggle button
                GestureDetector(
                  onTap: onToggleMinimalistMode,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF706C6C).withOpacity(0.10),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.18),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isMinimalistMode
                              ? Icons.widgets_outlined
                              : Icons.visibility_off_outlined,
                          color: Colors.white.withOpacity(0.7),
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isMinimalistMode ? 'Show' : 'Hide',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // --- Content: full dashboard or minimalist placeholder ---
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 400),
              crossFadeState: isMinimalistMode
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: _buildFullContent(context),
              secondChild: _buildMinimalistContent(),
              sizeCurve: Curves.easeInOut,
            ),
            const SizedBox(height: 150),
          ],
        ),
      ),
    );
  }

  /// Clean minimalist placeholder shown when minimalist mode is on.
  Widget _buildMinimalistContent() {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.explore_outlined,
                color: Colors.white.withOpacity(0.15), size: 48),
            const SizedBox(height: 12),
            Text(
              'Nothing Browser',
              style: TextStyle(
                color: Colors.white.withOpacity(0.2),
                fontSize: 16,
                fontWeight: FontWeight.w300,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Full dashboard content with all tiles and grids.
  Widget _buildFullContent(BuildContext context) {
    return Column(
      children: [
        // --- Top row: Music + Notes | Todos + AI ---
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left column: Music player + Notes
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  AspectRatio(
                    aspectRatio: 1.0,
                    child: GlassWidget(
                      borderRadius: BorderRadius.circular(8.0),
                      child: MusicPlayerTile(
                        onTap: onOpenMusic,
                        songTitle: songTitle,
                        songArtist: songArtist,
                        songThumbnailUrl: songThumbnailUrl,
                        isPlaying: isPlaying,
                        onPrevious: onMusicPrevious,
                        onPlayPause: onMusicPlayPause,
                        onNext: onMusicNext,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 250,
                    child: GlassWidget(
                      borderRadius: BorderRadius.circular(8.0),
                      child: NotesWidget(
                        notes: notes,
                        onNoteChanged: onNoteChanged,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Right column: Todos + Quick AI Access
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  AspectRatio(
                    aspectRatio: 1.0,
                    child: GlassWidget(
                      borderRadius: BorderRadius.circular(8.0),
                      child: TodosWidget(
                        todos: todos,
                        onToggleTodo: onToggleTodo,
                        onAddTodoTap: onAddTodoTap,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 250,
                    child: GlassWidget(
                      borderRadius: BorderRadius.circular(8.0),
                      child: QuickAIAccessWidget(
                        quickAILinks: quickAILinks,
                        onLoadUrl: onLoadUrl,
                        onAddAILink: onAddAILink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // --- Favourites section ---
        GlassWidget(
          borderRadius: BorderRadius.circular(8.0),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Favourites',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 16)),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 4,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    ...favourites.map((fav) => FavouriteButton(
                        favourite: fav,
                        onTap: () => onLoadUrl(fav.url),
                        onLongPress: () {
                          // Confirm removal dialog
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: const Color(0xFF1E1E1E),
                              title: const Text('Remove Favourite?',
                                  style: TextStyle(color: Colors.white)),
                              content: Text("Delete '${fav.title}'?",
                                  style: const TextStyle(
                                      color: Colors.white70)),
                              actions: [
                                TextButton(
                                  child: const Text('Cancel'),
                                  onPressed: () =>
                                      Navigator.pop(context),
                                ),
                                TextButton(
                                  child: const Text('Remove',
                                      style:
                                          TextStyle(color: Colors.red)),
                                  onPressed: () {
                                    onRemoveFavourite(fav);
                                    Navigator.pop(context);
                                  },
                                ),
                              ],
                            ),
                          );
                        })),
                    FavouriteButton(
                        icon: Icons.add, onTap: onAddFavouriteTap),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
