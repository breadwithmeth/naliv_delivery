
/// Модель для пагинации
class Pagination {
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  Pagination({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  /// Создать объект Pagination из JSON
  factory Pagination.fromJson(Map<String, dynamic> json) {
    return Pagination(
      page: json['page'] ?? 1,
      limit: json['limit'] ?? 10,
      total: json['total'] ?? 0,
      totalPages: json['totalPages'] ?? 0,
    );
  }

  @override
  String toString() {
    return 'Pagination{page: $page, limit: $limit, total: $total, totalPages: $totalPages}';
  }
}
