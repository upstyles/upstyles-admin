class UserQualityScore {
  const UserQualityScore({
    required this.userId,
    required this.email,
    required this.score,
    required this.approvedCount,
    required this.rejectedCount,
    required this.totalSubmissions,
  });

  final String userId;
  final String email;
  final double score;
  final int approvedCount;
  final int rejectedCount;
  final int totalSubmissions;
}

class UserQualityService {
  // Placeholder - can be expanded later
  Future<List<UserQualityScore>> getTopContributors({int limit = 10}) async {
    // TODO: Implement actual query
    return [];
  }
}
