/// Full-screen search overlay with URL bar and quick actions.
///
/// Provides a blurred backdrop with a text input for searching or entering
/// URLs, action buttons (Summarize, ChatAI, Send, Quick Note), and a list
/// of saved AI tools and favourites for quick access.
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:myapp/models/quick_ai_link.dart';
import 'package:myapp/models/favourite.dart';
import 'package:myapp/widgets/glass_widget.dart';

class SearchScreen extends StatelessWidget {
  /// Called when the overlay should be dismissed.
  final VoidCallback onClose;

  /// Called when the user submits a search query or URL.
  final ValueChanged<String> onSearch;

  /// Saved AI tool links to display in the list.
  final List<QuickAILink> quickAILinks;

  /// Saved favourites to display in the list.
  final List<Favourite> favourites;

  /// Called to navigate to a URL from the list.
  final ValueChanged<String> onLoadUrl;

  /// Called to show the AI tool chooser dialog.
  final VoidCallback onShowChatAIDialog;

  /// Called to copy the current URL to clipboard.
  final VoidCallback onShare;

  /// Called to show the quick note dialog.
  final VoidCallback onQuickNote;

  const SearchScreen({
    super.key,
    required this.onClose,
    required this.onSearch,
    required this.quickAILinks,
    required this.favourites,
    required this.onLoadUrl,
    required this.onShowChatAIDialog,
    required this.onShare,
    required this.onQuickNote,
  });

  @override
  Widget build(BuildContext context) {
    final TextEditingController searchController = TextEditingController();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Blurred backdrop (tapping dismisses the overlay)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onClose,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  color: Colors.black.withOpacity(0.50),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // --- Search bar ---
                  GlassWidget(
                    borderRadius: BorderRadius.circular(30),
                    useFigmaNavStyle: true,
                    child: TextField(
                      controller: searchController,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search or enter website',
                        hintStyle:
                            TextStyle(color: Colors.white.withOpacity(0.5)),
                        prefixIcon: Icon(Icons.search,
                            color: Colors.white.withOpacity(0.5)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 15),
                      ),
                      onSubmitted: onSearch,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // --- Action buttons row ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _SearchActionButton(
                          icon: Icons.summarize,
                          label: 'Summarize',
                          onTap: () {}),
                      _SearchActionButton(
                          icon: Icons.chat_bubble_outline,
                          label: 'ChatAI',
                          onTap: onShowChatAIDialog),
                      _SearchActionButton(
                          icon: Icons.send_outlined,
                          label: 'Send',
                          onTap: onShare),
                      _SearchActionButton(
                          icon: Icons.description_outlined,
                          label: 'Quick Note',
                          onTap: onQuickNote),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // --- Links list (AI tools + Favourites) ---
                  Expanded(
                    child: ListView(
                      children: [
                        ...quickAILinks.map((link) => _SearchListItem(
                              title: link.name,
                              subtitle: Uri.parse(link.url).host,
                              iconUrl: link.iconUrl,
                              onTap: () => onLoadUrl(link.url),
                            )),
                        ...favourites.map((fav) => _SearchListItem(
                              title: fav.title,
                              subtitle: Uri.parse(fav.url).host,
                              iconUrl: fav.iconUrl,
                              onTap: () => onLoadUrl(fav.url),
                            )),
                      ],
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

/// Circular action button used in the search screen's quick-action row.
class _SearchActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SearchActionButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(label,
              style:
                  const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}

/// Individual list item in the search screen showing a site with favicon.
class _SearchListItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final String iconUrl;
  final VoidCallback onTap;

  const _SearchListItem(
      {required this.title,
      required this.subtitle,
      required this.iconUrl,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: GestureDetector(
        onTap: onTap,
        child: GlassWidget(
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Image.network(
                  iconUrl,
                  width: 24,
                  height: 24,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.public,
                          size: 24, color: Colors.white70),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                    Text(subtitle,
                        style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
