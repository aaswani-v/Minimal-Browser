/// Data model for a Quick AI tool shortcut (e.g. ChatGPT, Gemini, Claude).
///
/// Displayed in the Quick AI Access grid on the home screen and in the
/// search screen AI chooser dialog. Persisted via SharedPreferences as JSON.
class QuickAILink {
  /// Display name for the AI tool (e.g. "ChatGPT").
  final String name;

  /// Full URL of the AI tool.
  final String url;

  QuickAILink({required this.name, required this.url});

  /// Returns a Google favicon service URL for this tool's icon.
  String get iconUrl {
    final domain = Uri.parse(url).host;
    return 'https://www.google.com/s2/favicons?domain=$domain&sz=64';
  }

  /// Serializes this AI link to a JSON-compatible map.
  Map<String, dynamic> toJson() => {'name': name, 'url': url};

  /// Deserializes a [QuickAILink] from a JSON-compatible map.
  static QuickAILink fromJson(Map<String, dynamic> json) =>
      QuickAILink(name: json['name'], url: json['url']);
}
