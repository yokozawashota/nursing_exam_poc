// lib/features/past_exam/screens/past_exam_my_answers_list_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/base_scaffold.dart';

import '../models/past_exam_history.dart';
import '../models/past_exam_question.dart';
import 'past_exam_my_answer_detail_screen.dart';
import 'past_exam_question_screen.dart';

enum PastExamCorrectFilter {
  all,
  correct,
  wrong,
}

enum PastExamKindFilter {
  all,
  hisshu,
  ippan,
  situation,
}

enum PastExamTimeFilter {
  all,
  am,
  pm,
}

class PastExamMyAnswersListScreen extends StatefulWidget {
  const PastExamMyAnswersListScreen({
    super.key,
    required this.examId,
    required this.examTitle,
    required this.totalQuestions,
  });

  final String examId;
  final String examTitle;
  final int totalQuestions;

  @override
  State<PastExamMyAnswersListScreen> createState() =>
      _PastExamMyAnswersListScreenState();
}

class _PastExamMyAnswersListScreenState extends State<PastExamMyAnswersListScreen> {
  // ===== ちらつき対策：TextFieldの状態保持 =====
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  Timer? _debounce;

  // 検索キーワード（反映用）
  String _searchKeyword = '';

  // フィルタ
  PastExamCorrectFilter _correctFilter = PastExamCorrectFilter.all;
  PastExamKindFilter _kindFilter = PastExamKindFilter.all;
  PastExamTimeFilter _timeFilter = PastExamTimeFilter.all;

  // ===== 読み込み（buildでやらない） =====
  bool _loading = true;
  List<PastExamAnswerRecord> _allRecords = const [];

  late final VoidCallback _versionListener;

  @override
  void initState() {
    super.initState();

    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();

    _versionListener = () {
      _load();
    };
    PastExamHistory.instance.versionListenable.addListener(_versionListener);

    _load();
  }

