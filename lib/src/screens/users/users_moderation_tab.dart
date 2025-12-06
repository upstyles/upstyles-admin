import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/logger.dart';
import '../../services/user_quality_service.dart';
import 'package:intl/intl.dart';

class UsersModerationTab extends StatefulWidget {
  const UsersModerationTab({super.key});

  @override
  State<UsersModerationTab> createState() => _UsersModerationTabState();
}

class _UsersModerationTabState extends State<UsersModerationTab> {
  final _firestore = FirebaseFirestore.instance;
  final _qualityService = UserQualityService();
  List<Map<String, dynamic>> _users = [];
  List<UserQualityScore> _topContributors = [];
  bool _isLoading = false;
  bool _showTopContributors = true;
  String _searchQuery = '';
  String _filterType = 'reported'; // all, reported, suspended

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _loadTopContributors();
  }

  Future<void> _loadTopContributors() async {
    try {
      final contributors = await _qualityService.getTopContributors(limit: 10);
      setState(() {
        _topContributors = contributors;
      });
    } catch (e) {
      AppLogger.error('Error loading top contributors: $e');
    }
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    
    try {
      Query query = _firestore.collection('users');

      if (_filterType == 'reported') {
        query = query.where('reported', isEqualTo: true);
      } else if (_filterType == 'suspended') {
        query = query.where('suspended', isEqualTo: true);
      }

      query = query.orderBy('createdAt', descending: true).limit(100);

      final snapshot = await query.get();
      
      setState(() {
        _users = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['uid'] = doc.id;
          return data;
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('Error loading users', error: e);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _suspendUser(String userId, String reason, int days) async {
    try {
      final suspendUntil = DateTime.now().add(Duration(days: days));
      
      await _firestore.collection('users').doc(userId).update({
        'suspended': true,
        'suspendedAt': FieldValue.serverTimestamp(),
        'suspendedUntil': Timestamp.fromDate(suspendUntil),
        'suspensionReason': reason,
      });

      // Optionally disable Firebase Auth
      // Would require admin SDK from Cloud Functions

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User suspended for $days days')),
        );
        _loadUsers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _unsuspendUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'suspended': false,
        'suspendedAt': null,
        'suspendedUntil': null,
        'suspensionReason': null,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User suspension lifted')),
        );
        _loadUsers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _clearReports(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'reported': false,
        'reportCount': 0,
        'reports': FieldValue.delete(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reports cleared')),
        );
        _loadUsers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search and filter bar
        Container(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Search users by username or email...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Filter: '),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Reported'),
                    selected: _filterType == 'reported',
                    onSelected: (_) {
                      setState(() => _filterType = 'reported');
                      _loadUsers();
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Suspended'),
                    selected: _filterType == 'suspended',
                    onSelected: (_) {
                      setState(() => _filterType = 'suspended');
                      _loadUsers();
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('All'),
                    selected: _filterType == 'all',
                    onSelected: (_) {
                      setState(() => _filterType = 'all');
                      _loadUsers();
                    },
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadUsers,
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        
        Expanded(child: _buildUsersList()),
      ],
    );
  }

  Widget _buildUsersList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    List<Map<String, dynamic>> filteredUsers = _users;
    if (_searchQuery.isNotEmpty) {
      filteredUsers = _users.where((user) {
        final username = (user['username'] ?? '').toLowerCase();
        final email = (user['email'] ?? '').toLowerCase();
        final query = _searchQuery.toLowerCase();
        return username.contains(query) || email.contains(query);
      }).toList();
    }

    if (filteredUsers.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.people, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('No users found', style: TextStyle(fontSize: 20)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: filteredUsers.length,
      itemBuilder: (context, index) => _buildUserCard(filteredUsers[index]),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final createdAt = (user['createdAt'] as Timestamp?)?.toDate();
    final isSuspended = user['suspended'] == true;
    final isReported = user['reported'] == true;
    final reportCount = user['reportCount'] ?? 0;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundImage: user['photoURL'] != null
              ? NetworkImage(user['photoURL'])
              : null,
          child: user['photoURL'] == null
              ? Text(user['username']?[0]?.toUpperCase() ?? '?')
              : null,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                '@${user['username'] ?? "unknown"}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (isSuspended)
              const Chip(
                label: Text('SUSPENDED'),
                backgroundColor: Colors.red,
                labelStyle: TextStyle(color: Colors.white),
              ),
            if (isReported && !isSuspended)
              Chip(
                label: Text('$reportCount REPORTS'),
                backgroundColor: Colors.orange,
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user['email'] ?? 'No email'),
            if (createdAt != null)
              Text('Joined: ${dateFormat.format(createdAt)}'),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User info
                _buildInfoRow('User ID', user['uid']),
                _buildInfoRow('Display Name', user['displayName'] ?? 'N/A'),
                _buildInfoRow('Profile Type', user['profileType'] ?? 'N/A'),
                
                if (user['bio'] != null) ...[
                  const SizedBox(height: 8),
                  const Text('Bio:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(user['bio']),
                ],

                if (isSuspended && user['suspensionReason'] != null) ...[
                  const SizedBox(height: 16),
                  const Text('Suspension Reason:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(user['suspensionReason'], style: const TextStyle(color: Colors.red)),
                ],

                if (isReported && user['reports'] != null) ...[
                  const SizedBox(height: 16),
                  const Text('Reports:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ...(user['reports'] as List).map((report) {
                    return Text('• ${report['reason'] ?? "No reason"}');
                  }),
                ],

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isReported && !isSuspended)
                      TextButton.icon(
                        onPressed: () => _clearReports(user['uid']),
                        icon: const Icon(Icons.check),
                        label: const Text('CLEAR REPORTS'),
                        style: TextButton.styleFrom(foregroundColor: Colors.green),
                      ),
                    const SizedBox(width: 8),
                    if (isSuspended)
                      ElevatedButton.icon(
                        onPressed: () => _unsuspendUser(user['uid']),
                        icon: const Icon(Icons.lock_open),
                        label: const Text('LIFT SUSPENSION'),
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: () async {
                          final result = await _showSuspensionDialog();
                          if (result != null) {
                            await _suspendUser(user['uid'], result['reason'], result['days']);
                          }
                        },
                        icon: const Icon(Icons.block),
                        label: const Text('SUSPEND USER'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _showSuspensionDialog() async {
    final reasonController = TextEditingController();
    int days = 7;

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Suspend User'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason *',
                  hintText: 'Why is this user being suspended?',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Duration: '),
                  DropdownButton<int>(
                    value: days,
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('1 day')),
                      DropdownMenuItem(value: 3, child: Text('3 days')),
                      DropdownMenuItem(value: 7, child: Text('7 days')),
                      DropdownMenuItem(value: 14, child: Text('14 days')),
                      DropdownMenuItem(value: 30, child: Text('30 days')),
                      DropdownMenuItem(value: 365, child: Text('1 year')),
                    ],
                    onChanged: (value) {
                      setState(() => days = value!);
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () {
                if (reasonController.text.isNotEmpty) {
                  Navigator.pop(context, {
                    'reason': reasonController.text,
                    'days': days,
                  });
                }
              },
              child: const Text('SUSPEND'),
            ),
          ],
        ),
      ),
    );
  }
}
