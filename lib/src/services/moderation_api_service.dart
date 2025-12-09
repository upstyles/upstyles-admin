import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

const String moderationApiBaseUrl = String.fromEnvironment(
  'MODERATION_API_BASE_URL',
  defaultValue: 'http://localhost:8080',
);

class ModerationApiService {
  ModerationApiService({http.Client? httpClient, FirebaseAuth? auth})
      : _http = httpClient ?? http.Client(),
        _auth = auth ?? FirebaseAuth.instance,
        _baseUrl = _normalizeBaseUrl(moderationApiBaseUrl);

  final http.Client _http;
  final FirebaseAuth _auth;
  final String _baseUrl;

  static String _normalizeBaseUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  Future<String> _requireToken() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Authentication required for moderation API calls');
    }
    // Force refresh token to get latest custom claims (moderator role)
    final token = await user.getIdToken(true); // true = force refresh
    if (token == null || token.isEmpty) {
      throw StateError('Unable to fetch Firebase ID token');
    }
    return token;
  }

  Future<Map<String, String>> _headers() async {
    final token = await _requireToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // EXPLORE MODERATION

  Future<List<ExploreCollection>> getExploreCollections() async {
    final url = Uri.parse('$_baseUrl/api/moderation/explore/collections');
    final headers = await _headers();

    final response = await _http.get(url, headers: headers);

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch collections: ${response.body}');
    }

    final data = jsonDecode(response.body);
    final collections = (data['collections'] as List?) ?? [];
    return collections.map((item) => ExploreCollection.fromJson(item)).toList();
  }

  Future<SubmissionQueueResult> getExploreQueue({
    String? status,
    int limit = 50,
    String? cursor,
  }) async {
    final queryParams = <String, String>{
      'limit': limit.toString(),
      if (status != null) 'status': status,
      if (cursor != null) 'cursor': cursor,
    };

    final url = Uri.parse('$_baseUrl/api/moderation/explore/queue')
        .replace(queryParameters: queryParams);
    final headers = await _headers();

    final response = await _http.get(url, headers: headers);

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch queue: ${response.body}');
    }

    final data = jsonDecode(response.body);
    return SubmissionQueueResult.fromJson(data);
  }

  Future<void> approveSubmission({
    required String submissionId,
    required String collectionId,
    double? trendScore,
  }) async {
    final url = Uri.parse('$_baseUrl/api/moderation/explore/$submissionId/approve');
    final headers = await _headers();

    final body = jsonEncode({
      'collectionId': collectionId,
      if (trendScore != null) 'trendScore': trendScore,
    });

    final response = await _http.post(url, headers: headers, body: body);

    if (response.statusCode != 200) {
      throw Exception('Failed to approve: ${response.body}');
    }
  }

  Future<void> rejectSubmission({
    required String submissionId,
    required String reason,
  }) async {
    final url = Uri.parse('$_baseUrl/api/moderation/explore/$submissionId/reject');
    final headers = await _headers();

    final body = jsonEncode({'reason': reason});

    final response = await _http.post(url, headers: headers, body: body);

    if (response.statusCode != 200) {
      throw Exception('Failed to reject: ${response.body}');
    }
  }
  Future<void> deleteSubmission({
    required String submissionId,
  }) async {
    final url = Uri.parse('$_baseUrl/api/moderation/explore/$submissionId');
    final headers = await _headers();

    final response = await _http.delete(url, headers: headers);

    if (response.statusCode != 200) {
      throw Exception('Failed to delete submission: ${response.body}');
    }
  }


  // BATCH OPERATIONS

  Future<BatchOperationResult> batchApproveSubmissions({
    required List<String> submissionIds,
    required String collectionId,
    double? trendScore,
  }) async {
    final url = Uri.parse('$_baseUrl/api/moderation/batch/batch-approve');
    final headers = await _headers();

    final body = jsonEncode({
      'submissionIds': submissionIds,
      'collectionId': collectionId,
      if (trendScore != null) 'trendScore': trendScore,
    });

    final response = await _http.post(url, headers: headers, body: body);

    if (response.statusCode != 200) {
      throw Exception('Batch approve failed: ${response.body}');
    }

    final data = jsonDecode(response.body);
    return BatchOperationResult.fromJson(data);
  }

  Future<BatchOperationResult> batchRejectSubmissions({
    required List<String> submissionIds,
    required String reason,
  }) async {
    final url = Uri.parse('$_baseUrl/api/moderation/batch/batch-reject');
    final headers = await _headers();

    final body = jsonEncode({
      'submissionIds': submissionIds,
      'reason': reason,
    });

    final response = await _http.post(url, headers: headers, body: body);

    if (response.statusCode != 200) {
      throw Exception('Batch reject failed: ${response.body}');
    }

    final data = jsonDecode(response.body);
    return BatchOperationResult.fromJson(data);
  }

  // AUDIT LOG

  Future<List<AuditLogEntry>> getAuditLog({
    int limit = 100,
    String? action,
    String? cursor,
  }) async {
    final queryParams = <String, String>{
      'limit': limit.toString(),
      if (action != null) 'action': action,
      if (cursor != null) 'cursor': cursor,
    };

    final url = Uri.parse('$_baseUrl/api/moderation/audit-log')
        .replace(queryParameters: queryParams);
    final headers = await _headers();

    final response = await _http.get(url, headers: headers);

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch audit log: ${response.body}');
    }

    final data = jsonDecode(response.body);
    final items = (data['items'] as List?) ?? [];
    return items.map((item) => AuditLogEntry.fromJson(item)).toList();
  }

  // USER MODERATION
  Future<List<dynamic>> getUsers({String? search, String? status}) async {
    final url = Uri.parse('$_baseUrl/api/moderation/users').replace(queryParameters: {
      if (search != null && search.isNotEmpty) 'search': search,
      if (status != null) 'status': status,
    });
    final headers = await _headers();
    final response = await _http.get(url, headers: headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['users'] as List;
    }
    throw Exception('Failed to fetch users');
  }

  Future<void> banUser({required String userId, required String reason}) async {
    final url = Uri.parse('$_baseUrl/api/moderation/users/$userId/ban');
    final headers = await _headers();
    final body = jsonEncode({'reason': reason});
    final response = await _http.post(url, headers: headers, body: body);
    if (response.statusCode != 200) throw Exception('Failed to ban user');
  }

  Future<void> unbanUser({required String userId}) async {
    final url = Uri.parse('$_baseUrl/api/moderation/users/$userId/unban');
    final headers = await _headers();
    final response = await _http.post(url, headers: headers);
    if (response.statusCode != 200) throw Exception('Failed to unban user');
  }

  Future<void> deleteUser({required String userId}) async {
    final url = Uri.parse('$_baseUrl/api/moderation/users/$userId');
    final headers = await _headers();
    final response = await _http.delete(url, headers: headers);
    if (response.statusCode != 200) throw Exception('Failed to delete user');
  }

  Future<Map<String, dynamic>> getUserDetails({required String userId}) async {
    final url = Uri.parse('$_baseUrl/api/moderation/users/$userId');
    final headers = await _headers();
    final response = await _http.get(url, headers: headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to fetch user details');
  }

  Future<void> hideUser({required String userId, String? reason}) async {
    final url = Uri.parse('$_baseUrl/api/moderation/users/$userId/hide');
    final headers = await _headers();
    final response = await _http.post(
      url,
      headers: headers,
      body: jsonEncode({'reason': reason}),
    );
    if (response.statusCode != 200) throw Exception('Failed to hide user');
  }

  Future<void> unhideUser({required String userId}) async {
    final url = Uri.parse('$_baseUrl/api/moderation/users/$userId/unhide');
    final headers = await _headers();
    final response = await _http.post(url, headers: headers);
    if (response.statusCode != 200) throw Exception('Failed to unhide user');
  }

  // POST MODERATION
  Future<List<dynamic>> getPosts({bool? flagged}) async {
    final url = Uri.parse('$_baseUrl/api/moderation/posts').replace(queryParameters: {
      if (flagged != null) 'flagged': flagged.toString(),
    });
    final headers = await _headers();
    final response = await _http.get(url, headers: headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['posts'] as List;
    }
    throw Exception('Failed to fetch posts');
  }

  Future<void> hidePost({required String postId, required String reason}) async {
    final url = Uri.parse('$_baseUrl/api/moderation/posts/$postId/hide');
    final headers = await _headers();
    final body = jsonEncode({'hidden': true, 'reason': reason});
    final response = await _http.post(url, headers: headers, body: body);
    if (response.statusCode != 200) throw Exception('Failed to hide post');
  }

  Future<void> deletePost({required String postId}) async {
    final url = Uri.parse('$_baseUrl/api/moderation/posts/$postId');
    final headers = await _headers();
    final response = await _http.delete(url, headers: headers);
    if (response.statusCode != 200) throw Exception('Failed to delete post');
  }

  Future<void> batchHidePosts({required List<String> postIds, String? reason}) async {
    final url = Uri.parse('$_baseUrl/api/moderation/posts/batch/hide');
    final headers = await _headers();
    final body = jsonEncode({'postIds': postIds, 'reason': reason});
    final response = await _http.post(url, headers: headers, body: body);
    if (response.statusCode != 200) throw Exception('Failed to batch hide posts');
  }

  Future<void> batchDeletePosts({required List<String> postIds}) async {
    final url = Uri.parse('$_baseUrl/api/moderation/posts/batch/delete');
    final headers = await _headers();
    final body = jsonEncode({'postIds': postIds});
    final response = await _http.post(url, headers: headers, body: body);
    if (response.statusCode != 200) throw Exception('Failed to batch delete posts');
  }

  // REPORTS
  Future<List<dynamic>> getReports({String? status, String? targetType}) async {
    final url = Uri.parse('$_baseUrl/api/moderation/reports').replace(queryParameters: {
      if (status != null) 'status': status,
      if (targetType != null) 'targetType': targetType,
    });
    final headers = await _headers();
    final response = await _http.get(url, headers: headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['reports'] as List;
    }
    throw Exception('Failed to fetch reports');
  }

  // COST / MODERATION STATS
  Future<Map<String, dynamic>> getModerationStats({DateTime? startDate, DateTime? endDate}) async {
    final queryParams = <String, String>{};
    if (startDate != null) queryParams['startDate'] = startDate.toIso8601String();
    if (endDate != null) queryParams['endDate'] = endDate.toIso8601String();

    final url = Uri.parse('$_baseUrl/api/admin/moderation/stats').replace(queryParameters: queryParams.isEmpty ? null : queryParams);
    final headers = await _headers();
    final response = await _http.get(url, headers: headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to fetch moderation stats: ${response.body}');
  }

  Future<Map<String, dynamic>> getModerationMonthlyCost() async {
    final url = Uri.parse('$_baseUrl/api/admin/moderation/monthly-cost');
    final headers = await _headers();
    final response = await _http.get(url, headers: headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to fetch monthly cost: ${response.body}');
  }

  Future<void> resolveReport({required String reportId, required String action, String? notes}) async {
    final url = Uri.parse('$_baseUrl/api/moderation/reports/$reportId/resolve');
    final headers = await _headers();
    final body = jsonEncode({'action': action, 'notes': notes});
    final response = await _http.post(url, headers: headers, body: body);
    if (response.statusCode != 200) throw Exception('Failed to resolve report');
  }
}

// Models

class ExploreCollection {
  const ExploreCollection({
    required this.id,
    required this.name,
    this.description,
    this.audience,
    this.priority,
  });

  factory ExploreCollection.fromJson(Map<String, dynamic> json) {
    return ExploreCollection(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      audience: json['audience'],
      priority: json['priority'],
    );
  }

  final String id;
  final String name;
  final String? description;
  final String? audience;
  final int? priority;
}

class SubmissionQueueResult {
  const SubmissionQueueResult({
    required this.items,
    this.nextCursor,
  });

  factory SubmissionQueueResult.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List?) ?? [];
    return SubmissionQueueResult(
      items: items.map((item) => SubmissionItem.fromJson(item)).toList(),
      nextCursor: json['nextCursor'],
    );
  }

  final List<SubmissionItem> items;
  final String? nextCursor;
}

