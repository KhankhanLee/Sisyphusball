/// Who pushes the stone, and in what. Shared by the client (to draw them)
/// and the server (to sell and check them). Looks are cosmetic only: they
/// never touch the climb, the score or the ranking.
library;

/// A playable figure. Both are free.
class Character {
  const Character(this.id, this.name, this.pronoun);

  final String id;
  final String name;
  final String pronoun;
}

/// Colors of a skin, as 0xAARRGGBB.
class SkinColors {
  const SkinColors({
    required this.skin,
    required this.hair,
    required this.cloth,
    required this.trim,
    this.glow,
  });

  final int skin, hair, cloth, trim;

  /// A soft halo around the figure, if any.
  final int? glow;
}

/// An outfit for one character. Free when [price] is 0, otherwise sold for
/// [price] π.
class Skin {
  const Skin(this.id, this.characterId, this.name, this.blurb, this.price, this.colors);

  final String id;
  final String characterId;
  final String name;
  final String blurb;
  final double price;
  final SkinColors colors;

  bool get free => price == 0;
}

const characters = [
  Character('him', 'Sisyphus', 'He'),
  Character('her', 'Sisyphe', 'She'),
];

const skins = [
  Skin('him-exile', 'him', 'Exile', 'The tunic he was condemned in.', 0,
      SkinColors(skin: 0xFFE9C9A6, hair: 0xFF4A3426, cloth: 0xFFD9CBB2, trim: 0xFF9C7A4E)),
  Skin('him-marble', 'him', 'Marble', 'Carved like the gods who sent him.', 1,
      SkinColors(skin: 0xFFF1E9DD, hair: 0xFFBFB6AA, cloth: 0xFFF7F4EE, trim: 0xFFD4AF37)),
  Skin('him-ember', 'him', 'Ember', 'Still warm from Tartarus.', 1,
      SkinColors(skin: 0xFFC98E6B, hair: 0xFF8E2A12, cloth: 0xFF2A1A1F, trim: 0xFFFF8A3D, glow: 0x55FF7A2E)),
  Skin('her-exile', 'her', 'Exile', 'The robe she was condemned in.', 0,
      SkinColors(skin: 0xFFF6DCC8, hair: 0xFFE4E6EF, cloth: 0xFFEDE6F6, trim: 0xFFA58AD0)),
  Skin('her-marble', 'her', 'Marble', 'Carved like the gods who sent her.', 1,
      SkinColors(skin: 0xFFF6E6D6, hair: 0xFFEEF0F4, cloth: 0xFFF8F5F0, trim: 0xFFD4AF37)),
  Skin('her-ember', 'her', 'Ember', 'Still warm from Tartarus.', 1,
      SkinColors(skin: 0xFFF1D5C1, hair: 0xFFDCDDE6, cloth: 0xFF241820, trim: 0xFFFF8A3D, glow: 0x55FF7A2E)),
];

const defaultCharacterId = 'him';

Character? characterById(String id) {
  for (final c in characters) {
    if (c.id == id) return c;
  }
  return null;
}

Skin? skinById(String id) {
  for (final s in skins) {
    if (s.id == id) return s;
  }
  return null;
}

Iterable<Skin> skinsOf(String characterId) => skins.where((s) => s.characterId == characterId);

/// The free skin every character starts with.
Skin defaultSkinOf(String characterId) => skinsOf(characterId).firstWhere((s) => s.free);

/// What a player wears: a character and one of its skins.
class Look {
  const Look(this.characterId, this.skinId);

  static final standard = Look(defaultCharacterId, defaultSkinOf(defaultCharacterId).id);

  final String characterId;
  final String skinId;

  Skin get skin => skinById(skinId) ?? defaultSkinOf(characterId);

  Map<String, dynamic> toJson() => {'character': characterId, 'skin': skinId};

  /// A valid look from JSON, or [standard] when it names nothing known.
  static Look fromJson(Object? j) {
    if (j is Map) {
      final c = j['character'], s = j['skin'];
      final skin = s is String ? skinById(s) : null;
      if (c is String && skin != null && skin.characterId == c) return Look(c, skin.id);
    }
    return standard;
  }
}
