import 'package:sisyphus_core/sisyphus_core.dart';

class ServerConfig {
  const ServerConfig({
    this.port = 8080,
    this.sandbox = true,
    this.allowGuests = true,
    this.seed = defaultSeed,
    this.validationKey = '',
    this.contactEmail = '',
    this.flutterEngine = '',
    this.debugShots = false,
    this.piApiKey = '',
    this.carvePrice = 1,
    this.carvingsFile,
    this.legalDir = 'legal',
    this.leaderboardSize = 50,
    this.piApiBase = 'https://api.minepi.com',
    this.dataFile,
    this.webDir,
  });

  /// Reads the environment. With `APP_ENV=production`, sandbox mode and guest
  /// play default to off so the ranking only holds verified Pioneers.
  factory ServerConfig.fromEnvironment(Map<String, String> env) {
    bool flag(String key, bool fallback) {
      final v = env[key];
      return v == null ? fallback : RegExp(r'^(1|true|yes)$', caseSensitive: false).hasMatch(v);
    }

    final production = env['APP_ENV'] == 'production';
    return ServerConfig(
      port: int.tryParse(env['PORT'] ?? '') ?? 8080,
      sandbox: flag('PI_SANDBOX', !production),
      allowGuests: flag('ALLOW_GUEST', !production),
      seed: int.tryParse(env['MOUNTAIN_SEED'] ?? '') ?? defaultSeed,
      validationKey: env['PI_VALIDATION_KEY'] ?? '',
      contactEmail: env['CONTACT_EMAIL'] ?? '',
      flutterEngine: env['FLUTTER_ENGINE'] ?? '',
      debugShots: flag('DEBUG_SHOTS', false),
      piApiKey: env['PI_API_KEY'] ?? '',
      carvePrice: double.tryParse(env['CARVE_PRICE'] ?? '') ?? 1,
      carvingsFile: env['CARVINGS_FILE'] ?? _besideDataFile(env['DATA_FILE'] ?? 'data/scores.json', 'carvings.json'),
      legalDir: env['LEGAL_DIR'] ?? 'legal',
      piApiBase: env['PI_API_BASE'] ?? 'https://api.minepi.com',
      dataFile: env['DATA_FILE'] ?? 'data/scores.json',
      webDir: env['WEB_DIR'] ?? '../app/build/web',
    );
  }

  final int port;
  final bool sandbox;
  final bool allowGuests;
  final int seed;

  /// Served at /validation-key.txt for the Pi Developer Portal domain check.
  final String validationKey;

  /// Shown on the Privacy Policy and Terms pages.
  final String contactEmail;

  /// Flutter engine settings for browsers, as JSON, e.g.
  /// `{"renderer":"canvaskit","canvasKitForceCpuOnly":true}`. Served at
  /// /api/engine; lets the renderer be switched without a rebuild.
  final String flutterEngine;

  /// Lets the app upload a screenshot of its own rendering (debugging).
  final bool debugShots;

  /// The app's server API key from the Pi Developer Portal. Enables
  /// "Carve the Mountain" (Pi payments); empty turns it off.
  final String piApiKey;

  /// What one carving costs, in π.
  final double carvePrice;

  /// Where carvings are persisted; null keeps them in memory only.
  final String? carvingsFile;

  /// Where privacy.html and terms.html live.
  final String legalDir;
  final int leaderboardSize;
  final String piApiBase;

  /// Where the ranking is persisted; null keeps it in memory only.
  final String? dataFile;

  /// The Flutter web build (`app/build/web`) to serve, if any.
  final String? webDir;
}

String _besideDataFile(String dataFile, String name) {
  final slash = dataFile.lastIndexOf('/');
  return slash == -1 ? name : '${dataFile.substring(0, slash + 1)}$name';
}
