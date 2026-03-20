/// App-wide constants used across multiple features.
///
/// Centralizes magic strings and configuration values so they can be
/// changed in a single place.

/// User-Agent string sent with every WebView request.
/// Spoofs a desktop Chrome browser so sites serve their full-featured
/// versions instead of stripped-down mobile pages.
const String kDesktopChromeUserAgent =
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

/// Hosts whose tabs are allowed to keep audio playing in the background.
/// When the user switches away from the app, only tabs matching one of
/// these hosts will continue playback (via the foreground service).
const Set<String> kBackgroundAudioAllowedHosts = {
  'youtube.com',
  'www.youtube.com',
  'm.youtube.com',
  'music.youtube.com',
  'open.spotify.com',
  'music.apple.com',
};
