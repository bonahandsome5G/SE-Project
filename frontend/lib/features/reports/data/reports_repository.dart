import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/supabase_service.dart';
import '../domain/report.dart';
import '../domain/report_comment.dart';

class NewReportPayload {
  const NewReportPayload({
    required this.categoryId,
    required this.description,
    required this.photoBytes,
    required this.photoExtension,
    required this.latitude,
    required this.longitude,
  });

  final int categoryId;
  final String description;
  final Uint8List photoBytes;
  final String photoExtension;
  final double latitude;
  final double longitude;
}

class ReportsRepository {
  final SupabaseClient _client = SupabaseService.client;
  final ApiClient _apiClient = ApiClient();

  Future<List<Report>> fetchMyReports() async {
    final response = await _apiClient.get('/citizen/reports') as List<dynamic>;

    return response.cast<Map<String, dynamic>>().map(Report.fromJson).toList();
  }

  Future<List<Report>> fetchCommunityReports() async {
    final response =
        await _apiClient.get('/citizen/community-reports') as List<dynamic>;

    return response.cast<Map<String, dynamic>>().map(Report.fromJson).toList();
  }

  Future<List<Report>> fetchNearbyReports({
    required double latitude,
    required double longitude,
    double radiusKm = 5,
  }) async {
    final response =
        await _apiClient.get(
              '/citizen/reports/nearby'
              '?latitude=$latitude&longitude=$longitude&radiusKm=$radiusKm',
            )
            as List<dynamic>;

    return response.cast<Map<String, dynamic>>().map(Report.fromJson).toList();
  }

  Future<List<ReportComment>> fetchReportComments(String reportId) async {
    final response =
        await _apiClient.get('/citizen/reports/$reportId/comments')
            as List<dynamic>;

    return response
        .cast<Map<String, dynamic>>()
        .map(ReportComment.fromJson)
        .toList();
  }

  Future<ReportComment> addReportComment({
    required String reportId,
    required String body,
  }) async {
    final response =
        await _apiClient.post('/citizen/reports/$reportId/comments', {
              'body': body,
            })
            as Map<String, dynamic>;

    return ReportComment.fromJson(response);
  }

  Future<({int upvoteCount, bool hasUpvoted})> toggleReportUpvote(
    String reportId,
  ) async {
    final response =
        await _apiClient.post('/citizen/reports/$reportId/upvote', {})
            as Map<String, dynamic>;

    return (
      upvoteCount: response['upvote_count'] as int? ?? 0,
      hasUpvoted: response['has_upvoted'] as bool? ?? false,
    );
  }

  Future<void> flagReport({
    required String reportId,
    required String reason,
  }) async {
    await _apiClient.post('/citizen/reports/$reportId/flag', {
      'reason': reason,
    });
  }

  Future<void> createReport(NewReportPayload payload) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Sesi login berakhir. Silakan login ulang.');
    }

    final fileName =
        '${user.id}/${DateTime.now().millisecondsSinceEpoch}.${payload.photoExtension}';

    await _client.storage
        .from(AppConfig.reportPhotoBucket)
        .uploadBinary(
          fileName,
          payload.photoBytes,
          fileOptions: const FileOptions(cacheControl: '3600'),
        );

    final photoUrl = _client.storage
        .from(AppConfig.reportPhotoBucket)
        .getPublicUrl(fileName);

    await _apiClient.post('/citizen/reports', {
      'categoryId': payload.categoryId,
      'description': payload.description,
      'photoUrl': photoUrl,
      'latitude': payload.latitude,
      'longitude': payload.longitude,
    });
  }
}
