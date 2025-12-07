import 'package:flutter/material.dart';
import '../../services/moderation_api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/section_header.dart';

class ReportsModerationTab extends StatefulWidget {
  const ReportsModerationTab({super.key});

  @override
  State<ReportsModerationTab> createState() => _ReportsModerationTabState();
}

class _ReportsModerationTabState extends State<ReportsModerationTab> {
  final _moderationApi = ModerationApiService();
  List<dynamic> _reports = [];
  bool _loading = true;
  String _statusFilter = 'pending';

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _loading = true);
    try {
      final reports = await _moderationApi.getReports(
        status: _statusFilter == 'all' ? null : _statusFilter,
      );
      if (mounted) {
        setState(() {
          _reports = reports;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading reports: $e')),
        );
      }
    }
  }

  Future<void> _resolveReport(dynamic report, String action) async {
    String? notes;
    if (action != 'dismissed') {
      notes = await _showNotesDialog('Resolution Notes', 'Optional notes:');
    }

    try {
      await _moderationApi.resolveReport(
        reportId: report['id'],
        action: action,
        notes: notes,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report ${action}'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        _loadReports();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<String?> _showNotesDialog(String title, String hint) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: hint),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('SUBMIT'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return AppTheme.warningColor;
      case 'dismissed':
        return Colors.grey;
      case 'actioned':
        return AppTheme.successColor;
      default:
        return AppTheme.infoColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header with filters
        Container(
          padding: const EdgeInsets.all(16),
          color: AppTheme.surfaceColor,
          child: Row(
            children: [
              const Text('Reports', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const Spacer(),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'pending', label: Text('Pending')),
                  ButtonSegment(value: 'actioned', label: Text('Actioned')),
                  ButtonSegment(value: 'all', label: Text('All')),
                ],
                selected: {_statusFilter},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() => _statusFilter = newSelection.first);
                  _loadReports();
                },
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadReports,
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Reports list
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _reports.isEmpty
                  ? const Center(child: Text('No reports found'))
                  : ListView.builder(
                      itemCount: _reports.length,
                      itemBuilder: (context, index) {
                        final report = _reports[index];
                        final status = report['status'] ?? 'pending';
                        
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(status),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        status.toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Report ${report['targetType']?.toUpperCase() ?? 'ITEM'}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                
                                // Reason
                                Row(
                                  children: [
                                    const Icon(Icons.report_problem, size: 16, color: AppTheme.textSecondary),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Reason: ${report['reason'] ?? 'No reason'}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                
                                if (report['description'] != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    report['description'],
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                                
                                const SizedBox(height: 8),
                                Text(
                                  'Reported by: ${report['reportedBy'] ?? 'Unknown'}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textTertiary,
                                  ),
                                ),
                                
                                if (status == 'pending') ...[
                                  const SizedBox(height: 16),
                                  // Actions
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: () => _resolveReport(report, 'dismissed'),
                                        icon: const Icon(Icons.close, size: 18),
                                        label: const Text('Dismiss'),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton.icon(
                                        onPressed: () => _resolveReport(report, 'actioned'),
                                        icon: const Icon(Icons.check, size: 18),
                                        label: const Text('Mark Actioned'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.successColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
