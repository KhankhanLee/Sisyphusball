// Grand titles for a climb that never ends.

class Tier {
  const Tier(this.min, this.name, this.motto);

  final int min;
  final String name;
  final String motto;
}

const tiers = <Tier>[
  Tier(0, '바닥의 조약돌', '모든 것은 여기서 시작하고, 여기로 돌아온다.'),
  Tier(10, '비탈의 견습생', '처음으로 돌의 무게를 알게 되었다.'),
  Tier(25, '언덕의 순례자', '길은 어디로도 이어지지 않지만, 걷는다.'),
  Tier(50, '산허리의 고행자', '내려갈 것을 알면서도 다시 손을 댄다.'),
  Tier(100, '능선의 반항인', '부조리를 알고도 굴복하지 않는 자.'),
  Tier(200, '정상을 꿈꾸는 자', '정상은 보이지 않는다. 그래서 계속 오른다.'),
  Tier(400, '신들의 골칫거리', '형벌이 더 이상 형벌로 작동하지 않는다.'),
  Tier(800, '행복한 시지프', '산정을 향한 투쟁, 그것만으로 충분하다.'),
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
  '돌은 다시 바닥으로 굴러 내려갔다.',
  '정상은 없다. 다시 밀어라.',
  '당신의 기록은 남았다. 돌은 남지 않았다.',
  '신들은 이것이 형벌이라 믿었다.',
  '내려가는 길에서, 잠시 숨을 고른다.',
  '1점. 또 1점. 그것이 전부이자 충분함이다.',
  '랭킹은 오르고, 돌은 내려간다.',
  '우리는 행복한 시지프를 상상해야 한다. — 알베르 카뮈',
];
