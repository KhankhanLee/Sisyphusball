import 'dart:convert';
import 'dart:io';

/// One player's wardrobe.
class Wardrobe {
  Wardrobe({Set<String>? owned, this.character, this.skin}) : owned = owned ?? {};

  factory Wardrobe.fromJson(Map<String, dynamic> j) => Wardrobe(
        owned: {for (final s in j['owned'] as List? ?? const []) s as String},
        character: j['character'] as String?,
        skin: j['skin'] as String?,
      );

  final Set<String> owned;
  String? character, skin;

  Map<String, dynamic> toJson() => {'owned': owned.toList()..sort(), 'character': character, 'skin': skin};
}

/// Wardrobes by player uid, plus the ids of payments already delivered;
/// optionally mirrored to a JSON file.
class LookStore {
  LookStore({this.path});

  final String? path;
  final Map<String, Wardrobe> _byUid = {};
  final Set<String> _payments = {};

  Wardrobe of(String uid) => _byUid[uid] ?? Wardrobe();

  bool delivered(String paymentId) => _payments.contains(paymentId);

  Future<void> load() async {
    final p = path;
    if (p == null || !await File(p).exists()) return;
    final data = jsonDecode(await File(p).readAsString()) as Map<String, dynamic>;
    _byUid
      ..clear()
      ..addAll({
        for (final e in (data['players'] as Map? ?? const {}).entries)
          e.key as String: Wardrobe.fromJson(e.value as Map<String, dynamic>),
      });
    _payments
      ..clear()
      ..addAll([for (final id in data['payments'] as List? ?? const []) id as String]);
  }

  /// Stores [wardrobe] for [uid] (and [paymentId] as delivered, if given)
  /// and writes the file before returning.
  Future<void> save(String uid, Wardrobe wardrobe, {String? paymentId}) async {
    _byUid[uid] = wardrobe;
    if (paymentId != null) _payments.add(paymentId);
    final p = path;
    if (p == null) return;
    final file = File(p);
    await file.parent.create(recursive: true);
    final tmp = File('$p.$pid.tmp');
    await tmp.writeAsString(
      jsonEncode({
        'players': {for (final e in _byUid.entries) e.key: e.value.toJson()},
        'payments': _payments.toList(),
      }),
      flush: true,
    );
    await tmp.rename(p);
  }
}
