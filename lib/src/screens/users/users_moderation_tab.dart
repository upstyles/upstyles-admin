import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/moderation_api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/section_header.dart';

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
      
      // Debug: Log user data to see what fields are available
      if (users.isNotEmpty) {
        print('[Users] Total users loaded: ${users.length}');
        print('[Users] Sample user data: ${users.first}');
        final firstUser = users.first as Map;
        print('[Users] Available keys: ${firstUser.keys.toList()}');
        print('[Users] Photo fields check:');
        print('  - photoUrl: ${firstUser['photoUrl']}');
        print('  - photoURL: ${firstUser['photoURL']}');
        print('  - profileImageUrl: ${firstUser['profileImageUrl']}');
        print('  - profilePhoto: ${firstUser['profilePhoto']}');
      }
      
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
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 1,
              ),
            ),
          ),
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
                          child: InkWell(
                            onTap: () => _showUserDetails(user),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                              children: [
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hide User'),
        content: const Text('This will hide all of the user\'s posts and content. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warningColor),
            child: const Text('HIDE'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _processing = true);
    try {
      // You'll need to add this endpoint to your moderation API
      // For now, we'll just show a message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hide user feature - API endpoint needed')),
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
                        child: _buildDetailedInfo(bio, banned),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      _buildUserCard(photoUrl, username, email, banned, createdAt),
                      const SizedBox(height: 24),
                      _buildDetailedInfo(bio, banned),
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
                color: Colors.black.withOpacity(0.1),
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
    if (photoUrl != null) {
      print('[UserDetail] Photo URL: $photoUrl');
    }
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Avatar
            CircleAvatar(
              radius: 60,
              backgroundColor: AppTheme.primaryLight,
              backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                  ? NetworkImage(photoUrl)
                  : null,
              onBackgroundImageError: photoUrl != null
                  ? (exception, stackTrace) {
                      print('[UserDetail] Error loading avatar: $exception');
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
            _buildInfoRow(Icons.fingerprint, 'User ID', widget.user['id'] ?? 'Unknown'),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            // Profile Link Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final username = widget.user['username'];
                  if (username != null) {
                    final url = Uri.parse('https://upstyles-pro.web.app/profile?username=$username');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  }
                },
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('View Profile on UpStyles'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
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

  Widget _buildDetailedInfo(String bio, bool banned) {
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
      ],
    );
  }

  Widget _buildStatCard(IconData icon, String label, String value, Color color) {
    return Container(
      width: 130,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
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
              color: color.withOpacity(0.8),
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
