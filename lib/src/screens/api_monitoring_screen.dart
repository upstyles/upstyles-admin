import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// API Monitoring screen for tracking API usage and costs
class ApiMonitoringScreen extends StatefulWidget {
  const ApiMonitoringScreen({super.key});

  @override
  State<ApiMonitoringScreen> createState() => _ApiMonitoringScreenState();
}

class _ApiMonitoringScreenState extends State<ApiMonitoringScreen> {
  final _firestore = FirebaseFirestore.instance;
  String _selectedPeriod = 'today';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Monitoring'),
        actions: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'today', label: Text('Today')),
              ButtonSegment(value: 'week', label: Text('Week')),
              ButtonSegment(value: 'month', label: Text('Month')),
            ],
            selected: {_selectedPeriod},
            onSelectionChanged: (Set<String> selected) {
              setState(() => _selectedPeriod = selected.first);
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Product API Section
            _buildProductApiSection(),
            const SizedBox(height: 24),
            
            // YouTube API Section
            _buildYouTubeApiSection(),
            const SizedBox(height: 24),
            
            // Recent API Calls
            _buildRecentCallsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildProductApiSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shopping_bag, size: 32, color: Colors.blue),
                const SizedBox(width: 12),
                const Text(
                  'Product API (Amazon)',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildApiMetrics('product_api_logs', Colors.blue),
          ],
        ),
      ),
    );
  }

  Widget _buildYouTubeApiSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.play_circle, size: 32, color: Colors.red),
                const SizedBox(width: 12),
                const Text(
                  'YouTube Data API',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildApiMetrics('youtube_api_logs', Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _buildApiMetrics(String collection, Color color) {
    final now = DateTime.now();
    DateTime startDate;
    
    switch (_selectedPeriod) {
      case 'today':
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case 'week':
        startDate = now.subtract(const Duration(days: 7));
        break;
      case 'month':
        startDate = now.subtract(const Duration(days: 30));
        break;
      default:
        startDate = DateTime(now.year, now.month, now.day);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection(collection)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final logs = snapshot.data!.docs;
        final totalRequests = logs.length;
        final successfulRequests = logs.where((doc) => 
          (doc.data() as Map<String, dynamic>)['success'] == true
        ).length;
        final failedRequests = totalRequests - successfulRequests;

        // Calculate estimated cost
        final double estimatedCost = collection == 'product_api_logs'
            ? totalRequests * 0.005 // $0.005 per request (estimate)
            : totalRequests * 0.001; // YouTube quota units

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Total Requests',
                    totalRequests.toString(),
                    Icons.api,
                    color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    'Successful',
                    successfulRequests.toString(),
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    'Failed',
                    failedRequests.toString(),
                    Icons.error,
                    Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    collection == 'product_api_logs' ? 'Est. Cost' : 'Quota Used',
                    collection == 'product_api_logs' 
                        ? '\$${estimatedCost.toStringAsFixed(2)}'
                        : estimatedCost.toStringAsFixed(0),
                    Icons.attach_money,
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentCallsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent API Calls',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildRecentCallsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentCallsList() {
    return StreamBuilder<List<QueryDocumentSnapshot>>(
      stream: Stream.fromFutures([
        _firestore
            .collection('product_api_logs')
            .orderBy('timestamp', descending: true)
            .limit(10)
            .get(),
        _firestore
            .collection('youtube_api_logs')
            .orderBy('timestamp', descending: true)
            .limit(10)
            .get(),
      ]).asyncMap((snapshots) async {
        final combined = <QueryDocumentSnapshot>[];
        for (final snapshot in snapshots) {
          combined.addAll(snapshot.docs);
        }
        combined.sort((a, b) {
          final aTime = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp;
          final bTime = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp;
          return bTime.compareTo(aTime);
        });
        return combined.take(20).toList();
      }),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final logs = snapshot.data!;

        if (logs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Text('No API calls yet'),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: logs.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, index) {
            final log = logs[index];
            final data = log.data() as Map<String, dynamic>;
            final timestamp = (data['timestamp'] as Timestamp).toDate();
            final isProduct = log.reference.parent.id == 'product_api_logs';
            final success = data['success'] ?? false;

            return ListTile(
              leading: Icon(
                isProduct ? Icons.shopping_bag : Icons.play_circle,
                color: isProduct ? Colors.blue : Colors.red,
              ),
              title: Text(
                data['endpoint'] ?? data['query'] ?? 'Unknown',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                DateFormat('MMM d, h:mm a').format(timestamp),
              ),
              trailing: Icon(
                success ? Icons.check_circle : Icons.error,
                color: success ? Colors.green : Colors.red,
              ),
            );
          },
        );
      },
    );
  }
}
