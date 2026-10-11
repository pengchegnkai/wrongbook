/// models/prompt_template.dart
class PromptTemplate {
  final int? id;
  final String name;
  final String? subject;
  final String? courseType;
  final String? questionType;
  final String templateContent;
  final bool isDefault;

  const PromptTemplate({
    this.id,
    required this.name,
    this.subject,
    this.courseType,
    this.questionType,
    required this.templateContent,
    this.isDefault = false,
  });

  factory PromptTemplate.fromJson(Map<String, dynamic> j) => PromptTemplate(
        id: j['id'],
        name: j['name'] ?? '',
        subject: j['subject'],
        courseType: j['course_type'],
        questionType: j['question_type'],
        templateContent: j['template_content'] ?? '',
        isDefault: j['is_default'] == true,
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'name': name,
        'subject': subject,
        'courseType': courseType,
        'questionType': questionType,
        'templateContent': templateContent,
        'isDefault': isDefault,
      };

  /// 设为默认的副本（列表页"设为默认"操作使用）
  PromptTemplate copyWithDefault() => PromptTemplate(
        id: id, name: name, subject: subject, courseType: courseType,
        questionType: questionType, templateContent: templateContent,
        isDefault: true,
      );
}

/// 可用变量（与后端 templateRenderer 一致）
const kTemplateVariables = [
  '{{subject}}', '{{chapter}}', '{{knowledgePoints}}', '{{originalQuestion}}',
  '{{myAnswer}}', '{{correctAnswer}}', '{{analysis}}', '{{errorType}}',
  '{{mastery}}', '{{questionType}}', '{{courseType}}', '{{extra}}',
];
