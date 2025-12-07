import 'package:flutter/material.dart';
import '../../services/moderation_api_service.dart';
import '../../theme/app_theme.dart';

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

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() => _loading = true);
    try {
      final posts = await _moderationApi.getPosts(flagged: _flaggedOnly ? true : null);
      if (mounted) {
        setState(() {
          _posts = posts;
          _loading = false;
          if (!_batchMode) _selectedPosts.clear();
        });
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
          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
          child: _PostDetailView(post: post, onRefresh: _loadPosts),
        ),
      ),
    );
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
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Posts', style: TextStyle(fontSize: isDesktop ? 18 : 16, fontWeight: FontWeight.w600)),
                  if (_batchMode && _selectedPosts.isNotEmpty)
                    Chip(
                      label: Text('${_selectedPosts.length} selected'),
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_batchMode && _selectedPosts.isNotEmpty) ...[
                    ElevatedButton.icon(
                      onPressed: _batchHidePosts,
                      icon: const Icon(Icons.visibility_off, size: 18),
                      label: Text(isDesktop ? 'Hide Selected' : 'Hide'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warningColor),
                    ),
                    ElevatedButton.icon(
                      onPressed: _batchDeletePosts,
                      icon: const Icon(Icons.delete, size: 18),
                      label: Text(isDesktop ? 'Delete Selected' : 'Delete'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
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
                  IconButton(icon: const Icon(Icons.refresh), onPressed: _loadPosts, tooltip: 'Refresh'),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Posts List
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _posts.isEmpty
                  ? const Center(child: Text('No posts found'))
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
                          itemCount: _posts.length,
                          itemBuilder: (context, index) {
                            final post = _posts[index];
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

  const _PostCard({
    required this.post,
    required this.batchMode,
    required this.isSelected,
    required this.onToggleSelect,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hidden = post['hidden'] == true;
    final flagged = post['flagged'] == true;
    final imageUrls = (post['imageUrls'] as List?)?.cast<String>() ?? [];
    final username = post['username'] ?? 'User ${post['authorId'] ?? ''}';

    return InkWell(
      onTap: onTap,
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrls.isNotEmpty)
              AspectRatio(
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
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (batchMode)
                          Checkbox(value: isSelected, onChanged: (_) => onToggleSelect()),
                        Expanded(
                          child: Text(username, style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
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
                    Expanded(
                      child: Text(
                        post['content'] ?? '',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, decoration: hidden ? TextDecoration.lineThrough : null),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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

  @override
  Widget build(BuildContext context) {
    final imageUrls = (widget.post['imageUrls'] as List?)?.cast<String>() ?? [];
    final username = widget.post['username'] ?? 'User ${widget.post['authorId'] ?? ''}';
    final hidden = widget.post['hidden'] == true;
    final flagged = widget.post['flagged'] == true;
    final likesCount = widget.post['likesCount'] ?? 0;
    final commentsCount = widget.post['commentsCount'] ?? 0;
    final createdAt = _formatTimestamp(widget.post['createdAt']);

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image Gallery
                if (imageUrls.isNotEmpty)
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
}
