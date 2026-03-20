/// Music player tile widget for the home screen.
///
/// Displays the currently playing song's artwork, title, artist, and
/// playback controls (previous / play-pause / next). Tapping the tile
/// opens YouTube Music in a new tab.
import 'package:flutter/material.dart';

class MusicPlayerTile extends StatelessWidget {
  /// Title of the currently playing song.
  final String songTitle;

  /// Artist of the currently playing song.
  final String songArtist;

  /// URL of the album art thumbnail (nullable when nothing is playing).
  final String? songThumbnailUrl;

  /// Whether music is currently playing.
  final bool isPlaying;

  /// Called when the entire tile is tapped (opens YouTube Music).
  final VoidCallback onTap;

  /// Called when the previous-track button is pressed.
  final VoidCallback onPrevious;

  /// Called when the play/pause button is pressed.
  final VoidCallback onPlayPause;

  /// Called when the next-track button is pressed.
  final VoidCallback onNext;

  const MusicPlayerTile({
    super.key,
    required this.songTitle,
    required this.songArtist,
    this.songThumbnailUrl,
    required this.isPlaying,
    required this.onTap,
    required this.onPrevious,
    required this.onPlayPause,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Album art background
          if (songThumbnailUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: Image.network(
                songThumbnailUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => const Icon(
                    Icons.music_note,
                    size: 56,
                    color: Colors.white30),
              ),
            ),
          // Gradient overlay for readability
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8.0),
              gradient: LinearGradient(
                colors: [
                  Colors.black
                      .withOpacity(songThumbnailUrl != null ? 0.6 : 0.0),
                  Colors.transparent,
                  Colors.black
                      .withOpacity(songThumbnailUrl != null ? 0.8 : 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
          // Song info and controls
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Song title and artist
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      songTitle,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      songArtist,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                // Playback controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    IconButton(
                        icon: const Icon(Icons.skip_previous,
                            color: Colors.white70),
                        onPressed: onPrevious,
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact),
                    IconButton(
                        icon: Icon(
                            isPlaying
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_filled,
                            color: Colors.white,
                            size: 40),
                        onPressed: onPlayPause,
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact),
                    IconButton(
                        icon: const Icon(Icons.skip_next,
                            color: Colors.white70),
                        onPressed: onNext,
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
