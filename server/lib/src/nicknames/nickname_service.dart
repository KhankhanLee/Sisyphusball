import '../auth/identity.dart';
import '../http/http_error.dart';
import 'nickname_store.dart';

const minNicknameLength = 2, maxNicknameLength = 16;

final _allowed = RegExp(r'^[\p{L}\p{N}_\- ]+$', unicode: true);

/// The nickname as it will be shown, or null when it is not allowed:
/// 2–16 letters, digits, spaces, `_` or `-` (any script).
String? cleanNickname(Object? raw) {
  if (raw is! String) return null;
  final name = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  final length = name.runes.length;
  if (length < minNicknameLength || length > maxNicknameLength) return null;
  return _allowed.hasMatch(name) ? name : null;
}

/// Lets Pi players show a nickname instead of their Pi username. Only the
/// display name changes; the Pi user id still identifies the player.
class NicknameService {
  NicknameService(this._store, {required this.enabled, required this.nameTakenElsewhere});

  final NicknameStore _store;
  final bool enabled;

  /// Whether some other player (not [uid]) already shows [name].
  final bool Function(String name, String uid) nameTakenElsewhere;

  bool _isPi(Identity who) => !who.guest && who.uid.startsWith('pi:');

  /// [who] as everyone else should see them.
  Identity personalize(Identity who) {
    final nickname = enabled && _isPi(who) ? _store.of(who.uid) : null;
    return nickname == null ? who : Identity(uid: who.uid, username: nickname, guest: who.guest);
  }

  /// Whether [who] still has to choose a nickname.
  bool needsNickname(Identity who) => enabled && _isPi(who) && _store.of(who.uid) == null;

  /// Sets [who]'s nickname and returns it as stored.
  Future<String> set(Identity who, Object? raw) async {
    if (!enabled) throw HttpError(404, 'not found');
    if (!_isPi(who)) throw HttpError(403, 'sign in with Pi to choose a nickname');
    final name = cleanNickname(raw);
    if (name == null) {
      throw HttpError(400, 'Use $minNicknameLength–$maxNicknameLength letters, numbers, spaces, _ or -.');
    }
    final key = name.toLowerCase();
    final takenByNickname = _store.entries.any((e) => e.key != who.uid && e.value.toLowerCase() == key);
    if (takenByNickname || nameTakenElsewhere(name, who.uid)) throw HttpError(409, 'That name is taken.');
    await _store.set(who.uid, name);
    return name;
  }
}
