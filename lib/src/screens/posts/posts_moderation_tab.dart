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

class _PostDetailView extends StatelessWidget {
  final dynamic post;
  final VoidCallback onRefresh;

  const _PostDetailView({required this.post, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final imageUrls = (post['imageUrls'] as List?)?.cast<String>() ?? [];
    final username = post['username'] ?? 'User ${post['authorId'] ?? ''}';
    final hidden = post['hidden'] == true;

    return Column(
      children: [
        AppBar(
          title: Text('Post Details'),
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
                if (imageUrls.isNotEmpty)
                  SizedBox(
                    height: 300,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: imageUrls.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Image.network(imageUrls[index], fit: BoxFit.cover),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 16),
                Text('Author: $username', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Text(post['content'] ?? '', style: const TextStyle(fontSize: 14)),
                if (post['hashtags'] != null) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 4,
                    children: (post['hashtags'] as List).map((tag) => Chip(label: Text('#$tag'), visualDensity: VisualDensity.compact)).toList(),
                  ),
                ],
                if (hidden && post['hideReason'] != null) ...[
                  const SizedBox(height: 12),
                  Text('Hidden: ${post['hideReason']}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
