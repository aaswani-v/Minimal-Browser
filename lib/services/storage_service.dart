/// Centralized data persistence layer using SharedPreferences.
///
/// Handles loading and saving of all user data: notes, todos, favourites,
/// AI links, browsing history, and preferences. All data is stored as
/// JSON-encoded strings under well-known key names.
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myapp/models/note.dart';
import 'package:myapp/models/todo_item.dart';
import 'package:myapp/models/favourite.dart';
import 'package:myapp/models/quick_ai_link.dart';
import 'package:myapp/models/history_item.dart';

/// SharedPreferences key constants — kept private to this file.
const String _kNotesKey = 'notes';
const String _kTodosKey = 'todos';
const String _kAILinksKey = 'quick_ai_links';
const String _kHistoryKey = 'browser_history';
const String _kFavouritesKey = 'browser_favourites';
const String _kMinimalistModeKey = 'minimalist_mode';

/// Provides static methods for loading and saving all persisted app data.
class StorageService {
  // ---------------------------------------------------------------------------
  // Loaders
  // ---------------------------------------------------------------------------

  /// Loads the saved notes list from disk, returning an empty list if none.
  static Future<List<Note>> loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kNotesKey) ?? '[]';
    return (jsonDecode(raw) as List).map((n) => Note.fromJson(n)).toList();
  }

  /// Loads the saved to-do items from disk, returning an empty list if none.
  static Future<List<TodoItem>> loadTodos() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kTodosKey) ?? '[]';
    return (jsonDecode(raw) as List).map((t) => TodoItem.fromJson(t)).toList();
  }

  /// Loads the saved favourites from disk, or returns `null` if nothing saved.
  /// (A `null` return means the caller should use default favourites.)
  static Future<List<Favourite>?> loadFavourites() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kFavouritesKey);
    if (raw == null) return null;
    return (jsonDecode(raw) as List).map((f) => Favourite.fromJson(f)).toList();
  }

  /// Loads the saved Quick AI links, or returns `null` if nothing saved.
  /// (A `null` return means the caller should use default AI links.)
  static Future<List<QuickAILink>?> loadQuickAILinks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kAILinksKey);
    if (raw == null) return null;
    return (jsonDecode(raw) as List)
        .map((l) => QuickAILink.fromJson(l))
        .toList();
  }

  /// Loads the browsing history from disk, returning an empty list if none.
  static Future<List<HistoryItem>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kHistoryKey) ?? '[]';
    return (jsonDecode(raw) as List)
        .map((h) => HistoryItem.fromJson(h))
        .toList();
  }

  /// Loads the user's minimalist mode preference.
  static Future<bool> loadMinimalistMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kMinimalistModeKey) ?? false;
  }

  // ---------------------------------------------------------------------------
  // Savers
  // ---------------------------------------------------------------------------

  /// Persists all user data in a single batch.
  ///
  /// Called after every state mutation to ensure data is never lost.
  static Future<void> saveAll({
    required List<Note> notes,
    required List<TodoItem> todos,
    required List<QuickAILink> quickAILinks,
    required List<HistoryItem> history,
    required List<Favourite> favourites,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kNotesKey, jsonEncode(notes.map((n) => n.toJson()).toList()));
    await prefs.setString(
        _kTodosKey, jsonEncode(todos.map((t) => t.toJson()).toList()));
    await prefs.setString(
        _kAILinksKey, jsonEncode(quickAILinks.map((l) => l.toJson()).toList()));
    await prefs.setString(
        _kHistoryKey, jsonEncode(history.map((h) => h.toJson()).toList()));
    await prefs.setString(_kFavouritesKey,
        jsonEncode(favourites.map((f) => f.toJson()).toList()));
  }

  /// Saves only the minimalist mode toggle (used independently of saveAll).
  static Future<void> saveMinimalistMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kMinimalistModeKey, value);
  }
}
