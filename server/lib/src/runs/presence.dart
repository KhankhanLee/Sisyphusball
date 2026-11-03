/// One person climbing right now.
class LiveClimber {
  const LiveClimber(this.id, this.name, this.height);

  /// Short public prefix of the run id, so a client can recognise itself.
  final String id;
  final String name;
  final int height;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'height': height};
}

/// Everyone climbing right now, highest first.
class Presence {
  const Presence(this.climbers, this.count);

  final List<LiveClimber> climbers;
  final int count;

  Map<String, dynamic> toJson() => {'count': count, 'climbers': [for (final c in climbers) c.toJson()]};
}
