/// Краткая ссылка на задачу из ответов Tracker API.
class IssueRef {
  const IssueRef({
    required this.id,
    required this.key,
    required this.display,
    this.self,
    this.statusKey,
    this.statusDisplay,
    this.createdAt,
    this.updatedAt,
  });

  factory IssueRef.fromJson(Map<String, dynamic> json) {
    final status = json['status'];
    String? statusKey;
    String? statusDisplay;
    if (status is Map<String, dynamic>) {
      statusKey = status['key']?.toString();
      statusDisplay = status['display']?.toString();
    } else if (status is String && status.isNotEmpty) {
      statusDisplay = status;
    }

    return IssueRef(
      id: '${json['id'] ?? ''}',
      key: '${json['key'] ?? ''}',
      display:
          '${json['display'] ?? json['summary'] ?? json['key'] ?? ''}',
      self: json['self'] as String?,
      statusKey: statusKey,
      statusDisplay: statusDisplay,
      createdAt: _dateOrNull(json['createdAt']),
      updatedAt: _dateOrNull(json['updatedAt']),
    );
  }

  final String id;
  final String key;
  final String display;
  final String? self;
  final String? statusKey;
  final String? statusDisplay;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
    if (self != null) 'self': self,
    'id': id,
    'key': key,
    'display': display,
    if (statusKey != null || statusDisplay != null)
      'status': {
        if (statusKey != null) 'key': statusKey,
        if (statusDisplay != null) 'display': statusDisplay,
      },
    if (createdAt != null) 'createdAt': createdAt!.toUtc().toIso8601String(),
    if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
  };

  static DateTime? _dateOrNull(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    final normalized = value.replaceFirstMapped(
      RegExp(r'([+-]\d{2})(\d{2})$'),
      (m) => '${m[1]}:${m[2]}',
    );
    return DateTime.tryParse(normalized);
  }
}
