// lib/models/category_models.dart

/// 分野（Domain）> 大項目（Major）> 中項目（Mid）> トピック（Topic）
/// のツリー構造を型で表現するためのモデル。

class Topic {
  final String id;     // 内部ID（=既存のラベルでもOK）
  final String label;  // 表示名
  const Topic({required this.id, required this.label});
}

class MidCategory {
  final String id;
  final String label;
  final List<Topic> topics;
  const MidCategory({
    required this.id,
    required this.label,
    required this.topics,
  });
}

class MajorCategory {
  final String id;
  final String label;
  final List<MidCategory> mids;
  const MajorCategory({
    required this.id,
    required this.label,
    required this.mids,
  });
}

class DomainCategory {
  final String id;       // 例: '成人看護学' / '必修'
  final String label;    // 表示名
  final List<MajorCategory> majors;
  const DomainCategory({
    required this.id,
    required this.label,
    required this.majors,
  });
}

/// 分野〜トピックを指すパス（履歴保存・選定結果の受け渡しに便利）
class CategoryPath {
  final String domainId;
  final String majorId;
  final String? midId;
  final String? topicId;
  const CategoryPath({
    required this.domainId,
    required this.majorId,
    this.midId,
    this.topicId,
  });

  CategoryPath copyWith({
    String? domainId,
    String? majorId,
    String? midId,
    String? topicId,
  }) {
    return CategoryPath(
      domainId: domainId ?? this.domainId,
      majorId: majorId ?? this.majorId,
      midId: midId ?? this.midId,
      topicId: topicId ?? this.topicId,
    );
  }
}

/// （任意）状況設定の観点コードを型で扱うためのenum
enum ScenarioAspect { A, B, C, D, E }

extension ScenarioAspectX on ScenarioAspect {
  String get code => toString().split('.').last; // 'A'..'E'
  static ScenarioAspect? fromCode(String? c) {
    if (c == null) return null;
    switch (c) {
      case 'A': return ScenarioAspect.A;
      case 'B': return ScenarioAspect.B;
      case 'C': return ScenarioAspect.C;
      case 'D': return ScenarioAspect.D;
      case 'E': return ScenarioAspect.E;
    }
    return null;
  }
}