import 'package:flutter/material.dart';
import '../../services/moderation_api_service.dart';
import '../../utils/logger.dart';
import '../../widgets/admin_components.dart';
import 'package:intl/intl.dart';

class ExploreSubmissionsTab extends StatefulWidget {
  const ExploreSubmissionsTab({super.key});

  @override
  State<ExploreSubmissionsTab> createState() => _ExploreSubmissionsTabState();
}

class _ExploreSubmissionsTabState extends State<ExploreSubmissionsTab> {
  final _moderationApi = ModerationApiService();
  List<SubmissionItem> _submissions = [];
  final Set<String> _selectedSubmissions = {};
  bool _isLoading = false;
  String? _errorMessage;
  String _filterStatus = 'pending';
  bool _bulkMode = false;
  String _viewMode = 'grid'; // 'grid' or 'list'
  
  @override
  void initState() {
    super.initState();
    _loadSubmissions();
  }

  Future<void> _loadSubmissions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _moderationApi.getExploreQueue(
        status: _filterStatus == 'all' ? null : _filterStatus,
        limit: 100,
      );
      
      setState(() {
        _submissions = result.items;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('Error loading moderation queue', error: e);
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _approveSubmission(SubmissionItem submission) async {
    final collectionId = await _showCollectionPicker();
    if (collectionId == null) return;

    final trendScore = await _showTrendScorePicker();
    if (trendScore == null) return;

    try {
      await _moderationApi.approveSubmission(
        submissionId: submission.id,
        collectionId: collectionId,
        trendScore: trendScore,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Submission approved')),
        );
        _loadSubmissions();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<String?> _showCollectionPicker() async {
    // Fetch available collections
    List<ExploreCollection> collections;
    try {
      collections = await _moderationApi.getExploreCollections();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading collections: $e')),
        );
      }
      return null;
    }

    if (collections.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No active collections found. Please create collections first.')),
        );
      }
      return null;
    }

    String? selectedCollectionId = collections.first.id;
    final customController = TextEditingController();
    bool useCustom = false;

    if (!mounted) return null;
    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Select Collection'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!useCustom) ...[
                const Text('Choose from existing collections:'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedCollectionId,
                  decoration: const InputDecoration(
                    labelText: 'Collection',
                    border: OutlineInputBorder(),
                  ),
                  items: collections.map((collection) {
                    return DropdownMenuItem(
                      value: collection.id,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(collection.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          if (collection.description != null)
                            Text(
                              collection.description!,
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedCollectionId = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      useCustom = true;
                    });
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Use custom collection ID'),
                ),
              ] else ...[
                const Text('Enter custom collection ID:'),
                const SizedBox(height: 8),
                TextField(
                  controller: customController,
                  decoration: const InputDecoration(
                    labelText: 'Collection ID',
                    hintText: 'e.g., trending_designs',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      useCustom = false;
                    });
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back to dropdown'),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () {
                final collectionId = useCustom 
                    ? customController.text.trim()
                    : selectedCollectionId;
                if (collectionId != null && collectionId.isNotEmpty) {
                  Navigator.pop(context, collectionId);
                }
              },
              child: const Text('SELECT'),
            ),
          ],
        ),
      ),
    );
  }

  Future<double?> _showTrendScorePicker() async {
    double score = 0.5;
    return showDialog<double>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Set Trend Score'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Score: ${score.toStringAsFixed(2)}'),
              Slider(
                value: score,
                min: 0,
                max: 1,
                divisions: 100,
                label: score.toStringAsFixed(2),
                onChanged: (value) {
                  setState(() {
                    score = value;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, score),
              child: const Text('SET'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _rejectSubmission(SubmissionItem submission) async {
    final reason = await _showRejectDialog();
    if (reason == null || reason.isEmpty) return;

    try {
      await _moderationApi.rejectSubmission(
        submissionId: submission.id,
        reason: reason,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Submission rejected')),
        );
        _loadSubmissions();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  // Batch operations
  Future<void> _deleteSubmission(SubmissionItem submission) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Submission'),
        content: Text(
          'Are you sure you want to permanently delete "${submission.title}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _moderationApi.deleteSubmission(
        submissionId: submission.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Submission deleted'), backgroundColor: Colors.red),
        );
        _loadSubmissions();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _batchApprove() async {
    final collectionId = await _showCollectionPicker();
    if (collectionId == null) return;

    final trendScore = await _showTrendScorePicker();
    if (trendScore == null) return;

    try {
      final result = await _moderationApi.batchApproveSubmissions(
        submissionIds: _selectedSubmissions.toList(),
        collectionId: collectionId,
        trendScore: trendScore,
      );

      if (mounted) {
        final successCount = result.success.length;
        final failedCount = result.failed.length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Approved: $successCount, Failed: $failedCount'),
            backgroundColor: failedCount > 0 ? Colors.orange : Colors.green,
          ),
        );
        setState(() {
          _selectedSubmissions.clear();
          _bulkMode = false;
        });
        _loadSubmissions();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Batch approve failed: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _batchReject() async {
    final reason = await _showRejectDialog();
    if (reason == null || reason.isEmpty) return;

    try {
      final result = await _moderationApi.batchRejectSubmissions(
        submissionIds: _selectedSubmissions.toList(),
        reason: reason,
      );

      if (mounted) {
        final successCount = result.success.length;
        final failedCount = result.failed.length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rejected: $successCount, Failed: $failedCount'),
            backgroundColor: failedCount > 0 ? Colors.orange : Colors.green,
          ),
        );
        setState(() {
          _selectedSubmissions.clear();
          _bulkMode = false;
        });
        _loadSubmissions();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Batch reject failed: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _batchDelete() async {
    if (_selectedSubmissions.isEmpty) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Submissions'),
        content: Text(
          'Are you sure you want to permanently delete ${_selectedSubmissions.length} submission(s)? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      int successCount = 0;
      int failCount = 0;

      for (final submissionId in _selectedSubmissions) {
        try {
          await _moderationApi.deleteSubmission(submissionId: submissionId);
          successCount++;
        } catch (e) {
          failCount++;
          debugPrint('Failed to delete $submissionId: $e');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted $successCount submission(s)${failCount > 0 ? ", $failCount failed" : ""}'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _selectedSubmissions.clear();
          _bulkMode = false;
        });
        _loadSubmissions();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Batch delete failed: ${e.toString()}')),
        );
      }
    }
  }

  Future<String?> _showRejectDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Submission'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Rejection Reason *',
            hintText: 'Explain why this was rejected...',
          ),
          maxLines: 3,
          maxLength: 500,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('REJECT'),
          ),
        ],
      ),
    );
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
              const Text('Filter: '),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Pending'),
                selected: _filterStatus == 'pending',
                onSelected: (_) {
                  setState(() => _filterStatus = 'pending');
                  _loadSubmissions();
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Flagged'),
                selected: _filterStatus == 'flagged',
                onSelected: (_) {
                  setState(() => _filterStatus = 'flagged');
                  _loadSubmissions();
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('All'),
                selected: _filterStatus == 'all',
                onSelected: (_) {
                  setState(() => _filterStatus = 'all');
                  _loadSubmissions();
                },
              ),
              const Spacer(),
              // Collapsible search to maximize real-estate on mobile
              CollapsibleSearchBar(
                onSearch: (q) {
                  // client-side filtering by title/author
                  setState(() {
                    // store query locally and filter client-side if desired
                    // currently we reload from server when filters change
                  });
                },
              ),
              const SizedBox(width: 8),
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
              const SizedBox(width: 8),
              // Batch mode toggle
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _bulkMode = !_bulkMode;
                    if (!_bulkMode) _selectedSubmissions.clear();
                  });
                },
                icon: Icon(_bulkMode ? Icons.check_box : Icons.check_box_outline_blank),
                label: Text(_bulkMode ? 'Exit Batch Mode' : 'Batch Mode'),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadSubmissions,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        
        // Batch actions bar
        if (_bulkMode && _selectedSubmissions.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.blue[50],
            child: Row(
              children: [
                Text('${_selectedSubmissions.length} selected'),
                const SizedBox(width: 16),
                if (_submissions.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        if (_selectedSubmissions.length == _submissions.length) {
                          _selectedSubmissions.clear();
                        } else {
                          _selectedSubmissions.addAll(_submissions.map((s) => s.id));
                        }
                      });
                    },
                    child: Text(_selectedSubmissions.length == _submissions.length 
                        ? 'Deselect All' 
                        : 'Select All'),
                  ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _batchApprove,
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _batchReject,
                  icon: const Icon(Icons.cancel),
                  label: const Text('Reject'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _batchDelete,
                  icon: const Icon(Icons.delete),
                  label: const Text('Delete'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[700],
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        const Divider(height: 1),
        
        // Submissions list
        Expanded(child: _buildSubmissionsList()),
      ],
    );
  }

  Widget _buildSubmissionsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(_errorMessage!),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadSubmissions,
                child: const Text('RETRY'),
              ),
            ],
          ),
        ),
      );
    }

    if (_submissions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.inbox, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'No $_filterStatus submissions',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _submissions.length,
      itemBuilder: (context, index) {
        return _buildSubmissionCard(_submissions[index]);
      },
    );
  }

  Widget _buildSubmissionCard(SubmissionItem submission) {
    final dateFormat = DateFormat('MMM d, yyyy • h:mm a');
    final isSelected = _selectedSubmissions.contains(submission.id);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: AdminCard(
        padding: EdgeInsets.zero,
        child: ExpansionTile(
          leading: _bulkMode
              ? Checkbox(
                  value: isSelected,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selectedSubmissions.add(submission.id);
                      } else {
                        _selectedSubmissions.remove(submission.id);
                      }
                    });
                  },
                )
              : null,
          title: Row(
            children: [
              Chip(
                label: Text(submission.type.toUpperCase()),
                backgroundColor: Colors.blue.shade100,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  submission.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text('By: ${submission.userId}'),
              Text('Submitted: ${dateFormat.format(submission.submittedAt)}'),
              if (submission.status == 'flagged')
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(Icons.warning, size: 16, color: Colors.orange),
                      SizedBox(width: 4),
                      Text(
                        'FLAGGED FOR REVIEW',
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Images
                  if (submission.mediaUrls.isNotEmpty) ...[
                    const Text(
                      'Media:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 200,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: submission.mediaUrls.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                submission.mediaUrls[index],
                                width: 200,
                                height: 200,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stack) => Container(
                                  width: 200,
                                  height: 200,
                                  color: Colors.grey.shade300,
                                  child: const Icon(Icons.broken_image),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Description
                  if (submission.description != null) ...[
                    const Text(
                      'Description:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(submission.description!),
                    const SizedBox(height: 16),
                  ],

                  // Tags
                  const Text(
                    'Tags:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: submission.tags.map((tag) {
                      return Chip(
                        label: Text(tag),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),

                  // Metadata
                  Row(
                    children: [
                      if (submission.difficulty != null)
                        Chip(
                          label: Text('Difficulty: ${submission.difficulty}'),
                          backgroundColor: Colors.purple.shade100,
                        ),
                      if (submission.priceRange != null) ...[
                        const SizedBox(width: 8),
                        Chip(
                          label: Text('Price: ${submission.priceRange}'),
                          backgroundColor: Colors.green.shade100,
                        ),
                      ],
                    ],
                  ),

                  if (submission.materials != null && submission.materials!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Materials:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(submission.materials!.join(', ')),
                  ],

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (submission.isPending || submission.isFlagged) ...[
                        IconButton(
                          onPressed: () => _deleteSubmission(submission),
                          icon: const Icon(Icons.delete_outline, color: Colors.grey),
                          tooltip: 'Delete',
                        ),
                        const SizedBox(width: 4),
                        TextButton.icon(
                          onPressed: () => _rejectSubmission(submission),
                          icon: const Icon(Icons.close, color: Colors.red),
                          label: const Text('REJECT'),
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () => _approveSubmission(submission),
                          icon: const Icon(Icons.check),
                          label: const Text('APPROVE'),
                        ),
                      ],
                      if (submission.isRejected) ...[
                        Expanded(
                          child: Text(
                            'Rejected: ${submission.rejectionReason ?? "No reason provided"}',
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                        IconButton(
                          onPressed: () => _deleteSubmission(submission),
                          icon: const Icon(Icons.delete_outline, color: Colors.grey),
                          tooltip: 'Delete',
                        ),
                      ],
                      if (submission.isApproved) ...[
                        const Text(
                          'Approved',
                          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => _deleteSubmission(submission),
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          tooltip: 'Delete Approved Entry',
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
