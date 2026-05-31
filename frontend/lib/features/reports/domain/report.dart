class Report {
  const Report({
    this.id,
    required this.userId,
    required this.categoryId,
    required this.categoryName,
    required this.description,
    required this.photoUrl,
    required this.latitude,
    required this.longitude,
    required this.status,
    this.upvoteCount = 0,
    this.commentCount = 0,
    this.hasUpvoted = false,
    this.createdAt,
  });

  final String? id;
  final String userId;
  final int categoryId;
  final String categoryName;
  final String description;
  final String photoUrl;
  final double latitude;
  final double longitude;
  final String status;
  final int upvoteCount;
  final int commentCount;
  final bool hasUpvoted;
  final DateTime? createdAt;

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: json['id']?.toString(),
      userId: json['user_id'] as String? ?? '',
      categoryId: json['category_id'] as int? ?? 0,
      categoryName: json['category_name'] as String? ?? 'Kategori laporan',
      description: json['description'] as String? ?? '',
      photoUrl: json['photo_url'] as String? ?? '',
      latitude: (json['latitude'] as num? ?? 0).toDouble(),
      longitude: (json['longitude'] as num? ?? 0).toDouble(),
      status: json['status'] as String? ?? 'pending',
      upvoteCount: json['upvote_count'] as int? ?? 0,
      commentCount: json['comment_count'] as int? ?? 0,
      hasUpvoted: json['has_upvoted'] as bool? ?? false,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );
  }

  Report copyWith({int? upvoteCount, int? commentCount, bool? hasUpvoted}) {
    return Report(
      id: id,
      userId: userId,
      categoryId: categoryId,
      categoryName: categoryName,
      description: description,
      photoUrl: photoUrl,
      latitude: latitude,
      longitude: longitude,
      status: status,
      upvoteCount: upvoteCount ?? this.upvoteCount,
      commentCount: commentCount ?? this.commentCount,
      hasUpvoted: hasUpvoted ?? this.hasUpvoted,
      createdAt: createdAt,
    );
  }
}
