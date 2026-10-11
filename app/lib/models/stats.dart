/// models/stats.dart
class OverviewStats {
  final int total;
  final int subjectCount;
  final Map<String, int> mastery;
  final int todayReview;
  final int verifiedSources;
  final int pendingVerify;

  const OverviewStats({
    required this.total,
    required this.subjectCount,
    required this.mastery,
    required this.todayReview,
    required this.verifiedSources,
    required this.pendingVerify,
  });

  factory OverviewStats.fromJson(Map<String, dynamic> j) => OverviewStats(
        total: j['total'] ?? 0,
        subjectCount: j['subjectCount'] ?? 0,
        mastery: (j['mastery'] as Map<String, dynamic>?)?.cast<String, int>() ?? {},
        todayReview: j['todayReview'] ?? 0,
        verifiedSources: j['verifiedSources'] ?? 0,
        pendingVerify: j['pendingVerify'] ?? 0,
      );
}

class SubjectStat {
  final String label;
  final int count;
  const SubjectStat(this.label, this.count);

  factory SubjectStat.fromJson(Map<String, dynamic> j) =>
      SubjectStat('${j['label'] ?? j['subject'] ?? j['error_type'] ?? j['mastery'] ?? j['day'] ?? ''}', j['n'] ?? 0);
}
