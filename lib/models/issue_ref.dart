/// Краткая ссылка на задачу из ответов Tracker API.
class IssueRef {
  const IssueRef({
    required this.id,
    required this.key,
    required this.display,
    this.self,
  });

  factory IssueRef.fromJson(Map<String, dynamic> json) {
    return IssueRef(
      id: '${json['id'] ?? ''}',
      key: '${json['key'] ?? ''}',
      display:
          '${json['display'] ?? json['summary'] ?? json['key'] ?? ''}',
      self: json['self'] as String?,
    );
  }

  final String id;
  final String key;
  final String display;
  final String? self;

  Map<String, dynamic> toJson() => {
    if (self != null) 'self': self,
    'id': id,
    'key': key,
    'display': display,
  };
}
