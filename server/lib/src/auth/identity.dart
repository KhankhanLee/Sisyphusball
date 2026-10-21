/// Who is playing, as established by an [AuthStrategy].
class Identity {
  const Identity({required this.uid, required this.username, this.guest = false});

  final String uid;
  final String username;
  final bool guest;

  Map<String, dynamic> toJson() => {'username': username, 'guest': guest};
}
