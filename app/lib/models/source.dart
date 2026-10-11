/// models/source.dart —— 错题来源（A/B/C 可信度）
class QuestionSource {
  final int id;
  final int questionId;
  final String? provider;
  final String? url;
  final String? title;
  final String? author;
  final String authority; // A | B | C
  final String? snippet;
  final double? similarityScore;
  final bool adopted;

  const QuestionSource({
    required this.id,
    required this.questionId,
    this.provider,
    this.url,
    this.title,
    this.author,
    this.authority = 'C',
    this.snippet,
    this.similarityScore,
    this.adopted = false,
  });

  factory QuestionSource.fromJson(Map<String, dynamic> j) => QuestionSource(
        id: j['id'],
        questionId: j['question_id'],
        provider: j['provider'],
        url: j['url'],
        title: j['title'],
        author: j['author'],
        authority: j['authority'] ?? 'C',
        snippet: j['snippet'],
        similarityScore: (j['similarity_score'] as num?)?.toDouble(),
        adopted: j['adopted'] == true,
      );
}

String authorityLabel(String level) {
  switch (level) {
    case 'A': return 'A 级（官方/权威）';
    case 'B': return 'B 级（知名教育平台）';
    default: return 'C 级（普通来源）';
  }
}
