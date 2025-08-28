import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/question_service.dart';
import '../widgets/base_scaffold.dart';
import '../widgets/app_buttons.dart';
import 'result_screen.dart';

import '../data/categories.dart';        // 一般（大>中）
import '../data/hisshu_categories.dart';  // 必修（大>中>小：大のみUI選択）

class QuestionScreen extends StatefulWidget {
  const QuestionScreen({super.key});

  @override
  State<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends State<QuestionScreen> {
  static const _forms = <String>['必修問題', '一般問題', '状況設定問題'];
  String _selectedForm = _forms.first;

  // 一般・状況設定：大>中
  late String _major = majorCategories.first;
  late String _midGeneral =
  midCategoriesOf(_major).isNotEmpty ? midCategoriesOf(_major).first : '';

  // 必修：大のみ（中・小は内部で選ぶ）
  late String _hisshuMajor = hisshuMajors.first;

  bool _isLoading = false;
  Map<String, dynamic>? _question;

  @override
  Widget build(BuildContext context) {
    final isHisshu = _selectedForm == '必修問題';

    return BaseScaffold(
      title: '問題を生成',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _Label('出題形式'),
          DropdownButtonFormField<String>(
            value: _selectedForm,
            items: _forms.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => setState(() => _selectedForm = v ?? _selectedForm),
            decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 16),

          if (isHisshu) ...[
            const _Label('必修（大項目）'),
            DropdownButtonFormField<String>(
              value: _hisshuMajor,
              items: hisshuMajors.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _hisshuMajor = v);
              },
              decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
            ),
          ] else ...[
            const _Label('分野（大項目）'),
            DropdownButtonFormField<String>(
              value: _major,
              items: majorCategories.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _major = v;
                  final mids = midCategoriesOf(_major);
                  _midGeneral = mids.isNotEmpty ? mids.first : '';
                });
              },
              decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
            ),
            const SizedBox(height: 12),
            const _Label('項目（中項目）'),
            DropdownButtonFormField<String>(
              value: _midGeneral.isNotEmpty ? _midGeneral : null,
              items: midCategoriesOf(_major).map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _midGeneral = v ?? _midGeneral),
              decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
            ),
          ],

          const SizedBox(height: 24),
          AppButtons.primary(
            label: '問題を生成',
            icon: Icons.bolt,
            onPressed: _isLoading ? null : _generateQuestion,
          ),
          const SizedBox(height: 16),

          if (_isLoading) const Center(child: CircularProgressIndicator()),
          if (!_isLoading && _question != null) _buildQuestionCard(),
        ],
      ),
    );
  }

  Widget _buildQuestionCard() {
    final q = _question!;
    final String questionText = _pickString(q, ['question','questionText','text']).ifEmpty('（問題文なし）');
    final List<String> choices = _asChoices(q['choices']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(questionText, style: Theme.of(context).textTheme.titleMedium))),
        const SizedBox(height: 12),
        if (choices.isEmpty)
          Card(
            color: Colors.amber.withOpacity(0.15),
            child: const ListTile(
              leading: Icon(Icons.warning_amber),
              title: Text('選択肢が取得できませんでした。もう一度「問題を生成」を押してください。'),
            ),
          )
        else
          ...List.generate(choices.length, (i) {
            final label = String.fromCharCode('A'.codeUnitAt(0) + i);
            return Card(
              child: ListTile(
                title: Text('$label.  ${choices[i]}'),
                onTap: () => _onAnswerSelected(i),
              ),
            );
          }),
      ],
    );
  }

  Future<void> _generateQuestion() async {
    setState(() { _isLoading = true; _question = null; });

    final isHisshu = _selectedForm == '必修問題';
    final category = isHisshu ? '必修::$_hisshuMajor' : _major;
    final subcategory = isHisshu ? null : (_midGeneral.isEmpty ? null : _midGeneral);

    try {
      final q = await QuestionService.fetchQuestion(
        category: category,
        difficulty: _selectedForm,
        subcategory: subcategory,
      );
      if (!mounted) return;

      if (q is! Map<String, dynamic>) {
        _showError('問題の取得形式が不正です（開発ログを確認）');
        setState(() => _question = null);
        return;
      }

      final questionText = _pickString(q, ['question','questionText','text']);
      final choices = _asChoices(q['choices']);
      if (questionText.isEmpty || choices.isEmpty) {
        _showError('問題の生成に失敗しました。もう一度お試しください。');
      }
      setState(() => _question = q);
    } catch (e, st) {
      // ignore: avoid_print
      print('[QuestionScreen] fetch 例外: $e\n$st');
      if (mounted) _showError('問題生成に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onAnswerSelected(int index) async {
    if (_question == null) return;

    final q = _question!;
    final String questionText = _pickString(q, ['question','questionText','text']).ifEmpty('');
    final List<String> choices = _asChoices(q['choices']);

    final String? correctLetterRaw = _pickString(q, ['correct','correctLetter','answer_key']);
    final int? correctIdxRaw = _asInt(q['correctIndex'] ?? q['answer_index'] ?? q['answerIndex']);

    final int correctIndex = correctLetterRaw != null &&
        correctLetterRaw.isNotEmpty &&
        _letterToIndex(correctLetterRaw) != null
        ? _letterToIndex(correctLetterRaw)!
        : (correctIdxRaw ?? 0).clamp(0, choices.isEmpty ? 0 : choices.length - 1);

    final String selectedLetter = _indexToLetter(index);
    final String correctLetter  = _indexToLetter(correctIndex);
    final String explanation    = _pickString(q, ['explanation','reason','解説']).ifEmpty('');

    HapticFeedback.selectionClick();

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          question: questionText,
          choices: _toChoiceMap(choices),
          selectedAnswer: selectedLetter,
          correctAnswer: correctLetter,
          explanation: explanation,
          onGenerateNext: _generateQuestion,
          category: _selectedForm == '必修問題' ? kHisshuCategory : _major,
          form: _selectedForm.replaceAll('問題', ''), // '必修' / '一般' / '状況設定'
        ),
      ),
    );
  }

  // ---- helpers ----
  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  String _pickString(Map<String, dynamic> map, List<String> keys) {
    for (final k in keys) {
      final v = map[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return '';
  }

  List<String> _asChoices(dynamic v) {
    if (v == null) return const <String>[];
    if (v is List) {
      return v.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
    }
    if (v is Map) {
      final keys = ['A','B','C','D'];
      return keys.map((k) => v[k]?.toString() ?? '').where((s) => s.isNotEmpty).toList();
    }
    return const <String>[];
  }

  Map<String, String> _toChoiceMap(List<String> choices) {
    final map = <String, String>{};
    for (var i = 0; i < choices.length; i++) {
      map[_indexToLetter(i)] = choices[i];
    }
    return map;
  }

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  String _indexToLetter(int i) => String.fromCharCode('A'.codeUnitAt(0) + i);

  int? _letterToIndex(String s) {
    if (s.isEmpty) return null;
    final up = s.trim().toUpperCase();
    final code = up.codeUnitAt(0) - 'A'.codeUnitAt(0);
    if (code < 0 || code > 25) return null;
    return code;
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
    );
  }
}

extension on String {
  String ifEmpty(String alt) => isEmpty ? alt : this;
}