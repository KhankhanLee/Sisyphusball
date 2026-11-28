import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Character sprites drawn in the game instead of the coded figure:
/// `assets/sprites/{skin id}.png`, a transparent full-body picture. Skins
/// without one keep the coded figure. Replace a file to change the art.
class Sprites extends ChangeNotifier {
  Sprites({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  static const skinIds = {'her-exile', 'her-starlight', 'her-lilac', 'her-herald', 'her-envoy'};

  final AssetBundle _bundle;
  final Map<String, ui.Image> _images = {};

  ui.Image? of(String skinId) => _images[skinId];

  /// Decodes every sprite once. A missing or broken file is skipped.
  Future<void> load() async {
    for (final id in skinIds) {
      try {
        final data = await _bundle.load('assets/sprites/$id.png');
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        _images[id] = (await codec.getNextFrame()).image;
      } catch (_) {
        // keeps the coded figure for this skin
      }
    }
    notifyListeners();
  }
}
