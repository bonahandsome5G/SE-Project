class ReportModel {
  final String? id;
  final String userId;
  final int categoryId;
  final String description;
  final String photoUrl;
  final double latitude;
  final double longitude;
  final String status;
  final DateTime? createdAt;

  ReportModel({
    this.id,
    required this.userId,
    required this.categoryId,
    required this.description,
    required this.photoUrl,
    required this.latitude,
    required this.longitude,
    this.status = 'pending',
    this.createdAt,
  });

  // 1. Mengubah data Map/JSON dari Supabase menjadi Objek Dart (ReportModel)
  factory ReportModel.fromJson(Map<String, dynamic> json) {
    return ReportModel(
      id: json['id'] as String?,
      userId: json['user_id'] as String? ?? '',
      categoryId: json['category_id'] as int? ?? 0,
      description: json['description'] as String? ?? '',
      photoUrl: json['photo_url'] as String? ?? '',
      // Menangani konversi tipe data num ke double dengan aman
      latitude: (json['latitude'] as num? ?? 0.0).toDouble(),
      longitude: (json['longitude'] as num? ?? 0.0).toDouble(),
      status: json['status'] as String? ?? 'pending',
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : null,
    );
  }

  // 2. Mengubah Objek Dart menjadi Map/JSON untuk dikirim/di-insert ke Supabase
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'category_id': categoryId,
      'description': description,
      'photo_url': photoUrl,
      'latitude': latitude,
      'longitude': longitude,
      'status': status,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }
}