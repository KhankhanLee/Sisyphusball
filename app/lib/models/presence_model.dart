import 'package:flutter/foundation.dart';
import 'package:sisyphus_core/sisyphus_core.dart';

import '../data/models.dart';
import '../events.dart';

/// Who is climbing right now.
/// Observes LiveFeed (everyone) and RunReporter (which run is mine, so I am
/// not drawn as my own ghost).
class PresenceModel extends ChangeNotifier implements Observer<AppEvent> {
  List<LiveClimber> climbers = const [];
  int count = 0;
  String? _myRunPrefix;

  /// Everyone but me.
  Iterable<LiveClimber> get others => climbers.where((c) => c.id != _myRunPrefix);

  @override
  void onEvent(AppEvent event) {
    switch (event) {
      case PresenceUpdated(:final climbers, :final count):
        this.climbers = climbers;
        this.count = count;
      case RunRegistered(:final runId):
        _myRunPrefix = runId.substring(0, 8);
      default:
        return;
    }
    notifyListeners();
  }
}
