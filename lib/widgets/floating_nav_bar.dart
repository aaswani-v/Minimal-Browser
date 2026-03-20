/// Floating bottom navigation bar with tab strip and URL/search bar.
///
/// Displays a horizontal scrollable list of open tabs above a search/URL
/// bar. The bar adapts its tint to the active tab's dominant color via
/// [GlassWidget]. Tabs can be switched with a tap and closed with a
/// double-tap.
import 'package:flutter/material.dart';
import 'package:myapp/models/browser_tab.dart';
import 'package:myapp/widgets/glass_widget.dart';

class FloatingNavBar extends StatelessWidget {
  /// All currently open browser tabs.
  final List<BrowserTab> tabs;

  /// Index of the currently active/visible tab.
  final int activeTabIndex;

  /// Dominant color from the active tab's favicon, used to tint the bar.
  final Color? adaptiveColor;

  /// Called when the user taps a tab to switch to it.
  final ValueChanged<int> onTabSelected;

  /// Called when the user double-taps a tab to close it.
  final ValueChanged<int> onCloseTab;

  /// Called when the user taps the "+" button to create a new tab.
  final VoidCallback onNewTab;

  /// Called when the user taps the search/URL bar.
  final VoidCallback onSearchTap;

  const FloatingNavBar({
    super.key,
    required this.tabs,
    required this.activeTabIndex,
    this.adaptiveColor,
    required this.onTabSelected,
    required this.onCloseTab,
    required this.onNewTab,
    required this.onSearchTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeTab = tabs[activeTabIndex];

    // Show hostname when a web page is loaded, otherwise show placeholder.
    String displayText = 'Search or type URL';
    if (activeTab.url.startsWith('http')) {
      try {
        displayText = Uri.parse(activeTab.url).host;
      } catch (e) {
        displayText = activeTab.title;
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // --- Tab strip ---
        SizedBox(
          height: 38,
          child: Row(
            children: [
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: tabs.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: _buildTab(
                        context,
                        tabs[index],
                        isActive: index == activeTabIndex,
                        onTap: () => onTabSelected(index),
                        onClose: () => onCloseTab(index),
                        adaptiveColor: adaptiveColor,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              // New tab button
              GestureDetector(
                onTap: onNewTab,
                child: GlassWidget(
                  borderRadius: BorderRadius.circular(8.0),
                  adaptiveColor: adaptiveColor,
                  useFigmaNavStyle: true,
                  child: Container(
                    width: 48,
                    alignment: Alignment.center,
                    child: const Icon(Icons.add, color: Colors.white70),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // --- Search / URL bar ---
        GestureDetector(
          onTap: onSearchTap,
          child: GlassWidget(
            borderRadius: BorderRadius.circular(12.0),
            adaptiveColor: adaptiveColor,
            useFigmaNavStyle: true,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Colors.white70, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      displayText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w400),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.menu, color: Colors.white70, size: 20),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Builds a single tab chip in the tab strip.
  Widget _buildTab(
    BuildContext context,
    BrowserTab tab, {
    required bool isActive,
    required VoidCallback onTap,
    required VoidCallback onClose,
    Color? adaptiveColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onClose, // Double-press to close tab
      child: GlassWidget(
        borderRadius: BorderRadius.circular(8.0),
        adaptiveColor: adaptiveColor,
        useFigmaNavStyle: true,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          decoration: BoxDecoration(
            color: isActive
                ? Colors.white.withOpacity(0.1)
                : Colors.transparent,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Tab favicon or fallback globe icon
              if (tab.favicon != null) ...[
                Image.network(
                  tab.favicon.toString(),
                  width: 18,
                  height: 18,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.public,
                          size: 18, color: Colors.white70),
                ),
                const SizedBox(width: 8),
              ] else ...[
                const Icon(Icons.public, size: 18, color: Colors.white70),
                const SizedBox(width: 8),
              ],
              // Tab title
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Text(
                    tab.title,
                    style: TextStyle(
                        color: isActive ? Colors.white : Colors.white70,
                        fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
