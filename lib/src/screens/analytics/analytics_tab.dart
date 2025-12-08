import 'package:flutter/material.dart';
import '../../services/moderation_api_service.dart';
import '../../theme/app_theme.dart';

class AnalyticsTab extends StatefulWidget {
  const AnalyticsTab({super.key});

  @override
  State<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<AnalyticsTab> {
  final _moderationApi = ModerationApiService();
  bool _loading = true;
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      final users = await _moderationApi.getUsers();
      final auditLogs = await _moderationApi.getAuditLog();
      
      final totalUsers = users.length;
      final bannedUsers = users.where((u) => u['banned'] == true).length;
      final hiddenUsers = users.where((u) => u['hidden'] == true).length;
      final activeUsers = totalUsers - bannedUsers;
      
      final totalActions = auditLogs.length;
      final banActions = auditLogs.where((a) => a.action == 'ban').length;
      final hideActions = auditLogs.where((a) => a.action == 'hide' || a.action == 'hide_user').length;
      
      if (mounted) {
        setState(() {
          _stats = {
            'totalUsers': totalUsers,
            'activeUsers': activeUsers,
            'bannedUsers': bannedUsers,
            'hiddenUsers': hiddenUsers,
            'totalActions': totalActions,
            'banActions': banActions,
            'hideActions': hideActions,
          };
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading stats: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              bottom: BorderSide(color: Theme.of(context).dividerColor, width: 1),
            ),
          ),
          child: Row(
            children: [
              const Text('Analytics Dashboard', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.refresh), onPressed: _loadStats, tooltip: 'Refresh'),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('User Statistics', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildStatCard('Total Users', '${_stats['totalUsers'] ?? 0}', Icons.people, AppTheme.primaryColor)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildStatCard('Active Users', '${_stats['activeUsers'] ?? 0}', Icons.check_circle, AppTheme.successColor)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildStatCard('Banned Users', '${_stats['bannedUsers'] ?? 0}', Icons.block, AppTheme.errorColor)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildStatCard('Hidden Users', '${_stats['hiddenUsers'] ?? 0}', Icons.visibility_off, AppTheme.warningColor)),
                        ],
                      ),
                      const SizedBox(height: 32),
                      const Text('Moderation Activity', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildStatCard('Total Actions', '${_stats['totalActions'] ?? 0}', Icons.history, AppTheme.infoColor)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildStatCard('Ban Actions', '${_stats['banActions'] ?? 0}', Icons.gavel, AppTheme.errorColor)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildStatCard('Hide Actions', '${_stats['hideActions'] ?? 0}', Icons.visibility_off_outlined, AppTheme.warningColor)),
                          const SizedBox(width: 16),
                          Expanded(child: Container()),
                        ],
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[700], fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
