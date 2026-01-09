// lib/features/past_exam/screens/past_exam_list_screen.dart
import 'package:flutter/material.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/base_scaffold.dart';

import '../models/past_exam_history.dart';
import '../models/past_exam_question.dart';
import '../services/past_exam_repository.dart';
import 'past_exam_question_screen.dart';

class PastExamListScreen extends StatefulWidget {
  const PastExamListScreen({
    super.key,
    required this.examId,
    required this.examTitle,
    required this.totalQuestions,
  });

  final String examId;      // '111'
  final String examTitle;   // '第111回（2022年）'
  final int totalQuestions; // 年度合計（表示用）

  @override
  State<PastExamListScreen> createState() => _PastExamListScreenState();
}

class _PastExamListScreenState extends State<PastExamListScreen> {
  bool _loading = true;

  List<PastExamAnswerRecord> _records = const [];

  final Map<String, int> _totalByPartKey = {};
  final Map<String, bool> _availableByPartKey = {};

  @override
  void initState() {
    super.initState();
    _load();
    PastExamHistory.instance.versionListenable.addListener(_onHistoryChanged);
  }

  @override
  void dispose() {
    PastExamHistory.instance.versionListenable.removeListener(_onHistoryChanged);
    super.dispose();
  }

  void _onHistoryChanged() {
    _loadHistoryOnly();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);

    await _loadHistoryOnly();
    await _probeParts();

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _loadHistoryOnly() async {
    try {
      final list = await PastExamHistory.instance.recordsForExam(widget.examId);
      if (!mounted) return;
      setState(() => _records = list);
    } catch (_) {
      if (!mounted) return;
      setState(() => _records = const []);
    }
  }

  static const _partMetas = <_PartMeta>[
    _PartMeta(partKey: 'hisshu_am', label: '必修問題', timeLabel: '午前'),
    _PartMeta(partKey: 'hisshu_pm', label: '必修問題', timeLabel: '午後'),
    _PartMeta(partKey: 'ippan_am', label: '一般問題', timeLabel: '午前'),
    _PartMeta(partKey: 'ippan_pm', label: '一般問題', timeLabel: '午後'),
    _PartMeta(partKey: 'jokyo_am', label: '状況設定問題', timeLabel: '午前'),
    _PartMeta(partKey: 'jokyo_pm', label: '状況設定問題', timeLabel: '午後'),
  ];

  List<_PartMeta> _partsOf(String timeLabel) {
    return _partMetas.where((p) => p.timeLabel == timeLabel).toList();
  }

  Future<void> _probeParts() async {
    _totalByPartKey.clear();
    _availableByPartKey.clear();

    for (final p in _partMetas) {
      try {
        final list = await PastExamRepository.instance.load(
          examId: widget.examId,
          partKey: p.partKey,
        );
        _availableByPartKey[p.partKey] = list.isNotEmpty;
        _totalByPartKey[p.partKey] = list.length;
      } catch (_) {
        _availableByPartKey[p.partKey] = false;
        _totalByPartKey[p.partKey] = 0;
      }
    }

    if (!mounted) return;
    setState(() {});
  }

  int _solvedCountForPartKey(String partLabelWithTime) {
    // partLabel の一致でカウント（保存側 PastExamQuestionScreen に partLabel を渡している前提）
    return _records.where((r) {
      final pl = (r.partLabel ?? '').trim();
      if (pl.isNotEmpty) return pl == partLabelWithTime;

      // フォールバック（古いデータ向け）
      final k = r.questionKey;
      return k.contains(partLabelWithTime);
    }).length;
  }

  int _solvedCountForPart(_PartMeta p) => _solvedCountForPartKey('${p.label} ${p.timeLabel}');

  int _totalCountForTime(String timeLabel) {
    var total = 0;
    for (final p in _partsOf(timeLabel)) {
      total += (_totalByPartKey[p.partKey] ?? 0);
    }
    return total;
  }

  int _solvedCountForTime(String timeLabel) {
    var solved = 0;
    for (final p in _partsOf(timeLabel)) {
      solved += _solvedCountForPart(p);
    }
    return solved;
  }

  bool _hasAnyDataForTime(String timeLabel) {
    return _partsOf(timeLabel).any((p) => (_availableByPartKey[p.partKey] ?? false));
  }

  String _partKindFromPartKey(String partKey) {
    final lower = partKey.toLowerCase();
    if (lower.startsWith('hisshu')) return '必修';
    if (lower.startsWith('ippan')) return '一般';
    if (lower.startsWith('jokyo')) return '状況設定';
    return '';
  }

