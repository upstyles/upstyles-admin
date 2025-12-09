import 'package:flutter/material.dart';
import '../../services/moderation_api_service.dart';
import '../../widgets/admin_components.dart';
import '../../theme/app_theme.dart';

class CostsTab extends StatefulWidget {
  const CostsTab({super.key});

  @override
  State<CostsTab> createState() => _CostsTabState();
}

class _CostsTabState extends State<CostsTab> {
  final _api = ModerationApiService();
  bool _loading = true;
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final monthly = await _api.getModerationMonthlyCost();
      final statsResp = await _api.getModerationStats();

      setState(() {
        _stats['monthly'] = monthly;
        _stats['byDay'] = statsResp['stats'] != null ? statsResp['stats']['byDay'] : (statsResp['byDay'] ?? {});
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load cost data: $e')),
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
            border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor, width: 1)),
          ),
          child: Row(
            children: [
              const Text('Costs & Recommendations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.refresh), onPressed: _load, tooltip: 'Refresh'),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildCard('This Month Cost', '\$${(_stats['monthly']?['totalCost'] ?? 0).toStringAsFixed(2)}', Icons.monetization_on, AppTheme.infoColor)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildCard('Images Processed', '${_stats['monthly']?['totalImages'] ?? 0}', Icons.image, AppTheme.primaryColor)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildCard('Avg Cost / Image', '\$${(_stats['monthly']?['averageCostPerImage'] ?? 0).toStringAsFixed(4)}', Icons.pie_chart, AppTheme.successColor)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text('Daily Cost Breakdown', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      _buildByDayList(),
                      const SizedBox(height: 24),
                      const Text('Recommendations', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      _buildRecommendations(),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildCard(String label, String value, IconData icon, Color color) {
    return AdminCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        ],
      ),
    );
  }

  Widget _buildByDayList() {
    final byDay = _stats['byDay'] as Map<String, dynamic>? ?? {};
    if (byDay.isEmpty) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('No data'));
    }
    final entries = byDay.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
    return AdminCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: entries.map((e) {
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
      ),
    );
  }

  Widget _buildRecommendations() {
    return AdminCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('1. Enable client-side pre-filtering', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('Use a lightweight NSFW check (nsfwjs) before upload to avoid unnecessary Vision API calls.'),
          const SizedBox(height: 12),
          const Text('2. Sample images for multi-image submissions', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('For submissions with many images, check 1-2 representative images instead of all.'),
          const SizedBox(height: 12),
          const Text('3. Cache moderation results', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('Store results for images previously scanned to avoid duplicate calls.'),
          const SizedBox(height: 12),
          const Text('4. Set up budget alerts & monitoring', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('Use Cloud Billing budgets and the admin monthly cost endpoint to detect spikes.'),
        ],
      ),
    );
  }
}
