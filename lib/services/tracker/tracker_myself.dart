/// Ответ `GET /v3/myself`.
class TrackerMyself {
  const TrackerMyself({
    required this.id,
    required this.display,
    this.email,
  });

  factory TrackerMyself.fromJson(Map<String, dynamic> json) {
    return TrackerMyself(
      id: '${json['login'] ?? json['uid'] ?? json['id'] ?? ''}',
      display: '${json['display'] ?? json['login'] ?? json['id'] ?? ''}',
      email: json['email'] as String?,
    );
  }

  final String id;
  final String display;
  final String? email;
}
