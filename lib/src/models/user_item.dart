class UserItem {
  final String id;
  final String? username;
  final String? displayName;
  final String? email;
  final String? photoUrl;
  final bool banned;
  final String? banReason;
  final DateTime? createdAt;

  UserItem({
    required this.id,
    this.username,
    this.displayName,
    this.email,
    this.photoUrl,
    this.banned = false,
    this.banReason,
    this.createdAt,
  });

  factory UserItem.fromJson(Map<String, dynamic> json) {
    return UserItem(
      id: json['id'] as String,
      username: json['username'] as String?,
      displayName: json['displayName'] as String?,
      email: json['email'] as String?,
      photoUrl: json['photoUrl'] as String?,
      banned: json['banned'] as bool? ?? false,
      banReason: json['banReason'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }
}

class PostItem {
  final String id;
  final String userId;
  final String? username;
  final String content;
  final bool hidden;
  final String? hideReason;
  final bool flagged;
  final int reportCount;
  final DateTime? createdAt;

  PostItem({
    required this.id,
    required this.userId,
    this.username,
    required this.content,
    this.hidden = false,
    this.hideReason,
    this.flagged = false,
    this.reportCount = 0,
    this.createdAt,
  });

  factory PostItem.fromJson(Map<String, dynamic> json) {
    return PostItem(
      id: json['id'] as String,
      userId: json['userId'] as String,
      username: json['username'] as String?,
      content: json['content'] as String? ?? '',
      hidden: json['hidden'] as bool? ?? false,
      hideReason: json['hideReason'] as String?,
      flagged: json['flagged'] as bool? ?? false,
      reportCount: json['reportCount'] as int? ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }
}

class ReportItem {
  final String id;
  final String targetType;
  final String targetId;
  final String reportedBy;
  final String reason;
  final String? description;
  final String status;
  final DateTime createdAt;

  ReportItem({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.reportedBy,
    required this.reason,
    this.description,
    this.status = 'pending',
    required this.createdAt,
  });

  factory ReportItem.fromJson(Map<String, dynamic> json) {
    return ReportItem(
      id: json['id'] as String,
      targetType: json['targetType'] as String,
      targetId: json['targetId'] as String,
      reportedBy: json['reportedBy'] as String,
      reason: json['reason'] as String,
      description: json['description'] as String?,
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
