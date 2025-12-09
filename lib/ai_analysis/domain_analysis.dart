// lib/ai_analysis/domain_analysis.dart
import '../models/answer_history.dart';

/// 分野集計 1件分
class DomainAgg {
  final String name;
  int total;
  int correct;

  DomainAgg({
    required this.name,
    this.total = 0,
    this.correct = 0,
  });

  factory DomainAgg.empty(String name) => DomainAgg(name: name);

  double get rate => total == 0 ? 0.0 : correct / total;
}

/// 「必修＋10分野＋その他」を扱う分野分析ユーティリティ
class DomainAnalysis {
  /// 分野選択（必修＋10分野）の固定リスト
  static const List<String> domainOptions = [
    '必修',
    '人体の構造と機能',
    '疾病の成り立ちと回復の促進',
    '健康支援と社会保障制度',
    '成人看護学',
    '老年看護学',
    '小児看護学',
    '母性看護学',
    '精神看護学',
    '在宅看護論／地域・在宅看護論',
    '看護の統合と実践',
    'その他',
  ];

  /// 1問のレコードを「必修＋10分野＋その他」のどれかにマッピングする
  ///
  /// 分野を起点として、必要に応じて
  ///   - domain（分野）
  ///   - major（科目）
  ///   - mid（中項目）
  ///   - topic（トピック）
  /// の文字列も使って判定します。
  static String domainKeyOfRecord(AnswerRecord r) {
    // 分野起点で文字列を構成（difficulty は補助情報として後ろに付ける）
    final buf = StringBuffer();
    if (r.domain != null && r.domain!.isNotEmpty) {
      buf.write('${r.domain} ');
    }
    if (r.major != null && r.major!.isNotEmpty) {
      buf.write('${r.major} ');
    }
    if (r.mid != null && r.mid!.isNotEmpty) {
      buf.write('${r.mid} ');
    }
    if (r.topic != null && r.topic!.isNotEmpty) {
      buf.write('${r.topic} ');
    }
    // difficulty も最後に加えて、必修などを拾えるようにしておく
    final allText = '${buf.toString()} ${r.difficulty}'.trim();

    // 0) 「必修」は difficulty または他の項目に含まれていれば必修扱い
    if (r.difficulty.contains('必修') || allText.contains('必修')) {
      return '必修';
    }

    // ① 基礎3分野
    if (allText.contains('人体の構造')) {
      return '人体の構造と機能';
    }
    if (allText.contains('疾病の成り立ち') || allText.contains('回復の促進')) {
      return '疾病の成り立ちと回復の促進';
    }
    if (allText.contains('健康支援') || allText.contains('社会保障')) {
      return '健康支援と社会保障制度';
    }

    // ② 各看護学分野
    if (allText.contains('成人看護')) {
      return '成人看護学';
    }
    if (allText.contains('老年看護')) {
      return '老年看護学';
    }
    if (allText.contains('小児看護')) {
      return '小児看護学';
    }
    if (allText.contains('母性看護')) {
      return '母性看護学';
    }
    if (allText.contains('精神看護')) {
      return '精神看護学';
    }
    if (allText.contains('在宅看護論') || allText.contains('地域・在宅看護')) {
      return '在宅看護論／地域・在宅看護論';
    }
    if (allText.contains('統合と実践') || allText.contains('看護の統合')) {
      return '看護の統合と実践';
    }

    // ③ どれにも当てはまらなければその他
    return 'その他';
  }

  /// 解答履歴を「必修＋各分野」ごとに集計
  static Map<String, DomainAgg> aggregateByDomain(List<AnswerRecord> items) {
    final map = <String, DomainAgg>{};

    for (final r in items) {
      final key = domainKeyOfRecord(r);
      final agg = map.putIfAbsent(key, () => DomainAgg.empty(key));
      agg.total += 1;
      if (r.isCorrect) agg.correct += 1;
    }

    // 存在しない分野も 0 で用意（UI の並びを固定したいので）
    for (final name in domainOptions) {
      map.putIfAbsent(name, () => DomainAgg.empty(name));
    }

    return map;
  }
}