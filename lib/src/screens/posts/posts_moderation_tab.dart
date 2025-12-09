import 'package:flutter/material.dart';
import '../../services/moderation_api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_components.dart';
import '../../widgets/section_header.dart';

class PostsModerationTab extends StatefulWidget {
  const PostsModerationTab({super.key});

  @override
  State<PostsModerationTab> createState() => _PostsModerationTabState();
}

class _PostsModerationTabState extends State<PostsModerationTab> {
  final _moderationApi = ModerationApiService();
  List<dynamic> _posts = [];
  bool _loading = true;
  bool _flaggedOnly = false;
  bool _batchMode = false;
  Set<String> _selectedPosts = {};
  String _viewMode = 'list'; // 'grid' or 'list'
  String _sortBy = 'recent'; // 'recent', 'likes', 'comments'
  String? _searchQuery;

  void _toggleSelectAll() {
    setState(() {
      if (_selectedPosts.length == _posts.length) {
        _selectedPosts.clear();
      } else {
        _selectedPosts = _posts.map((p) => p['id'].toString()).toSet();
      }
    });
  }

  void _sortPosts() {
    setState(() {
      switch (_sortBy) {
        case 'recent':
          _posts.sort((a, b) {
            final aDate = a['createdAt'] ?? a['created_at'];
            final bDate = b['createdAt'] ?? b['created_at'];
            if (aDate == null && bDate == null) return 0;
            if (aDate == null) return 1;
            if (bDate == null) return -1;
            return DateTime.parse(bDate.toString()).compareTo(DateTime.parse(aDate.toString()));
          });
          break;
        case 'likes':
          _posts.sort((a, b) {
            final aLikes = a['likesCount'] ?? 0;
            final bLikes = b['likesCount'] ?? 0;
            return (bLikes as int).compareTo(aLikes as int);
          });
          break;
        case 'comments':
          _posts.sort((a, b) {
            final aComments = a['commentsCount'] ?? 0;
            final bComments = b['commentsCount'] ?? 0;
            return (bComments as int).compareTo(aComments as int);
          });
          break;
      }
    });
  }

