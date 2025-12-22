// lib/screens/past_exam/past_exam_question_screen.dart
import 'package:flutter/material.dart';

import '../../models/nurai_question.dart';
import '../../models/past_exam_history.dart';
import '../../widgets/base_scaffold.dart';
import '../../theme/app_theme.dart';

class PastExamQuestionScreen extends StatefulWidget {
  const PastExamQuestionScreen({
    super.key,
    required this.examTitle,
    required this.partLabel,
    required this.questions,
  });

  final String examTitle;
  final String partLabel;
  final List<NuraiQuestion> questions;

  @override
  State<PastExamQuestionScreen> createState() => _PastExamQuestionScreenState();
}

class _PastExamQuestionScreenState extends State<PastExamQuestionScreen> {
  int _index = 0;

  final Map<int, Set<String>> _selectedMap = {};
  final Map<int, String> _inputMap = {}; // ★入力式の回答保持
  late final List<bool?> _results;

  final TextEditingController _inputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _results = List<bool?>.filled(widget.questions.length, null);
    _syncInputController(); // 初期問題が入力式なら同期
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  NuraiQuestion get _currentQuestion => widget.questions[_index];

  Set<String> get _currentSelected => _selectedMap[_index] ?? <String>{};

  String get _currentInput => _inputMap[_index] ?? '';

  void _setSelected(Set<String> labels) {
    setState(() {
      _selectedMap[_index] = labels;
    });
  }

  void _toggleChoice(String label) {
    final q = _currentQuestion;
    if (q.isInput) return; // ★入力式は選択肢操作しない

    final current = Set<String>.from(_currentSelected);

    if (q.isMultiple) {
      if (current.contains(label)) {
        current.remove(label);
      } else {
        current.add(label);
      }
    } else {
      current
        ..clear()
        ..add(label);
    }
    _setSelected(current);
  }

  void _setInput(String v) {
    setState(() {
      _inputMap[_index] = v;
    });
  }

  void _syncInputController() {
    final q = _currentQuestion;
    if (!q.isInput) return;

    final text = _currentInput;
    if (_inputController.text != text) {
      _inputController.text = text;
      _inputController.selection = TextSelection.fromPosition(
        TextPosition(offset: _inputController.text.length),
      );
    }
  }

  String _extractExamId(String title) {
    final m = RegExp(r'第(\d+)回').firstMatch(title);
    return m?.group(1) ?? '';
  }

  String _questionKey({
    required String examId,
    required String partLabel,
    required int index,
    required NuraiQuestion q,
  }) {
    final tag = (q.sourceTag ?? '').trim();
    if (tag.isNotEmpty) return tag;
    final n = index + 1;
    return '第$examId回 $partLabel $n問';
  }

  String _normalizeExamTitle(String t) {
    final m = RegExp(r'(第\d+回（[^）]+）)').firstMatch(t);
    return m?.group(1) ?? t;
  }

  String _inferPartKind(String partLabel) {
    final t = partLabel.trim();
    if (t.contains('状況')) return '状況設定';
    if (t.contains('一般')) return '一般';
    if (t.contains('必修')) return '必修';
    return '';
  }

  // ====== 入力式（計算）用：正答比較 ======
  String _normalizeNumberString(String s) {
    final map = {
      '０': '0',
      '１': '1',
      '２': '2',
      '３': '3',
      '４': '4',
      '５': '5',
      '６': '6',
      '７': '7',
      '８': '8',
      '９': '9',
      '．': '.',
      '。': '.',
      '，': ',',
      '、': ',',
      '　': ' ',
    };
    var t = s.trim();
    for (final e in map.entries) {
      t = t.replaceAll(e.key, e.value);
    }
    t = t.replaceAll(',', '');
    t = t.replaceAll(' ', '');
    return t;
  }

  bool _isInputCorrect(NuraiQuestion q, String userInput) {
    final correct =
    (q.correctLabels.isNotEmpty ? q.correctLabels.first : '').toString();

    final a = _normalizeNumberString(userInput);
    final b = _normalizeNumberString(correct);

    final da = double.tryParse(a);
    final db = double.tryParse(b);

    if (da != null && db != null) {
      // 誤差許容（ほぼ一致）
      return (da - db).abs() < 1e-9;
    }
    return a == b;
  }

  Future<void> _confirmAnswer() async {
    final q = _currentQuestion;

    // ===== 入力式 =====
    if (q.isInput) {
      final input = _normalizeNumberString(_currentInput);

      if (input.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('解答を入力してください。')),
        );
        return;
      }

      final isCorrect = _isInputCorrect(q, input);

      setState(() {
        _results[_index] = isCorrect;
      });

      final examId = _extractExamId(widget.examTitle);
      if (examId.isNotEmpty) {
        final key = _questionKey(
          examId: examId,
          partLabel: widget.partLabel,
          index: _index,
          q: q,
        );

        final questionNo = _index + 1;

        await PastExamHistory.instance.upsertAnswerWithSnapshot(
          examId: examId,
          questionKey: key,
          isCorrect: isCorrect,
          answeredAt: DateTime.now(), // ✅ 追加
          examTitle: _normalizeExamTitle(widget.examTitle),
          partLabel: widget.partLabel,
          partKind: _inferPartKind(widget.partLabel),
          questionNo: questionNo,
          questionText: q.questionText,
          choices: q.choices, // 空でOK
          correctLabels: q.correctLabels, // ["3.8"] など
          selectedLabels: [input], // ★入力値を保存
          explanation: q.explanation,
          rationales: q.rationales,
          imagePath: q.imagePath,
        );
      }

