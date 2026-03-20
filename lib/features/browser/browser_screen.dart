/// BrowserScreen — the main stateful orchestrator of the app.
///
/// Manages:
/// - Tab creation, switching, and closing
/// - InAppWebView instances per tab
/// - Music playback detection and control (YouTube Music)
/// - Foreground service lifecycle for background audio
/// - Data loading/saving via [StorageService]
/// - Navigation (back button, URL loading, search)
/// - Scroll-hide behavior for the floating nav bar
///
/// All UI sub-components (home, search, history, nav bar) are composed
/// here via their respective widget imports.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:palette_generator/palette_generator.dart';

// --- Models ---
import 'package:myapp/models/browser_tab.dart';
import 'package:myapp/models/note.dart';
import 'package:myapp/models/todo_item.dart';
import 'package:myapp/models/favourite.dart';
import 'package:myapp/models/quick_ai_link.dart';
import 'package:myapp/models/history_item.dart';

// --- Core ---
import 'package:myapp/core/constants.dart';
import 'package:myapp/core/dialogs.dart';

// --- Services ---
import 'package:myapp/services/media_playback_service.dart';
import 'package:myapp/services/storage_service.dart';

// --- Shared Widgets ---
import 'package:myapp/widgets/floating_nav_bar.dart';

// --- Feature Screens ---
import 'package:myapp/features/home/home_screen_content.dart';
import 'package:myapp/features/search/search_screen.dart';
import 'package:myapp/features/history/history_screen.dart';

