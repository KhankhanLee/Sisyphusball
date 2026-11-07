import 'dart:convert';
import 'dart:io';

import 'carving.dart';

/// Keeps the newest [limit] carvings, optionally mirrored to a JSON file.
class CarvingStore {
  CarvingStore({this.path, this.limit = 1000});

  final String? path;
  final int limit;
  final List<Carving> _items = [];

  List<Carving> get all => List.unmodifiable(_items);

  bool has(String id) => _items.any((c) => c.id == id);

  Future<void> load() async {
    final p = path;
    if (p == null || !await File(p).exists()) return;
    final data = jsonDecode(await File(p).readAsString()) as Map<String, dynamic>;
    _items
      ..clear()
      ..addAll([for (final j in data['carvings'] as List? ?? const []) Carving.fromJson(j as Map<String, dynamic>)]);
  }

  /// Adds [c] and writes the file before returning, so a paid carving is
  /// durable once the payment is completed.
  Future<void> add(Carving c) async {
    _items.add(c);
    if (_items.length > limit) _items.removeRange(0, _items.length - limit);
    final p = path;
    if (p == null) return;
    final file = File(p);
    await file.parent.create(recursive: true);
    final tmp = File('$p.$pid.tmp');
    await tmp.writeAsString(jsonEncode({'carvings': [for (final c in _items) c.toJson()]}), flush: true);
    await tmp.rename(p);
  }
}
