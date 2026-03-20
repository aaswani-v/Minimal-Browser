/// Data model for a favourite/bookmarked website.
///
/// Displayed as circular icons in the Favourites grid on the home screen.
/// Persisted via SharedPreferences as JSON.
class Favourite {
  /// Display name for the favourite (e.g. "YouTube").
  final String title;

  /// Full URL of the favourite website.
  final String url;

  Favourite({required this.title, required this.url});

  /// Returns a Google favicon service URL for this site's icon.
  String get iconUrl {
    try {
      final domain = Uri.parse(url).host;
      return 'https://www.google.com/s2/favicons?domain=$domain&sz=128';
    } catch (_) {
      return '';
    }
  }

  /// Serializes this favourite to a JSON-compatible map.
  Map<String, dynamic> toJson() => {'title': title, 'url': url};

  /// Deserializes a [Favourite] from a JSON-compatible map.
  static Favourite fromJson(Map<String, dynamic> json) =>
      Favourite(title: json['title'], url: json['url']);
}
