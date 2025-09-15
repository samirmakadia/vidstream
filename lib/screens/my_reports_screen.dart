import 'package:flutter/material.dart';
import 'package:vidmeet/services/report_service.dart';
import 'package:vidmeet/models/api_models.dart';

import '../manager/applovin_ad_manager.dart';
import '../manager/setting_manager.dart';
import '../utils/graphics.dart';
import '../utils/utils.dart';
import '../widgets/empty_section.dart';
import '../widgets/professional_bottom_ad.dart';

class MyReportsScreen extends StatefulWidget {
  final String currentUserId;

  const MyReportsScreen({
    super.key,
    required this.currentUserId,
  });

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  final ReportService _reportService = ReportService();
  List<Report> _reports = [];
  bool _isLoading = true;
  final Set<String> _deletingReports = {};
  bool _isFetchingMore = false;
  bool _hasMore = true;
  int _page = 1;
  final int _pageSize = 20;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchReports();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200 &&
          !_isFetchingMore &&
          _hasMore) {
        _fetchReports(isLoadingShow: false, refresh: false);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchReports({bool isLoadingShow = true, bool refresh = true}) async {
    if (refresh) {
      setState(() {
        _reports.clear();
        _page = 1;
        _hasMore = true;
      });
    }

    if (!_hasMore) return;

    if (isLoadingShow && _reports.isEmpty) {
      setState(() => _isLoading = true);
    } else {
      setState(() => _isFetchingMore = true);
    }

    try {
      final fetchedReports = await _reportService.getUserReports(
        widget.currentUserId,
        page: _page,
        limit: _pageSize,
      );

      setState(() {
        _reports.addAll(fetchedReports);
        _hasMore = fetchedReports.length == _pageSize;
        if (_hasMore) _page++;
        _isLoading = false;
        _isFetchingMore = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isFetchingMore = false;
      });
      if (mounted) {
        Graphics.showTopDialog(context, "Error", 'Failed to load reports: $e', type: ToastType.error);
      }
    }
  }

  Future<void> _deleteReport(Report report) async {
    setState(() => _deletingReports.add(report.id));
    try {
      await _reportService.deleteReport(report.id);
       _fetchReports(isLoadingShow: false);
      if (mounted) {
        Graphics.showTopDialog(context, "Success", 'Report deleted successfully');
      }
    } catch (e) {
      if (mounted) {
        Graphics.showTopDialog(context, "Oops!", 'Failed to delete report: $e', type: ToastType.error);
      }
    } finally {
      if (mounted) {
        setState(() => _deletingReports.remove(report.id));
      }
    }
  }

  void _showDeleteConfirmation(Report report) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Delete Report',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Are you sure you want to delete this report?\n\nThis action cannot be undone.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteReport(report);
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('My Reports'),
      ),
      body: SafeArea(
        child: ProfessionalBottomAd(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _reports.isEmpty
              ? _buildEmptyState()
              : _buildReportList()
        ),
      ),
    );
  }

  Widget _buildReportItem(Report report) {
    final isDeleting = _deletingReports.contains(report.id);
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (report.status.toLowerCase()) {
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        statusText = 'Pending Review';
        break;
      case 'reviewed':
        statusColor = Colors.blue;
        statusIcon = Icons.visibility;
        statusText = 'Under Review';
        break;
      case 'resolved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Resolved';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
        statusText = 'Unknown';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey[900]?.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey[800]!,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.report,
                    color: Colors.red,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${report.targetType.toUpperCase()} Report',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _formatDate(report.createdAt),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        statusIcon,
                        color: statusColor,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Reason
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reason: ',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Expanded(
                  child: Text(
                    report.reason,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),

            // Description (if available)
            if (report.description != null && report.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Details: ',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      report.description!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),

            // Target Info
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[800]?.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    report.targetType == 'video' ? Icons.video_library : Icons.comment,
                    color: Colors.white.withValues(alpha: 0.7),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Reported ${report.targetType} ID: ${report.targetId.substring(0, 8)}...',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: isDeleting ? null : () => _showDeleteConfirmation(report),
                  icon: isDeleting
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.red,
                    ),
                  )
                      : const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                  label: Text(
                    isDeleting ? 'Deleting...' : 'Delete Report',
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.red.withValues(alpha: 0.1),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                      side: BorderSide(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportList() {
    return SafeArea(
      child: RefreshIndicator(
          onRefresh: () => _fetchReports(),
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: Utils.getTotalItems(_reports.length, SettingManager().nativeFrequency) + (_isFetchingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (_isFetchingMore && index == Utils.getTotalItems(_reports.length, SettingManager().nativeFrequency)) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator(color: Colors.white)),
              );
            }

            if (Utils.isAdIndex(index, _reports.length, SettingManager().nativeFrequency,
                Utils.getTotalItems(_reports.length, SettingManager().nativeFrequency))) {
              if (AppLovinAdManager.isMrecAdLoaded) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: AppLovinAdManager.mrecAd(),
                );
              } else {
                return const SizedBox.shrink();
              }
            }

            final reportIndex = Utils.getUserIndex(index, _reports.length, SettingManager().nativeFrequency);
            final report = _reports[reportIndex];

            return _buildReportItem(report);
          },
        )
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: EmptySection(
        icon: Icons.report_off,
        title: 'No Reports Yet',
        subtitle:
        'You haven\'t reported any content yet.\nHelp keep our community safe by reporting inappropriate content.',
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }
}