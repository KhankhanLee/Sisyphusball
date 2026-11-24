import 'dart:convert';
import 'dart:io';

/// Pi user id -> chosen nickname, optionally mirrored to a JSON file.
class NicknameStore {
  NicknameStore({this.path});

  final String? path;
  final Map<String, String> _byUid = {};

  String? of(String uid) => _byUid[uid];

  Iterable<MapEntry<String, String>> get entries => _byUid.entries;

  Future<void> load() async {
    final p = path;
    if (p == null || !await File(p).exists()) return;
    final data = jsonDecode(await File(p).readAsString()) as Map<String, dynamic>;
    _byUid
      ..clear()
      ..addAll({for (final e in (data['nicknames'] as Map? ?? const {}).entries) e.key as String: e.value as String});
  }

  Future<void> set(String uid, String nickname) async {
    _byUid[uid] = nickname;
    final p = path;
    if (p == null) return;
    final file = File(p);
    await file.parent.create(recursive: true);
    final tmp = File('$p.$pid.tmp');
    await tmp.writeAsString(jsonEncode({'nicknames': _byUid}), flush: true);
    await tmp.rename(p);
  }
}
