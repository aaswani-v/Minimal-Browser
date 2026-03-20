/// Data model for a to-do list item on the home screen.
///
/// Supports toggling completion state. Persisted via SharedPreferences as JSON.
class TodoItem {
  /// The task description.
  String task;

  /// Whether this task has been completed.
  bool isDone;

  TodoItem({required this.task, this.isDone = false});

  /// Serializes this to-do item to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'task': task,
        'isDone': isDone,
      };

  /// Deserializes a [TodoItem] from a JSON-compatible map.
  static TodoItem fromJson(Map<String, dynamic> json) => TodoItem(
        task: json['task'],
        isDone: json['isDone'],
      );
}
