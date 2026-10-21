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

/// What the painter draws on top of the mountain besides the player's own
/// stone. Kept as an interface so the painter does not know where it comes
/// from (see `SceneOverlayModel`).
abstract interface class SceneOverlay {
  List<Ghost> get ghosts;

  List<Marker> get markers;
}
