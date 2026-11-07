/// Words a player paid to leave on the mountain at a height they reached.
class Carving {
  const Carving({required this.id, required this.username, required this.height, required this.text, required this.at});

  factory Carving.fromJson(Map<String, dynamic> j) => Carving(
        id: j['id'] as String,
        username: j['username'] as String,
        height: j['height'] as int,
        text: j['text'] as String,
        at: j['at'] as int? ?? 0,
      );

  /// The Pi payment identifier that paid for it.
  final String id;
  final String username;
  final int height;
  final String text;
  final int at; // ms since epoch

  /// What clients see (the payment id stays on the server).
  Map<String, dynamic> toPublicJson() => {'username': username, 'height': height, 'text': text, 'at': at};

  Map<String, dynamic> toJson() => {'id': id, ...toPublicJson()};
}

const maxCarvingLength = 40;

final _linkLike = RegExp(r'(https?:|www\.|\w\.(com|net|org|io|app|me|xyz|link|ly|gg|co|kr)\b)', caseSensitive: false);
final _control = RegExp(r'[\u0000-\u001F\u007F-\u009F\u200B-\u200F\u202A-\u202E\u2066-\u2069]');

/// The text as it will be carved, or null when it cannot be: empty, longer
/// than [maxCarvingLength], or carrying a link or control characters.
String? cleanCarvingText(Object? raw) {
  if (raw is! String) return null;
  if (_control.hasMatch(raw.replaceAll(RegExp(r'[\t\n\r]'), ' '))) return null;
  final text = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (text.isEmpty || text.runes.length > maxCarvingLength) return null;
  if (_linkLike.hasMatch(text)) return null;
  return text;
}