  List<dynamic> _getFilteredPosts() {
    if (_searchQuery == null || _searchQuery!.isEmpty) {
      return _posts;
    }
    final query = _searchQuery!.toLowerCase();
    return _posts.where((post) {
      final content = (post['content'] ?? '').toString().toLowerCase();
      final username = (post['username'] ?? '').toString().toLowerCase();
      return content.contains(query) || username.contains(query);
    }).toList();
  }

  
  Future<void> _loadPosts() async {
    try {
      final posts = await _moderationApi.getPosts(flagged: _flaggedOnly ? true : null);
      if (mounted) {
        setState(() {
          _posts = posts;
          _loading = false;
          if (!_batchMode) _selectedPosts.clear();
        });
        _sortPosts();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading posts: $e')),
        );
      }
    }
  }

  Future<void> _batchHidePosts() async {
    if (_selectedPosts.isEmpty) return;
    final reason = await _showReasonDialog('Batch Hide Posts', 'Reason for hiding ${_selectedPosts.length} posts:');
    if (reason == null || reason.isEmpty) return;
    try {
      await _moderationApi.batchHidePosts(postIds: _selectedPosts.toList(), reason: reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_selectedPosts.length} posts hidden')),
        );
        _loadPosts();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _batchDeletePosts() async {
    if (_selectedPosts.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Batch Delete'),
        content: Text('Delete ${_selectedPosts.length} posts? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
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
      await _moderationApi.batchDeletePosts(postIds: _selectedPosts.toList());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_selectedPosts.length} posts deleted')),
        );
        _loadPosts();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showPostDetails(dynamic post) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200, maxHeight: 800),
          child: _PostDetailView(post: post, onRefresh: _loadPosts),
        ),
      ),
    );
  }

  Future<void> _handleQuickAction(String postId, String action) async {
    if (action == 'hide') {
      final reason = await _showReasonDialog('Hide Post', 'Enter reason for hiding:');
      if (reason == null || reason.isEmpty) return;
      
      try {
        await _moderationApi.hidePost(postId: postId, reason: reason);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Post hidden'), backgroundColor: AppTheme.warningColor),
          );
          _loadPosts();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    } else if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Post'),
          content: const Text('Permanently delete this post? This cannot be undone.'),
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
        await _moderationApi.deletePost(postId: postId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Post deleted'), backgroundColor: AppTheme.errorColor),
          );
          _loadPosts();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
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
    final isDesktop = MediaQuery.of(context).size.width > 900;
    return Column(
      children: [
        // Search and filters bar
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
              Flexible(
                child: CollapsibleSearchBar(
                  initialValue: _searchQuery ?? '',
                  onSearch: (q) => setState(() => _searchQuery = q.isEmpty ? null : q),
                ),
              ),
            ],
          ),
        ),
        // Header
        SectionHeader(
          title: 'Posts',
          trailing: _batchMode && _selectedPosts.isNotEmpty
              ? Chip(
                  label: Text('${_selectedPosts.length} selected'),
                  visualDensity: VisualDensity.compact,
                )
              : null,
          actions: [
            if (_batchMode) ...[
              TextButton.icon(
                onPressed: _toggleSelectAll,
                icon: Icon(_selectedPosts.length == _posts.length ? Icons.deselect : Icons.select_all, size: 18),
                label: Text(_selectedPosts.length == _posts.length ? 'Deselect All' : 'Select All'),
              ),
            ],
            if (_batchMode && _selectedPosts.isNotEmpty) ...[
              FilledButton.icon(
                onPressed: _batchHidePosts,
                icon: const Icon(Icons.visibility_off, size: 18),
                label: Text(isDesktop ? 'Hide Selected' : 'Hide'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.warningColor,
                ),
              ),
              FilledButton.icon(
                onPressed: _batchDeletePosts,
                icon: const Icon(Icons.delete, size: 18),
                label: Text(isDesktop ? 'Delete Selected' : 'Delete'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.errorColor,
                ),
              ),
            ],
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _batchMode = !_batchMode;
                  if (!_batchMode) _selectedPosts.clear();
                });
              },
              icon: Icon(_batchMode ? Icons.close : Icons.checklist, size: 18),
              label: Text(_batchMode ? 'Exit Batch' : 'Batch Mode'),
            ),
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
            const SizedBox(width: 8),
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
                  DropdownMenuItem(value: 'likes', child: Text('Most Likes')),
                  DropdownMenuItem(value: 'comments', child: Text('Most Comments')),
                ],
                onChanged: (value) {
                  setState(() => _sortBy = value!);
                  _sortPosts();
                },
              ),
            ),
            const SizedBox(width: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('All')),
                ButtonSegment(value: true, label: Text('Flagged')),
              ],
              selected: {_flaggedOnly},
              onSelectionChanged: (Set<bool> newSelection) {
                setState(() => _flaggedOnly = newSelection.first);
                _loadPosts();
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadPosts,
              tooltip: 'Refresh',
            ),
          ],
        ),
        // Posts List
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _getFilteredPosts().isEmpty
                  ? const Center(child: Text('No posts found'))
                  : _viewMode == 'list'
                      ? ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _getFilteredPosts().length,
                          itemBuilder: (context, index) {
                            final post = _getFilteredPosts()[index];
                            return _PostListItem(
                              post: post,
                              batchMode: _batchMode,
                              isSelected: _selectedPosts.contains(post['id']),
                              onToggleSelect: () {
                                setState(() {
                                  if (_selectedPosts.contains(post['id'])) {
                                    _selectedPosts.remove(post['id']);
                                  } else {
                                    _selectedPosts.add(post['id']);
                                  }
                                });
                              },
                              onTap: () => _showPostDetails(post),
                              onQuickAction: (action) => _handleQuickAction(post['id'], action),
                            );
                          },
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final crossAxisCount = constraints.maxWidth > 1200 ? 3 : constraints.maxWidth > 800 ? 2 : 1;
                            return GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 0.75,
                              ),
                              itemCount: _getFilteredPosts().length,
                              itemBuilder: (context, index) {
                                final post = _getFilteredPosts()[index];
                                return _PostCard(
                                  post: post,
                                  batchMode: _batchMode,
                                  isSelected: _selectedPosts.contains(post['id']),
                                  onToggleSelect: () {
                                    setState(() {
                                      if (_selectedPosts.contains(post['id'])) {
                                        _selectedPosts.remove(post['id']);
                                      } else {
                                        _selectedPosts.add(post['id']);
                                      }
                                    });
                                  },
                                  onTap: () => _showPostDetails(post),
                                  onQuickAction: (action) => _handleQuickAction(post['id'], action),
                                );
                              },
                            );
                          },
                        ),
        ),
      ],
    );
  }
}

