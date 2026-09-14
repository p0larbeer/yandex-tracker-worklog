import 'issue_ref.dart';
import 'user_ref.dart';
import '../core/utils/tracker_date.dart';

/// Запись worklog Tracker API (все основные поля ответа).
class WorklogEntry {
  const WorklogEntry({
    required this.id,
    required this.version,
    required this.issue,
    required this.start,
    required this.duration,
    this.self,
    this.comment,
    this.createdBy,
    this.updatedBy,
    this.createdAt,
    this.updatedAt,
  });

  factory WorklogEntry.fromJson(Map<String, dynamic> json) {
    final issueJson = json['issue'];
    if (issueJson is! Map<String, dynamic>) {
      throw FormatException('worklog.issue missing: $json');
    }
    return WorklogEntry(
      self: json['self'] as String?,
      id: '${json['id']}',
      version: '${json['version'] ?? ''}',
      issue: IssueRef.fromJson(issueJson),
      comment: json['comment'] as String?,
      createdBy: _userOrNull(json['createdBy']),
      updatedBy: _userOrNull(json['updatedBy']),
      createdAt: _dateOrNull(json['createdAt']),
      updatedAt: _dateOrNull(json['updatedAt']),
      start: _parseDate(json['start'], field: 'start'),
      duration: '${json['duration'] ?? ''}',
    );
  }

  static List<WorklogEntry> listFromJson(dynamic json) {
    if (json is! List) {
      throw FormatException('Expected worklog array, got: $json');
    }
    return json
        .map((e) => WorklogEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  final String? self;
  final String id;
  final String version;
  final IssueRef issue;
  final String? comment;
  final UserRef? createdBy;
  final UserRef? updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Дата/время работы (поле `start`) — основа группировки по дням.
  final DateTime start;
  final String duration;

  Map<String, dynamic> toJson() => {
    if (self != null) 'self': self,
    'id': id,
    'version': version,
    'issue': issue.toJson(),
    if (comment != null) 'comment': comment,
    if (createdBy != null) 'createdBy': createdBy!.toJson(),
    if (updatedBy != null) 'updatedBy': updatedBy!.toJson(),
    if (createdAt != null) 'createdAt': createdAt!.toUtc().toIso8601String(),
    if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
    'start': start.toUtc().toIso8601String(),
    'duration': duration,
  };

  static UserRef? _userOrNull(dynamic value) {
    if (value is Map<String, dynamic>) return UserRef.fromJson(value);
    return null;
  }

  static DateTime? _dateOrNull(dynamic value) {
    if (value == null) return null;
    return _parseDate(value, field: 'date');
  }

  static DateTime _parseDate(dynamic value, {required String field}) {
    if (value is! String || value.isEmpty) {
      throw FormatException('Missing $field');
    }
    // Tracker часто отдаёт +0000 без двоеточия — DateTime.parse это ест не всегда.
    final normalized = value.replaceFirstMapped(
      RegExp(r'([+-]\d{2})(\d{2})$'),
      (m) => '${m[1]}:${m[2]}',
    );
    return DateTime.parse(normalized);
  }
}

/// Тело создания / обновления worklog.
class WorklogWriteRequest {
  const WorklogWriteRequest({
    required this.start,
    required this.duration,
    this.comment,
  });

  final DateTime start;
  final String duration;
  final String? comment;

  Map<String, dynamic> toJson() => {
    'start': formatTrackerDate(start),
    'duration': duration,
    if (comment != null && comment!.trim().isNotEmpty) 'comment': comment,
  };
}
