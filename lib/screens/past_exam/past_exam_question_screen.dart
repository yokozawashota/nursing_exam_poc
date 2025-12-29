// lib/screens/past_exam/past_exam_question_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/nurai_question.dart';
import '../../models/past_exam_history.dart';
import '../../theme/app_theme.dart';
import '../../widgets/base_scaffold.dart';

class PastExamQuestionScreen extends StatefulWidget {
  const PastExamQuestionScreen({
    super.key,
    required this.examTitle,
    required this.partLabel,
    required this.questions,
    required this.examId, // ✅ 推測に頼らない（必須）
    this.partKind,
  });

  final String examTitle;
  final String partLabel;
  final List<NuraiQuestion> questions;

  /// ✅ 履歴保存用（必須）
  final String examId;

  /// 履歴保存用（無くても動く）
  final String? partKind;

  @override
  State<PastExamQuestionScreen> createState() => _PastExamQuestionScreenState();
}

class _PastExamQuestionScreenState extends State<PastExamQuestionScreen> {
  int _index = 0;

  // 解答状態
  bool _answered = false;
  Set<String> _selected = {}; // 選択式用（A/B/C...）
  String _inputAnswer = ''; // 入力式用
  bool _isCorrect = false;

  // 背景文の折りたたみ
  bool _bgExpanded = false;

  final TextEditingController _inputCtl = TextEditingController();

  NuraiQuestion get _q => widget.questions[_index];

  bool get _isInputMode => _q.choices.isEmpty; // choicesが空なら入力式

  @override
  void dispose() {
    _inputCtl.dispose();
    super.dispose();
  }

  /// ✅ 履歴キーは「sourceTag をそのまま使う」
  /// - PastExamHistory 側で examId::questionKey として保存されるので examId は二重に入れない
  /// - sourceTag が空のときだけフォールバックで生成
  ///
  /// これで「past_exam:113:past_exam:113:...」のような二重加工が発生しない
  String _questionKeyForHistory() {
    final q = _q;
    final tag = q.sourceTag.trim();
    if (tag.isNotEmpty) return tag;

    // tag が空の場合だけ、画面側で安定キーを作る（最低限）
    return 'past_exam:${widget.partLabel}:${_index + 1}';
  }

  bool _isMultiKind(String kind) {
    final k = kind.trim().toLowerCase();
    return k == 'multi' || k == 'multiple';
  }

