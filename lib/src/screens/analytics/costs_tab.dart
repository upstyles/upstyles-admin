import 'package:flutter/material.dart';
import '../../services/moderation_api_service.dart';
import '../../widgets/admin_components.dart';
import '../../theme/app_theme.dart';
import 'package:url_launcher/url_launcher_string.dart';

class CostsTab extends StatefulWidget {
  // optional injected API client for testing
  final ModerationApiService? api;
  const CostsTab({Key? key, this.api}) : super(key: key);

  @override
  State<CostsTab> createState() => _CostsTabState();
}

class _CostsTabState extends State<CostsTab> {
  ModerationApiService? _defaultApi;
  bool _loading = true;
  Map<String, dynamic> _stats = {};
  final Map<String, bool> _toggles = {
    'clientPreFilter': true,
    'sampling': true,
    'cache': true,
    'budgetAlerts': true,
  };

  @override
  void initState() {
    super.initState();
    _load();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    try {
      final apiClient = widget.api ?? _defaultApi ?? ( _defaultApi = ModerationApiService());
      final prefs = await apiClient.getAdminPrefs();
      if (!mounted) return;
      // Map persisted toggles into local toggles if present
      setState(() {
        _toggles['clientPreFilter'] = prefs['clientPreFilter'] ?? _toggles['clientPreFilter'];
        _toggles['sampling'] = prefs['sampling'] ?? _toggles['sampling'];
        _toggles['cache'] = prefs['cache'] ?? _toggles['cache'];
        _toggles['budgetAlerts'] = prefs['budgetAlerts'] ?? _toggles['budgetAlerts'];
      });
    } catch (e) {
      // ignore prefs load errors
      debugPrint('[CostsTab] Failed to load prefs: $e');
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final apiClient = widget.api ?? (_defaultApi ??= ModerationApiService());
      final monthly = await apiClient.getModerationMonthlyCost();
      final statsResp = await apiClient.getModerationStats();

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
                      // Alert banner when approaching threshold
                      _buildAlertBanner(),
                      const SizedBox(height: 12),
                      const Text('Recommendations', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      _buildToggleableRecommendations(),
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

  Widget _buildAlertBanner() {
    final totalCost = (_stats['monthly']?['totalCost'] ?? 0).toDouble();
    final threshold = (_stats['monthly']?['threshold'] ?? 100).toDouble();
    if (threshold <= 0) return const SizedBox.shrink();
    final pct = totalCost / threshold;
    if (pct < 0.75) return const SizedBox.shrink();

    final isCritical = pct >= 1.0;
    final color = isCritical ? AppTheme.errorColor : Colors.orange;
    final title = isCritical
        ? 'Vision API cost exceeded threshold'
        : 'Vision API cost approaching threshold';
    final message = isCritical
        ? 'Monthly cost (\$${totalCost.toStringAsFixed(2)}) exceeded threshold (\$${threshold.toStringAsFixed(2)}). Take action.'
        : 'Monthly cost is at ${(pct * 100).toStringAsFixed(0)}% of threshold (\$${threshold.toStringAsFixed(2)}). Consider optimizations.';

    return AdminCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(isCritical ? Icons.error : Icons.warning, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 4),
                Text(message),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () {
              // Link to quick actions (setup guide)
              launchUrlString('https://raw.githubusercontent.com/upstyles/explore-api/main/VISION_API_QUICKSTART.md');
            },
            icon: const Icon(Icons.launch),
            label: const Text('View Guide'),
            style: ElevatedButton.styleFrom(foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleableRecommendations() {
    // Helper to render a toggle row with optional link
    Widget toggleRow({required String keyName, required String title, required String description, String? docUrl}) {
      return AdminCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(description),
                  if (docUrl != null) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => launchUrlString(docUrl),
                      child: const Text('Open guide'),
                    ),
                  ],
                ],
              ),
            ),
            Switch(
              value: _toggles[keyName] ?? false,
              onChanged: (v) async {
                setState(() => _toggles[keyName] = v);
                await _savePrefs();
              },
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        toggleRow(
          keyName: 'clientPreFilter',
          title: 'Client-side pre-filtering',
          description: 'Run a lightweight NSFW check in the client to avoid needless server calls.',
          docUrl: 'https://raw.githubusercontent.com/upstyles/explore-api/main/VISION_API_QUICKSTART.md',
        ),
        const SizedBox(height: 8),
        toggleRow(
          keyName: 'sampling',
          title: 'Sampling for multi-image submissions',
          description: 'Check 1–2 representative images rather than scanning all.',
        ),
        const SizedBox(height: 8),
        toggleRow(
          keyName: 'cache',
          title: 'Cache moderation results',
          description: 'Reuse previous results for identical images to reduce calls.',
        ),
        const SizedBox(height: 8),
        toggleRow(
          keyName: 'budgetAlerts',
          title: 'Budget Alerts',
          description: 'Enable Cloud Billing budgets and email notifications.',
          docUrl: 'https://console.cloud.google.com/billing/budgets',
        ),
      ],
    );
  }

  // Persist toggle state to admin prefs when changed
  Future<void> _savePrefs() async {
    try {
      final apiClient = widget.api ?? _defaultApi ?? ( _defaultApi = ModerationApiService());
      await apiClient.setAdminPrefs({
        'clientPreFilter': _toggles['clientPreFilter'],
        'sampling': _toggles['sampling'],
        'cache': _toggles['cache'],
        'budgetAlerts': _toggles['budgetAlerts'],
      });
    } catch (e) {
      debugPrint('[CostsTab] Failed to save prefs: $e');
    }
  }

}