      if (!mounted) return;
      return;
    }

    // ===== 選択式 =====
    final selected = _currentSelected.toList()..sort();

    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('少なくとも1つは選択してください。')),
      );
      return;
    }

    final selectedSet = selected.toSet();
    final correctSet = q.correctLabels.toSet();
    final isCorrect = selectedSet.length == correctSet.length &&
        selectedSet.containsAll(correctSet);

    setState(() {
      _results[_index] = isCorrect;
    });

    final examId = _extractExamId(widget.examTitle);
    if (examId.isNotEmpty) {
      final key = _questionKey(
        examId: examId,
        partLabel: widget.partLabel,
        index: _index,
        q: q,
      );

      final questionNo = _index + 1;

      await PastExamHistory.instance.upsertAnswerWithSnapshot(
        examId: examId,
        questionKey: key,
        isCorrect: isCorrect,
        answeredAt: DateTime.now(), // ✅ 追加
        examTitle: _normalizeExamTitle(widget.examTitle),
        partLabel: widget.partLabel,
        partKind: _inferPartKind(widget.partLabel),
        questionNo: questionNo,
        questionText: q.questionText,
        imagePath: q.imagePath,
        choices: q.choices,
        correctLabels: q.correctLabels,
        selectedLabels: selected,
        explanation: q.explanation,
        rationales: q.rationales,
      );
    }

    if (!mounted) return;
  }

  void _goPrev() {
    if (_index == 0) return;
    setState(() => _index--);
    _syncInputController();
  }

  void _goNext() {
    if (_index >= widget.questions.length - 1) return;
    setState(() => _index++);
    _syncInputController();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = _currentQuestion;
    final selected = _currentSelected;
    final result = _results[_index];

    final indexText = '${_index + 1} / ${widget.questions.length}';

    // build のたびに同期（入力式で戻ってきたときのズレ防止）
    if (q.isInput) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncInputController();
      });
    }

    return BaseScaffold(
      title: widget.examTitle,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.partLabel,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '第 ${_index + 1} 問  ($indexText)',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),

                // 問題
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withOpacity(0.6),
                    ),
                  ),
                  child: Text(
                    q.questionText,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                  ),
                ),

                // ★ 画像（ある場合だけ表示）
                if (q.hasImage) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withOpacity(0.6),
                      ),
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
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // ===== 入力式（計算など） =====
                if (q.isInput) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: TextField(
                      controller: _inputController,
                      keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                      ),
                      onChanged: (v) => _setInput(v),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (result != null) ...[
                    Text(
                      result ? 'この問題は「正解」です。' : 'この問題は「不正解」です。',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: result ? Colors.green[700] : Colors.red[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'あなたの解答：${_currentInput.isEmpty ? '(未入力)' : _currentInput}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (q.correctLabels.isNotEmpty)
                      Text(
                        '正答：${q.correctLabels.first}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ] else ...[
                  // ===== 選択式（既存） =====
                  Column(
                    children: q.choices.entries.map((entry) {
                      final label = entry.key;
                      final text = entry.value;
                      final isSelected = selected.contains(label);

                      final isCorrectLabel = q.correctLabels.contains(label);
                      final isAnswered = result != null;

                      Color? borderColor = Colors.black12;
                      Color? bgColor = theme.colorScheme.surface;
                      IconData? leadingIcon;

                      if (isAnswered) {
                        if (isCorrectLabel) {
                          borderColor = Colors.green.withOpacity(0.7);
                          if (isSelected) {
                            bgColor = Colors.green.withOpacity(0.07);
                            leadingIcon = Icons.check_circle_outline;
                          }
                        } else if (isSelected && !isCorrectLabel) {
                          borderColor = Colors.red.withOpacity(0.7);
                          bgColor = Colors.red.withOpacity(0.04);
                          leadingIcon = Icons.cancel_outlined;
                        }
                      } else if (isSelected) {
                        borderColor = theme.colorScheme.primary;
                        bgColor = theme.colorScheme.primary.withOpacity(0.06);
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _toggleChoice(label),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 26,
                                  child: Text(
                                    label,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(text,
                                      style: theme.textTheme.bodyMedium),
                                ),
                                if (leadingIcon != null) ...[
                                  const SizedBox(width: 8),
                                  Icon(
                                    leadingIcon,
                                    size: 20,
                                    color: isCorrectLabel
                                        ? Colors.green[700]
                                        : Colors.red[700],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  if (result != null)
                    Text(
                      result ? 'この問題は「正解」です。' : 'この問題は「不正解」です。',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: result ? Colors.green[700] : Colors.red[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],

                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _index == 0 ? null : _goPrev,
                        child: const Text('前の問題'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _confirmAnswer,
                        child: const Text('解答を確定'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _index == widget.questions.length - 1
                            ? null
                            : _goNext,
                        child: const Text('次の問題'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}