  Future<void> _openPart(_PartMeta p) async {
    try {
      final questions = await PastExamRepository.instance.load(
        examId: widget.examId,
        partKey: p.partKey,
      );

      if (!mounted) return;

      if (questions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('このパートの過去問データが見つかりませんでした（${p.partKey}.json）')),
        );
        return;
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PastExamQuestionScreen(
            examTitle: widget.examTitle,
            partLabel: '${p.label} ${p.timeLabel}',
            questions: questions,
            examId: widget.examId, // ✅ 必須
            partKind: _partKindFromPartKey(p.partKey), // ✅ 履歴用（任意だが入れておく）
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('過去問の読み込みに失敗しました: $e')),
      );
    }
  }

  Future<void> _openTimeAll(String timeLabel) async {
    final parts = _partsOf(timeLabel).where((p) => (_availableByPartKey[p.partKey] ?? false)).toList();

    if (parts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$timeLabel の過去問データが見つかりませんでした')),
      );
      return;
    }

    try {
      final merged = <NuraiQuestion>[];

      for (final p in parts) {
        final list = await PastExamRepository.instance.load(
          examId: widget.examId,
          partKey: p.partKey,
        );
        merged.addAll(list);
      }

      if (!mounted) return;

      if (merged.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$timeLabel の過去問データが見つかりませんでした')),
        );
        return;
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PastExamQuestionScreen(
            examTitle: widget.examTitle,
            partLabel: timeLabel, // まとめ解答
            questions: merged,
            examId: widget.examId, // ✅ 必須
            partKind: 'まとめ', // ✅ 履歴表示のラベル用（任意）
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('過去問の読み込みに失敗しました: $e')),
      );
    }
  }

  void _showPartsSheet(String timeLabel) {
    final parts = _partsOf(timeLabel).where((p) => (_availableByPartKey[p.partKey] ?? false)).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final theme = Theme.of(context);

        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.black12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ヘッダー
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$timeLabel：種別ごとに解く',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '必修・一般・状況設定から選べます',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // リスト
                ...parts.map((p) {
                  final total = _totalByPartKey[p.partKey] ?? 0;
                  final solved = _solvedCountForPart(p);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        Navigator.of(context).pop();
                        _openPart(p);
                      },
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${p.label} $timeLabel',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '$solved問 / $total問 解答',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),

                if (parts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Text(
                      'この時間帯のデータが見つかりませんでした',
                      style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final hasAm = _hasAnyDataForTime('午前');
    final hasPm = _hasAnyDataForTime('午後');

    return BaseScaffold(
      title: widget.examTitle,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          _totalCard(theme),
          const SizedBox(height: 14),

          _timeCard(
            theme,
            timeLabel: '午前',
            hasData: hasAm,
            solved: _solvedCountForTime('午前'),
            total: _totalCountForTime('午前'),
            onStart: hasAm ? () => _openTimeAll('午前') : null,
            onByType: hasAm ? () => _showPartsSheet('午前') : null,
          ),

          const SizedBox(height: 12),

          _timeCard(
            theme,
            timeLabel: '午後',
            hasData: hasPm,
            solved: _solvedCountForTime('午後'),
            total: _totalCountForTime('午後'),
            onStart: hasPm ? () => _openTimeAll('午後') : null,
            onByType: hasPm ? () => _showPartsSheet('午後') : null,
          ),

          if (!hasAm && !hasPm)
            Padding(
              padding: const EdgeInsets.only(top: 28),
              child: Center(
                child: Text(
                  'この年度の過去問データが見つかりませんでした。',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _totalCard(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Text(
        '総問題数：${widget.totalQuestions}問',
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _timeCard(
      ThemeData theme, {
        required String timeLabel,
        required bool hasData,
        required int solved,
        required int total,
        required VoidCallback? onStart,
        required VoidCallback? onByType,
      }) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Opacity(
        opacity: hasData ? 1.0 : 0.45,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 上段：タイトル＋開始ボタン
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$timeLabelの問題を解く',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
                SizedBox(
                  height: 38,
                  child: ElevatedButton(
                    onPressed: onStart,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: const Text(
                      '開始',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // 進捗
            Text(
              hasData ? '$solved問 / $total問 解答' : 'データ未登録',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),

            // 種別リンク（副機能）
            if (hasData) ...[
              const SizedBox(height: 12),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onByType,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.tune_rounded, size: 18, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        '種別ごとに問題を解く',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.primary, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PartMeta {
  final String partKey;
  final String label;     // 必修問題 / 一般問題 / 状況設定問題（時間は別で付ける）
  final String timeLabel; // 午前/午後

  const _PartMeta({
    required this.partKey,
    required this.label,
    required this.timeLabel,
  });
}