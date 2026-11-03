/// Grand titles for a climb that never ends.
class Tier {
  const Tier(this.min, this.name, this.motto);

  final int min;
  final String name;
  final String motto;
}

const tiers = <Tier>[
  Tier(0, 'Pebble at the Bottom', 'Everything begins here, and everything returns here.'),
  Tier(10, 'Apprentice of the Slope', 'You have learned the weight of the stone.'),
  Tier(25, 'Pilgrim of the Hill', 'The path leads nowhere. You walk it anyway.'),
  Tier(50, 'Ascetic of the Mountainside', 'You know it will fall. You put your hands on it again.'),
  Tier(100, 'Rebel of the Ridge', 'Aware of the absurd, and unbowed.'),
  Tier(200, 'Dreamer of the Summit', 'The summit cannot be seen. So you keep climbing.'),
  Tier(400, 'Nuisance to the Gods', 'The punishment no longer works as a punishment.'),
  Tier(800, 'Happy Sisyphus', 'The struggle itself toward the heights is enough to fill a heart.'),
];

Tier tierFor(int score) => tiers.lastWhere((t) => score >= t.min);

Tier? nextTier(int score) {
  for (final t in tiers) {
    if (t.min > score) return t;
  }
  return null;
}

/// Shown each time the stone rolls back down.
const refrains = <String>[
  'The stone rolled back to the bottom.',
  'There is no summit. Push again.',
  'Your record remains. Your stone does not.',
  'The gods believed this was a punishment.',
  'On the way down, catch your breath.',
  'One point. Then another. That is all, and it is enough.',
  'The rankings rise. The stone falls.',
  'One must imagine Sisyphus happy. — Albert Camus',
];
