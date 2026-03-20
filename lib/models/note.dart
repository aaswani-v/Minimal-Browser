/// Data model for a quick note saved on the home screen.
///
/// Notes are persisted via SharedPreferences as JSON.
class Note {
  /// The text content of the note.
  String content;

  /// When the note was last created or modified.
  final DateTime timestamp;

  Note({required this.content, required this.timestamp});

  /// Serializes this note to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'content': content,
        'timestamp': timestamp.toIso8601String(),
      };

  /// Deserializes a [Note] from a JSON-compatible map.
  static Note fromJson(Map<String, dynamic> json) => Note(
        content: json['content'],
        timestamp: DateTime.parse(json['timestamp']),
      );
}
