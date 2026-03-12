// lib/features/ai_analysis/screens/ai_analysis_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // ✅ 追加：debugPrintStack 用

import 'package:nursing_exam_poc/features/history/services/history_answer_service.dart';
import 'package:nursing_exam_poc/shared/theme/app_theme.dart';
import 'package:nursing_exam_poc/shared/widgets/base_scaffold.dart';

import 'package:nursing_exam_poc/features/ai_analysis/domain/domain_analysis.dart';
import 'package:nursing_exam_poc/features/ai_analysis/models/ai_analysis_models.dart';
import 'package:nursing_exam_poc/features/ai_analysis/screens/ai_analysis_detail_screen.dart';
import 'package:nursing_exam_poc/features/ai_analysis/screens/ai_analysis_history_screen.dart';
import 'package:nursing_exam_poc/features/ai_analysis/services/ai_analysis_service.dart';
import 'package:nursing_exam_poc/features/ai_analysis/storage/ai_analysis_history.dart';

class AiAnalysisScreen extends StatefulWidget {
  const AiAnalysisScreen({super.key});

  @override
  State<AiAnalysisScreen> createState() => _AiAnalysisScreenState();
}

class _AiAnalysisScreenState extends State<AiAnalysisScreen> {
  late Future<List<AnswerRecord>> _future;

  bool _isAnalyzingOverall = false;
  bool _isAnalyzingDomain = false;

  // 分野選択（必修＋10分野）は DomainAnalysis 側の定義をそのまま利用
  List<String> get _domainOptions => DomainAnalysis.domainOptions;

  String _selectedDomain = '必修';

  static const List<String> _requiredMajorOrder = [
    '健康の定義と理解',
    '健康に影響する要因',
    '看護で活用する社会保障',
    '看護における倫理',
    '看護に関わる基本的法律',
    '人間の特性',
    '人間のライフサイクル各期の特徴と生活',
    '看護の対象としての患者と家族',
    '主な看護活動の場と看護の機能',
    '人体の構造と機能',
    '徴候と疾患',
    '薬物の作用とその管理',
    '看護における基本技術',
    '日常生活援助技術',
    '患者の安全・安楽を守る看護技術',
    '診療に伴う看護技術',
  ];

  static const Map<String, List<String>> _domainMajorOrderMap = {
    '必修': _requiredMajorOrder,
    '人体の構造と機能': [
      '細胞と組織',
      '生体リズムと内部環境の恒常性',
      '神経系',
      '運動器系',
      '感覚器系',
      '循環器系',
      '血液',
      '体液',
      '生体の防御機構',
      '呼吸器系',
      '消化器系',
      '代謝系',
      '泌尿器系',
      '体温調節',
      '内分泌系',
    ],
    '疾病の成り立ちと回復の促進': [
      '疾病の成り立ち総論',
      '感染症の成り立ちと回復',
      '免疫とアレルギー',
      '腫瘍（がん）',
      '循環器疾患',
      '呼吸器疾患',
      '消化器疾患',
      '内分泌・代謝疾患',
      '腎・泌尿器疾患',
      '血液・造血器疾患',
      '運動器疾患',
      '神経・筋疾患',
      '感覚器疾患',
      '皮膚疾患',
      'その他の疾患と回復',
    ],
    '健康支援と社会保障制度': [
      '保健・医療・福祉制度の概要',
      '社会保障制度',
      '医療保険制度',
      '介護保険制度',
      '年金制度',
      '公的扶助制度',
      '地域包括ケア',
      '保健活動と健康増進',
      '生活習慣病予防',
    ],
    '成人看護学': [
      '急性期看護総論',
      '慢性期看護総論',
      '周手術期看護',
      '終末期看護',
      '循環器疾患の看護',
      '呼吸器疾患の看護',
      '消化器疾患の看護',
      '内分泌・代謝疾患の看護',
      '腎・泌尿器疾患の看護',
      '血液・造血器疾患の看護',
      '運動器疾患の看護',
      '神経疾患の看護',
      '感覚器疾患の看護',
      '皮膚疾患の看護',
      'その他成人期の看護',
    ],
    '老年看護学': [
      '老年期の発達と特徴',
      '老年期の健康課題',
      '老年症候群',
      '認知症の理解と看護',
      '老年期慢性疾患の看護',
      '日常生活支援',
      '家族支援と地域支援',
      '介護予防と多職種連携',
    ],
    '小児看護学': [
      '小児の成長と発達',
      '小児の健康と疾病',
      '小児のフィジカルアセスメント',
      '小児の栄養と食生活',
      '小児感染症と予防接種',
      '学童・思春期の健康課題',
      '家族看護と育児支援',
    ],
    '母性看護学': [
      '女性の生理と健康',
      '妊娠期の看護',
      '分娩期の看護',
      '産褥期の看護',
      '新生児看護',
      '母乳育児支援',
      '女性の健康問題',
    ],
    '精神看護学': [
      '精神保健の基礎',
      '主要な精神疾患',
      'ストレスと適応',
      '精神症状の理解',
      '心理社会的支援',
      '精神科リハビリテーション',
      '家族支援',
      '地域精神看護',
    ],
    '在宅看護論／地域・在宅看護論': [
      '在宅療養の基礎',
      '在宅ケアマネジメント',
      '訪問看護技術',
      '終末期在宅ケア',
      '家族支援と相談支援',
      '地域包括ケアと多職種連携',
      '在宅での疾病管理',
    ],
    '看護の統合と実践': [
      '看護過程の統合',
      '臨床判断と看護診断',
      '倫理的課題への対応',
      '安全管理と質改善',
      'チーム医療と多職種連携',
      '看護実践能力の評価',
    ],
  };

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

