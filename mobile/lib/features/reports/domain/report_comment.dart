class ReportComment {
  const ReportComment({
    required this.id,
    required this.reportId,
    required this.body,
    required this.authorName,
    this.createdAt,
  });

  final String id;
  final String reportId;
  final String body;
  final String authorName;
  final DateTime? createdAt;

  factory ReportComment.fromJson(Map<String, dynamic> json) {
    return ReportComment(
      id: json['id'] as String? ?? '',
      reportId: json['report_id'] as String? ?? '',
      body: json['body'] as String? ?? '',
      authorName: json['author_name'] as String? ?? 'Warga',
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );
  }
}
