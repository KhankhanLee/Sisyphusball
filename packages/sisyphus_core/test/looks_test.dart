import 'package:sisyphus_core/sisyphus_core.dart';
import 'package:test/test.dart';

void main() {
  test('every character has exactly one free skin and unique ids', () {
    for (final c in characters) {
      expect(skinsOf(c.id).where((s) => s.free), hasLength(1), reason: c.id);
    }
    expect(skins.map((s) => s.id).toSet(), hasLength(skins.length));
  });

  test('Look.fromJson falls back to the standard look for anything unknown or mismatched', () {
    expect(Look.fromJson({'character': 'her', 'skin': 'her-ember'}).skinId, 'her-ember');
    expect(Look.fromJson({'character': 'him', 'skin': 'her-ember'}).skinId, Look.standard.skinId);
    expect(Look.fromJson({'character': 'x', 'skin': 'y'}).characterId, defaultCharacterId);
    expect(Look.fromJson(null).skinId, 'him-exile');
  });
}
