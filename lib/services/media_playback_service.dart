import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

typedef MediaActionCallback = void Function(String action);

class MediaPlaybackService {
  static const MethodChannel _channel =
      MethodChannel('com.example.nothing_browser/media');

  static MediaActionCallback? _mediaActionCallback;
  static bool _handlerInitialized = false;

  static void initializeActionListener({MediaActionCallback? onAction}) {
    _mediaActionCallback = onAction;

    if (_handlerInitialized) {
      return;
    }

    _channel.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'onMediaAction') {
        final raw = call.arguments;
        if (raw is Map) {
          final action = raw['action']?.toString();
          if (action != null) {
            _mediaActionCallback?.call(action);
          }
        }
      }
    });

    _handlerInitialized = true;
  }

  static Future<bool> start({
    String title = 'Minimal Browser',
    String artist = 'Playing',
    String? artUrl,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('startService', {
        'title': title,
        'artist': artist,
        'artUrl': artUrl,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('MediaPlaybackService.start error: $e');
      return false;
    }
  }

  static Future<bool> stop() async {
    try {
      final result = await _channel.invokeMethod<bool>('stopService');
      return result ?? false;
    } catch (e) {
      debugPrint('MediaPlaybackService.stop error: $e');
      return false;
    }
  }

  static Future<bool> updateMetadata({
    required String title,
    required String artist,
    String? artUrl,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('updateMetadata', {
        'title': title,
        'artist': artist,
        'artUrl': artUrl,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('MediaPlaybackService.updateMetadata error: $e');
      return false;
    }
  }

  static Future<bool> setPlaying({required bool isPlaying}) async {
    try {
      final result = await _channel.invokeMethod<bool>('setPlaying', {
        'isPlaying': isPlaying,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('MediaPlaybackService.setPlaying error: $e');
      return false;
    }
  }
}
