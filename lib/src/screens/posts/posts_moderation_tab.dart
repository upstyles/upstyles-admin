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

  Future<void> _hidePost(dynamic post) async {
    final reason = await _showReasonDialog('Hide Post', 'Enter reason for hiding:');
    if (reason == null || reason.isEmpty) return;

    try {
      await _moderationApi.hidePost(postId: post['id'], reason: reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post hidden'), backgroundColor: Colors.orange),
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

  Future<void> _deletePost(dynamic post) async {
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
      await _moderationApi.deletePost(postId: post['id']);
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
        // Header with filters
        Container(
          padding: const EdgeInsets.all(16),
          color: AppTheme.surfaceColor,
          child: Row(
            children: [
              const Text('Posts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const Spacer(),
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
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadPosts,
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Posts list
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _posts.isEmpty
                  ? const Center(child: Text('No posts found'))
                  : ListView.builder(
                      itemCount: _posts.length,
                      itemBuilder: (context, index) {
                        final post = _posts[index];
                        final hidden = post['hidden'] == true;
                        final flagged = post['flagged'] == true;
                        
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header
                                Row(
                                  children: [
                                    Text(
                                      post['username'] ?? 'User ${post['userId']}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (flagged) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.warningColor,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'FLAGGED',
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
                                          color: Colors.grey,
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
                                const SizedBox(height: 8),
                                
                                // Content
                                Text(
                                  post['content'] ?? '',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: hidden ? AppTheme.textSecondary : AppTheme.textPrimary,
                                    decoration: hidden ? TextDecoration.lineThrough : null,
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                
                                if (hidden && post['hideReason'] != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Hidden: ${post['hideReason']}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                                
                                const SizedBox(height: 12),
                                
                                // Actions
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (!hidden)
                                      ElevatedButton.icon(
                                        onPressed: () => _hidePost(post),
                                        icon: const Icon(Icons.visibility_off, size: 18),
                                        label: const Text('Hide'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.warningColor,
                                        ),
                                      ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      onPressed: () => _deletePost(post),
                                      icon: const Icon(Icons.delete, size: 18),
                                      label: const Text('Delete'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.errorColor,
                                      ),
                                    ),
                                  ],
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
