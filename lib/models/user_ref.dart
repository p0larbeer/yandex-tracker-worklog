/// Краткая ссылка на пользователя из ответов Tracker API.
class UserRef {
  const UserRef({
    required this.id,
    required this.display,
    this.self,
  });

  factory UserRef.fromJson(Map<String, dynamic> json) {
    return UserRef(
      id: '${json['id'] ?? json['login'] ?? ''}',
      display: '${json['display'] ?? json['id'] ?? ''}',
      self: json['self'] as String?,
    );
  }

  final String id;
  final String display;
  final String? self;

  Map<String, dynamic> toJson() => {
    if (self != null) 'self': self,
    'id': id,
    'display': display,
  };
}
