/// Data model representing a single browser tab.
///
/// Each tab maintains its own URL, title, favicon, extracted dominant color
/// (used for adaptive UI theming), and a unique [GlobalKey] for the WebView.
import 'package:flutter/material.dart';

class BrowserTab {
  /// Unique identifier for this tab, generated from millisecondsSinceEpoch.
  final int id;

  /// The current URL loaded in this tab.
  String url;

  /// The display title (usually the page title or hostname).
  String title;

  /// Favicon URI extracted from the loaded page.
  Uri? favicon;

  /// Dominant color extracted from the favicon via palette_generator.
  /// Used to tint the nav bar and glass widgets adaptively.
  Color? dominantColor;

  /// Whether this tab is playing YouTube Music content.
  bool isYouTubeMusicTab = false;

  /// Unique key for the InAppWebView widget belonging to this tab.
  final GlobalKey webViewKey = GlobalKey();

  BrowserTab({
    required this.id,
    this.url = 'about:blank',
    this.title = 'New Tab',
  });
}
