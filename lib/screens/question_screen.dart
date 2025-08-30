// lib/screens/question_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';

import '../widgets/base_scaffold.dart';
import '../widgets/app_buttons.dart';

import '../data/categories.dart';            // domains / midsOf / topicsOf / situationalDomains
import '../data/hisshu_categories.dart';     // kHisshuCategory, hisshuMajors()
import '../services/question_service.dart';
import 'result_screen.dart';

class QuestionScreen extends StatefulWidget {
  const QuestionScreen({super.key});
  @override
  State<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends State<QuestionScreen> {
  // 出題形式（順番固定：必修問題 → 一般問題 → 状況設定問題）
  static const String modeHisshu = '必修問題';
  static const String modeGeneral = '一般問題';
  static const String modeSituational = '状況設定問題';

  // 状況設定の観点（完全一致表記）
  static const Map<String, String> _scenarioAspects = {
    'A': 'A. 対象や家族に切れ目のない支援を提供するための継続した看護',
    'B': 'B. 複合的な状況にある対象や、複合的に提供されている看護の状況を判断し、危険を回避する取組み',
    'C': 'C. 看護の提供者が、看護場面において自身の安全を確保するための総合的な判断や対応',
    'D': 'D. 発災からの経過に応じて被災者に提供される診療や支援を促進するための看護',
    'E': 'E. A～Dを促進するための多職種連携',
  };

  String _mode = modeHisshu; // 先頭を必修に

  // 一般／状況設定 共通の選択
  String _selectedDomain = domains.first;
  String _selectedMajor =
  majorsOf(domains.first).isNotEmpty ? majorsOf(domains.first).first : '';
  String? _selectedMid; // 任意指定（nullなら裏でランダム）

  // 必修
  String _selectedHisshuMajor = '';
  List<String> get hisshuMajorItems => hisshuMajors();

  // 状況設定：観点コード（'A'〜'E'）。nullならランダム
  String? _selectedScenarioAspectCode;

  // 画面状態
  bool _isLoading = false;

  // 出題中の問題
  String? _questionText;
  Map<String, String>? _choices; // {'A':'...', 'B':'...'}
  String? _correct; // 'A'|'B'|'C'|'D'
  String? _explanation;
  Map<String, String>? _rationales;
  String? _userAnswer; // ユーザー選択

  // 中項目を明示指定するか
  bool _useMid = false;

  // 履歴保存用メタ
  Map<String, dynamic>? _meta;

  @override
  void initState() {
    super.initState();
    // 必修の初期選択
    _selectedHisshuMajor =
    hisshuMajorItems.isNotEmpty ? hisshuMajorItems.first : '';
    // 一般の初期選択
    _resetGeneralMajorAndMid(_selectedDomain);
  }

  void _resetGeneralMajorAndMid(String domain) {
    final ms = majorsOf(domain);
    final newMajor = ms.isNotEmpty ? ms.first : '';
    final mids = (newMajor.isEmpty) ? const <String>[] : midsOf(domain, newMajor);
    setState(() {
      _selectedDomain = domain;
      _selectedMajor = newMajor;
      _selectedMid = mids.isNotEmpty ? mids.first : null;
    });
  }

  String _randomScenarioAspectCode() {
    const keys = ['A', 'B', 'C', 'D', 'E'];
    return keys[Random().nextInt(keys.length)];
  }

  Future<void> _generateQuestion() async {
    setState(() {
      _isLoading = true;
      _questionText = null;
      _choices = null;
      _correct = null;
      _explanation = null;
      _rationales = null;
      _userAnswer = null;
      _meta = null;
    });

    try {
      final difficulty = _mode;

      late final String domainArg;
      late final String majorArg;
      String? midArg;
      String? scenarioAspectCode;

      if (_mode == modeHisshu) {
        domainArg = kHisshuCategory;
        majorArg = _selectedHisshuMajor;
        midArg = null; // 裏でランダム
      } else {
        // 一般 or 状況設定
        domainArg = _selectedDomain;
        majorArg = _selectedMajor;
        midArg = _useMid ? _selectedMid : null;

        if (_mode == modeSituational) {
          scenarioAspectCode =
              _selectedScenarioAspectCode ?? _randomScenarioAspectCode();
        }
      }

      final data = await QuestionService.fetchQuestion(
        difficulty: difficulty,
        domain: domainArg,
        major: majorArg,
        mid: midArg,
        scenarioAspect: scenarioAspectCode, // 任意受け取り
      );

      setState(() {
        _questionText = (data['question'] ?? '') as String;

        // choices：Map でも List でも受け付け → Map<String,String> に正規化
        final dynamic rawChoices = data['choices'];
        Map<String, String>? toMap;
        if (rawChoices is Map) {
          toMap =
              rawChoices.map((k, v) => MapEntry(k.toString(), v.toString()));
        } else if (rawChoices is List) {
          final labels = ['A', 'B', 'C', 'D'];
          final n = rawChoices.length < 4 ? rawChoices.length : 4;
          toMap = {
            for (var i = 0; i < n; i++) labels[i]: rawChoices[i].toString(),
          };
        }
        _choices = toMap;

        // 正答：correctIndex（int）優先 → 文字（A/B/C/D）も許容
        String? correctLetter;
        final idx = data['correctIndex'];
        if (idx is int && idx >= 0 && idx < 4) {
          correctLetter = ['A', 'B', 'C', 'D'][idx];
        } else {
          correctLetter = (data['correct'] ??
              data['correctAnswer'] ??
              data['answer'])
              ?.toString();
        }
        _correct = correctLetter ?? '';

        _explanation = (data['explanation'] ?? '') as String;

        final rawRat = data['rationales'] as Map?;
        _rationales =
            rawRat?.map((k, v) => MapEntry(k.toString(), v.toString()));

        // 履歴保存用メタ
        final rawMeta = data['meta'] as Map?;
        _meta = rawMeta?.map((k, v) => MapEntry(k.toString(), v));
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('問題の生成に失敗しました：$e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _submitAnswer() {
    if (_questionText == null || _choices == null || _correct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('問題を生成してから解答してください。')),
      );
      return;
    }
    if (_userAnswer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('選択肢を選んでください。')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          question: _questionText!,
          choices: _choices!,
          selectedAnswer: _userAnswer!,
          correctAnswer: _correct!,
          explanation: _explanation ?? '',
          rationales: _rationales,
          onGenerateNext: _generateQuestion,
          // 履歴保存メタ（個別渡し）
          difficulty: _mode,
          domain: _meta?['domain'] as String?,
          major: _meta?['major'] as String?,
          mid: _meta?['mid'] as String?,
          topic: _meta?['topic'] as String?,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 状況設定モードのときだけ、領域候補を限定
    final domainItems =
    _mode == modeSituational ? situationalDomains : domains;

    return BaseScaffold(
      title: '出題',
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 出題形式（順番：必修問題／一般問題／状況設定問題）
              _LabeledBox(
                label: '出題形式',
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _mode,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                          value: modeHisshu, child: Text(modeHisshu)),
                      DropdownMenuItem(
                          value: modeGeneral, child: Text(modeGeneral)),
                      DropdownMenuItem(
                          value: modeSituational, child: Text(modeSituational)),
                    ],
                    onChanged: (val) {
                      if (val == null) return;
                      setState(() {
                        _mode = val;
                        // 領域候補が変わる可能性があるので、状況設定→一般／必修に戻ったら念のため再初期化
                        if (_mode != modeHisshu) {
                          final useList =
                          _mode == modeSituational ? situationalDomains : domains;
                          final dom = useList.contains(_selectedDomain)
                              ? _selectedDomain
                              : useList.first;
                          _resetGeneralMajorAndMid(dom);
                        }
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),

              if (_mode == modeGeneral || _mode == modeSituational) ...[
                _LabeledBox(
                  label: '分野',
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: domainItems.contains(_selectedDomain)
                          ? _selectedDomain
                          : domainItems.first,
                      isExpanded: true,
                      items: domainItems
                          .map((e) =>
                          DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (val) {
                        if (val == null) return;
                        _resetGeneralMajorAndMid(val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                _LabeledBox(
                  label: '大項目',
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedMajor.isNotEmpty ? _selectedMajor : null,
                      isExpanded: true,
                      items: majorsOf(_selectedDomain)
                          .map((e) =>
                          DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (val) {
                        if (val == null) return;
                        final mids = midsOf(_selectedDomain, val);
                        setState(() {
                          _selectedMajor = val;
                          _selectedMid = mids.isNotEmpty ? mids.first : null;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // 状況設定の観点（A〜E）
                if (_mode == modeSituational) ...[
                  _LabeledBox(
                    label: '状況設定の観点',
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _selectedScenarioAspectCode,
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('（未選択／ランダム）'),
                          ),
                          ..._scenarioAspects.entries.map(
                                (e) => DropdownMenuItem<String?>(
                              value: e.key,
                              child: Text(e.value),
                            ),
                          ),
                        ],
                        onChanged: (val) =>
                            setState(() => _selectedScenarioAspectCode = val),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                Row(
                  children: [
                    Switch(
                      value: _useMid,
                      onChanged: (v) => setState(() => _useMid = v),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('中項目を指定する（オフなら裏でランダム選択）'),
                    ),
                  ],
                ),
                if (_useMid) ...[
                  const SizedBox(height: 8),
                  _LabeledBox(
                    label: '中項目',
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedMid,
                        isExpanded: true,
                        items: midsOf(_selectedDomain, _selectedMajor)
                            .map((e) =>
                            DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (val) => setState(() => _selectedMid = val),
                      ),
                    ),
                  ),
                ],
              ] else ...[
                // 必修
                _LabeledBox(
                  label: '大項目（必修）',
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: hisshuMajorItems.contains(_selectedHisshuMajor)
                          ? _selectedHisshuMajor
                          : (hisshuMajorItems.isNotEmpty
                          ? hisshuMajorItems.first
                          : null),
                      isExpanded: true,
                      items: hisshuMajorItems
                          .map((e) =>
                          DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _selectedHisshuMajor = val ?? ''),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : AppButtons.primary(
                label: '問題を生成',
                icon: Icons.auto_awesome,
                onPressed: _generateQuestion,
              ),

              const SizedBox(height: 24),
              if (_questionText != null && _choices != null) ...[
                const Divider(height: 32),
                const Text(
                  '問題',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _questionText!,
                  style: const TextStyle(
                      fontSize: 16, fontFamily: 'NotoSansJP'),
                ),
                const SizedBox(height: 16),

                // 選択肢（結果画面風カードUI：先頭の丸囲み・右端の小さい丸は排除）
                ...['A', 'B', 'C', 'D']
                    .where((k) => _choices!.containsKey(k))
                    .map((k) {
                  final text = _choices![k]!;
                  final selected = _userAnswer == k;
                  return _OptionTile(
                    label: k,
                    text: text,
                    selected: selected,
                    onTap: () => setState(() => _userAnswer = k),
                  );
                }),

                const SizedBox(height: 8),
                AppButtons.success(
                  label: '解答する',
                  icon: Icons.check_circle,
                  onPressed: _submitAnswer,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 共通：ラベル付きの箱型コンテナ（UIを崩さないため最低限の装飾に留める）
class _LabeledBox extends StatelessWidget {
  final String label;
  final Widget child;
  const _LabeledBox({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: '',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ).copyWith(labelText: label),
      child: child,
    );
  }
}

// 出題ページの選択肢を結果画面風カードで表示（先頭の丸囲み/右端の丸は無し）
class _OptionTile extends StatelessWidget {
  final String label;     // 'A'..'D'
  final String text;      // 選択肢本文
  final bool selected;    // 選択中かどうか
  final VoidCallback onTap;

  const _OptionTile({
    required this.label,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? Colors.teal.withOpacity(0.12) : null;
    final borderColor = selected ? Colors.teal : Colors.black12;

    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          // 文字のまま（丸囲み無し）
          leading: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          title: Text(text),
          // 右端の小さい丸は表示しない
          trailing: null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        ),
      ),
    );
  }
}