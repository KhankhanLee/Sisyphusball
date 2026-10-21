/// Every user-facing sentence, in one place.
abstract final class Copy {
  // title
  static const appName = 'Sisyphusball';
  static const tagline = 'There is no summit. Push anyway.';
  static const checkingAccount = 'Checking your Pi account…';
  static const signInFailed = 'Could not sign in.';
  static const openInPiBrowser = 'Please open this game in the Pi Browser.';
  static const guest = 'Guest';
  static const playSolo = 'Push Alone';
  static const playSoloHint = 'Ranked';
  static const playVersus = 'Push Together';
  static const playVersusHint = '2P · one device';
  static const hallOfFame = 'Hall of Fame';
  static const howTo = 'Hold to push the stone up. Let go and it rolls back down.\n'
      'Touch a sweeping rock and it tumbles all the way to the bottom.\n'
      '1 m = 1 point.';

  static String playerName(String name, {required bool isGuest}) => isGuest ? '$name ($guest)' : name;

  static String playerLine(String name, bool isGuest, String tier, int best) =>
      '${playerName(name, isGuest: isGuest)} · $tier${best > 0 ? ' · best ${best}m' : ''}';

  static String worldLine(int players, int runs, int meters) =>
      '$players ${players == 1 ? 'person has' : 'people have'} pushed ${_n(runs)} times, ${_n(meters)}m in all.\n'
      'Stones at the summit right now: 0';

  // guest sign-in
  static const guestDialogTitle = 'Play as Guest';
  static const guestDialogBody = 'Outside the Pi Browser you play as a guest. Choose a name.';
  static const guestNameHint = 'Your name';
  static const guestStart = 'Start';

  // in-game
  static String hudLine(String tier, int best) => '$tier · best ${best}m';

  static String liveCount(int n) => n == 1 ? '1 person is pushing right now' : '$n people are pushing right now';

  // after a solo climb
  static const recording = 'Carving your record…';
  static const newBest = 'A new best. The stone is still at the bottom.';
  static const notRecorded = 'Not recorded — the server could not be reached.';
  static const noMoreTiers = 'No title left to earn. The stone is at the bottom all the same.';
  static const pushAgain = 'Push Again';
  static const home = 'Home';

  static String bestSoFar(int best) => 'Your best: ${best}m';

  static String recordFailed(Object error) => 'Not recorded: $error';

  static String nextTier(String name, int meters) => '${meters}m to “$name”';

  static String rank(int rank, int players) => 'Rank $rank of $players';

  static String lifetime(int meters, int runs) =>
      'You have pushed ${_n(meters)}m over $runs ${runs == 1 ? 'climb' : 'climbs'}.\n'
      'Every one of those stones is at the bottom.';

  // after a 2P round
  static const versusRefrain = 'Both stones have rolled back to the bottom.';
  static const versusDraw = 'A draw. Both at the bottom.';
  static const versusCoda = 'And both will push again.';
  static const pushTogetherAgain = 'Push Together Again';

  static String versusWinner(int player) => 'P$player pushed higher.';

  static String versusScores(int a, int b) => 'P1 ${a}m · P2 ${b}m';

  // hall of fame
  static const boardSubtitle = 'Updated live. Every stone is at the bottom.';
  static const statPlayers = 'Sisyphi';
  static const statMeters = 'Pushed together';
  static const statSummit = 'At the summit';
  static const emptyBoard = 'No one has pushed the stone yet.';
  static const pushingNow = 'Pushing right now';
  static const nobodyPushing = 'No one right now. The mountain is quiet.';
  static const back = 'Back';

  static String timesPushed(int n) => n == 1 ? 'pushed once' : 'pushed $n times';

  // markers drawn on the mountain
  static String myBestMarker(int best) => 'My best ${best}m';

  static String leaderMarker(String name) => '#1 $name';

  /// 12345 -> 12,345
  static String _n(int value) {
    final s = value.toString();
    final out = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
      out.write(s[i]);
    }
    return out.toString();
  }

  static String meters(int value) => '${_n(value)}m';

  static String count(int value) => _n(value);
}
