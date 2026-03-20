/// Data model for a browser history entry.
///
/// Tracks visited pages with their title, URL, and visit timestamp.
/// Displayed grouped by date in the History screen.
/// Persisted via SharedPreferences as JSON.
class HistoryItem {
  /// Page title at time of visit.
  final String title;

  /// Full URL that was visited.
  final String url;

  /// Timestamp when the page was visited.
  final DateTime visitedAt;

  HistoryItem({
    required this.title,
    required this.url,
    required this.visitedAt,
  });

  /// Returns a Google favicon service URL for this site's icon.
  String get iconUrl {
    try {
      final domain = Uri.parse(url).host;
      return 'https://www.google.com/s2/favicons?domain=$domain&sz=64';
    } catch (_) {
      return '';
    }
  }

  /// Serializes this history item to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'title': title,
        'url': url,
        'visitedAt': visitedAt.toIso8601String(),
      };

  /// Deserializes a [HistoryItem] from a JSON-compatible map.
  static HistoryItem fromJson(Map<String, dynamic> json) => HistoryItem(
        title: json['title'],
        url: json['url'],
        visitedAt: DateTime.parse(json['visitedAt']),
      );
}
