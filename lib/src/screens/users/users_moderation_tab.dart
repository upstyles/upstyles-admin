import 'package:flutter/material.dart';
import '../../services/moderation_api_service.dart';
import '../../theme/app_theme.dart';

class UsersModerationTab extends StatefulWidget {
  const UsersModerationTab({super.key});

  @override
  State<UsersModerationTab> createState() => _UsersModerationTabState();
}

class _UsersModerationTabState extends State<UsersModerationTab> {
  final _moderationApi = ModerationApiService();
  List<dynamic> _users = [];
  bool _loading = true;
  String? _searchQuery;
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    try {
      final users = await _moderationApi.getUsers(
        search: _searchQuery,
        status: _statusFilter == 'all' ? null : _statusFilter,
      );
      if (mounted) {
        setState(() {
          _users = users;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading users: $e')),
        );
      }
    }
  }

  Future<void> _banUser(dynamic user) async {
    final reason = await _showReasonDialog('Ban User', 'Enter ban reason:');
    if (reason == null || reason.isEmpty) return;

    try {
      await _moderationApi.banUser(userId: user['id'], reason: reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User banned'), backgroundColor: Colors.red),
        );
        _loadUsers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _unbanUser(dynamic user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unban User'),
        content: Text('Unban ${user['username'] ?? user['email']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('UNBAN'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _moderationApi.unbanUser(userId: user['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User unbanned'), backgroundColor: AppTheme.successColor),
        );
        _loadUsers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _deleteUser(dynamic user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text(
          'Permanently delete ${user['username'] ?? user['email']} and ALL their content? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _moderationApi.deleteUser(userId: user['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User deleted'), backgroundColor: AppTheme.errorColor),
        );
        _loadUsers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<String?> _showReasonDialog(String title, String hint) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: hint),
          maxLines: 3,
          autofocus: true,
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header with search and filters
        Container(
          padding: const EdgeInsets.all(16),
          color: AppTheme.surfaceColor,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search users by username or email...',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onSubmitted: (value) {
                    setState(() => _searchQuery = value.isEmpty ? null : value);
                    _loadUsers();
                  },
                ),
              ),
              const SizedBox(width: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'all', label: Text('All')),
                  ButtonSegment(value: 'banned', label: Text('Banned')),
                ],
                selected: {_statusFilter},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() => _statusFilter = newSelection.first);
                  _loadUsers();
                },
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadUsers,
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Users list
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _users.isEmpty
                  ? const Center(child: Text('No users found'))
                  : ListView.builder(
                      itemCount: _users.length,
                      itemBuilder: (context, index) {
                        final user = _users[index];
                        final banned = user['banned'] == true;
                        
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                // Avatar
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: AppTheme.primaryLight,
                                  backgroundImage: user['photoUrl'] != null
                                      ? NetworkImage(user['photoUrl'])
                                      : null,
                                  child: user['photoUrl'] == null
                                      ? Text(
                                          (user['username'] ?? user['email'] ?? 'U')[0].toUpperCase(),
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 16),

                                // User info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            user['username'] ?? 'No username',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if (banned) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppTheme.errorColor,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                'BANNED',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        user['email'] ?? 'No email',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                      if (banned && user['banReason'] != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Reason: ${user['banReason']}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.errorColor,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),

                                // Actions
                                if (banned)
                                  ElevatedButton.icon(
                                    onPressed: () => _unbanUser(user),
                                    icon: const Icon(Icons.check, size: 18),
                                    label: const Text('Unban'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.successColor,
                                    ),
                                  )
                                else
                                  ElevatedButton.icon(
                                    onPressed: () => _banUser(user),
                                    icon: const Icon(Icons.block, size: 18),
                                    label: const Text('Ban'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.errorColor,
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                IconButton(
                                  onPressed: () => _deleteUser(user),
                                  icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor),
                                  tooltip: 'Delete User',
                                ),
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
