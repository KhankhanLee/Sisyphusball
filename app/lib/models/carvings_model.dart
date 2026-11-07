import 'package:flutter/foundation.dart';
import 'package:sisyphus_core/sisyphus_core.dart';

import '../data/models.dart';
import '../events.dart';

/// The words carved into the mountain, and what carving costs.
/// Observes LiveFeed (everyone's carvings, live).
class CarvingsModel extends ChangeNotifier implements Observer<AppEvent> {
  List<Carving> carvings = const [];

  /// In π; null while payments are off.
  double? price;

  void setPrice(double? value) {
    price = value;
    notifyListeners();
  }

  @override
  void onEvent(AppEvent event) {
    if (event case CarvingsUpdated(:final carvings)) {
      this.carvings = carvings;
      notifyListeners();
    }
  }
}
