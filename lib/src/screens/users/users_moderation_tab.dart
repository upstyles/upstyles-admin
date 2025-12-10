import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/moderation_api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/user_card_skeleton.dart';
import '../../widgets/admin_components.dart';

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
  String _sortBy = 'recent';
  Set<String> _selectedUserIds = {};
  bool _selectAll = false;
  bool _batchMode = false;
  String _viewMode = 'list'; // 'grid' or 'list'

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  void _sortUsers() {
    setState(() {
      switch (_sortBy) {
        case 'recent':
          _users.sort((a, b) {
            final aDate = a['created_at'] ?? a['createdAt'];
            final bDate = b['created_at'] ?? b['createdAt'];
            if (aDate == null && bDate == null) return 0;
            if (aDate == null) return 1;
            if (bDate == null) return -1;
            return DateTime.parse(bDate.toString()).compareTo(DateTime.parse(aDate.toString()));
          });
          break;
        case 'posts':
          _users.sort((a, b) {
            final aPosts = a['posts_count'] ?? a['postsCount'] ?? 0;
            final bPosts = b['posts_count'] ?? b['postsCount'] ?? 0;
            return (bPosts as int).compareTo(aPosts as int);
          });
          break;
        case 'username':
          _users.sort((a, b) {
            final aName = (a['username'] ?? '').toString().toLowerCase();
            final bName = (b['username'] ?? '').toString().toLowerCase();
            return aName.compareTo(bName);
          });
          break;
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      _selectAll = !_selectAll;
      if (_selectAll) {
        _selectedUserIds = _users.map((u) => u['id'].toString()).toSet();
      } else {
        _selectedUserIds.clear();
      }
    });
  }

  void _toggleUserSelection(String userId) {
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
      } else {
        _selectedUserIds.add(userId);
      }
      _selectAll = _selectedUserIds.length == _users.length;
    });
  }

  Future<void> _batchBan() async {
    if (_selectedUserIds.isEmpty) return;
    final reason = await _showReasonDialog('Batch Ban', 'Reason for banning ${_selectedUserIds.length} users:');
    if (reason == null || reason.isEmpty) return;
    try {
      for (final userId in _selectedUserIds) {
        await _moderationApi.banUser(userId: userId, reason: reason);
      }
      if (mounted) {
        final count = _selectedUserIds.length;
        setState(() => _selectedUserIds.clear());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$count users banned'), backgroundColor: AppTheme.errorColor),
        );
        _loadUsers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _batchHide() async {
    if (_selectedUserIds.isEmpty) return;
    final reason = await _showReasonDialog('Batch Hide', 'Reason for hiding ${_selectedUserIds.length} users:');
    if (reason == null || reason.isEmpty) return;
    try {
      for (final userId in _selectedUserIds) {
        await _moderationApi.hideUser(userId: userId, reason: reason);
      }
      if (mounted) {
        final count = _selectedUserIds.length;
        setState(() => _selectedUserIds.clear());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$count users hidden'), backgroundColor: AppTheme.warningColor),
        );
        _loadUsers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    try {
      final users = await _moderationApi.getUsers(
        search: _searchQuery,
        status: _statusFilter == 'all' ? null : _statusFilter,
      );
      
      // Debug: Log user data to see what fields are available
      if (users.isNotEmpty) {
        debugPrint('[Users] Total users loaded: ${users.length}');
        if (kDebugMode) {
          debugPrint('[Users] Sample user data: ${users.first}');
          final firstUser = users.first as Map;
          debugPrint('[Users] Available keys: ${firstUser.keys.toList()}');
        }
      }
      
      if (mounted) {
        setState(() {
          _users = users;
          _loading = false;
        });
        _sortUsers();
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
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              // Search on its own row for consistent layout
              Row(
                children: [
                  Expanded(
                    child: CollapsibleSearchBar(
                      initialValue: _searchQuery ?? '',
                      onSearch: (q) {
                        setState(() => _searchQuery = q.isEmpty ? null : q);
                        _loadUsers();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  // Select all checkbox (only in batch mode)
                  if (_batchMode) ...[
                    Checkbox(
                      value: _selectAll,
                      onChanged: (value) => _toggleSelectAll(),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _selectedUserIds.isEmpty 
                          ? 'Select all'
                          : '${_selectedUserIds.length} selected',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(width: 16),
                  ],
                  // Batch mode toggle
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _batchMode = !_batchMode;
                        if (!_batchMode) {
                          _selectedUserIds.clear();
                          _selectAll = false;
                        }
                      });
                    },
                    icon: Icon(_batchMode ? Icons.close : Icons.checklist, size: 18),
                    label: Text(_batchMode ? 'Exit Batch' : 'Batch Mode'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // View mode toggle
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'grid', label: Text('Grid'), icon: Icon(Icons.grid_view, size: 16)),
                      ButtonSegment(value: 'list', label: Text('List'), icon: Icon(Icons.view_list, size: 16)),
                    ],
                    selected: {_viewMode},
                    onSelectionChanged: (Set<String> newSelection) {
                      setState(() => _viewMode = newSelection.first);
                    },
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 130,
                    child: DropdownButtonFormField<String>(
                      initialValue: _statusFilter,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All')),
                        DropdownMenuItem(value: 'banned', child: Text('Banned')),
                        DropdownMenuItem(value: 'active', child: Text('Active')),
                      ],
                      onChanged: (value) {
                        setState(() => _statusFilter = value!);
                        _loadUsers();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 150,
                    child: DropdownButtonFormField<String>(
                      initialValue: _sortBy,
                      decoration: const InputDecoration(
                        labelText: 'Sort By',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'recent', child: Text('Most Recent')),
                        DropdownMenuItem(value: 'posts', child: Text('Most Posts')),
                        DropdownMenuItem(value: 'username', child: Text('A-Z')),
                      ],
                      onChanged: (value) {
                        setState(() => _sortBy = value!);
                        _sortUsers();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadUsers,
                    tooltip: 'Refresh',
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        
        // Batch action bar
        if (_batchMode && _selectedUserIds.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              border: Border(
                bottom: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 20, color: AppTheme.primaryColor),
                    const SizedBox(width: 12),
                    Text(
                      '${_selectedUserIds.length} user${_selectedUserIds.length != 1 ? 's' : ''} selected',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => setState(() => _selectedUserIds.clear()),
                      icon: const Icon(Icons.clear, size: 18),
                      label: const Text('Clear'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _batchHide,
                      icon: const Icon(Icons.visibility_off, size: 18),
                      label: const Text('Hide'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.warningColor,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _batchBan,
                      icon: const Icon(Icons.block, size: 18),
                      label: const Text('Ban'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.errorColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

        // Users list
        Expanded(
          child: _loading
              ? ListView.builder(
                  itemCount: 8,
                  itemBuilder: (context, index) => const UserCardSkeleton(),
                )
              : _users.isEmpty
                  ? const Center(child: Text('No users found'))
                  : _viewMode == 'grid'
                      ? LayoutBuilder(
                          builder: (context, constraints) {
                            final crossAxisCount = constraints.maxWidth > 1200 ? 3 : constraints.maxWidth > 800 ? 2 : 1;
                            return GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 1.5,
                              ),
                              itemCount: _users.length,
                              itemBuilder: (context, index) {
                                final user = _users[index];
                                final banned = user['banned'] == true;
                                final hidden = user['hidden'] == true;
                                final userId = user['id']?.toString() ?? '';
                                final isSelected = _selectedUserIds.contains(userId);
                                
                                return Padding(
                                  padding: const EdgeInsets.all(0),
                                  child: AdminCard(
                                    padding: const EdgeInsets.all(16),
                                    child: InkWell(
                                      onTap: () => _showUserDetails(user),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              if (_batchMode)
                                                Checkbox(
                                                  value: isSelected,
                                                  onChanged: (value) => _toggleUserSelection(userId),
                                                ),
                                              CircleAvatar(
                                                radius: 24,
                                                backgroundColor: AppTheme.primaryLight,
                                                backgroundImage: user['avatar_url'] != null && user['avatar_url'].toString().isNotEmpty
                                                    ? NetworkImage(user['avatar_url'])
                                                    : null,
                                                child: user['avatar_url'] == null || user['avatar_url'].toString().isEmpty
                                                    ? Text(
                                                        (user['username'] ?? user['email'] ?? 'U')[0].toUpperCase(),
                                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                                      )
                                                    : null,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      user['username'] ?? 'No username',
                                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    Text(
                                                      user['email'] ?? 'No email',
                                                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              if (banned)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.errorColor,
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: const Text('BANNED', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                                ),
                                              if (hidden)
                                                Container(
                                                  margin: const EdgeInsets.only(left: 4),
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey,
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: const Text('HIDDEN', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              Icon(Icons.article, size: 14, color: Colors.blue[300]),
                                              const SizedBox(width: 4),
                                              Text('${user['posts_count'] ?? 0}', style: const TextStyle(fontSize: 12)),
                                              const SizedBox(width: 16),
                                              Icon(Icons.people, size: 14, color: Colors.green[300]),
                                              const SizedBox(width: 4),
                                              Text('${user['followers_count'] ?? 0}', style: const TextStyle(fontSize: 12)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        )
                      : ListView.builder(
                      itemCount: _users.length,
                      itemBuilder: (context, index) {
                        final user = _users[index];
                        final banned = user['banned'] == true;
                        final hidden = user['hidden'] == true;
                        final userId = user['id']?.toString() ?? '';
                        final isSelected = _selectedUserIds.contains(userId);
                        
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: AdminCard(
                            padding: const EdgeInsets.all(16),
                            child: InkWell(
                              onTap: () => _showUserDetails(user),
                              child: Row(
                              children: [
                                // Checkbox (only in batch mode)
                                if (_batchMode) ...[
                                  Checkbox(
                                    value: isSelected,
                                    onChanged: (value) => _toggleUserSelection(userId),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                // Avatar
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: AppTheme.primaryLight,
                                  backgroundImage: user['avatar_url'] != null && user['avatar_url'].toString().isNotEmpty
                                      ? NetworkImage(user['avatar_url'])
                                      : null,
                                  child: user['avatar_url'] == null || user['avatar_url'].toString().isEmpty
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
                                          if (hidden) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppTheme.warningColor,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                'HIDDEN',
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

                                // Arrow icon to indicate clickable
                                const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                              ],
                            ),
                          ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  void _showUserDetails(dynamic user) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200, maxHeight: 800),
          child: _UserDetailView(user: user, onUpdate: _loadUsers),
        ),
      ),
    );
  }
}

class _UserDetailView extends StatefulWidget {
  final dynamic user;
  final VoidCallback onUpdate;

  const _UserDetailView({required this.user, required this.onUpdate});

  @override
  State<_UserDetailView> createState() => _UserDetailViewState();
}

class _UserDetailViewState extends State<_UserDetailView> {
  final _moderationApi = ModerationApiService();
  bool _processing = false;
  List<dynamic> _recentPosts = [];
  List<dynamic> _moderationHistory = [];
  int _reportsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUserDetails();
  }

  Future<void> _loadUserDetails() async {
    try {
      final response = await _moderationApi.getUserDetails(userId: widget.user['id']);
      if (mounted) {
        setState(() {
          _recentPosts = response['recentPosts'] ?? [];
          _moderationHistory = response['moderationHistory'] ?? [];
          _reportsCount = response['stats']?['reports'] ?? 0;
        });
      }
    } catch (e) {
      debugPrint('[UserDetail] Error loading details: $e');
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    try {
      DateTime date;
      if (timestamp is Map && timestamp.containsKey('_seconds')) {
        date = DateTime.fromMillisecondsSinceEpoch(timestamp['_seconds'] * 1000);
      } else if (timestamp is String) {
        date = DateTime.parse(timestamp);
      } else {
        return 'Unknown';
      }
      
      final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
      final amPm = date.hour >= 12 ? 'PM' : 'AM';
      final minute = date.minute.toString().padLeft(2, '0');
      
      return '${date.month}/${date.day}/${date.year} at $hour:$minute $amPm';
    } catch (e) {
      return 'Unknown';
    }
  }

  Future<void> _banUser() async {
    final reason = await _showReasonDialog('Ban User', 'Enter reason for banning this user:');
    if (reason == null || reason.isEmpty) return;

    setState(() => _processing = true);
    try {
      await _moderationApi.banUser(userId: widget.user['id'], reason: reason);
      if (mounted) {
        Navigator.pop(context);
        widget.onUpdate();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User banned'), backgroundColor: AppTheme.errorColor),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _unbanUser() async {
    setState(() => _processing = true);
    try {
      await _moderationApi.unbanUser(userId: widget.user['id']);
      if (mounted) {
        Navigator.pop(context);
        widget.onUpdate();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User unbanned'), backgroundColor: AppTheme.successColor),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _hideUser() async {
    final reason = await _showReasonDialog('Hide User', 'Enter reason for hiding this user:');
    if (reason == null || reason.isEmpty) return;

    setState(() => _processing = true);
    try {
      await _moderationApi.hideUser(userId: widget.user['id'], reason: reason);
      if (mounted) {
        Navigator.pop(context);
        widget.onUpdate();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User and all content hidden'), backgroundColor: AppTheme.warningColor),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _unhideUser() async {
    setState(() => _processing = true);
    try {
      await _moderationApi.unhideUser(userId: widget.user['id']);
      if (mounted) {
        Navigator.pop(context);
        widget.onUpdate();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User and all content restored'), backgroundColor: AppTheme.successColor),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _deleteUser() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: const Text('PERMANENTLY delete this user and all their data? This CANNOT be undone!'),
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

    setState(() => _processing = true);
    try {
      await _moderationApi.deleteUser(userId: widget.user['id']);
      if (mounted) {
        Navigator.pop(context);
        widget.onUpdate();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User deleted'), backgroundColor: AppTheme.errorColor),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
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
    final banned = widget.user['banned'] == true;
    final hidden = widget.user['hidden'] == true;
    final createdAt = _formatTimestamp(widget.user['created_at'] ?? widget.user['createdAt']);
    final photoUrl = widget.user['avatar_url'];
    final username = widget.user['username'] ?? 'No username';
    final email = widget.user['email'] ?? 'No email';
    final bio = widget.user['bio'] ?? '';
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Column(
      children: [
        AppBar(
          title: const Text('User Details'),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
          ],
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: isDesktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left side - Avatar and basic info
                      SizedBox(
                        width: 300,
                        child: _buildUserCard(photoUrl, username, email, banned, createdAt),
                      ),
                      const SizedBox(width: 24),
                      // Right side - Detailed info
                      Expanded(
                        child: _buildDetailedInfo(bio, banned, hidden),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      _buildUserCard(photoUrl, username, email, banned, createdAt),
                      const SizedBox(height: 24),
                      _buildDetailedInfo(bio, banned, hidden),
                    ],
                  ),
          ),
        ),
        // Action Buttons
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              if (!banned)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _processing ? null : _banUser,
                    icon: const Icon(Icons.block),
                    label: const Text('Ban User'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.errorColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              if (banned)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _processing ? null : _unbanUser,
                    icon: const Icon(Icons.check),
                    label: const Text('Unban User'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              if (!hidden)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _processing ? null : _hideUser,
                    icon: const Icon(Icons.visibility_off),
                    label: const Text('Hide User'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.warningColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              if (hidden)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _processing ? null : _unhideUser,
                    icon: const Icon(Icons.visibility),
                    label: const Text('Unhide User'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _processing ? null : _deleteUser,
                  icon: const Icon(Icons.delete_forever),
                  label: const Text('Delete User'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[900],
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUserCard(String? photoUrl, String username, String email, bool banned, String createdAt) {
    // Debug logging
    if (kDebugMode && photoUrl != null) {
      debugPrint('[UserDetail] Photo URL: $photoUrl');
    }
    
    return AdminCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Avatar
          CircleAvatar(
            radius: 60,
            backgroundColor: AppTheme.primaryLight,
            backgroundImage: photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
            onBackgroundImageError: photoUrl != null
                ? (exception, stackTrace) {
                    debugPrint('[UserDetail] Error loading avatar: $exception');
                  }
                : null,
            child: photoUrl == null || photoUrl.isEmpty
                ? Text(
                    username[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 16),
          // Username
          Text(
            username,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          // Email
          Text(
            email,
            style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodySmall?.color),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          // Status Badge
          if (banned)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.errorColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'BANNED',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.successColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'ACTIVE',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          // Signup Date
          _buildInfoRow(Icons.calendar_today, 'Joined', createdAt),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.access_time, 'Last Active', _formatTimestamp(widget.user['last_login'] ?? widget.user['lastLogin'] ?? widget.user['updated_at'])),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.fingerprint, 'User ID', widget.user['id'] ?? 'Unknown'),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          // Profile Link Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final userId = widget.user['id'];
                if (userId != null) {
                  final username = widget.user['username'] ?? '';
                  final url = Uri.parse('https://upstyles-pro.web.app/');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                  if (mounted && username.isNotEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Opening UpStyles. Search for: @$username'),
                        duration: const Duration(seconds: 5),
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('View on UpStyles'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Theme.of(context).textTheme.bodySmall?.color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color),
              ),
              Text(
                value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedInfo(String bio, bool banned, bool hidden) {
    final postsCount = widget.user['postsCount'] ?? 0;
    final followersCount = widget.user['followersCount'] ?? 0;
    final followingCount = widget.user['followingCount'] ?? 0;
    final likesReceived = widget.user['likesReceivedCount'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bio Section
        if (bio.isNotEmpty) ...[
          const Text(
            'Bio',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            bio,
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),
        ],

        // Activity Stats
        const Text(
          'Activity Stats',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _buildStatCard(Icons.photo_library, 'Posts', postsCount.toString(), Colors.blue),
            _buildStatCard(Icons.people, 'Followers', followersCount.toString(), Colors.purple),
            _buildStatCard(Icons.person_add, 'Following', followingCount.toString(), Colors.green),
            _buildStatCard(Icons.favorite, 'Likes', likesReceived.toString(), Colors.red),
          ],
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 24),

        // Account Information
        const Text(
          'Account Information',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        _buildInfoTile('User Type', widget.user['userType'] ?? 'enthusiast'),
        _buildInfoTile('Email Verified', widget.user['emailVerified'] == true ? 'Yes' : 'No'),
        _buildInfoTile('Pro Badge', widget.user['isPro'] == true ? 'Yes' : 'No'),
        
        // Reports Section
        if (_reportsCount > 0) ...[
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.flag, color: Colors.orange[700], size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reports',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange[900],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'This user has been reported $_reportsCount time${_reportsCount > 1 ? 's' : ''}',
                        style: TextStyle(fontSize: 13, color: Colors.orange[900]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange[700],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$_reportsCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Recent Posts Section
        if (_recentPosts.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),
          const Text(
            'Recent Posts',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ...List.generate(_recentPosts.length.clamp(0, 3), (index) {
            final post = _recentPosts[index];
            final content = post['content'] ?? '';
            final imageUrls = (post['imageUrls'] as List?)?.cast<String>() ?? [];
            final hasImage = imageUrls.isNotEmpty;
            
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasImage)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(
                        imageUrls.first,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                      ),
                    ),
                  if (hasImage) const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          content.length > 100 ? '${content.substring(0, 100)}...' : content,
                          style: const TextStyle(fontSize: 13),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatTimestamp(post['created_at']),
                          style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          if (_recentPosts.length > 3)
            Text(
              '+ ${_recentPosts.length - 3} more posts',
              style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color),
            ),
        ],

        // Moderation History Section
        if (_moderationHistory.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),
          const Text(
            'Moderation History',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ...List.generate(_moderationHistory.length.clamp(0, 5), (index) {
            final entry = _moderationHistory[index];
            final action = entry['action'] ?? 'unknown';
            final moderatorEmail = entry['moderatorEmail'] ?? 'Unknown';
            final timestamp = entry['timestamp'];
            
            IconData icon;
            Color color;
            switch (action) {
              case 'ban':
                icon = Icons.block;
                color = Colors.red;
                break;
              case 'unban':
                icon = Icons.check_circle;
                color = Colors.green;
                break;
              case 'hide_user':
                icon = Icons.visibility_off;
                color = Colors.orange;
                break;
              case 'unhide_user':
                icon = Icons.visibility;
                color = Colors.green;
                break;
              default:
                icon = Icons.info;
                color = Colors.blue;
            }
            
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          action.replaceAll('_', ' ').toUpperCase(),
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'by $moderatorEmail',
                          style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _formatTimestamp(timestamp),
                    style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color),
                  ),
                ],
              ),
            );
          }),
        ],
        
        // Ban Info
        if (banned && widget.user['banReason'] != null) ...[
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red[700], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Ban Reason',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.red[900],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  widget.user['banReason'],
                  style: TextStyle(fontSize: 14, color: Colors.red[900]),
                ),
              ],
            ),
          ),
        ],

        // Hide Info
        if (hidden && widget.user['hideReason'] != null) ...[
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.visibility_off, color: Colors.orange[700], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Hide Reason',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange[900],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  widget.user['hideReason'],
                  style: TextStyle(fontSize: 14, color: Colors.orange[900]),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatCard(IconData icon, String label, String value, Color color) {
    return Container(
      width: 130,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
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
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