class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key});

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen>
    with WidgetsBindingObserver {
  // ---------------------------------------------------------------------------
  // State Fields
  // ---------------------------------------------------------------------------

  /// Whether the home screen is in minimalist (hidden widgets) mode.
  bool _isMinimalistMode = false;

  /// Full browsing history, ordered most-recent first.
  List<HistoryItem> _history = [];

  /// Whether the history overlay is currently visible.
  bool _isHistoryVisible = false;

  /// Map of tab IDs to their InAppWebView controllers.
  final Map<int, InAppWebViewController> _webViewControllers = {};

  /// All open browser tabs.
  final List<BrowserTab> _tabs = [];

  /// Index of the currently active tab.
  int _activeTabIndex = 0;

  /// Page loading progress (0.0 to 1.0).
  double _progress = 0;

  /// Currently playing song metadata.
  String _songTitle = 'Not Playing';
  String _songArtist = 'Open YouTube Music';
  String? _songThumbnailUrl;
  bool _isPlaying = false;

  /// Periodic timer that polls YouTube Music for track info.
  Timer? _musicUpdateTimer;

  /// Whether the floating nav bar is visible (hidden on scroll-down).
  bool _isNavBarVisible = true;

  /// Scroll controller for the home screen content.
  final ScrollController _homeScrollController = ScrollController();

  /// Last known Y scroll position of the WebView (for hide-on-scroll).
  double _lastWebViewScrollY = 0;

  /// GlobalKey for the nav bar.
  final GlobalKey _navBarKey = GlobalKey();

  /// Whether the search overlay is currently visible.
  bool _isSearchVisible = false;

  // --- Home Screen Data ---
  List<Note> _notes = [];
  List<TodoItem> _todos = [];

  /// User's saved favourites (defaults used if nothing persisted).
  List<Favourite> _favourites = [
    Favourite(title: 'YouTube', url: 'https://youtube.com'),
    Favourite(title: 'Reddit', url: 'https://reddit.com'),
    Favourite(title: 'Wikipedia', url: 'https://wikipedia.org'),
  ];

  /// User's saved AI tool shortcuts (defaults used if nothing persisted).
  List<QuickAILink> _quickAILinks = [
    QuickAILink(name: 'ChatGPT', url: 'https://chat.openai.com'),
    QuickAILink(name: 'Gemini', url: 'https://gemini.google.com'),
    QuickAILink(name: 'Claude', url: 'https://claude.ai'),
  ];

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize native media action listener (play/pause from notification).
    MediaPlaybackService.initializeActionListener(
      onAction: _handleNativeMediaAction,
    );

    _addTab(isFirstTab: true);
    _loadData();
    _homeScrollController.addListener(_handleHomeScroll);

    // Poll YouTube Music for track info every 2 seconds.
    _musicUpdateTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_tabs.any((tab) => tab.isYouTubeMusicTab)) {
        _updateMusicInfo();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopForegroundServiceIfRunning();
    _homeScrollController.removeListener(_handleHomeScroll);
    _homeScrollController.dispose();
    _musicUpdateTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      _handleAppPaused();
      return;
    }
    if (state == AppLifecycleState.resumed) {
      _handleAppResumed();
    }
  }

  // ---------------------------------------------------------------------------
  // Background Audio & Foreground Service
  // ---------------------------------------------------------------------------

  /// Checks if a URL belongs to a host allowed for background audio.
  bool _isAllowedBackgroundAudioUrl(String? url) {
    if (url == null || !url.startsWith('http')) return false;
    try {
      final host = Uri.parse(url).host.toLowerCase();
      return kBackgroundAudioAllowedHosts.contains(host);
    } catch (_) {
      return false;
    }
  }

  /// Whether the currently active tab is on a background-audio-allowed host.
  bool _activeTabAllowsBackgroundAudio() {
    return _isAllowedBackgroundAudioUrl(_activeTab.url);
  }

  /// Called when the app goes to the background.
  Future<void> _handleAppPaused() async {
    final controller = _activeWebViewController;
    if (controller == null) return;

    if (_activeTabAllowsBackgroundAudio()) {
      await _pushCurrentTrackToNativeNotification();
      await _startForegroundServiceIfNeeded();
    } else {
      await _stopForegroundServiceIfRunning();
      await controller.pauseTimers();
    }
  }

  /// Called when the app returns to the foreground.
  Future<void> _handleAppResumed() async {
    final controller = _activeWebViewController;
    if (controller != null) {
      await controller.resumeTimers();
    }
    await _syncForegroundServiceForCurrentUrl();
  }

  /// Starts the Android foreground service for background audio playback.
  Future<void> _startForegroundServiceIfNeeded() async {
    if (!Platform.isAndroid) return;
    await MediaPlaybackService.start(
      title: _songTitle,
      artist: _songArtist,
      artUrl: _songThumbnailUrl,
    );
    await MediaPlaybackService.setPlaying(isPlaying: _isPlaying);
  }

  /// Stops the foreground service if currently running.
  Future<void> _stopForegroundServiceIfRunning() async {
    if (!Platform.isAndroid) return;
    await MediaPlaybackService.stop();
  }

  /// Ensures the foreground service state matches the current tab.
  Future<void> _syncForegroundServiceForCurrentUrl() async {
    if (!Platform.isAndroid) return;
    if (_activeTabAllowsBackgroundAudio()) {
      await _pushCurrentTrackToNativeNotification();
      await _startForegroundServiceIfNeeded();
    } else {
      await _stopForegroundServiceIfRunning();
    }
  }

  /// Pushes current track metadata to the native notification.
  Future<void> _pushCurrentTrackToNativeNotification() async {
    if (!Platform.isAndroid) return;
    await MediaPlaybackService.updateMetadata(
      title: _songTitle,
      artist: _songArtist,
      artUrl: _songThumbnailUrl,
    );
    await MediaPlaybackService.setPlaying(isPlaying: _isPlaying);
  }

  /// Handles actions from the native media notification (play/pause/next/prev).
  void _handleNativeMediaAction(String action) {
    debugPrint('Native media action: $action');
    if (action == 'play_pause' || action == 'next' || action == 'prev') {
      _triggerMusicControlAction(action);
    }
  }

  /// Sends a media control command to the YouTube Music WebView.
  void _triggerMusicControlAction(String action) {
    final musicTab = _tabs.firstWhere(
      (t) => t.isYouTubeMusicTab,
      orElse: () => _activeTab,
    );
    final controller = _webViewControllers[musicTab.id];
    if (controller == null) return;

    switch (action) {
      case 'prev':
        controller.evaluateJavascript(
          source: "document.querySelector('.previous-button')?.click()",
        );
        break;
      case 'next':
        controller.evaluateJavascript(
          source: "document.querySelector('.next-button')?.click()",
        );
        break;
      case 'play_pause':
        controller.evaluateJavascript(
          source: "document.getElementById('play-pause-button')?.click()",
        );
        break;
    }
    Future.delayed(const Duration(milliseconds: 500), _updateMusicInfo);
  }

  // ---------------------------------------------------------------------------
  // Data Persistence
  // ---------------------------------------------------------------------------

  /// Loads all persisted data from SharedPreferences via [StorageService].
  Future<void> _loadData() async {
    final notes = await StorageService.loadNotes();
    final todos = await StorageService.loadTodos();
    final minimalist = await StorageService.loadMinimalistMode();
    final aiLinks = await StorageService.loadQuickAILinks();
    final history = await StorageService.loadHistory();
    final favourites = await StorageService.loadFavourites();

    if (!mounted) return;
    setState(() {
      _notes = notes;
      _todos = todos;
      _isMinimalistMode = minimalist;
      if (aiLinks != null) _quickAILinks = aiLinks;
      _history = history;
      if (favourites != null) _favourites = favourites;
    });
  }

  /// Saves all user data to SharedPreferences.
  Future<void> _saveData() async {
    await StorageService.saveAll(
      notes: _notes,
      todos: _todos,
      quickAILinks: _quickAILinks,
      history: _history,
      favourites: _favourites,
    );
  }

  // ---------------------------------------------------------------------------
  // Data Mutation Helpers
  // ---------------------------------------------------------------------------

  /// Adds or updates the single quick note.
  void _addNote(String content) {
    setState(() {
      if (_notes.isEmpty) {
        _notes.add(Note(content: content, timestamp: DateTime.now()));
      } else {
        _notes[0] = Note(content: content, timestamp: DateTime.now());
      }
    });
    _saveData();
  }

  /// Adds a new to-do item to the top of the list.
  void _addTodo(String task) {
    if (task.isNotEmpty) {
      setState(() => _todos.insert(0, TodoItem(task: task)));
      _saveData();
    }
  }

  /// Toggles the done/undone state of a to-do at the given index.
  void _toggleTodo(int index) {
    setState(() => _todos[index].isDone = !_todos[index].isDone);
    _saveData();
  }

  /// Adds a new favourite website.
  void _addFavourite(String title, String url) {
    if (title.isNotEmpty && url.isNotEmpty) {
      String finalUrl = url.startsWith('http') ? url : 'https://$url';
      setState(
          () => _favourites.add(Favourite(title: title, url: finalUrl)));
      _saveData();
    }
  }

  /// Removes a favourite from the list.
  void _removeFavourite(Favourite favourite) {
    setState(() => _favourites.remove(favourite));
    _saveData();
  }

  /// Adds a new AI tool shortcut.
  void _addAILink(String name, String url) {
    if (name.isNotEmpty && url.isNotEmpty) {
      String finalUrl = url.startsWith('http') ? url : 'https://$url';
      setState(() =>
          _quickAILinks.add(QuickAILink(name: name, url: finalUrl)));
      _saveData();
    }
  }

  /// Adds a history entry for a visited URL.
  void _addHistoryItem(String title, String url) {
    if (url.startsWith('http')) {
      setState(() {
        // Remove duplicate if exists (most recent visit takes precedence).
        _history.removeWhere((h) => h.url == url);
        _history.insert(
            0,
            HistoryItem(
                title: title, url: url, visitedAt: DateTime.now()));
        // Cap history at 500 entries.
        if (_history.length > 500) {
          _history = _history.sublist(0, 500);
        }
      });
      _saveData();
    }
  }

  /// Removes a single history item by index.
  void _removeHistoryItem(int index) {
    setState(() => _history.removeAt(index));
    _saveData();
  }

  /// Clears the entire browsing history.
  void _clearHistory() {
    setState(() => _history.clear());
    _saveData();
  }

  // ---------------------------------------------------------------------------
  // Scroll & Navigation
  // ---------------------------------------------------------------------------

  /// Hides/shows the nav bar based on home screen scroll direction.
  void _handleHomeScroll() {
    if (_homeScrollController.position.userScrollDirection ==
        ScrollDirection.reverse) {
      if (_isNavBarVisible) setState(() => _isNavBarVisible = false);
    }
    if (_homeScrollController.position.userScrollDirection ==
        ScrollDirection.forward) {
      if (!_isNavBarVisible) setState(() => _isNavBarVisible = true);
    }
  }

  /// Convenience getter for the currently active tab.
  BrowserTab get _activeTab => _tabs[_activeTabIndex];

  /// Whether the active tab has a real web page loaded (not about:blank).
  bool get _showWebContent => _activeTab.url.startsWith('http');

  /// The WebView controller for the currently active tab.
  InAppWebViewController? get _activeWebViewController =>
      _webViewControllers[_activeTab.id];

  /// Creates a new browser tab and optionally switches to it.
  void _addTab({
    bool isFirstTab = false,
    String url = 'about:blank',
    String title = 'New Tab',
    bool isMusicTab = false,
  }) {
    setState(() {
      final newTab = BrowserTab(
          id: DateTime.now().millisecondsSinceEpoch,
          url: url,
          title: title);
      newTab.isYouTubeMusicTab = isMusicTab;
      _tabs.add(newTab);
      if (!isFirstTab) {
        _setActiveTab(_tabs.length - 1);
      }
    });
  }

  /// Switches to the tab at the given index.
  void _setActiveTab(int index) {
    if (index >= 0 && index < _tabs.length) {
      setState(() {
        _activeTabIndex = index;
      });
      _syncForegroundServiceForCurrentUrl();
    }
  }

  /// Closes the tab at the given index.
  void _closeTab(int index) {
    _webViewControllers.remove(_tabs[index].id);

    // If it's the last tab, reset it instead of removing.
    if (_tabs.length == 1) {
      setState(() {
        _tabs[0] = BrowserTab(id: DateTime.now().millisecondsSinceEpoch);
        _webViewControllers.clear();
      });
      _setActiveTab(0);
      return;
    }

    setState(() {
      _tabs.removeAt(index);
      if (_activeTabIndex >= index && _activeTabIndex > 0) {
        _activeTabIndex--;
      }
      _setActiveTab(_activeTabIndex);
    });
  }

  /// Loads a URL in the current tab or creates a new one if on the home screen.
  void _loadUrl(String url) {
    if (_isSearchVisible) {
      setState(() => _isSearchVisible = false);
    }

    // If we're on the home screen, open a new tab.
    if (!_showWebContent) {
      _addTab(url: url, title: _getHostname(url));
      return;
    }

    // Otherwise, navigate in the current tab.
    if (_activeWebViewController != null) {
      _activeWebViewController!
          .loadUrl(urlRequest: URLRequest(url: WebUri(url)));
      setState(() {
        _activeTab.url = url;
        _activeTab.title = _getHostname(url);
      });
    }
  }

  /// Extracts the hostname from a URL, stripping "www.".
  String _getHostname(String url) {
    try {
      return Uri.parse(url).host.replaceAll('www.', '');
    } catch (_) {
      return 'Loading...';
    }
  }

  /// Handles the Android back button behavior.
  Future<bool> _onWillPop() async {
    // Dismiss search overlay first.
    if (_isSearchVisible) {
      setState(() => _isSearchVisible = false);
      return false;
    }
    // Go back in WebView history if possible.
    if (_activeWebViewController != null &&
        await _activeWebViewController!.canGoBack()) {
      _activeWebViewController!.goBack();
      return false;
    }
    // If on a web page, go back to home screen.
    if (!_showWebContent) {
      return true;
    } else {
      setState(() {
        _activeTab.url = 'about:blank';
        _activeTab.title = 'New Tab';
        _activeTab.favicon = null;
        _activeTab.dominantColor = null;
      });
      _setActiveTab(_activeTabIndex);
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Music Info Polling
  // ---------------------------------------------------------------------------

  /// Polls the YouTube Music WebView for current track metadata.
  void _updateMusicInfo() async {
    BrowserTab? musicTab;
    try {
      musicTab = _tabs.firstWhere((t) => t.isYouTubeMusicTab);
    } catch (e) {
      return; // No music tab exists
    }

    final musicWebViewController = _webViewControllers[musicTab.id];
    if (musicWebViewController == null || !mounted) return;

    // Method 1: MediaSession API (Primary)
    const getMediaInfoJs = """
      (function() {
          if (!navigator.mediaSession || !navigator.mediaSession.metadata) { return null; }
          const metadata = navigator.mediaSession.metadata;
          const artwork = metadata.artwork;
          const largestArtwork = (artwork && artwork.length > 0)
              ? artwork.reduce((a, b) => (parseInt(a.sizes.split('x')[0]) > parseInt(b.sizes.split('x')[0])) ? a : b)
              : null;
          return JSON.stringify({
              title: metadata.title,
              artist: metadata.artist,
              thumbnailUrl: largestArtwork ? largestArtwork.src : null
          });
      })();
    """;

    final mediaInfoJson =
        await musicWebViewController.evaluateJavascript(
            source: getMediaInfoJs);
    final playButtonAriaLabel =
        await musicWebViewController.evaluateJavascript(
            source:
                "document.getElementById('play-pause-button')?.getAttribute('aria-label')");

    if (mediaInfoJson is String) {
      final mediaInfo = jsonDecode(mediaInfoJson);
      final title = mediaInfo['title'];
      if (title != null && title.isNotEmpty) {
        if (mounted) {
          setState(() {
            _songTitle = title;
            _songArtist = mediaInfo['artist'] ?? 'Artist Name';
            _songThumbnailUrl = mediaInfo['thumbnailUrl'];
            _isPlaying = playButtonAriaLabel == 'Pause';
          });
          unawaited(_pushCurrentTrackToNativeNotification());
        }
        return; // Success via MediaSession API
      }
    }

    // Method 2: Direct DOM Query (Fallback)
    const getTitleJs =
        "document.querySelector('ytmusic-player-bar .title.yt-formatted-string')?.innerText";
    const getArtistJs =
        "document.querySelector('ytmusic-player-bar .byline.yt-formatted-string')?.innerText.split('•')[0].trim()";
    const getThumbnailJs =
        "document.querySelector('ytmusic-player-bar #song-image img')?.src";

    final titleResult =
        await musicWebViewController.evaluateJavascript(
            source: getTitleJs);
    final artistResult =
        await musicWebViewController.evaluateJavascript(
            source: getArtistJs);
    final thumbnailResult =
        await musicWebViewController.evaluateJavascript(
            source: getThumbnailJs);

    final String? title =
        (titleResult is String && titleResult.isNotEmpty)
            ? titleResult
            : null;
    final String? artist =
        (artistResult is String && artistResult.isNotEmpty)
            ? artistResult
            : null;
    final String? thumbnailUrl =
        (thumbnailResult is String && thumbnailResult.isNotEmpty)
            ? thumbnailResult
            : null;

    if (mounted) {
      if (title != null) {
        setState(() {
          _songTitle = title;
          _songArtist = artist ?? 'Artist Name';
          _songThumbnailUrl = thumbnailUrl;
          _isPlaying = playButtonAriaLabel == 'Pause';
        });
        unawaited(_pushCurrentTrackToNativeNotification());
      } else {
        setState(() {
          _songTitle = 'Not Playing';
          _songArtist = 'Open YouTube Music';
          _songThumbnailUrl = null;
          _isPlaying = false;
        });
        unawaited(_pushCurrentTrackToNativeNotification());
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Search Handling
  // ---------------------------------------------------------------------------

  /// Resolves a search query into a URL and navigates to it.
  void _handleSearch(String query) {
    if (query.trim().isEmpty) return;
    String url;
    String cleanQuery = query.trim();
    if (cleanQuery.contains('.') && !cleanQuery.contains(' ')) {
      url = 'https://$cleanQuery';
    } else {
      url =
          'https://www.google.com/search?q=${Uri.encodeComponent(cleanQuery)}';
    }
    _loadUrl(url);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        if (await _onWillPop()) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              // --- Background gradient (only on home screen) ---
              if (!_showWebContent)
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFB15656),
                        Color(0xFF4B2424),
                      ],
                      stops: [0.17, 0.68],
                    ),
                  ),
                ),

              // --- Main content area ---
              AnimatedPadding(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                padding: EdgeInsets.zero,
                child: Stack(
                  children: [
                    // WebView stack (one per tab, only active tab visible)
                    Stack(
                      children: _tabs.asMap().entries.map((entry) {
                        int index = entry.key;
                        BrowserTab tab = entry.value;
                        return Offstage(
                          offstage:
                              index != _activeTabIndex || !_showWebContent,
                          child: InAppWebView(
                            key: tab.webViewKey,
                            initialSettings: InAppWebViewSettings(
                              userAgent: kDesktopChromeUserAgent,
                              useHybridComposition: false,
                              mediaPlaybackRequiresUserGesture: false,
                              allowsInlineMediaPlayback: true,
                            ),
                            onWebViewCreated: (controller) {
                              _webViewControllers[tab.id] = controller;
                              if (tab.url.startsWith('http')) {
                                controller.loadUrl(
                                    urlRequest: URLRequest(
                                        url: WebUri(tab.url)));
                              }
                            },
                            onLoadStop: (controller, url) async {
                              if (url != null &&
                                  url.toString().startsWith('http')) {
                                List<Favicon> favicons =
                                    await controller.getFavicons();
                                String? title =
                                    await controller.getTitle();
                                Color? dominantColor;

                                if (favicons.isNotEmpty) {
                                  tab.favicon = favicons.first.url;
                                  try {
                                    final PaletteGenerator palette =
                                        await PaletteGenerator
                                            .fromImageProvider(
                                      NetworkImage(
                                          tab.favicon.toString()),
                                      size: const Size(32, 32),
                                    );
                                    dominantColor =
                                        palette.dominantColor?.color;
                                  } catch (e) {
                                    /* Could not generate palette */
                                  }
                                }

                                if (mounted) {
                                  setState(() {
                                    if (index == _activeTabIndex) {
                                      _progress = 0.0;
                                    }
                                    tab.url = url.toString();
                                    tab.title = title ??
                                        _getHostname(url.toString());
                                    tab.dominantColor = dominantColor;
                                    if (url.host.contains(
                                        'music.youtube.com')) {
                                      tab.isYouTubeMusicTab = true;
                                    }
                                  });
                                  // Track in history
                                  _addHistoryItem(
                                    title ??
                                        _getHostname(url.toString()),
                                    url.toString(),
                                  );
                                  if (tab.isYouTubeMusicTab) {
                                    Future.delayed(
                                        const Duration(seconds: 1),
                                        _updateMusicInfo);
                                  }
                                }
                              }
                              _syncForegroundServiceForCurrentUrl();
                            },
                            onLoadStart: (controller, url) {
                              if (mounted) {
                                setState(() {
                                  if (url != null) {
                                    tab.url = url.toString();
                                  }
                                  tab.title = 'Loading...';
                                  tab.favicon = null;
                                  tab.dominantColor = null;
                                  if (index == _activeTabIndex) {
                                    _progress = 0.0;
                                  }
                                });
                              }
                              _syncForegroundServiceForCurrentUrl();
                            },
                            onProgressChanged: (controller, progress) {
                              if (mounted) {
                                setState(() {
                                  if (index == _activeTabIndex) {
                                    _progress = progress / 100.0;
                                  }
                                });
                              }
                            },
                            onScrollChanged: (controller, x, y) {
                              if (y > _lastWebViewScrollY && y > 50) {
                                if (_isNavBarVisible) {
                                  setState(
                                      () => _isNavBarVisible = false);
                                }
                              } else if (y < _lastWebViewScrollY) {
                                if (!_isNavBarVisible) {
                                  setState(
                                      () => _isNavBarVisible = true);
                                }
                              }
                              _lastWebViewScrollY = y.toDouble();
                            },
                            onUpdateVisitedHistory:
                                (controller, url, _) {
                              if (url != null) {
                                tab.url = url.toString();
                              }
                              _syncForegroundServiceForCurrentUrl();
                            },
                          ),
                        );
                      }).toList(),
                    ),

                    // Home screen (shown when no web page is loaded)
                    if (!_showWebContent)
                      HomeScreenContent(
                        scrollController: _homeScrollController,
                        notes: _notes,
                        onNoteChanged: (newContent) =>
                            _addNote(newContent),
                        todos: _todos,
                        favourites: _favourites,
                        quickAILinks: _quickAILinks,
                        onAddTodoTap: () =>
                            showAddTodoDialog(context, _addTodo),
                        onToggleTodo: _toggleTodo,
                        onLoadUrl: _loadUrl,
                        onAddAILink: () =>
                            showAddAIDialog(context, _addAILink),
                        onAddFavouriteTap: () =>
                            showAddFavouriteDialog(
                                context, _addFavourite),
                        onRemoveFavourite: _removeFavourite,
                        isMinimalistMode: _isMinimalistMode,
                        onToggleMinimalistMode: () async {
                          setState(() =>
                              _isMinimalistMode = !_isMinimalistMode);
                          await StorageService.saveMinimalistMode(
                              _isMinimalistMode);
                        },
                        onHistoryTap: () {
                          setState(() => _isHistoryVisible = true);
                        },
                        onOpenMusic: () {
                          _addTab(
                              url: 'https://music.youtube.com',
                              title: 'YouTube Music',
                              isMusicTab: true);
                        },
                        songTitle: _songTitle,
                        songArtist: _songArtist,
                        songThumbnailUrl: _songThumbnailUrl,
                        isPlaying: _isPlaying,
                        onMusicPrevious: () {
                          final musicTab = _tabs.firstWhere(
                              (t) => t.isYouTubeMusicTab,
                              orElse: () => _activeTab);
                          _webViewControllers[musicTab.id]
                              ?.evaluateJavascript(
                                  source:
                                      "document.querySelector('.previous-button').click()");
                          Future.delayed(
                              const Duration(milliseconds: 500),
                              _updateMusicInfo);
                        },
                        onMusicPlayPause: () {
                          final musicTab = _tabs.firstWhere(
                              (t) => t.isYouTubeMusicTab,
                              orElse: () => _activeTab);
                          _webViewControllers[musicTab.id]
                              ?.evaluateJavascript(
                                  source:
                                      "document.getElementById('play-pause-button').click()");
                          Future.delayed(
                              const Duration(milliseconds: 500),
                              _updateMusicInfo);
                        },
                        onMusicNext: () {
                          final musicTab = _tabs.firstWhere(
                              (t) => t.isYouTubeMusicTab,
                              orElse: () => _activeTab);
                          _webViewControllers[musicTab.id]
                              ?.evaluateJavascript(
                                  source:
                                      "document.querySelector('.next-button').click()");
                          Future.delayed(
                              const Duration(milliseconds: 500),
                              _updateMusicInfo);
                        },
                      ),
                  ],
                ),
              ),

              // --- Loading progress bar ---
              if (_progress > 0 && _progress < 1)
                Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(
                      value: _progress,
                      backgroundColor: Colors.transparent,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white),
                      minHeight: 2,
                    )),

              // --- Floating nav bar ---
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  transform: Matrix4.translationValues(
                      0, _isNavBarVisible ? 0 : 200, 0),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: FloatingNavBar(
                      key: _navBarKey,
                      tabs: _tabs,
                      activeTabIndex: _activeTabIndex,
                      adaptiveColor: _activeTab.dominantColor,
                      onTabSelected: _setActiveTab,
                      onCloseTab: _closeTab,
                      onNewTab: () => _addTab(),
                      onSearchTap: () =>
                          setState(() => _isSearchVisible = true),
                    ),
                  ),
                ),
              ),

              // --- Search overlay ---
              if (_isSearchVisible)
                SearchScreen(
                  onClose: () =>
                      setState(() => _isSearchVisible = false),
                  onSearch: _handleSearch,
                  quickAILinks: _quickAILinks,
                  favourites: _favourites,
                  onLoadUrl: _loadUrl,
                  onShowChatAIDialog: () => showChatAIDialog(
                      context, _quickAILinks, _loadUrl),
                  onShare: () {
                    Clipboard.setData(
                        ClipboardData(text: _activeTab.url));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('Link copied to clipboard!')),
                    );
                  },
                  onQuickNote: () => showQuickNoteDialog(
                      context, _notes, _addNote),
                ),

              // --- History overlay ---
              if (_isHistoryVisible)
                HistoryScreen(
                  history: _history,
                  onClose: () =>
                      setState(() => _isHistoryVisible = false),
                  onLoadUrl: (url) {
                    setState(() => _isHistoryVisible = false);
                    _loadUrl(url);
                  },
                  onRemoveItem: _removeHistoryItem,
                  onClearAll: _clearHistory,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
