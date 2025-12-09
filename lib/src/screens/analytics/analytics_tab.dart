import 'package:flutter/material.dart';
import '../../services/moderation_api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_components.dart';

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
            // moderation cost placeholders
            'visionTotalCost': 0.0,
            'visionTotalImages': 0,
            'visionAvgCostPerImage': 0.0,
            'visionByDay': {},
          };
          _loading = false;
        });
      }
      // Fetch moderation cost stats separately (don't block UI)
      _loadModerationCostStats();
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading stats: $e')),
        );
      }
    }
  }

  Future<void> _loadModerationCostStats() async {
    try {
      final monthly = await _moderationApi.getModerationMonthlyCost();
      final statsResp = await _moderationApi.getModerationStats();
      if (mounted) {
        setState(() {
          _stats['visionTotalCost'] = (monthly['totalCost'] ?? 0).toDouble();
          _stats['visionTotalImages'] = monthly['totalImages'] ?? 0;
          _stats['visionAvgCostPerImage'] = monthly['averageCostPerImage'] ?? 0.0;
          final byDay = (statsResp['stats'] != null ? statsResp['stats']['byDay'] : statsResp['byDay']) ?? {};
          _stats['visionByDay'] = byDay;
        });
      }
    } catch (e) {
      // non-fatal
      debugPrint('Failed to load moderation cost stats: $e');
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
                      const SizedBox(height: 32),
                      const Text('Moderation Costs (Vision API)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildStatCard('This Month Cost', '\$${(_stats['visionTotalCost'] ?? 0).toStringAsFixed(2)}', Icons.monetization_on, AppTheme.infoColor)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildStatCard('Images Processed', '${_stats['visionTotalImages'] ?? 0}', Icons.image, AppTheme.primaryColor)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildStatCard('Avg Cost / Image', '\$${(_stats['visionAvgCostPerImage'] ?? 0).toStringAsFixed(4)}', Icons.pie_chart, AppTheme.successColor)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const SizedBox(height: 8),
                      _buildByDayList(),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return AdminCard(
      padding: const EdgeInsets.all(20),
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

  Widget _buildByDayList() {
    final byDay = _stats['visionByDay'] as Map<String, dynamic>? ?? {};
    if (byDay.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('No moderation cost data available yet.'),
      );
    }

    final entries = byDay.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    return AdminCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Daily breakdown', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...entries.map((e) {
            final date = e.key;
            final obj = e.value as Map<String, dynamic>;
            final images = obj['images'] ?? 0;
            final cost = (obj['cost'] ?? 0).toDouble();
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(child: Text(date)),
                  Text('$images imgs', style: const TextStyle(color: Colors.grey)),
                  const SizedBox(width: 12),
                  Text('\$${cost.toStringAsFixed(3)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
