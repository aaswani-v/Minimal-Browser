import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

// --- Data Models ---

class BrowserTab {
  final int id;
  String url;
  String title;
  Uri? favicon;
  Color? dominantColor;
  bool isYouTubeMusicTab = false;
  final GlobalKey webViewKey = GlobalKey();

  BrowserTab(
      {required this.id, this.url = "about:blank", this.title = "New Tab"});
}

class Note {
  String content;
  final DateTime timestamp;
  Note({required this.content, required this.timestamp});
  Map<String, dynamic> toJson() =>
      {'content': content, 'timestamp': timestamp.toIso8601String()};
  static Note fromJson(Map<String, dynamic> json) => Note(
      content: json['content'], timestamp: DateTime.parse(json['timestamp']));
}

class TodoItem {
  String task;
  bool isDone;
  print(task) {
    // TODO: implement print
    throw UnimplementedError();
  }

  TodoItem({required this.task, this.isDone = false});
  Map<String, dynamic> toJson() => {'task': task, 'isDone': isDone};
  static TodoItem fromJson(Map<String, dynamic> json) =>
      TodoItem(task: json['task'], isDone: json['isDone']);
}

class Favourite {
  final String title;
  final String url;
  Favourite({required this.title, required this.url});

  String get iconUrl {
    final domain = Uri.parse(url).host;
    return 'https://www.google.com/s2/favicons?domain=$domain&sz=128';
  }
}

// MODIFIED: Added toJson and fromJson for saving custom AI links
class QuickAILink {
  final String name;
  final String url;
  QuickAILink({required this.name, required this.url});

  String get iconUrl {
    final domain = Uri.parse(url).host;
    return 'https://www.google.com/s2/favicons?domain=$domain&sz=64';
  }

  Map<String, dynamic> toJson() => {'name': name, 'url': url};
  static QuickAILink fromJson(Map<String, dynamic> json) =>
      QuickAILink(name: json['name'], url: json['url']);
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nothing Browser',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        fontFamily: 'Inter',
      ),
      home: const BrowserScreen(),
    );
  }
}

