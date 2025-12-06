import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/logger.dart';

class AnalyticsTab extends StatefulWidget {
  const AnalyticsTab({super.key});

  @override
  State<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<AnalyticsTab> {
  final _firestore = FirebaseFirestore.instance;
  bool _loading = true;
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _loading = true);
    try {
      // Fetch real-time stats from Firestore
      final submissions = await _firestore.collection('explore_submissions').get();
      
      final total = submissions.docs.length;
      final pending = submissions.docs.where((d) => d.data()['status'] == 'pending').length;
      final approved = submissions.docs.where((d) => d.data()['status'] == 'approved').length;
      final rejected = submissions.docs.where((d) => d.data()['status'] == 'rejected').length;
      
      // Calculate approval rate
      final reviewed = approved + rejected;
      final approvalRate = reviewed > 0 ? (approved / reviewed * 100) : 0.0;
      
      // Top tags
      final tagCounts = <String, int>{};
      for (final doc in submissions.docs) {
        final tags = List<String>.from(doc.data()['tags'] ?? []);
        for (final tag in tags) {
          tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
        }
      }
      final topTags = tagCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      setState(() {
        _stats = {
          'total': total,
          'pending': pending,
          'approved': approved,
          'rejected': rejected,
          'approvalRate': approvalRate,
          'topTags': topTags.take(10).toList(),
        };
        _loading = false;
      });
    } catch (e) {
      AppLogger.error('Error loading analytics: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadAnalytics,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOverviewCards(),
            const SizedBox(height: 24),
            _buildApprovalRate(),
            const SizedBox(height: 24),
            _buildTopTags(),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCards() {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _buildStatCard('Total', '${_stats['total']}', Icons.article, Colors.blue),
        _buildStatCard('Pending', '${_stats['pending']}', Icons.pending, Colors.orange),
        _buildStatCard('Approved', '${_stats['approved']}', Icons.check_circle, Colors.green),
        _buildStatCard('Rejected', '${_stats['rejected']}', Icons.cancel, Colors.red),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildApprovalRate() {
    final rate = _stats['approvalRate'] ?? 0.0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Approval Rate', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: rate / 100,
                    minHeight: 20,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      rate > 70 ? Colors.green : rate > 50 ? Colors.orange : Colors.red,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text('${rate.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopTags() {
    final topTags = _stats['topTags'] as List<MapEntry<String, int>>? ?? [];
    if (topTags.isEmpty) return const SizedBox.shrink();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Top Tags', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...topTags.map((entry) {
              final percentage = (entry.value / _stats['total'] * 100).toStringAsFixed(1);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(child: Text('#${entry.key}')),
                    Text('${entry.value} ($percentage%)', style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}