  @override
  void dispose() {
    PastExamHistory.instance.versionListenable.removeListener(_versionListener);
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final list = await PastExamHistory.instance.recordsForExam(widget.examId);
      if (!mounted) return;
      setState(() {
        _allRecords = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _allRecords = const [];
        _loading = false;
      });
    }
  }

  Future<void> _reloadPull() async {
    await _load();
  }

  // ---- kind推測（partKindが空でも label から拾う） ----
  String _inferPartKindFromLabel(String label) {
    final t = label.trim();
    if (t.contains('状況')) return '状況設定';
    if (t.contains('一般')) return '一般';
    if (t.contains('必修')) return '必修';
    return '';
  }

  String _normalizedKind(PastExamAnswerRecord r) {
    final raw = (r.partKind ?? '').trim();
    if (raw.isNotEmpty) return raw;
    return _inferPartKindFromLabel(r.partLabel ?? '');
  }

  // ---- 午前/午後推測 ----
  PastExamTimeFilter _inferTime(PastExamAnswerRecord r) {
    final t = '${r.partLabel ?? ''} ${r.partKind ?? ''}'.trim();
    if (t.contains('午前')) return PastExamTimeFilter.am;
    if (t.contains('午後')) return PastExamTimeFilter.pm;
    return PastExamTimeFilter.all;
  }

  bool _matchesTime(PastExamAnswerRecord r) {
    switch (_timeFilter) {
      case PastExamTimeFilter.all:
        return true;
      case PastExamTimeFilter.am:
        return _inferTime(r) == PastExamTimeFilter.am;
      case PastExamTimeFilter.pm:
        return _inferTime(r) == PastExamTimeFilter.pm;
    }
  }

  // ===== フィルタ適用 =====
  bool _matchesCorrect(PastExamAnswerRecord r) {
    switch (_correctFilter) {
      case PastExamCorrectFilter.all:
        return true;
      case PastExamCorrectFilter.correct:
        return r.isCorrect;
      case PastExamCorrectFilter.wrong:
        return !r.isCorrect;
    }
  }

  bool _matchesKind(PastExamAnswerRecord r) {
    final kind = _normalizedKind(r);
    switch (_kindFilter) {
      case PastExamKindFilter.all:
        return true;
      case PastExamKindFilter.hisshu:
        return kind.contains('必修');
      case PastExamKindFilter.ippan:
        return kind.contains('一般');
      case PastExamKindFilter.situation:
        return kind.contains('状況');
    }
  }

  bool _matchesSearch(PastExamAnswerRecord r, String q) {
    final needle = q.trim();
    if (needle.isEmpty) return true;

    final hay = <String>[
      r.questionKey,
      r.examTitle ?? '',
      r.partLabel ?? '',
      r.partKind ?? '',
      r.questionText ?? '',
      ...((r.choices ?? const <String, String>{}).values),
      ...((r.selectedLabels ?? const <String>[])),
      ...((r.correctLabels ?? const <String>[])),
    ].join('\n');

    return hay.contains(needle);
  }

  List<PastExamAnswerRecord> _applyFilter(List<PastExamAnswerRecord> items) {
    var list = List<PastExamAnswerRecord>.from(items);

    list = list.where((r) {
      return _matchesCorrect(r) &&
          _matchesKind(r) &&
          _matchesTime(r) &&
          _matchesSearch(r, _searchKeyword);
    }).toList();

    // recordsForExam は PastExamHistory 側で「新しい順」
    return list;
  }

  double _accuracyOf(Iterable<PastExamAnswerRecord> items) {
    if (items.isEmpty) return 0.0;
    final correct = items.where((r) => r.isCorrect).length;
    return correct / items.length;
  }

  String _pct(double v) => '${(v * 100).toStringAsFixed(1)}%';

  String _formatDateTime(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y/$m/$d $hh:$mm';
  }

  Future<bool?> _confirmResetDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('解答履歴をリセットしますか？'),
        content: Text(
          '${widget.examTitle} の解答履歴がすべて削除されます。\n'
              'この操作は元に戻せません。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'リセット',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // ✅ ここが今回の本命：不正解を解き直す（復習ラベルは一切使わない）
  // =========================

  /// ✅ 年度内の不正解を「元の partLabel / partKind」ごとにグループ化する
  Map<_RetryGroupKey, List<PastExamAnswerRecord>> _wrongGroupsForRetry() {
    final wrong = _allRecords.where((r) => !r.isCorrect).toList();

    final Map<_RetryGroupKey, List<PastExamAnswerRecord>> groups = {};
    for (final r in wrong) {
      if (!r.hasSnapshot) continue; // スナップショット無いものは復習できない
      final key = _RetryGroupKey(
        partLabel: (r.partLabel ?? '').trim(),
        partKind: (r.partKind ?? '').trim(),
      );
      (groups[key] ??= []).add(r);
    }

    // 各グループを出題順っぽく整列
    for (final entry in groups.entries) {
      entry.value.sort((a, b) {
        final an = a.questionNo ?? 1 << 30;
        final bn = b.questionNo ?? 1 << 30;
        if (an != bn) return an.compareTo(bn);
        return a.answeredAtMs.compareTo(b.answeredAtMs);
      });
    }

    return groups;
  }

  /// ✅ PastExamAnswerRecord（履歴スナップショット）→ NuraiQuestion（出題用）に復元
  NuraiQuestion _toQuestionFromRecord(PastExamAnswerRecord r) {
    final questionText = (r.questionText ?? r.questionKey).trim();
    final choices = r.choices ?? const <String, String>{};
    final correctLabels = r.correctLabels ?? const <String>[];

    // 履歴だけだと厳密には分からないが最低限でOK
    final kind = (correctLabels.length >= 2) ? 'multi' : 'single';
    final requiredCorrectCount = (kind == 'multi') ? correctLabels.length : 1;

    final imagePath = (r.imagePath ?? '').trim();
    final imageRequired = imagePath.isNotEmpty;

    return NuraiQuestion(
      questionText: questionText,
      backgroundText: null,
      choices: choices,
      correctLabels: correctLabels,
      choiceRationales: r.rationales,
      explanation: r.explanation,
      questionKind: kind,
      requiredCorrectCount: requiredCorrectCount,

      // 履歴からは取れないのでダミー（表示やロジックに影響させない）
      difficulty: 'past_exam',
      domain: '',
      major: '',
      mid: null,
      topic: null,

      sourceType: 'past_exam',
      sourceTag: r.questionKey, // ユニークキー

      imagePath: imageRequired ? imagePath : null,
      imageRequired: imageRequired,
    );
  }

  Future<_RetryGroupKey?> _pickRetryGroup(
      BuildContext context,
      Map<_RetryGroupKey, List<PastExamAnswerRecord>> groups,
      ) async {
    final keys = groups.keys.toList();

    // グループが1つなら選択不要
    if (keys.length == 1) return keys.first;

    return showModalBottomSheet<_RetryGroupKey>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            itemCount: keys.length,
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemBuilder: (_, i) {
              final k = keys[i];
              final count = groups[k]?.length ?? 0;

              // 表示名（空だった場合の保険）
              final label = (k.partLabel.isNotEmpty) ? k.partLabel : '（パート不明）';
              final kind = (k.partKind.isNotEmpty) ? k.partKind : '';

              return ListTile(
                title: Text(
                  kind.isEmpty ? label : '$kind ・ $label',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text('不正解：$count 問'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(ctx).pop(k),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _startRetryWrong(BuildContext context) async {
    final groups = _wrongGroupsForRetry();

    if (groups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('不正解の履歴がありません（または復習用スナップショットがありません）')),
      );
      return;
    }

    final picked = await _pickRetryGroup(context, groups);
    if (picked == null) return;

    final records = groups[picked] ?? const <PastExamAnswerRecord>[];
    if (records.isEmpty) return;

    final qs = <NuraiQuestion>[
      for (final r in records) _toQuestionFromRecord(r),
    ];

    // ✅ ここが最重要：
    // PastExamQuestionScreen に「復習」などのラベルは一切渡さず、
    // 元の partLabel / partKind をそのまま渡す
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PastExamQuestionScreen(
          examId: widget.examId,
          examTitle: widget.examTitle,
          partLabel: picked.partLabel.isNotEmpty ? picked.partLabel : '（不正解の解き直し）',
          questions: qs,
          partKind: picked.partKind.isNotEmpty ? picked.partKind : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final all = _allRecords;
    final items = _applyFilter(all);

    final correctCount = all.where((r) => r.isCorrect).length;
    final wrongCount = all.length - correctCount;
    final acc = _accuracyOf(all);

    final hasSituation = all.any((r) => _normalizedKind(r).contains('状況'));

    return BaseScaffold(
      title: widget.examTitle,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _reloadPull,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
          itemCount: (all.isEmpty ? 1 : items.length + 1),
          separatorBuilder: (_, index) {
            if (index == 0) return const SizedBox(height: 8);
            return const Divider(height: 0);
          },
          itemBuilder: (context, index) {
            // ===== ヘッダー（常に表示） =====
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _headerCard(
                      context,
                      theme,
                      total: all.length,
                      correct: correctCount,
                      wrong: wrongCount,
                      accuracy: acc,
                      onReset: all.isEmpty
                          ? null
                          : () async {
                        final ok = await _confirmResetDialog(context);
                        if (ok != true) return;
                        await PastExamHistory.instance.resetExam(widget.examId);

                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${widget.examTitle} の解答履歴をリセットしました'),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _searchAndFilterBar(
                      theme,
                      hasSituation: hasSituation,
                    ),
                    if (all.isEmpty) ...[
                      const SizedBox(height: 20),
                      Center(
                        child: Text(
                          'まだ解答履歴がありません',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ] else if (items.isEmpty) ...[
                      const SizedBox(height: 20),
                      Center(
                        child: Text(
                          '検索条件に一致する解答履歴が見つかりませんでした',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(
                          '表示：${items.length}件',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }

            // データなしならヘッダーのみ
            if (all.isEmpty || items.isEmpty) {
              return const SizedBox.shrink();
            }

            final r = items[index - 1];
            return _buildRow(context, theme, r);
          },
        ),
      ),
    );
  }

  // ===== UI部品 =====

  Widget _headerCard(
      BuildContext context,
      ThemeData theme, {
        required int total,
        required int correct,
        required int wrong,
        required double accuracy,
        required VoidCallback? onReset,
      }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 上段：タイトル＋リセット
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '解答履歴（過去問）',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '解答数：$total 問   /   正答率：${_pct(accuracy)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '内訳：正解 $correct ・ 不正解 $wrong',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: onReset,
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: const Text('リセット'),
              ),
            ],
          ),
          // ✅ 下部：不正解を解き直す（常に表示・不正解0なら無効化）
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: (wrong > 0)
                  ? () => _startRetryWrong(context)
                  : null, // ← ここが重要（null でグレーアウト）
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('不正解を解き直す'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchAndFilterBar(
      ThemeData theme, {
        required bool hasSituation,
      }) {
    return Column(
      children: [
        // 検索（debounceで“止まった瞬間だけ反映”）
        TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          decoration: InputDecoration(
            hintText: '問題文・選択肢・パート名などで検索',
            prefixIcon: const Icon(Icons.search),
            isDense: true,
            border: const OutlineInputBorder(),
            suffixIcon: _searchController.text.trim().isEmpty
                ? null
                : IconButton(
              onPressed: () {
                _debounce?.cancel();
                _searchController.clear();
                setState(() => _searchKeyword = '');
              },
              icon: const Icon(Icons.clear_rounded),
            ),
          ),
          onChanged: (value) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 150), () {
              if (!mounted) return;
              setState(() {
                _searchKeyword = value;
              });
            });
          },
        ),
        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<PastExamKindFilter>(
                value: _kindFilter,
                decoration: const InputDecoration(
                  labelText: '種別',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(
                    value: PastExamKindFilter.all,
                    child: Text('全パート'),
                  ),
                  const DropdownMenuItem(
                    value: PastExamKindFilter.hisshu,
                    child: Text('必修のみ'),
                  ),
                  const DropdownMenuItem(
                    value: PastExamKindFilter.ippan,
                    child: Text('一般のみ'),
                  ),
                  if (hasSituation)
                    const DropdownMenuItem(
                      value: PastExamKindFilter.situation,
                      child: Text('状況設定のみ'),
                    ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _kindFilter = v);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<PastExamCorrectFilter>(
                value: _correctFilter,
                decoration: const InputDecoration(
                  labelText: '正誤',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: PastExamCorrectFilter.all,
                    child: Text('すべて'),
                  ),
                  DropdownMenuItem(
                    value: PastExamCorrectFilter.correct,
                    child: Text('正解のみ'),
                  ),
                  DropdownMenuItem(
                    value: PastExamCorrectFilter.wrong,
                    child: Text('不正解のみ'),
                  ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _correctFilter = v);
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        DropdownButtonFormField<PastExamTimeFilter>(
          value: _timeFilter,
          decoration: const InputDecoration(
            labelText: '午前・午後',
            isDense: true,
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(
              value: PastExamTimeFilter.all,
              child: Text('すべて'),
            ),
            DropdownMenuItem(
              value: PastExamTimeFilter.am,
              child: Text('午前'),
            ),
            DropdownMenuItem(
              value: PastExamTimeFilter.pm,
              child: Text('午後'),
            ),
          ],
          onChanged: (v) {
            if (v == null) return;
            setState(() => _timeFilter = v);
          },
        ),
      ],
    );
  }

  Widget _buildRow(BuildContext context, ThemeData theme, PastExamAnswerRecord r) {
    final kind = _normalizedKind(r);
    final part = (r.partLabel ?? '').trim();
    final no = r.questionNo ?? 0;
    final when = _formatDateTime(r.ts);

    final title = (r.questionText ?? '').trim();
    final showTitle = title.isNotEmpty ? title : r.questionKey;

    final leadingIcon = Icon(
      r.isCorrect ? Icons.check_circle_outline : Icons.cancel_outlined,
      color: r.isCorrect ? Colors.green[600] : Colors.red[500],
    );

    final meta = [
      if (kind.isNotEmpty) kind,
      if (part.isNotEmpty) part,
      if (no > 0) '第$no問',
    ].join(' ・ ');

    return ListTile(
      leading: leadingIcon,
      title: Text(
        showTitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text('$when${meta.isEmpty ? '' : ' ・ $meta'}'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PastExamMyAnswerDetailScreen(record: r),
          ),
        );
      },
    );
  }
}

class _RetryGroupKey {
  final String partLabel;
  final String partKind;

  const _RetryGroupKey({
    required this.partLabel,
    required this.partKind,
  });

  @override
  bool operator ==(Object other) {
    return other is _RetryGroupKey &&
        other.partLabel == partLabel &&
        other.partKind == partKind;
  }

  @override
  int get hashCode => Object.hash(partLabel, partKind);
}