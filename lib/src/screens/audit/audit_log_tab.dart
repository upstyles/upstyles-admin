import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/logger.dart';
import 'package:intl/intl.dart';

class AuditLogTab extends StatefulWidget {
  const AuditLogTab({super.key});

  @override
  State<AuditLogTab> createState() => _AuditLogTabState();
}

class _AuditLogTabState extends State<AuditLogTab> {
  final _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = false;
  String _filterAction = 'all'; // all, approve, reject, remove, suspend

  @override
  void initState() {
    super.initState();
    _loadAuditLogs();
  }

  Future<void> _loadAuditLogs() async {
    setState(() => _isLoading = true);
    
    try {
      Query query = _firestore
          .collection('moderation_audit_log')
          .orderBy('timestamp', descending: true)
          .limit(100);

      if (_filterAction != 'all') {
        query = query.where('action', isEqualTo: _filterAction);
      }

      final snapshot = await query.get();
      
      setState(() {
        _logs = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return data;
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('Error loading audit logs', error: e);
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter bar
        Container(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              const Text('Action: '),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _filterAction,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All')),
                  DropdownMenuItem(value: 'approve', child: Text('Approvals')),
                  DropdownMenuItem(value: 'reject', child: Text('Rejections')),
                  DropdownMenuItem(value: 'remove', child: Text('Removals')),
                  DropdownMenuItem(value: 'suspend', child: Text('Suspensions')),
                ],
                onChanged: (value) {
                  setState(() => _filterAction = value!);
                  _loadAuditLogs();
                },
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadAuditLogs,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        
        Expanded(child: _buildLogsList()),
      ],
    );
  }

  Widget _buildLogsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_logs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('No audit logs', style: TextStyle(fontSize: 20)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _logs.length,
      itemBuilder: (context, index) => _buildLogCard(_logs[index]),
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log) {
    final dateFormat = DateFormat('MMM d, yyyy • h:mm:ss a');
    final timestamp = (log['timestamp'] as Timestamp?)?.toDate();
    final action = log['action'] ?? 'unknown';
    final moderator = log['moderatorId'] ?? 'Unknown';
    
    IconData icon;
    Color color;
    
    switch (action) {
      case 'approve':
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case 'reject':
        icon = Icons.cancel;
        color = Colors.red;
        break;
      case 'remove':
        icon = Icons.delete;
        color = Colors.orange;
        break;
      case 'suspend':
        icon = Icons.block;
        color = Colors.purple;
        break;
      default:
        icon = Icons.info;
        color = Colors.blue;
    }
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(
          action.toUpperCase(),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Moderator: $moderator'),
            if (timestamp != null)
              Text(dateFormat.format(timestamp)),
            if (log['targetType'] != null)
              Text('Target: ${log['targetType']} (${log['targetId']})'),
            if (log['reason'] != null)
              Text('Reason: ${log['reason']}'),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}
