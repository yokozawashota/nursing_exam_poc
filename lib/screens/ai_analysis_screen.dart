// lib/screens/ai_analysis_screen.dart
import 'package:flutter/material.dart';

import '../widgets/base_scaffold.dart';
import '../models/answer_history.dart';
import '../theme/app_theme.dart';

import '../ai_analysis/ai_analysis_models.dart';
import '../ai_analysis/ai_analysis_service.dart';
import '../ai_analysis/ai_analysis_history.dart';
import '../ai_analysis/ai_analysis_prefs.dart';

import 'ai_analysis_detail_screen.dart';
import 'ai_analysis_history_screen.dart';

class AiAnalysisScreen extends StatefulWidget {
  const AiAnalysisScreen({super.key});

  @override
  State<AiAnalysisScreen> createState() => _AiAnalysisScreenState();
}

class _AiAnalysisScreenState extends State<AiAnalysisScreen> {
  late Future<List<AnswerRecord>> _future;

  bool _isAnalyzingOverall = false;
  bool _isAnalyzingDomain = false;

  // 分野選択（必修＋10分野）
  static const List<String> _domainOptions = [
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

  String _selectedDomain = '必修';

  @override
  void initState() {
    super.initState();
    _future = AnswerHistory.instance.all();
  }

  Future<void> _reload() async {
    setState(() {
      _future = AnswerHistory.instance.all();
    });
    await _future;
  }

  // ===== 共通の集計ロジック =====

  double _accuracyOf(List<AnswerRecord> items) {
    if (items.isEmpty) return 0.0;
    final correct = items.where((r) => r.isCorrect).length;
    return correct / items.length;
  }

  /// 1問のレコードを「必修＋10分野＋その他」のどれかにマッピングする
  String _domainKeyOfRecord(AnswerRecord r) {
    final buf = StringBuffer();
    buf.write(r.difficulty);
    if (r.domain != null) buf.write(' ${r.domain}');
    if (r.major != null) buf.write(' ${r.major}');
    if (r.mid != null) buf.write(' ${r.mid}');
    if (r.topic != null) buf.write(' ${r.topic}');
    final text = buf.toString();

    // 0) difficulty が「必修問題」なら必修に寄せる
    if (r.difficulty.contains('必修')) {
      return '必修';
    }

    // ① 基礎3分野
    if (text.contains('人体の構造')) {
      return '人体の構造と機能';
    }
    if (text.contains('疾病の成り立ち') || text.contains('回復の促進')) {
      return '疾病の成り立ちと回復の促進';
    }
    if (text.contains('健康支援') || text.contains('社会保障')) {
      return '健康支援と社会保障制度';
    }

    // ② 各看護学分野
    if (text.contains('成人看護')) {
      return '成人看護学';
    }
    if (text.contains('老年看護')) {
      return '老年看護学';
    }
    if (text.contains('小児看護')) {
      return '小児看護学';
    }
    if (text.contains('母性看護')) {
      return '母性看護学';
    }
    if (text.contains('精神看護')) {
      return '精神看護学';
    }
    if (text.contains('在宅看護論') || text.contains('地域・在宅看護')) {
      return '在宅看護論／地域・在宅看護論';
    }
    if (text.contains('統合と実践') || text.contains('看護の統合')) {
      return '看護の統合と実践';
    }

    // ③ どれにも当てはまらなければその他
    return 'その他';
  }

  Map<String, _DomainAgg> _aggregateByDomain(List<AnswerRecord> items) {
    final map = <String, _DomainAgg>{};
    for (final r in items) {
      final key = _domainKeyOfRecord(r);
      final agg = map.putIfAbsent(key, () => _DomainAgg.empty(key));
      agg.total += 1;
      if (r.isCorrect) agg.correct += 1;
    }

    // 存在しない分野も0で用意しておく（UIの並びを固定）
    for (final name in _domainOptions) {
      map.putIfAbsent(name, () => _DomainAgg.empty(name));
    }

    return map;
  }

  String _pct(double v) => '${(v * 100).toStringAsFixed(1)}%';

  // ===== AI分析 → 履歴保存 → 詳細画面へ遷移 =====

  Future<void> _runOverallAnalysis(List<AnswerRecord> records) async {
    if (records.isEmpty) return;

    setState(() => _isAnalyzingOverall = true);
    try {
      final result = await AiAnalysisService.analyzeOverall(
        records: records,
        tone: await AiAnalysisPrefs.getTone(),
      );

      final accAll = _accuracyOf(records);
      final body = _buildFullBody(result);

      final entry = AiAnalysisHistoryEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        createdAt: DateTime.now(),
        scope: 'overall',
        targetLabel: '全体',
        totalAnswers: result.totalAnswers,
        accuracy: accAll,
        body: body,
      );

      await AiAnalysisHistory.instance.add(entry);

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AiAnalysisDetailScreen(entry: entry),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI分析中にエラーが発生しました：$e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isAnalyzingOverall = false);
      }
    }
  }

  Future<void> _runDomainAnalysis(
      List<AnswerRecord> records, String domainKey) async {
    final byDomain = _aggregateByDomain(records);
    final agg = byDomain[domainKey] ?? _DomainAgg.empty(domainKey);

    if (agg.total == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('「$domainKey」の解答履歴がまだありません。')),
      );
      return;
    }

    if (agg.total < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '「$domainKey」のAI分析には、少なくとも5問以上の解答があると安定します。（現在: ${agg.total}問）'),
        ),
      );
    }

    final filtered =
    records.where((r) => _domainKeyOfRecord(r) == domainKey).toList();
    if (filtered.isEmpty) return;

    setState(() => _isAnalyzingDomain = true);
    try {
      final result = await AiAnalysisService.analyzeOverall(
        records: filtered,
        tone: await AiAnalysisPrefs.getTone(),
      );

      final acc = _accuracyOf(filtered);
      final body = _buildFullBody(result);

      final entry = AiAnalysisHistoryEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        createdAt: DateTime.now(),
        scope: 'domain',
        targetLabel: domainKey,
        totalAnswers: result.totalAnswers,
        accuracy: acc,
        body: body,
      );

      await AiAnalysisHistory.instance.add(entry);

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AiAnalysisDetailScreen(entry: entry),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('分野別AI分析中にエラーが発生しました：$e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isAnalyzingDomain = false);
      }
    }
  }

  /// 旧UIと同様の構成で、AiAnalysisResult から本文テキストを組み立てる
  String _buildFullBody(AiAnalysisResult r) {
    final buf = StringBuffer();

    buf.writeln('【出題形式ごとの傾向】');
    buf.writeln(r.difficultyComment);
    buf.writeln();
    buf.writeln('【分野別の強みと課題】');
    buf.writeln(r.domainComment);
    buf.writeln();
    buf.writeln('【これからの学び方の提案】');
    buf.writeln(r.studyAdvice);
    buf.writeln();
    buf.writeln('【NurAIからのひとこと】');
    buf.writeln(r.nuraiComment);

    return buf.toString().trimRight();
  }

  // ===== UI =====

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BaseScaffold(
      title: 'AI分析',
      showBack: false,
      showFooter: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.history_rounded),
          tooltip: '分析履歴を見る',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const AiAnalysisHistoryScreen(),
              ),
            );
          },
        ),
      ],
      body: FutureBuilder<List<AnswerRecord>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('解答履歴の読み込みに失敗しました：${snap.error}'),
              ),
            );
          }

          final records = snap.data ?? const <AnswerRecord>[];
          final total = records.length;
          final accAll = _accuracyOf(records);

          final now = DateTime.now();
          final from7d = now.subtract(const Duration(days: 7));
          final recent7d = records.where((r) => r.ts.isAfter(from7d)).toList();
          final accRecent7d = _accuracyOf(recent7d);

          final byDomainAgg = _aggregateByDomain(records);

          return RefreshIndicator(
            onRefresh: _reload,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // コンセプトカード
                      _conceptCard(theme, total),

                      const SizedBox(height: 20),

                      // ★ 「全体をAI分析」ボタン（サマリカードより上）
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          style: AppStyles.ctaButton(context),
                          icon: _isAnalyzingOverall
                              ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white),
                            ),
                          )
                              : const Icon(Icons.auto_awesome_rounded),
                          label: Text(
                            _isAnalyzingOverall
                                ? '全体を分析中...'
                                : 'NurAIに全体の学習状況を分析してもらう',
                          ),
                          onPressed: _isAnalyzingOverall || records.isEmpty
                              ? null
                              : () => _runOverallAnalysis(records),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // サマリカード（総合）
                      _summaryRow(theme, total, accAll, recent7d.length,
                          accRecent7d),

                      const SizedBox(height: 24),

                      // 分野ごとの分析セクション
                      Text(
                        '分野ごとのAI分析',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '必修や成人看護学など、特定の分野にフォーカスして分析します。',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.textSecondary),
                      ),

                      const SizedBox(height: 16),

                      // ★ 分野選択 + 分析ボタン（カードの上に移動）
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedDomain,
                              isExpanded: true, // ★ 追加：内部のRowを幅いっぱいにして縮めやすくする
                              decoration: const InputDecoration(
                                labelText: '分析したい分野',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: _domainOptions
                                  .map(
                                    (d) => DropdownMenuItem<String>(
                                  value: d,
                                  child: Text(
                                    d,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis, // ★ 長い文は「…」で省略
                                  ),
                                ),
                              )
                                  .toList(),
                              onChanged: (val) {
                                if (val == null) return;
                                setState(() => _selectedDomain = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                              ),
                              onPressed: _isAnalyzingDomain || records.isEmpty
                                  ? null
                                  : () => _runDomainAnalysis(records, _selectedDomain),
                              child: _isAnalyzingDomain
                                  ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                                  : const Text('分野を分析'),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // 分野別回答数カード（Wrap）
                      _domainCards(byDomainAgg),

                      const SizedBox(height: 16),

                      if (records.isEmpty)
                        Text(
                          'まだ解答履歴がありません。\nまずはホーム画面から「問題を生成する」や「模試モード」で、いくつか問題を解いてみましょう。',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: AppColors.textSecondary),
                        )
                      else
                        Text(
                          '※ 解けば解くほど、NurAIの分析はあなたに最適化されていきます。',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ===== 下請けUI部品 =====

  Widget _conceptCard(ThemeData theme, int total) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.psychology_rounded,
              size: 32, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '解けば解くほど育つ、あなた専用のAIコーチ',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'NurAIのAI分析は、あなたの解答履歴をもとに「得意」「苦手」「これからの学び方」を一緒に考える機能です。'
                      '問題を解くたびに、NurAIはあなたの傾向を学習して賢くなっていきます。',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 8),
                Text(
                  total == 0
                      ? 'まずは10〜20問程度を目安に、いろいろな分野の問題を解いてみましょう。'
                      : 'すでに $total 問のデータが蓄積されています。解けば解くほど、より精度の高い分析ができるようになります。',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(
      ThemeData theme,
      int total,
      double accAll,
      int recentCount,
      double accRecent7d,
      ) {
    return Row(
      children: [
        Expanded(
          child: _miniStatCard(
            theme,
            title: '累計',
            main: '$total 問',
            sub: '総合正答率：${_pct(accAll)}',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _miniStatCard(
            theme,
            title: '直近7日',
            main: '$recentCount 問',
            sub: '正答率：${_pct(accRecent7d)}',
          ),
        ),
      ],
    );
  }

  Widget _miniStatCard(
      ThemeData theme, {
        required String title,
        required String main,
        required String sub,
      }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(
            main,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _domainCards(Map<String, _DomainAgg> agg) {
    final theme = Theme.of(context);

    // _domainOptions の順で集計値を並べる
    final list = _domainOptions
        .map((name) => agg[name] ?? _DomainAgg.empty(name))
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final maxW = constraints.maxWidth;
        // 2カラム分の幅を計算（左右にきれいに揃うように）
        final itemWidth = (maxW - spacing) / 2;

        return Wrap(
          spacing: spacing,
          runSpacing: 12,
          children: list.map((a) {
            final selected = (a.name == _selectedDomain);

            return SizedBox(
              width: itemWidth,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  setState(() => _selectedDomain = a.name);
                },
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? theme.colorScheme.primary.withOpacity(0.08)
                        : theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected ? AppColors.primary : Colors.black12,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '回答数：${a.total}問',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                      Text(
                        '正答率：${_pct(a.rate)}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _DomainAgg {
  final String name;
  int total;
  int correct;

  _DomainAgg({
    required this.name,
    required this.total,
    required this.correct,
  });

  factory _DomainAgg.empty(String name) =>
      _DomainAgg(name: name, total: 0, correct: 0);

  double get rate => total == 0 ? 0.0 : correct / total;
}