// lib/data/general/nursing_integration_practice.dart
//
// 看護の統合と実践（看-82〜看-84）原典完全一致版
// ・番号/英字は半角「1. 」「A. 」で統一
// ・小項目も原典どおりに収録
// ・関数名は categories.dart の参照に合わせて
//    nursingIntegrationPracticeMajors / Mids / TopicsOf を提供

final Map<String, Map<String, List<String>>> _nursingIntegration = {
  // 看-82
  '1. 看護におけるマネジメント': {
    'A. 看護におけるマネジメントの目的と方法': [
      '看護マネジメントの目的とプロセス',
      '看護組織の構成と職務',
      '看護行政の動向と看護マネジメント',
    ],
    'B. 医療・看護における質の保証と評価、改善の仕組み': [
      '医療・看護の質保証と評価',
      '医療・看護の標準化（標準看護計画、クリニカルパス）',
    ],
    'C. 看護業務のマネジメント': [
      '看護業務基準、看護手順',
      '看護提供システム',
      '複数の看護業務が同時に発生した場合の判断や対処方法',
    ],
    'D. 看護業務に関する情報に係る技術と取扱い': [
      '医療・看護業務に関する情報の活用と保管',
      '診療記録等の電子化と医療情報システム',
    ],
    'E. 医療安全を維持する仕組みと対策': [
      '安全管理体制整備、医療安全文化の醸成',
      '医療事故・インシデントレポートの分析と活用',
    ],
    'F. 看護師の働き方のマネジメント': [
      '看護師等の労働安全衛生',
      '看護の交代勤務',
      'ワーク・ライフ・バランスを促進する働き方',
    ],
  },

  // 看-83
  '2. 災害と看護': {
    'A. 災害時の医療を支えるしくみ': [
      '災害に関する法と制度',
      '災害時の医療体制',
    ],
    'B. 災害各期の特徴と看護': [
      '災害各期の特徴',
      '災害時の被災者・支援者の身体反応と心理過程',
      '災害時に生じやすい健康被害の特徴',
      '災害各期における要支援者を含むすべての被災者への看護',
    ],
  },

  // 看-84
  '3. 国際化と看護': {
    'A. グローバル化に伴う世界の健康目標と課題': [
      '世界共通の健康目標',
      '人間の安全保障',
      'プライマリ・ヘルス・ケア',
    ],
    'B. グローバルな社会における看護': [
      '看護の対象となる人々（在留外国人、在外日本人、帰国日本人、国際協力活動を必要とする人々）の健康課題',
      '多様な文化を考慮した看護',
    ],
  },
};

/// 大項目一覧
List<String> nursingIntegrationPracticeMajors() =>
    _nursingIntegration.keys.toList();

/// 指定大項目の中項目一覧
List<String> nursingIntegrationPracticeMids(String major) =>
    _nursingIntegration[major]?.keys.toList() ?? const [];

/// 指定（大項目, 中項目）の小項目（キーワード）
/// mid を null にすると、その大項目配下の全キーワードを連結して返す
List<String> nursingIntegrationPracticeTopicsOf(String major, [String? mid]) {
  final map = _nursingIntegration[major];
  if (map == null) return const [];
  if (mid == null) {
    final all = <String>[];
    for (final v in map.values) {
      all.addAll(v);
    }
    return all;
  }
  return map[mid] ?? const [];
}