  bool _judgeInputCorrect({
    required String input,
    required List<String> correctLabels,
  }) {
    final inT = input.trim();
    if (inT.isEmpty) return false;

    final correct = correctLabels.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (correct.isEmpty) return false;

    final inNum = double.tryParse(inT);
    if (inNum != null) {
      for (final c in correct) {
        final cNum = double.tryParse(c);
        if (cNum != null) {
          if ((inNum - cNum).abs() < 1e-6) return true;
        }
      }
    }

    return correct.contains(inT);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = _q;

    final total = widget.questions.length;
    final numberLabel = '${_index + 1} / $total';

    final bg = (q.backgroundText ?? '').trim();

    final canSubmit = _answered
        ? true
        : (_isInputMode ? _inputAnswer.trim().isNotEmpty : _selected.isNotEmpty);

    return BaseScaffold(
      title: widget.partLabel,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          // 上部情報
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.examTitle,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                numberLabel,
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 背景文（状況設定など）
          if (bg.isNotEmpty) ...[
            _BackgroundBlock(
              text: bg,
              expanded: _bgExpanded,
              onToggle: () => setState(() => _bgExpanded = !_bgExpanded),
            ),
            const SizedBox(height: 12),
          ],

          // 問題文
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.6)),
            ),
            child: Text(
              q.questionText,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
          ),

          if (q.imageRequired && (q.imagePath ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.6)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: Image.asset(
                    q.imagePath!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        '画像を読み込めません: ${q.imagePath}',
                        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // ===== 入力式（計算など：choicesが空）=====
          if (_isInputMode) ...[
            Text(
              '解答を入力',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.6)),
              ),
              child: TextField(
                controller: _inputCtl,
                enabled: !_answered,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9\.\-]')),
                ],
                decoration: const InputDecoration(
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _inputAnswer = v),
              ),
            ),
            const SizedBox(height: 10),
          ] else ...[
            // ===== 選択式 =====
            ...q.choices.entries.map((e) {
              final label = e.key;
              final text = e.value;

              final isSelected = _selected.contains(label);
              final correctSet = q.correctLabels.toSet();
              final isCorrectChoice = correctSet.contains(label);

              Color border = Colors.black12;
              Color bgc = theme.colorScheme.surface;

              if (_answered) {
                if (isCorrectChoice) {
                  border = Colors.green.withOpacity(0.75);
                  bgc = Colors.green.withOpacity(0.06);
                } else if (isSelected && !isCorrectChoice) {
                  border = Colors.red.withOpacity(0.75);
                  bgc = Colors.red.withOpacity(0.05);
                }
              } else {
                if (isSelected) {
                  border = theme.colorScheme.primary.withOpacity(0.7);
                  bgc = theme.colorScheme.primary.withOpacity(0.06);
                }
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _answered ? null : () => _tapChoice(label),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: bgc,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 28,
                          child: Text(
                            label,
                            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            text,
                            style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],

          const SizedBox(height: 8),

          // 下部ボタン（前へ/解答/次へ）
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _index == 0 ? null : _prev,
                  child: const Text('前へ'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: canSubmit ? (_answered ? _next : _check) : null,
                  child: Text(_answered ? '次へ' : '解答する'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // 解答後：解説＆根拠
          if (_answered) ...[
            const SizedBox(height: 10),
            _ResultBlock(
              isCorrect: _isCorrect,
              explanation: (q.explanation ?? '').trim(),
              choiceRationales: q.choiceRationales ?? const {},
              correctLabels: q.correctLabels,
              selectedLabels: _isInputMode ? [_inputAnswer.trim()] : _selected.toList(),
              showAnswerAsTextInput: _isInputMode,
            ),
          ],
        ],
      ),
    );
  }

  void _tapChoice(String label) {
    final q = _q;
    final isMulti = _isMultiKind(q.questionKind);

    setState(() {
      HapticFeedback.selectionClick();

      if (isMulti) {
        if (_selected.contains(label)) {
          _selected.remove(label);
        } else {
          _selected.add(label);
        }
      } else {
        _selected = {label};
      }
    });
  }

  void _check() async {
    final q = _q;

    bool isCorrect = false;

    if (_isInputMode) {
      final input = _inputAnswer.trim();
      if (input.isEmpty) return;

      isCorrect = _judgeInputCorrect(
        input: input,
        correctLabels: q.correctLabels,
      );
    } else {
      if (_selected.isEmpty) return;

      final correct = q.correctLabels.toSet();
      final selected = _selected.toSet();
      final kind = q.questionKind;

      if (kind == 'select_incorrect') {
        isCorrect = selected.length == correct.length && selected.containsAll(correct);
      } else if (_isMultiKind(kind)) {
        isCorrect = selected.length == correct.length && selected.containsAll(correct);
      } else {
        isCorrect = selected.length == 1 && correct.contains(selected.first);
      }
    }

    setState(() {
      _answered = true;
      _isCorrect = isCorrect;
    });

    final key = _questionKeyForHistory();

    try {
      await PastExamHistory.instance.upsertAnswerWithSnapshot(
        examId: widget.examId,
        questionKey: key,
        isCorrect: isCorrect,
        examTitle: widget.examTitle,
        partLabel: widget.partLabel,
        partKind: widget.partKind,
        questionNo: _index + 1,
        questionText: q.questionText,
        choices: q.choices,
        correctLabels: q.correctLabels,
        selectedLabels: _isInputMode ? [_inputAnswer.trim()] : _selected.toList(),
        explanation: q.explanation,
        rationales: q.choiceRationales,
        imagePath: q.imagePath,
      );

      debugPrint('[PAST_EXAM] saved ✅ examId=${widget.examId} key=$key part=${widget.partLabel} no=${_index + 1}');
    } catch (e, st) {
      debugPrint('[PAST_EXAM] save FAILED ❌ examId=${widget.examId} key=$key');
      debugPrint(e.toString());
      debugPrint(st.toString());
    }
  }

  void _prev() {
    if (_index <= 0) return;

    setState(() {
      _index--;
      _answered = false;
      _selected = {};
      _inputAnswer = '';
      _inputCtl.text = '';
      _isCorrect = false;
      _bgExpanded = false;
    });
  }

  void _next() {
    if (_index + 1 >= widget.questions.length) {
      final total = widget.questions.length;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => _PastExamSimpleResultScreen(
            title: widget.partLabel,
            subtitle: widget.examTitle,
            total: total,
          ),
        ),
      );
      return;
    }

    setState(() {
      _index++;
      _answered = false;
      _selected = {};
      _inputAnswer = '';
      _inputCtl.text = '';
      _isCorrect = false;
      _bgExpanded = false;
    });
  }
}

