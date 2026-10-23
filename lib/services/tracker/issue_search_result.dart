import '../../models/issue_ref.dart';

/// Страница результатов поиска задач (+ метаданные пагинации Tracker).
class IssueSearchResult {
  const IssueSearchResult({
    required this.issues,
    required this.page,
    required this.perPage,
    this.totalCount,
    this.totalPages,
  });

  factory IssueSearchResult.empty({int page = 1, int perPage = 10}) {
    return IssueSearchResult(
      issues: const [],
      page: page,
      perPage: perPage,
      totalCount: 0,
      totalPages: 0,
    );
  }

  final List<IssueRef> issues;
  final int page;
  final int perPage;
  final int? totalCount;
  final int? totalPages;

  bool get hasMore {
    if (totalPages != null && totalPages! > 0) {
      return page < totalPages!;
    }
    if (totalCount != null) {
      return page * perPage < totalCount!;
    }
    return issues.length >= perPage;
  }
}
