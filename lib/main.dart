/// Nothing Browser — App Entry Point
///
/// This file bootstraps the Flutter application with a dark Material theme
/// and delegates everything to [BrowserScreen], which orchestrates all
/// browser features (tabs, WebView, home screen, search, history, etc.).
import 'package:flutter/material.dart';
import 'package:myapp/features/browser/browser_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

/// Root widget — configures the MaterialApp with a dark theme.
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