class SubmissionItem {
  const SubmissionItem({
    required this.id,
    required this.userId,
    required this.status,
    required this.type,
    required this.title,
    required this.mediaUrls,
    required this.tags,
    required this.submittedAt,
    this.description,
    this.difficulty,
    this.priceRange,
    this.materials,
    this.reviewedAt,
    this.reviewedBy,
    this.rejectionReason,
    this.approvedEntryId,
  });

  factory SubmissionItem.fromJson(Map<String, dynamic> json) {
    return SubmissionItem(
      id: json['id'],
      userId: json['userId'],
      status: json['status'],
      type: json['type'],
      title: json['title'],
      mediaUrls: List<String>.from(json['mediaUrls'] ?? []),
      tags: List<String>.from(json['tags'] ?? []),
      submittedAt: DateTime.parse(json['submittedAt']),
      description: json['description'],
      difficulty: json['difficulty'],
      priceRange: json['priceRange'],
      materials: json['materials'] != null 
          ? List<String>.from(json['materials']) 
          : null,
      reviewedAt: json['reviewedAt'] != null 
          ? DateTime.parse(json['reviewedAt']) 
          : null,
      reviewedBy: json['reviewedBy'],
      rejectionReason: json['rejectionReason'],
      approvedEntryId: json['approvedEntryId'],
    );
  }

