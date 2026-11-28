import 'package:flutter_test/flutter_test.dart';
import 'package:sisyphus_core/sisyphus_core.dart';
import 'package:sisyphusball/game/sprites.dart';
import 'package:sisyphusball/models/carvings_model.dart';
import 'package:sisyphusball/models/leaderboard_model.dart';
import 'package:sisyphusball/models/look_model.dart';
import 'package:sisyphusball/models/player_model.dart';
import 'package:sisyphusball/models/presence_model.dart';
import 'package:sisyphusball/models/scene_overlay_model.dart';

void main() {
  testWidgets('every Sisyphe skin has a sprite, and the game draws the one being worn', (tester) async {
    final sprites = Sprites();
    await tester.runAsync(sprites.load);
    for (final skin in skinsOf('her')) {
      expect(sprites.of(skin.id), isNotNull, reason: skin.id);
    }
    expect(sprites.of('him-exile'), isNull, reason: 'Sisyphus keeps the drawn figure');

    final looks = LookModel();
    final overlay = SceneOverlayModel(
      player: PlayerModel(),
      leaderboard: LeaderboardModel(),
      presence: PresenceModel(),
      carvings: CarvingsModel(),
      looks: looks,
      sprites: sprites,
    );
    expect(overlay.sprite, isNull);
    looks.apply({
      'look': {'character': 'her', 'skin': 'her-herald'},
      'owned': ['her-herald'],
    });
    expect(overlay.sprite, same(sprites.of('her-herald')));
  });
}
