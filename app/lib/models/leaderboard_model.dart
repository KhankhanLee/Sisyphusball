import 'package:flutter/foundation.dart';
import 'package:sisyphus_core/sisyphus_core.dart';

import '../data/models.dart';
import '../events.dart';

/// The Hall of Fame and the world totals.
/// Observes LiveFeed (everyone's climbs) and RunReporter (my own climb, which
/// can arrive a moment before the feed catches up).
class LeaderboardModel extends ChangeNotifier implements Observer<AppEvent> {
  List<BoardEntry> top = const [];
  WorldStats stats = const WorldStats();

  BoardEntry? get leader => top.firstOrNull;

  @override
  void onEvent(AppEvent event) {
    switch (event) {
      case BoardUpdated(:final top, :final stats):
        this.top = top;
        this.stats = stats;
      case RunRecorded(result: RunResult(:final stats?)):
        this.stats = stats;
      default:
        return;
    }
    notifyListeners();
  }
}