  final String id;
  final String userId;
  final String status;
  final String type;
  final String title;
  final List<String> mediaUrls;
  final List<String> tags;
  final DateTime submittedAt;
  final String? description;
  final String? difficulty;
  final String? priceRange;
  final List<String>? materials;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? rejectionReason;
  final String? approvedEntryId;

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isFlagged => status == 'flagged';
}

class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    required this.action,
    required this.moderatorId,
    required this.targetType,
    required this.targetId,
    required this.timestamp,
    this.moderatorEmail,
    this.reason,
    this.metadata,
  });

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) {
    return AuditLogEntry(
      id: json['id'],
      action: json['action'],
      moderatorId: json['moderatorId'],
      targetType: json['targetType'],
      targetId: json['targetId'],
      timestamp: DateTime.parse(json['timestamp']),
      moderatorEmail: json['moderatorEmail'],
      reason: json['reason'],
      metadata: json['metadata'],
    );
  }

  final String id;
  final String action;
  final String moderatorId;
  final String targetType;
  final String targetId;
  final DateTime timestamp;
  final String? moderatorEmail;
  final String? reason;
  final Map<String, dynamic>? metadata;
}

class BatchOperationResult {
  const BatchOperationResult({
    required this.success,
    required this.failed,
  });

  factory BatchOperationResult.fromJson(Map<String, dynamic> json) {
    return BatchOperationResult(
      success: List<String>.from(json['success'] ?? []),
      failed: (json['failed'] as List?)?.map((item) {
        return BatchOperationFailure(
          id: item['id'],
          error: item['error'],
        );
      }).toList() ?? [],
    );
  }

  final List<String> success;
  final List<BatchOperationFailure> failed;
}

class BatchOperationFailure {
  const BatchOperationFailure({
    required this.id,
    required this.error,
  });

  final String id;
  final String error;
}