  // =========================
  // ★ 追加：AI生成のみ抽出
  // =========================
  List<AnswerRecord> _aiOnly(List<AnswerRecord> all) {
    return all.where((r) {
      // sourceType が無い/古いデータでも落ちないように安全に扱う
      final st = (r.sourceType ?? 'ai').trim();
      return st.isEmpty || st == 'ai';
    }).toList();
  }

  // ===== 共通の集計ロジック =====
  double _accuracyOf(List<AnswerRecord> items) {
    if (items.isEmpty) return 0.0;
    final correct = items.where((r) => r.isCorrect).length;
    return correct / items.length;
  }

  Map<String, DomainAgg> _aggregateByDomain(List<AnswerRecord> items) {
    return DomainAnalysis.aggregateByDomain(items);
  }

  String _pct(double v) => '${(v * 100).toStringAsFixed(1)}%';

  String _normalizeMajorLabel(String raw) {
    final trimmed = raw.trim();
    final m = RegExp(r'^\d+\.\s*(.*)$').firstMatch(trimmed);
    if (m != null && m.group(1) != null) {
      return m.group(1)!.trim();
    }
    return trimmed;
  }

  String _formatStudyAdvice(String raw) {
    var t = raw.trim();
    for (final n in ['2', '3', '4', '5']) {
      t = t.replaceAll(' $n.', '\n$n.');
    }
    return t;
  }

