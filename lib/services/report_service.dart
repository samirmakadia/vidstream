import 'package:vidmeet/models/api_models.dart';
import 'package:vidmeet/repositories/api_repository.dart';

import '../models/response_model.dart';

class ReportService {
  ApiRepository get _apiRepository => ApiRepository.instance;

  // Report content (video or comment)
  Future<String> reportContent({
    required String reporterId,
    required String targetId,
    required String targetType,
    required String reason,
    String? description,
  }) async {
    try {
      final report = await _apiRepository.api.createReport(
        reportType: 'content',
        targetId: targetId,
        targetType: targetType,
        reason: reason,
        description: description,
      );

      if (report != null) {
        return 'Report submitted successfully';
      }

      return 'Report could not be submitted';
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return 'Failed to submit report: $e';
    }
  }




  // Report user
  Future<String> reportUser({
    required String reporterId,
    required String targetUserId,
    required String reason,
    String? description,
  }) async {
    return await reportContent(
      reporterId: reporterId,
      targetId: targetUserId,
      targetType: 'user',
      reason: reason,
      description: description,
    );
  }

  // Report video
  Future<String> reportVideo({
    required String reporterId,
    required String videoId,
    required String reason,
    String? description,
  }) async {
    return await reportContent(
      reporterId: reporterId,
      targetId: videoId,
      targetType: 'video',
      reason: reason,
      description: description,
    );
  }

  // Report comment
  Future<String> reportComment({
    required String reporterId,
    required String commentId,
    required String reason,
    String? description,
  }) async {
    return await reportContent(
      reporterId: reporterId,
      targetId: commentId,
      targetType: 'comment',
      reason: reason,
      description: description,
    );
  }

  // Get user's reports
  Future<List<Report>> getUserReports(String userId, {int page = 1, int limit = 30}) async {
    try {
      final response = await _apiRepository.api.getUserReports(page: page, limit: limit);
      return response?.data ?? [];
    } catch (e) {
      print('Error getting user reports: $e');
      return [];
    }
  }

  // Get reports by reporter (alias for backward compatibility)
  Future<List<Report>> getReportsByReporter(String reporterId) async {
    return getUserReports(reporterId);
  }

  // Update report status (admin only)
  Future<void> updateReportStatus(String reportId, String status) async {
    try {
      await _apiRepository.api.updateReportStatus(reportId: reportId, status: status);
    } catch (e) {
      throw 'Failed to update report status: $e';
    }
  }

  // Delete report
  Future<void> deleteReport(String reportId) async {
    try {
      await _apiRepository.api.deleteReport(reportId);
    } catch (e) {
      throw 'Failed to delete report: $e';
    }
  }
}