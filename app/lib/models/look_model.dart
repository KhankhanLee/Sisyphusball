import 'package:flutter/foundation.dart';
import 'package:sisyphus_core/sisyphus_core.dart';

/// What the player wears and which skins they own.
class LookModel extends ChangeNotifier {
  Look look = Look.standard;
  Set<String> owned = {};

  /// Whether skins can be bought here (the server takes Pi payments).
  bool shopOpen = false;

  /// The skin being bought right now, if any.
  String? buying;

  bool owns(Skin skin) => skin.free || owned.contains(skin.id);

  bool wears(Skin skin) => look.skinId == skin.id;

  /// Takes the server's `{look, owned}`.
  void apply(Map<String, dynamic> state) {
    look = Look.fromJson(state['look']);
    owned = {for (final s in state['owned'] as List? ?? const []) s as String};
    notifyListeners();
  }

  void setShopOpen(bool open) {
    shopOpen = open;
    notifyListeners();
  }

  void setBuying(String? skinId) {
    buying = skinId;
    notifyListeners();
  }
}