  Future<void> _runOverallAnalysis(List<AnswerRecord> records) async {
    if (records.isEmpty) return;

    setState(() => _isAnalyzingOverall = true);
    try {
      final result = await AiAnalysisService.analyzeOverall(
        records: records,
        isDomainScope: false,
      );

      final accAll = _accuracyOf(records);
      final body = _buildFullBody(
        result: result,
        scope: 'overall',
        targetLabel: '全体',
        sourceRecords: records,
      );

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
    } catch (e, st) {
      // ✅ 追加：スタックトレースを確実に出す
      debugPrint('AI分析(全体) エラー: $e');
      debugPrintStack(stackTrace: st);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI分析中にエラーが発生しました：$e')),
      );
    } finally {
      if (mounted) setState(() => _isAnalyzingOverall = false);
    }
  }

  Future<void> _runDomainAnalysis(List<AnswerRecord> records, String domainKey) async {
    final byDomain = _aggregateByDomain(records);
    final agg = byDomain[domainKey] ?? DomainAgg.empty(domainKey);

    if (agg.total == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('「$domainKey」の解答履歴がまだありません。')),
      );
      return;
    }

    final filtered = records
        .where((r) => DomainAnalysis.domainKeyOfRecord(r) == domainKey)
        .toList();
    if (filtered.isEmpty) return;

    setState(() => _isAnalyzingDomain = true);
    try {
      final result = await AiAnalysisService.analyzeOverall(
        records: filtered,
        isDomainScope: true,
      );

      final acc = _accuracyOf(filtered);
      final body = _buildFullBody(
        result: result,
        scope: 'domain',
        targetLabel: domainKey,
        sourceRecords: filtered,
      );

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
    } catch (e, st) {
      // ✅ 追加：スタックトレースを確実に出す
      debugPrint('AI分析(分野:$domainKey) エラー: $e');
      debugPrintStack(stackTrace: st);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('分野別AI分析中にエラーが発生しました：$e')),
      );
    } finally {
      if (mounted) setState(() => _isAnalyzingDomain = false);
    }
  }

  String _buildFullBody({
    required AiAnalysisResult result,
    required String scope,
    required String targetLabel,
    required List<AnswerRecord> sourceRecords,
  }) {
    final buf = StringBuffer();

    int _countCorrect(Iterable<AnswerRecord> items) =>
        items.where((r) => r.isCorrect).length;

    if (scope == 'overall') {
      final byDifficulty = <String, List<AnswerRecord>>{};
      for (final r in sourceRecords) {
        final key = (r.difficulty.isEmpty) ? '未分類' : r.difficulty.trim();
        byDifficulty.putIfAbsent(key, () => []).add(r);
      }

      buf.writeln('【出題形式別の成績】');
      final orderedKeys = <String>[
        '必修問題', '必修', '一般問題', '一般', '状況設定問題', '状況設定',
      ];
      final already = <String>{};

      void writeLinesForKey(String label) {
        final items = byDifficulty[label];
        if (items == null || items.isEmpty) return;
        already.add(label);
        final total = items.length;
        final correct = _countCorrect(items);
        final rate = correct / total;
        buf.writeln('・$label：${_pct(rate)}（$correct/$total問）');
      }

      for (final k in orderedKeys) {
        writeLinesForKey(k);
      }
      for (final entry in byDifficulty.entries) {
        if (already.contains(entry.key)) continue;
        final items = entry.value;
        if (items.isEmpty) continue;
        final total = items.length;
        final correct = _countCorrect(items);
        final rate = correct / total;
        buf.writeln('・${entry.key}：${_pct(rate)}（$correct/$total問）');
      }

      buf.writeln(result.difficultyComment);
      buf.writeln();

      final byDomain = _aggregateByDomain(sourceRecords);

      buf.writeln('【分野別の成績概要】');
      for (final name in _domainOptions) {
        final agg = byDomain[name] ?? DomainAgg.empty(name);
        if (agg.total == 0) continue;
        buf.writeln('・$name：${_pct(agg.rate)}（${agg.correct}/${agg.total}問）');
      }

      buf.writeln(result.domainComment);
      buf.writeln();

      buf.writeln('【これからの学び方の提案】');
      buf.writeln(_formatStudyAdvice(result.studyAdvice));
      buf.writeln();
      buf.writeln('【NurAIからのひとこと】');
      buf.writeln(result.nuraiComment);

      return buf.toString().trimRight();
    }

    final totalInDomain = sourceRecords.length;
    final correctInDomain = _countCorrect(sourceRecords);
    final rateInDomain = totalInDomain == 0 ? 0.0 : correctInDomain / totalInDomain;

    buf.writeln('【分野別の成績】');
    buf.writeln('・$targetLabel：${_pct(rateInDomain)}（$correctInDomain/$totalInDomain問）');
    buf.writeln(result.difficultyComment);
    buf.writeln();

    final byMajor = <String, List<AnswerRecord>>{};
    for (final r in sourceRecords) {
      final raw = (r.major ?? '').trim();
      final key = _normalizeMajorLabel(raw);
      final label = key.isEmpty ? '未分類' : key;
      byMajor.putIfAbsent(label, () => []).add(r);
    }

    buf.writeln('【科目ごとの成績】');

    final predefinedMajors = _domainMajorOrderMap[targetLabel];

    if (predefinedMajors != null && predefinedMajors.isNotEmpty) {
      for (final label in predefinedMajors) {
        final items = byMajor[label] ?? const <AnswerRecord>[];
        final total = items.length;
        final correct = _countCorrect(items);
        final rate = total == 0 ? 0.0 : correct / total;
        buf.writeln('・$label：${_pct(rate)}（$correct/$total問）');
      }

      final extraKeys = byMajor.keys.where((k) => !predefinedMajors.contains(k)).toList()..sort();
      for (final label in extraKeys) {
        final items = byMajor[label] ?? const <AnswerRecord>[];
        final total = items.length;
        final correct = _countCorrect(items);
        final rate = total == 0 ? 0.0 : correct / total;
        buf.writeln('・$label：${_pct(rate)}（$correct/$total問）');
      }
    } else {
      final majorEntries = byMajor.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
      for (final e in majorEntries) {
        final items = e.value;
        if (items.isEmpty) continue;
        final total = items.length;
        final correct = _countCorrect(items);
        final rate = correct / total;
        buf.writeln('・${e.key}：${_pct(rate)}（$correct/$total問）');
      }
    }

    buf.writeln(result.domainComment);
    buf.writeln();

    buf.writeln('【これからの学び方の提案】');
    buf.writeln(_formatStudyAdvice(result.studyAdvice));
    buf.writeln();
    buf.writeln('【NurAIからのひとこと】');
    buf.writeln(result.nuraiComment);

    return buf.toString().trimRight();
  }

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

          final allRecords = snap.data ?? const <AnswerRecord>[];

          // =========================
          // ★ ここが今回の本丸：AI生成だけに限定
          // =========================
          final records = _aiOnly(allRecords);

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
                      _conceptCard(theme, total),
                      const SizedBox(height: 20),
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
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                              : const Icon(Icons.auto_awesome_rounded),
                          label: Text(
                            _isAnalyzingOverall ? '全体を分析中...' : 'NurAIに全体の学習状況を分析してもらう',
                          ),
                          onPressed: _isAnalyzingOverall || records.isEmpty
                              ? null
                              : () => _runOverallAnalysis(records),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _summaryRow(
                        theme,
                        total,
                        accAll,
                        recent7d.length,
                        accRecent7d,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        '分野ごとのAI分析',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '必修や成人看護学など、特定の分野にフォーカスして分析します。',
                        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedDomain,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: '分析したい分野',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: _domainOptions
                                  .map((d) => DropdownMenuItem<String>(
                                value: d,
                                child: Text(d, maxLines: 1, overflow: TextOverflow.ellipsis),
                              ))
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
                      _domainCards(byDomainAgg),
                      const SizedBox(height: 16),
                      if (records.isEmpty)
                        Text(
                          'AI生成問題の解答履歴がまだありません。\nホーム画面から「問題を生成する」や「模試モード」で、いくつかAI生成問題を解いてみましょう。',
                          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                        )
                      else
                        Text(
                          '※ 解けば解くほど、NurAIの分析はあなたに最適化されていきます。',
                          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
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
          const Icon(
            Icons.psychology_rounded,
            size: 32,
            color: AppColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '解けば解くほど育つ、あなた専用のAIコーチ',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'NurAIのAI分析は、あなたの解答履歴をもとに「得意」「苦手」「これからの学び方」を一緒に考える機能です。'
                      '問題を解くたびに、NurAIはあなたの傾向を学習して賢くなっていきます。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  total == 0
                      ? 'まずは10〜20問程度を目安に、いろいろな分野の問題を解いてみましょう。'
                      : 'すでに $total 問のデータが蓄積されています。解けば解くほど、より精度の高い分析ができるようになります。',
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
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
          Text(title, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(main, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(sub, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _domainCards(Map<String, DomainAgg> agg) {
    final theme = Theme.of(context);

    final list = _domainOptions.map((name) => agg[name] ?? DomainAgg.empty(name)).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final maxW = constraints.maxWidth;
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
                onTap: () => setState(() => _selectedDomain = a.name),
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
                        style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '回答数：${a.total}問',
                        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                      ),
                      Text(
                        '正答率：${_pct(a.rate)}',
                        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
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