class _PostCard extends StatelessWidget {
  final dynamic post;
  final bool batchMode;
  final bool isSelected;
  final VoidCallback onToggleSelect;
  final VoidCallback onTap;
  final Function(String action) onQuickAction;

  const _PostCard({
    required this.post,
    required this.batchMode,
    required this.isSelected,
    required this.onToggleSelect,
    required this.onTap,
    required this.onQuickAction,
  });

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
      final now = DateTime.now();
      final diff = now.difference(date);
      
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inDays < 1) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${date.month}/${date.day}/${date.year}';
    } catch (e) {
      return 'Unknown';
    }
  }

  String _formatFullDateTime(dynamic timestamp) {
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

  @override
  Widget build(BuildContext context) {
    final hidden = post['hidden'] == true;
    final flagged = post['flagged'] == true;
    final imageUrls = (post['imageUrls'] as List?)?.cast<String>() ?? [];
    final username = post['username'] ?? 'User ${post['authorId'] ?? ''}';
    final likesCount = post['likesCount'] ?? 0;
    final commentsCount = post['commentsCount'] ?? 0;
    final createdAt = _formatTimestamp(post['createdAt']);
    final fullDateTime = _formatFullDateTime(post['createdAt']);

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          if (imageUrls.isNotEmpty)
            Stack(
              children: [
                InkWell(
                  onTap: onTap,
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Image.network(
                      imageUrls.first,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.broken_image, size: 48),
                      ),
                    ),
                  ),
                ),
                if (imageUrls.length > 1)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.image, size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            '${imageUrls.length}',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with checkbox, username, and badges
                  Row(
                    children: [
                      if (batchMode)
                        Checkbox(
                          value: isSelected,
                          onChanged: (_) => onToggleSelect(),
                        ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              username,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              createdAt,
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).textTheme.bodySmall?.color,
                              ),
                            ),
                            Tooltip(
                              message: fullDateTime,
                              child: Text(
                                fullDateTime,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (flagged)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.warningColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('FLAG', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                      if (hidden)
                        Container(
                          margin: const EdgeInsets.only(left: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('HIDE', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Content
                  Expanded(
                    child: Text(
                      post['content'] ?? '',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        decoration: hidden ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Engagement stats and Post ID
                  Row(
                    children: [
                      Icon(Icons.favorite, size: 14, color: Colors.red[300]),
                      const SizedBox(width: 4),
                      Text('$likesCount', style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 16),
                      Icon(Icons.comment, size: 14, color: Colors.blue[300]),
                      const SizedBox(width: 4),
                      Text('$commentsCount', style: const TextStyle(fontSize: 12)),
                      const Spacer(),
                      Tooltip(
                        message: 'Post ID: ${post['id']}',
                        child: Icon(
                          Icons.info_outline,
                          size: 14,
                          color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Action buttons
          if (!batchMode)
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => onTap(),
                      icon: const Icon(Icons.visibility, size: 16),
                      label: const Text('View', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  if (!hidden)
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => onQuickAction('hide'),
                        icon: const Icon(Icons.visibility_off, size: 16),
                        label: const Text('Hide', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          foregroundColor: AppTheme.warningColor,
                        ),
                      ),
                    ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => onQuickAction('delete'),
                      icon: const Icon(Icons.delete, size: 16),
                      label: const Text('Delete', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        foregroundColor: AppTheme.errorColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PostListItem extends StatelessWidget {
  final dynamic post;
  final bool batchMode;
  final bool isSelected;
  final VoidCallback onToggleSelect;
  final VoidCallback onTap;
  final Function(String action) onQuickAction;

  const _PostListItem({
    required this.post,
    required this.batchMode,
    required this.isSelected,
    required this.onToggleSelect,
    required this.onTap,
    required this.onQuickAction,
  });

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
      final now = DateTime.now();
      final diff = now.difference(date);
      
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inDays < 1) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${date.month}/${date.day}/${date.year}';
    } catch (e) {
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final username = post['username'] ?? post['authorUsername'] ?? 'User ${post['authorId'] ?? ''}';
    final content = post['content'] ?? post['caption'] ?? '';
    final imageUrls = (post['imageUrls'] as List?)?.cast<String>() ?? [];
    final photoUrl = imageUrls.isNotEmpty ? imageUrls.first : null;
    final flagged = post['flagged'] == true;
    final hidden = post['hidden'] == true;
    final createdAt = _formatTimestamp(post['createdAt'] ?? post['created_at']);
    final likesCount = post['likesCount'] ?? 0;
    final commentsCount = post['commentsCount'] ?? 0;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: batchMode ? onToggleSelect : onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Checkbox in batch mode
              if (batchMode)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (_) => onToggleSelect(),
                  ),
                ),
              // Thumbnail
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: photoUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          photoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.image, size: 32),
                        ),
                      )
                    : const Icon(Icons.image, size: 32),
              ),
              const SizedBox(width: 16),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            username,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          createdAt,
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (content.isNotEmpty)
                      Text(
                        content,
                        style: const TextStyle(fontSize: 14),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 8),
                    // Engagement stats
                    Row(
                      children: [
                        Icon(Icons.favorite, size: 14, color: Colors.red[300]),
                        const SizedBox(width: 4),
                        Text('$likesCount', style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 12),
                        Icon(Icons.comment, size: 14, color: Colors.blue[300]),
                        const SizedBox(width: 4),
                        Text('$commentsCount', style: const TextStyle(fontSize: 12)),
                        if (imageUrls.length > 1) ...[
                          const SizedBox(width: 12),
                          Icon(Icons.image, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text('${imageUrls.length}', style: const TextStyle(fontSize: 12)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (flagged)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.errorColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.flag, size: 12, color: AppTheme.errorColor),
                                SizedBox(width: 4),
                                Text(
                                  'Flagged',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.errorColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (hidden)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.warningColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.visibility_off, size: 12, color: AppTheme.warningColor),
                                SizedBox(width: 4),
                                Text(
                                  'Hidden',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.warningColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // Quick actions
              if (!batchMode)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: onQuickAction,
                  itemBuilder: (context) => [
                    if (!hidden)
                      const PopupMenuItem(
                        value: 'hide',
                        child: Row(
                          children: [
                            Icon(Icons.visibility_off, size: 18, color: AppTheme.warningColor),
                            SizedBox(width: 12),
                            Text('Hide'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: AppTheme.errorColor),
                          SizedBox(width: 12),
                          Text('Delete'),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostDetailView extends StatefulWidget {
  final dynamic post;
  final VoidCallback onRefresh;

  const _PostDetailView({required this.post, required this.onRefresh});

  @override
  State<_PostDetailView> createState() => _PostDetailViewState();
}

class _PostDetailViewState extends State<_PostDetailView> {
  final _moderationApi = ModerationApiService();
  bool _processing = false;

  Future<void> _hidePost() async {
    final reason = await _showReasonDialog('Hide Post', 'Enter reason for hiding:');
    if (reason == null || reason.isEmpty) return;

    setState(() => _processing = true);
    try {
      await _moderationApi.hidePost(postId: widget.post['id'], reason: reason);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post hidden'), backgroundColor: AppTheme.warningColor),
        );
        widget.onRefresh();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _deletePost() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Permanently delete this post? This cannot be undone.'),
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
      await _moderationApi.deletePost(postId: widget.post['id']);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post deleted'), backgroundColor: AppTheme.errorColor),
        );
        widget.onRefresh();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processing = false);
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('SUBMIT'),
          ),
        ],
      ),
    );
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
      final now = DateTime.now();
      final diff = now.difference(date);
      
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inDays < 1) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${date.month}/${date.day}/${date.year}';
    } catch (e) {
      return 'Unknown';
    }
  }

  String _formatFullDateTime(dynamic timestamp) {
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

  @override
  Widget build(BuildContext context) {
    final imageUrls = (widget.post['imageUrls'] as List?)?.cast<String>() ?? [];
    final username = widget.post['username'] ?? 'User ${widget.post['authorId'] ?? ''}';
    final hidden = widget.post['hidden'] == true;
    final flagged = widget.post['flagged'] == true;
    final likesCount = widget.post['likesCount'] ?? 0;
    final commentsCount = widget.post['commentsCount'] ?? 0;
    final createdAt = _formatTimestamp(widget.post['createdAt']);
    final fullDateTime = _formatFullDateTime(widget.post['createdAt']);
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Column(
      children: [
        AppBar(
          title: const Text('Post Details'),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
          ],
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: isDesktop && imageUrls.isNotEmpty
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image Gallery (Left)
                      Expanded(
                        flex: 1,
                        child: SizedBox(
                          height: 500,
                          child: imageUrls.length > 1
                              ? ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: imageUrls.length,
                                  itemBuilder: (context, index) {
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          imageUrls[index],
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(
                                            width: 500,
                                            color: Colors.grey[300],
                                            child: const Icon(Icons.broken_image, size: 48),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    imageUrls.first,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: Colors.grey[300],
                                      child: const Icon(Icons.broken_image, size: 48),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Post Details (Right)
                      Expanded(
                        flex: 1,
                        child: _buildPostDetails(context, username, createdAt, fullDateTime, likesCount, commentsCount, flagged, hidden),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image Gallery (Mobile)
                      if (imageUrls.isNotEmpty) ...[
                        SizedBox(
                          height: 300,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: imageUrls.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    imageUrls[index],
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 300,
                                      color: Colors.grey[300],
                                      child: const Icon(Icons.broken_image, size: 48),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      // Post Details (Mobile)
                      _buildPostDetails(context, username, createdAt, fullDateTime, likesCount, commentsCount, flagged, hidden),
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
              if (!hidden)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _processing ? null : _hidePost,
                    icon: const Icon(Icons.visibility_off),
                    label: const Text('Hide Post'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.warningColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              if (!hidden) const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _processing ? null : _deletePost,
                  icon: const Icon(Icons.delete),
                  label: const Text('Delete Post'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.errorColor,
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

  Widget _buildPostDetails(BuildContext context, String username, String createdAt, String fullDateTime, int likesCount, int commentsCount, bool flagged, bool hidden) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Author & Status
        Row(
          children: [
            CircleAvatar(
              child: Text(username[0].toUpperCase()),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(username, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      if (flagged) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.warningColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('FLAGGED', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                      if (hidden) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('HIDDEN', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(createdAt, style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
                  Text(fullDateTime, style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7))),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 16),

        // Content
        Text(widget.post['content'] ?? '', style: const TextStyle(fontSize: 15, height: 1.4)),

        // Hashtags
        if (widget.post['hashtags'] != null && (widget.post['hashtags'] as List).isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: (widget.post['hashtags'] as List).map((tag) => 
              Chip(
                label: Text('#$tag'),
                visualDensity: VisualDensity.compact,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              )
            ).toList(),
          ),
        ],

        // Location
        if (widget.post['location'] != null) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.location_on, size: 16),
              const SizedBox(width: 4),
              Text(widget.post['location'], style: const TextStyle(fontSize: 13)),
            ],
          ),
        ],

        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 16),

        // Engagement Stats
        Row(
          children: [
            Icon(Icons.favorite, size: 20, color: Colors.red[300]),
            const SizedBox(width: 4),
            Text('$likesCount likes', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(width: 24),
            Icon(Icons.comment, size: 20, color: Colors.blue[300]),
            const SizedBox(width: 4),
            Text('$commentsCount comments', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),

        // Hidden Reason
        if (hidden && widget.post['hideReason'] != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.visibility_off, size: 20, color: Colors.orange[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Hidden: ${widget.post['hideReason']}',
                    style: TextStyle(fontSize: 13, color: Colors.orange[900]),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Post ID
        const SizedBox(height: 16),
        SelectableText(
          'Post ID: ${widget.post['id']}',
          style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color, fontFamily: 'monospace'),
        ),
      ],
    );
  }
}
