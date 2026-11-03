import 'package:sisyphus_core/sisyphus_core.dart';

import '../auth/identity.dart';
import '../events.dart';
import 'score_models.dart';
import 'score_repository.dart';

/// The ranking. A [Subject]: every recorded climb announces
/// [LeaderboardChanged], and [PersonalBest] when a record falls.
///
/// Dart serves every request on one event loop and [record] never awaits,
/// so two climbs finishing at the same moment can never interleave.
class ScoreService with Subject<ServerEvent> {
  ScoreService(this._repository, {this.boardSize = 50});

  final ScoreRepository _repository;
  final int boardSize;
  List<PlayerRecord>? _ranking; // cache, rebuilt after any change

  ({bool isBest, Standing standing}) record(Identity who, int score) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final player = _repository.find(who.uid) ??
        PlayerRecord(uid: who.uid, username: who.username, guest: who.guest);
    final isBest = score > player.best;
    player
      ..username = who.username
      ..runs += 1
      ..totalMeters += score
      ..lastAt = now;
    if (isBest) {
      player
        ..best = score
        ..bestAt = now;
    }
    _repository.totals
      ..runs += 1
      ..meters += score;
    _repository.save(player);
    _ranking = null;

    final standing = standingOf(who.uid);
    if (isBest) notify(PersonalBest(who.username, score, standing.rank));
    notify(LeaderboardChanged(leaderboard()));
    return (isBest: isBest, standing: standing);
  }

  Leaderboard leaderboard() => Leaderboard(_ranked.take(boardSize).toList(), _repository.totals);

  Standing standingOf(String uid) {
    final p = _repository.find(uid);
    if (p == null) return const Standing();
    final i = _ranked.indexWhere((r) => r.uid == uid);
    return Standing(best: p.best, rank: i == -1 ? null : i + 1, runs: p.runs, totalMeters: p.totalMeters);
  }

  List<PlayerRecord> get _ranked => _ranking ??= _repository.players.where((p) => p.best > 0).toList()
    ..sort((a, b) {
      final byBest = b.best.compareTo(a.best);
      return byBest != 0 ? byBest : a.bestAt.compareTo(b.bestAt); // earlier wins ties
    });
}