/// 背景文の折りたたみブロック
class _BackgroundBlock extends StatelessWidget {
  const _BackgroundBlock({
    required this.text,
    required this.expanded,
    required this.onToggle,
  });

  final String text;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.6)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '背景文（タップで${expanded ? "閉じる" : "表示"}）',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Icon(
                    expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
              if (expanded) ...[
                const SizedBox(height: 10),
                Text(
                  text,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 解説＋根拠（同フォント）
class _ResultBlock extends StatelessWidget {
  const _ResultBlock({
    required this.isCorrect,
    required this.explanation,
    required this.choiceRationales,
    required this.correctLabels,
    required this.selectedLabels,
    required this.showAnswerAsTextInput,
  });

  final bool isCorrect;
  final String explanation;
  final Map<String, String> choiceRationales;
  final List<String> correctLabels;
  final List<String> selectedLabels;
  final bool showAnswerAsTextInput;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final correctSet = correctLabels.toSet();
    final selectedSet = selectedLabels.toSet();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isCorrect ? '正解' : '不正解',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: isCorrect ? Colors.green : Colors.red,
            ),
          ),
          const SizedBox(height: 10),

          if (showAnswerAsTextInput) ...[
            Text('あなたの解答', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(
              selectedLabels.isNotEmpty ? selectedLabels.first : '',
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
            const SizedBox(height: 10),

            Text('正答', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(
              correctLabels.isNotEmpty ? correctLabels.join(', ') : '',
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
            const SizedBox(height: 12),
          ],

          if (explanation.trim().isNotEmpty) ...[
            Text('解説', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(explanation, style: theme.textTheme.bodyMedium?.copyWith(height: 1.45)),
            const SizedBox(height: 12),
          ],

          if (choiceRationales.isNotEmpty) ...[
            Text('根拠', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            ...choiceRationales.entries.map((e) {
              final label = e.key;
              final text = e.value;

              String mark = '';
              if (correctSet.contains(label)) mark = '【正】';
              if (selectedSet.contains(label) && !correctSet.contains(label)) mark = '【選】';

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '$mark$label：$text',
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

/// 依存を増やさない簡易リザルト画面
class _PastExamSimpleResultScreen extends StatelessWidget {
  const _PastExamSimpleResultScreen({
    required this.title,
    required this.subtitle,
    required this.total,
  });

  final String title;
  final String subtitle;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BaseScaffold(
      title: '結果',
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.6)),
                  ),
                  child: Text(
                    'このパートは $total 問です。',
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('戻る'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}