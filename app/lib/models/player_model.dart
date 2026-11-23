import 'package:flutter/foundation.dart';
import 'package:sisyphus_core/sisyphus_core.dart';

import '../data/models.dart';
import '../events.dart';

enum SignInStatus { pending, signedIn, failed }

/// Who is playing and how they stand.
/// Observes AuthService (sign-in, nickname) and RunReporter (new standings).
class PlayerModel extends ChangeNotifier implements Observer<AppEvent> {
  SignInStatus status = SignInStatus.pending;
  String? failure;
  Player? player;
  Standing standing = const Standing();

  /// Whether this server lets Pi players choose a nickname.
  bool nicknames = false;

  bool get isPi => signedIn && player?.guest == false;

  bool get needsNickname => isPi && player!.needsNickname;

  void enableNicknames(bool on) {
    nicknames = on;
    notifyListeners();
  }

  bool get signedIn => status == SignInStatus.signedIn;
  String get username => player?.username ?? '';
  Tier get tier => tierFor(standing.best);

  @override
  void onEvent(AppEvent event) {
    switch (event) {
      case SignedIn(:final player, :final standing):
        status = SignInStatus.signedIn;
        this.player = player;
        this.standing = standing;
      case NicknameChanged(:final player):
        this.player = player;
      case SignInFailed(:final reason):
        status = SignInStatus.failed;
        failure = reason;
      case RunRecorded(result: RunResult(:final standing?)):
        this.standing = standing;
      default:
        return;
    }
    notifyListeners();
  }
}
