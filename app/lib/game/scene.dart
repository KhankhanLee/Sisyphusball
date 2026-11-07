enum GameMode { idle, solo, versus }

/// Another player climbing right now, drawn as a translucent stone.
class Ghost {
  const Ghost(this.name, this.height);

  final String name;
  final double height;
}

/// A dashed line across the path: a goal that moves nothing.
class Marker {
  const Marker(this.height, this.label, this.color);

  final double height;
  final String label;
  final int color;
}

/// Words someone paid to carve at a height: they stay when the stone falls.
class Engraving {
  const Engraving(this.height, this.text, this.author);

  final double height;
  final String text;
  final String author;
}

/// What the painter draws on top of the mountain besides the player's own
/// stone. Kept as an interface so the painter does not know where it comes
/// from (see `SceneOverlayModel`).
abstract interface class SceneOverlay {
  List<Ghost> get ghosts;

  List<Marker> get markers;

  List<Engraving> get engravings;
}