class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key});

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  // --- Minimalist Mode ---
  bool _isMinimalistMode = false;
  final Map<int, InAppWebViewController> _webViewControllers = {};
  List<BrowserTab> _tabs = [];
  int _activeTabIndex = 0;
  double _progress = 0;

  String _songTitle = "Not Playing";
  String _songArtist = "Open YouTube Music";
  String? _songThumbnailUrl;
  bool _isPlaying = false;
  Timer? _musicUpdateTimer;

  bool _isNavBarVisible = true;
  final ScrollController _homeScrollController = ScrollController();
  double _lastWebViewScrollY = 0;

  final GlobalKey _navBarKey = GlobalKey();
  double _navBarHeight = 0;

  // --- Search Screen State ---
  bool _isSearchVisible = false;

  // --- Home Screen Data ---
  List<Note> _notes = [];
  List<TodoItem> _todos = [];
  final List<Favourite> _favourites = [
    Favourite(title: "YouTube", url: "https://youtube.com"),
    Favourite(title: "Reddit", url: "https://reddit.com"),
    Favourite(title: "Wikipedia", url: "https://wikipedia.org"),
  ];
  // MODIFIED: This list will now be loaded from memory, with these as defaults.
  List<QuickAILink> _quickAILinks = [
    QuickAILink(name: "ChatGPT", url: "https://chat.openai.com"),
    QuickAILink(name: "Gemini", url: "https://gemini.google.com"),
    QuickAILink(name: "Claude", url: "https://claude.ai"),
  ];

  @override
  void initState() {
    super.initState();
    _addTab(isFirstTab: true);
    _loadData();
    _homeScrollController.addListener(_handleHomeScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final RenderBox? renderBox =
          _navBarKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        setState(() {
          _navBarHeight = renderBox.size.height;
        });
      }
    });

    _musicUpdateTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_tabs.any((tab) => tab.isYouTubeMusicTab)) {
        _updateMusicInfo();
      }
    });
  }

  @override
  void dispose() {
    _homeScrollController.removeListener(_handleHomeScroll);
    _homeScrollController.dispose();
    _musicUpdateTimer?.cancel();
    super.dispose();
  }

  // --- Data Persistence ---
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      final notesString = prefs.getString('notes') ?? '[]';
      _notes = (jsonDecode(notesString) as List)
          .map((n) => Note.fromJson(n))
          .toList();

      final todosString = prefs.getString('todos') ?? '[]';
      _todos = (jsonDecode(todosString) as List)
          .map((t) => TodoItem.fromJson(t))
          .toList();

      // Load minimalist mode preference
      _isMinimalistMode = prefs.getBool('minimalist_mode') ?? false;

      // MODIFIED: Load custom AI links or use defaults if none are saved.
      final aiLinksString = prefs.getString('quick_ai_links');
      if (aiLinksString != null) {
        _quickAILinks = (jsonDecode(aiLinksString) as List)
            .map((l) => QuickAILink.fromJson(l))
            .toList();
      }
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'notes', jsonEncode(_notes.map((n) => n.toJson()).toList()));
    await prefs.setString(
        'todos', jsonEncode(_todos.map((t) => t.toJson()).toList()));
    // MODIFIED: Save custom AI links
    await prefs.setString('quick_ai_links',
        jsonEncode(_quickAILinks.map((l) => l.toJson()).toList()));
  }

  void _addNote(String content) {
    setState(() {
      if (_notes.isEmpty) {
        _notes.add(Note(content: content, timestamp: DateTime.now()));
      } else {
        _notes[0].content = content;
        _notes[0] = Note(content: content, timestamp: DateTime.now());
      }
    });
    _saveData();
  }

  void _addTodo(String task) {
    if (task.isNotEmpty) {
      setState(() => _todos.insert(0, TodoItem(task: task)));
      _saveData();
    }
  }

  void _toggleTodo(int index) {
    setState(() => _todos[index].isDone = !_todos[index].isDone);
    _saveData();
  }

  // ADDED: Method to add a new AI link
  void _addAILink(String name, String url) {
    if (name.isNotEmpty && url.isNotEmpty) {
      // Basic URL validation
      String finalUrl = url.startsWith('http') ? url : 'https://$url';
      setState(() => _quickAILinks.add(QuickAILink(name: name, url: finalUrl)));
      _saveData();
    }
  }

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

  BrowserTab get _activeTab => _tabs[_activeTabIndex];
  bool get _showWebContent => _activeTab.url.startsWith("http");
  InAppWebViewController? get _activeWebViewController =>
      _webViewControllers[_activeTab.id];

  void _addTab(
      {bool isFirstTab = false,
      String url = "about:blank",
      String title = "New Tab",
      bool isMusicTab = false}) {
    setState(() {
      final newTab = BrowserTab(
          id: DateTime.now().millisecondsSinceEpoch, url: url, title: title);
      newTab.isYouTubeMusicTab = isMusicTab;
      _tabs.add(newTab);
      if (!isFirstTab) {
        _setActiveTab(_tabs.length - 1);
      }
    });
  }

  void _setActiveTab(int index) {
    if (index >= 0 && index < _tabs.length) {
      setState(() {
        _activeTabIndex = index;
      });
    }
  }

  void _closeTab(int index) {
    _webViewControllers.remove(_tabs[index].id);

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

  void _loadUrl(String url) {
    if (_isSearchVisible) {
      setState(() => _isSearchVisible = false);
    }

    if (!_showWebContent) {
      _addTab(url: url, title: _getHostname(url));
      return;
    }

    if (_activeWebViewController != null) {
      _activeWebViewController!
          .loadUrl(urlRequest: URLRequest(url: WebUri(url)));
      setState(() {
        _activeTab.url = url;
        _activeTab.title = _getHostname(url);
      });
    }
  }

  String _getHostname(String url) {
    try {
      return Uri.parse(url).host.replaceAll('www.', '');
    } catch (_) {
      return "Loading...";
    }
  }

  Future<bool> _onWillPop() async {
    if (_isSearchVisible) {
      setState(() => _isSearchVisible = false);
      return false;
    }
    if (_activeWebViewController != null &&
        await _activeWebViewController!.canGoBack()) {
      _activeWebViewController!.goBack();
      return false;
    }
    if (!_showWebContent) {
      return true;
    } else {
      setState(() {
        _activeTab.url = "about:blank";
        _activeTab.title = "New Tab";
        _activeTab.favicon = null;
        _activeTab.dominantColor = null;
      });
      _setActiveTab(_activeTabIndex);
      return false;
    }
  }

  void _updateMusicInfo() async {
    BrowserTab? musicTab;
    try {
      musicTab = _tabs.firstWhere((t) => t.isYouTubeMusicTab);
    } catch (e) {
      return; // No music tab exists
    }

    final musicWebViewController = _webViewControllers[musicTab.id];
    if (musicWebViewController == null || !mounted) return;

    // --- Method 1: MediaSession API (Primary) ---
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
        await musicWebViewController.evaluateJavascript(source: getMediaInfoJs);
    final playButtonAriaLabel = await musicWebViewController.evaluateJavascript(
        source:
            "document.getElementById('play-pause-button')?.getAttribute('aria-label')");

    if (mediaInfoJson is String) {
      final mediaInfo = jsonDecode(mediaInfoJson);
      final title = mediaInfo['title'];
      if (title != null && title.isNotEmpty) {
        if (mounted) {
          setState(() {
            _songTitle = title;
            _songArtist = mediaInfo['artist'] ?? "Artist Name";
            _songThumbnailUrl = mediaInfo['thumbnailUrl'];
            _isPlaying = playButtonAriaLabel == "Pause";
          });
        }
        return; // Success, exit here
      }
    }

    // --- Method 2: Direct DOM Query (Fallback) ---
    const getTitleJs =
        "document.querySelector('ytmusic-player-bar .title.yt-formatted-string')?.innerText";
    const getArtistJs =
        "document.querySelector('ytmusic-player-bar .byline.yt-formatted-string')?.innerText.split('•')[0].trim()";
    const getThumbnailJs =
        "document.querySelector('ytmusic-player-bar #song-image img')?.src";

    final titleResult =
        await musicWebViewController.evaluateJavascript(source: getTitleJs);
    final artistResult =
        await musicWebViewController.evaluateJavascript(source: getArtistJs);
    final thumbnailResult =
        await musicWebViewController.evaluateJavascript(source: getThumbnailJs);

    final String? title =
        (titleResult is String && titleResult.isNotEmpty) ? titleResult : null;
    final String? artist = (artistResult is String && artistResult.isNotEmpty)
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
          _songArtist = artist ?? "Artist Name";
          _songThumbnailUrl = thumbnailUrl;
          _isPlaying = playButtonAriaLabel == "Pause";
        });
      } else {
        setState(() {
          _songTitle = "Not Playing";
          _songArtist = "Open YouTube Music";
          _songThumbnailUrl = null;
          _isPlaying = false;
        });
      }
    }
  }

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
              AnimatedPadding(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                padding: EdgeInsets.zero,
                child: Stack(
                  children: [
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
                              userAgent: tab.isYouTubeMusicTab
                                  ? "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/108.0.0.0 Safari/537.36"
                                  : "",
                              useHybridComposition: false,
                              mediaPlaybackRequiresUserGesture: false,
                            ),
                            onWebViewCreated: (controller) {
                              _webViewControllers[tab.id] = controller;
                              if (tab.url.startsWith("http")) {
                                controller.loadUrl(
                                    urlRequest:
                                        URLRequest(url: WebUri(tab.url)));
                              }
                            },
                            onLoadStop: (controller, url) async {
                              if (url != null &&
                                  url.toString().startsWith("http")) {
                                List<Favicon> favicons =
                                    await controller.getFavicons();
                                String? title = await controller.getTitle();
                                Color? dominantColor;

                                if (favicons.isNotEmpty) {
                                  tab.favicon = favicons.first.url;
                                  try {
                                    final PaletteGenerator palette =
                                        await PaletteGenerator
                                            .fromImageProvider(
                                      NetworkImage(tab.favicon.toString()),
                                      size: const Size(32, 32),
                                    );
                                    dominantColor =
                                        palette.dominantColor?.color;
                                  } catch (e) {/* Could not generate palette */}
                                }

                                if (mounted) {
                                  setState(() {
                                    if (index == _activeTabIndex)
                                      _progress = 0.0;
                                    tab.url = url.toString();
                                    tab.title =
                                        title ?? _getHostname(url.toString());
                                    tab.dominantColor = dominantColor;
                                    if (url.host
                                        .contains("music.youtube.com")) {
                                      tab.isYouTubeMusicTab = true;
                                    }
                                  });
                                  if (tab.isYouTubeMusicTab) {
                                    // A short delay helps ensure the player bar is loaded
                                    Future.delayed(const Duration(seconds: 1),
                                        _updateMusicInfo);
                                  }
                                }
                              }
                            },
                            onLoadStart: (controller, url) {
                              if (mounted) {
                                setState(() {
                                  tab.title = "Loading...";
                                  tab.favicon = null;
                                  tab.dominantColor = null;
                                  if (index == _activeTabIndex) _progress = 0.0;
                                });
                              }
                            },
                            onProgressChanged: (controller, progress) {
                              if (mounted) {
                                setState(() {
                                  if (index == _activeTabIndex)
                                    _progress = progress / 100.0;
                                });
                              }
                            },
                            onScrollChanged: (controller, x, y) {
                              if (y > _lastWebViewScrollY && y > 50) {
                                if (_isNavBarVisible)
                                  setState(() => _isNavBarVisible = false);
                              } else if (y < _lastWebViewScrollY) {
                                if (!_isNavBarVisible)
                                  setState(() => _isNavBarVisible = true);
                              }
                              _lastWebViewScrollY = y.toDouble();
                            },
                          ),
                        );
                      }).toList(),
                    ),
                    if (!_showWebContent)
                      HomeScreenContent(
                        scrollController: _homeScrollController,
                        notes: _notes,
                        onNoteChanged: (newContent) => _addNote(newContent),
                        todos: _todos,
                        favourites: _favourites,
                        quickAILinks: _quickAILinks,
                        onAddTodoTap: _showAddTodoDialog,
                        onToggleTodo: _toggleTodo,
                        onLoadUrl: _loadUrl,
                        onAddAILink: _showAddAIDialog,
                        isMinimalistMode: _isMinimalistMode,
                        onToggleMinimalistMode: () async {
                          setState(
                              () => _isMinimalistMode = !_isMinimalistMode);
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool(
                              'minimalist_mode', _isMinimalistMode);
                        },
                        onOpenMusic: () {
                          _addTab(
                              url: "https://music.youtube.com",
                              title: "YouTube Music",
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
                          _webViewControllers[musicTab.id]?.evaluateJavascript(
                              source:
                                  "document.querySelector('.previous-button').click()");
                          Future.delayed(const Duration(milliseconds: 500),
                              _updateMusicInfo);
                        },
                        onMusicPlayPause: () {
                          final musicTab = _tabs.firstWhere(
                              (t) => t.isYouTubeMusicTab,
                              orElse: () => _activeTab);
                          _webViewControllers[musicTab.id]?.evaluateJavascript(
                              source:
                                  "document.getElementById('play-pause-button').click()");
                          Future.delayed(const Duration(milliseconds: 500),
                              _updateMusicInfo);
                        },
                        onMusicNext: () {
                          final musicTab = _tabs.firstWhere(
                              (t) => t.isYouTubeMusicTab,
                              orElse: () => _activeTab);
                          _webViewControllers[musicTab.id]?.evaluateJavascript(
                              source:
                                  "document.querySelector('.next-button').click()");
                          Future.delayed(const Duration(milliseconds: 500),
                              _updateMusicInfo);
                        },
                      ),
                  ],
                ),
              ),
              if (_progress > 0 && _progress < 1)
                Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(
                      value: _progress,
                      backgroundColor: Colors.transparent,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.white),
                      minHeight: 2,
                    )),
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
              if (_isSearchVisible)
                SearchScreen(
                  onClose: () => setState(() => _isSearchVisible = false),
                  onSearch: _handleSearch,
                  quickAILinks: _quickAILinks,
                  favourites: _favourites,
                  onLoadUrl: _loadUrl,
                  onShowChatAIDialog: _showChatAIDialog,
                  onShare: () {
                    Clipboard.setData(ClipboardData(text: _activeTab.url));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text("Link copied to clipboard!")),
                    );
                  },
                  onQuickNote: _showQuickNoteDialog,
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddTodoDialog() {
    final TextEditingController textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title:
            const Text("Add a new task", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: textController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Your task...",
            hintStyle: TextStyle(color: Colors.grey),
          ),
          onSubmitted: (value) {
            _addTodo(value);
            Navigator.of(context).pop();
          },
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text("Add"),
            onPressed: () {
              _addTodo(textController.text);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  // ADDED: Dialog for adding a new AI Link
  void _showAddAIDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController urlController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Add AI Tool", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: "Name (e.g., Perplexity)",
                hintStyle: TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: urlController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: "URL (e.g., perplexity.ai)",
                hintStyle: TextStyle(color: Colors.grey),
              ),
              onSubmitted: (value) {
                _addAILink(nameController.text, value);
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text("Add"),
            onPressed: () {
              _addAILink(nameController.text, urlController.text);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  void _showSearchDialog() {
    final TextEditingController textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Search or Type URL",
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: textController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "e.g., google.com",
            hintStyle: TextStyle(color: Colors.grey),
          ),
          onSubmitted: (value) {
            _handleSearch(value);
            Navigator.of(context).pop();
          },
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text("Go"),
            onPressed: () {
              _handleSearch(textController.text);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  void _showChatAIDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title:
            const Text("Choose AI Tool", style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _quickAILinks.length,
            itemBuilder: (context, index) {
              final aiLink = _quickAILinks[index];
              return ListTile(
                leading: Image.network(aiLink.iconUrl,
                    width: 24,
                    height: 24,
                    errorBuilder: (c, e, s) => const Icon(Icons.computer)),
                title: Text(aiLink.name,
                    style: const TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.of(context).pop();
                  _loadUrl(aiLink.url);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showQuickNoteDialog() {
    final TextEditingController textController = TextEditingController(
        text: _notes.isNotEmpty ? _notes.first.content : "");
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Quick Note", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: textController,
          autofocus: true,
          maxLines: 5,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Your note...",
            hintStyle: TextStyle(color: Colors.grey),
          ),
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text("Save"),
            onPressed: () {
              _addNote(textController.text);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  void _handleSearch(String query) {
    if (query.trim().isEmpty) return;
    String url;
    String cleanQuery = query.trim();
    if (cleanQuery.contains('.') && !cleanQuery.contains(' ')) {
      url = "https://$cleanQuery";
    } else {
      url =
          "https://www.google.com/search?q=${Uri.encodeComponent(cleanQuery)}";
    }
    _loadUrl(url);
  }
}

class GlassWidget extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final Color? adaptiveColor;
  final bool useFigmaNavStyle;

  const GlassWidget(
      {super.key,
      required this.child,
      this.borderRadius = const BorderRadius.all(Radius.circular(16.0)),
      this.adaptiveColor,
      this.useFigmaNavStyle = false});

  @override
  Widget build(BuildContext context) {
    final color = adaptiveColor;
    final blurSigma = useFigmaNavStyle ? 64.0 : 48.0;
    final decoration = useFigmaNavStyle
        ? BoxDecoration(
            color: Colors.white.withOpacity(0.01),
            borderRadius: borderRadius,
          )
        : color != null
            ? BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withOpacity(0.3),
                    color.withOpacity(0.15),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: borderRadius,
                border: Border.all(
                  color: Colors.white.withOpacity(0.18),
                  width: 1.0,
                ),
              )
            // Figma specs: fill #706C6C @ 10%, stroke #FFFFFF @ 18%, blur 30
            : BoxDecoration(
                color: const Color(0xFF706C6C).withOpacity(0.10),
                borderRadius: borderRadius,
                border: Border.all(
                  color: Colors.white.withOpacity(0.18),
                  width: 1.0,
                ),
              );

    return ClipRRect(
      borderRadius: borderRadius,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            decoration: decoration,
            child: child,
          ),
        ),
      ),
    );
  }
}

class FloatingNavBar extends StatelessWidget {
  final List<BrowserTab> tabs;
  final int activeTabIndex;
  final Color? adaptiveColor;
  final ValueChanged<int> onTabSelected;
  final ValueChanged<int> onCloseTab;
  final VoidCallback onNewTab;
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

    String displayText = "Search or type URL";
    if (activeTab.url.startsWith("http")) {
      try {
        displayText = Uri.parse(activeTab.url).host;
      } catch (e) {
        displayText = activeTab.title;
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
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
        GestureDetector(
          onTap: onSearchTap,
          child: GlassWidget(
            borderRadius: BorderRadius.circular(12.0),
            adaptiveColor: adaptiveColor,
            useFigmaNavStyle: true,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

  Widget _buildTab(BuildContext context, BrowserTab tab,
      {required bool isActive,
      required VoidCallback onTap,
      required VoidCallback onClose,
      Color? adaptiveColor}) {
    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onClose, // Double press to close tab
      child: GlassWidget(
        borderRadius: BorderRadius.circular(8.0),
        adaptiveColor: adaptiveColor,
        useFigmaNavStyle: true,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          decoration: BoxDecoration(
            color:
                isActive ? Colors.white.withOpacity(0.1) : Colors.transparent,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (tab.favicon != null) ...[
                Image.network(
                  tab.favicon.toString(),
                  width: 18,
                  height: 18,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.public, size: 18, color: Colors.white70),
                ),
                const SizedBox(width: 8),
              ] else ...[
                const Icon(Icons.public, size: 18, color: Colors.white70),
                const SizedBox(width: 8),
              ],
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

class HomeScreenContent extends StatelessWidget {
  final ScrollController scrollController;
  final List<Note> notes;
  final ValueChanged<String> onNoteChanged;
  final List<TodoItem> todos;
  final List<Favourite> favourites;
  final List<QuickAILink> quickAILinks;
  final VoidCallback onAddTodoTap;
  final ValueChanged<int> onToggleTodo;
  final ValueChanged<String> onLoadUrl;
  final VoidCallback onOpenMusic;
  final VoidCallback onAddAILink;
  final bool isMinimalistMode;
  final VoidCallback onToggleMinimalistMode;
  final String songTitle;
  final String songArtist;
  final String? songThumbnailUrl;
  final bool isPlaying;
  final VoidCallback onMusicPrevious;
  final VoidCallback onMusicPlayPause;
  final VoidCallback onMusicNext;

  const HomeScreenContent(
      {super.key,
      required this.scrollController,
      required this.notes,
      required this.onNoteChanged,
      required this.todos,
      required this.favourites,
      required this.quickAILinks,
      required this.onAddTodoTap,
      required this.onToggleTodo,
      required this.onLoadUrl,
      required this.onOpenMusic,
      required this.onAddAILink,
      required this.isMinimalistMode,
      required this.onToggleMinimalistMode,
      required this.songTitle,
      required this.songArtist,
      required this.songThumbnailUrl,
      required this.isPlaying,
      required this.onMusicPrevious,
      required this.onMusicPlayPause,
      required this.onMusicNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: SingleChildScrollView(
        controller: scrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            // Minimalist mode toggle button
            Align(
              alignment: Alignment.topRight,
              child: GestureDetector(
                onTap: onToggleMinimalistMode,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF706C6C).withOpacity(0.10),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.18),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isMinimalistMode
                            ? Icons.widgets_outlined
                            : Icons.visibility_off_outlined,
                        color: Colors.white.withOpacity(0.7),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isMinimalistMode ? "Show" : "Hide",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Content area with animated visibility
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 400),
              crossFadeState: isMinimalistMode
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: _buildFullContent(),
              secondChild: _buildMinimalistContent(),
              sizeCurve: Curves.easeInOut,
            ),
            const SizedBox(height: 150),
          ],
        ),
      ),
    );
  }

  Widget _buildMinimalistContent() {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.explore_outlined,
                color: Colors.white.withOpacity(0.15), size: 48),
            const SizedBox(height: 12),
            Text(
              "Nothing Browser",
              style: TextStyle(
                color: Colors.white.withOpacity(0.2),
                fontSize: 16,
                fontWeight: FontWeight.w300,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullContent() {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  AspectRatio(
                    aspectRatio: 1.0,
                    child: GlassWidget(
                      borderRadius: BorderRadius.circular(8.0),
                      child: _MusicPlayerTile(
                        onTap: onOpenMusic,
                        songTitle: songTitle,
                        songArtist: songArtist,
                        songThumbnailUrl: songThumbnailUrl,
                        isPlaying: isPlaying,
                        onPrevious: onMusicPrevious,
                        onPlayPause: onMusicPlayPause,
                        onNext: onMusicNext,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 250,
                    child: GlassWidget(
                      borderRadius: BorderRadius.circular(8.0),
                      child: _NotesWidget(
                        notes: notes,
                        onNoteChanged: onNoteChanged,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  AspectRatio(
                    aspectRatio: 1.0,
                    child: GlassWidget(
                      borderRadius: BorderRadius.circular(8.0),
                      child: _TodosWidget(
                        todos: todos,
                        onToggleTodo: onToggleTodo,
                        onAddTodoTap: onAddTodoTap,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 250,
                    child: GlassWidget(
                      borderRadius: BorderRadius.circular(8.0),
                      child: _QuickAIAccessWidget(
                        quickAILinks: quickAILinks,
                        onLoadUrl: onLoadUrl,
                        onAddAILink: onAddAILink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GlassWidget(
          borderRadius: BorderRadius.circular(8.0),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Favourites",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 16)),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 4,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    ...favourites.map((fav) => _FavouriteButton(
                        favourite: fav, onTap: () => onLoadUrl(fav.url))),
                    _FavouriteButton(icon: Icons.add, onTap: () {}),
                  ],
                )
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// MODIFIED: This widget is updated to prevent the 'setState called during build' error.
class _NotesWidget extends StatefulWidget {
  final List<Note> notes;
  final ValueChanged<String> onNoteChanged;

  const _NotesWidget({required this.notes, required this.onNoteChanged});

  @override
  State<_NotesWidget> createState() => _NotesWidgetState();
}

class _NotesWidgetState extends State<_NotesWidget> {
  late TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(
        text: widget.notes.isNotEmpty ? widget.notes.first.content : "");
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _NotesWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newText = widget.notes.isNotEmpty ? widget.notes.first.content : "";
    if (_noteController.text != newText) {
      // Safely update the controller's text without triggering a rebuild loop or moving the cursor.
      _noteController.value = _noteController.value.copyWith(text: newText);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Quick Notes",
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 16)),
          const SizedBox(height: 8),
          Expanded(
            child: TextField(
              controller: _noteController,
              onChanged: widget
                  .onNoteChanged, // Use onChanged for safer state updates.
              expands: true,
              maxLines: null,
              style: const TextStyle(color: Colors.white70),
              decoration: const InputDecoration(
                hintText: "Tap to start writing...",
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.white54),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TodosWidget extends StatelessWidget {
  final List<TodoItem> todos;
  final VoidCallback onAddTodoTap;
  final ValueChanged<int> onToggleTodo;

  const _TodosWidget(
      {required this.todos,
      required this.onAddTodoTap,
      required this.onToggleTodo});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Expanded(
                child: Text("To-Do List",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 16)),
              ),
              IconButton(
                icon: const Icon(Icons.add, color: Colors.white70),
                onPressed: onAddTodoTap,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: todos.isEmpty
                ? const Center(
                    child: Text("No tasks yet.",
                        style: TextStyle(color: Colors.white54)))
                : ListView.builder(
                    itemCount: todos.length,
                    itemBuilder: (context, index) {
                      final todo = todos[index];
                      return CheckboxListTile(
                        value: todo.isDone,
                        onChanged: (_) => onToggleTodo(index),
                        title: Text(
                          todo.task,
                          style: TextStyle(
                            color: todo.isDone ? Colors.white54 : Colors.white,
                            decoration: todo.isDone
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: Colors.white,
                        checkColor: Colors.black,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _MusicPlayerTile extends StatelessWidget {
  final String songTitle;
  final String songArtist;
  final String? songThumbnailUrl;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onPrevious;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;

  const _MusicPlayerTile({
    required this.songTitle,
    required this.songArtist,
    this.songThumbnailUrl,
    required this.isPlaying,
    required this.onTap,
    required this.onPrevious,
    required this.onPlayPause,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (songThumbnailUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: Image.network(
                songThumbnailUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => const Icon(
                    Icons.music_note,
                    size: 56,
                    color: Colors.white30),
              ),
            ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8.0),
              gradient: LinearGradient(
                colors: [
                  Colors.black
                      .withOpacity(songThumbnailUrl != null ? 0.6 : 0.0),
                  Colors.transparent,
                  Colors.black.withOpacity(songThumbnailUrl != null ? 0.8 : 0.0)
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      songTitle,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      songArtist,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    IconButton(
                        icon: const Icon(Icons.skip_previous,
                            color: Colors.white70),
                        onPressed: onPrevious,
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact),
                    IconButton(
                        icon: Icon(
                            isPlaying
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_filled,
                            color: Colors.white,
                            size: 40),
                        onPressed: onPlayPause,
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact),
                    IconButton(
                        icon:
                            const Icon(Icons.skip_next, color: Colors.white70),
                        onPressed: onNext,
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAIAccessWidget extends StatelessWidget {
  final List<QuickAILink> quickAILinks;
  final ValueChanged<String> onLoadUrl;
  final VoidCallback onAddAILink; // ADDED: Callback for the new button

  const _QuickAIAccessWidget(
      {required this.quickAILinks,
      required this.onLoadUrl,
      required this.onAddAILink});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Quick AI Access",
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 16)),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              // MODIFIED: Added 1 to item count for the "add" button
              itemCount: quickAILinks.length + 1,
              itemBuilder: (context, index) {
                // If it's the last item, show the "add" button
                if (index == quickAILinks.length) {
                  return _QuickAIAddButton(onTap: onAddAILink);
                }
                // Otherwise, show the AI link button
                final link = quickAILinks[index];
                return _QuickAIButton(
                    link: link, onTap: () => onLoadUrl(link.url));
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAIButton extends StatelessWidget {
  final QuickAILink link;
  final VoidCallback onTap;
  const _QuickAIButton({required this.link, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.network(
              link.iconUrl,
              width: 24,
              height: 24,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.computer, size: 24, color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: Text(
                link.name,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ADDED: A new button widget for adding AI links
class _QuickAIAddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _QuickAIAddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxHeight < 64 || constraints.maxWidth < 64;
          return Container(
            padding: EdgeInsets.all(compact ? 4 : 8),
            decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(color: Colors.white.withOpacity(0.2))),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add,
                  color: Colors.white.withOpacity(0.7),
                  size: compact ? 16 : 24,
                ),
                if (!compact) ...[
                  const SizedBox(height: 8),
                  Text("Add Tool",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.7), fontSize: 12)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FavouriteButton extends StatelessWidget {
  final Favourite? favourite;
  final IconData? icon;
  final VoidCallback onTap;
  const _FavouriteButton({this.favourite, this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: icon != null
              ? Icon(icon, color: Colors.white70)
              : favourite != null
                  ? ClipOval(
                      child: Image.network(
                        favourite!.iconUrl,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Text(
                            favourite!.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ),
                    )
                  : const SizedBox.shrink(),
        ),
      ),
    );
  }
}

// ADDED: New Search Screen Widget
class SearchScreen extends StatelessWidget {
  final VoidCallback onClose;
  final ValueChanged<String> onSearch;
  final List<QuickAILink> quickAILinks;
  final List<Favourite> favourites;
  final ValueChanged<String> onLoadUrl;
  final VoidCallback onShowChatAIDialog;
  final VoidCallback onShare;
  final VoidCallback onQuickNote;

  const SearchScreen({
    super.key,
    required this.onClose,
    required this.onSearch,
    required this.quickAILinks,
    required this.favourites,
    required this.onLoadUrl,
    required this.onShowChatAIDialog,
    required this.onShare,
    required this.onQuickNote,
  });

  @override
  Widget build(BuildContext context) {
    final TextEditingController searchController = TextEditingController();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onClose,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  color: Colors.black.withOpacity(0.50),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Search Bar
                  GlassWidget(
                    borderRadius: BorderRadius.circular(30),
                    useFigmaNavStyle: true,
                    child: TextField(
                      controller: searchController,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Search or enter website",
                        hintStyle:
                            TextStyle(color: Colors.white.withOpacity(0.5)),
                        prefixIcon: Icon(Icons.search,
                            color: Colors.white.withOpacity(0.5)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 15),
                      ),
                      onSubmitted: onSearch,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _SearchActionButton(
                          icon: Icons.summarize,
                          label: "Summarize",
                          onTap: () {}),
                      _SearchActionButton(
                          icon: Icons.chat_bubble_outline,
                          label: "ChatAI",
                          onTap: onShowChatAIDialog),
                      _SearchActionButton(
                          icon: Icons.send_outlined,
                          label: "Send",
                          onTap: onShare),
                      _SearchActionButton(
                          icon: Icons.description_outlined,
                          label: "Quick Note",
                          onTap: onQuickNote),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Link List
                  Expanded(
                    child: ListView(
                      children: [
                        ...quickAILinks.map((link) => _SearchListItem(
                              title: link.name,
                              subtitle: Uri.parse(link.url).host,
                              iconUrl: link.iconUrl,
                              onTap: () => onLoadUrl(link.url),
                            )),
                        ...favourites.map((fav) => _SearchListItem(
                              title: fav.title,
                              subtitle: Uri.parse(fav.url).host,
                              iconUrl: fav.iconUrl,
                              onTap: () => onLoadUrl(fav.url),
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SearchActionButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}

class _SearchListItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final String iconUrl;
  final VoidCallback onTap;

  const _SearchListItem(
      {required this.title,
      required this.subtitle,
      required this.iconUrl,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: GestureDetector(
        onTap: onTap,
        child: GlassWidget(
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Image.network(
                  iconUrl,
                  width: 24,
                  height: 24,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.public, size: 24, color: Colors.white70),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                    Text(subtitle,
                        style: const TextStyle(color: Colors.white70)),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
// " and I would like to get some help with it.
// I have the following query:
// now the search screen is not closing on tap... it's like a solid screen over the webview, only back gesture is working
