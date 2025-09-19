// lib/screens/question_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';

import '../widgets/base_scaffold.dart';
import '../widgets/question_block.dart';
import '../widgets/question_controls.dart';

import '../services/category_repository.dart';   // ★ 追加：候補取得を型リポジトリ経由に
import '../data/categories.dart';                // situationalDomains は現状ここから
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

  String _mode = modeHisshu; // 初期は必修

  // 一般／状況設定 共通の選択
  String _selectedDomain = CategoryRepository.generalDomains().isNotEmpty
      ? CategoryRepository.generalDomains().first
      : '';
  String _selectedMajor =
  CategoryRepository.generalMajorsOf(
    CategoryRepository.generalDomains().isNotEmpty
        ? CategoryRepository.generalDomains().first
        : '',
  ).isNotEmpty
      ? CategoryRepository.generalMajorsOf(
    CategoryRepository.generalDomains().isNotEmpty
        ? CategoryRepository.generalDomains().first
        : '',
  ).first
      : '';
  String? _selectedMid; // 任意指定（nullなら裏でランダム）

  // 必修
  String _selectedHisshuMajor = '';
  List<String> get hisshuMajorItems => CategoryRepository.hisshuMajorItems();

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
    final ms = CategoryRepository.generalMajorsOf(domain);
    final newMajor = ms.isNotEmpty ? ms.first : '';
    final mids = (newMajor.isEmpty)
        ? const <String>[]
        : CategoryRepository.generalMidsOf(domain, newMajor);
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
        domainArg = '必修'; // kHisshuCategory はサービス側で扱うため、ここは表示目的での値でOK
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

      // QuestionService は choices(Map<String,String>) と correct(ラベル) を返す想定
      setState(() {
        _questionText = (data['question'] as String?)?.trim();
        final rawChoices = data['choices'] as Map?;
        _choices =
            rawChoices?.map((k, v) => MapEntry(k.toString(), v.toString()));

        _correct = (data['correct'] ?? data['correctAnswer'] ?? data['answer'])
            ?.toString();

        _explanation = (data['explanation'] as String?) ?? '';

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
    final domainList =
    _mode == modeSituational ? situationalDomains : CategoryRepository.generalDomains();

    return BaseScaffold(
      title: '出題',
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ====== コントロール部（表示専用） ======
              QuestionControls(
                mode: _mode,
                onModeChanged: (val) {
                  setState(() {
                    _mode = val;
                    // 領域候補が変わる可能性があるので、状況設定→一般／必修に戻ったら念のため再初期化
                    if (_mode != modeHisshu) {
                      final useList =
                      _mode == modeSituational ? situationalDomains : CategoryRepository.generalDomains();
                      final dom = useList.contains(_selectedDomain)
                          ? _selectedDomain
                          : (useList.isNotEmpty ? useList.first : _selectedDomain);
                      _resetGeneralMajorAndMid(dom);
                    }
                  });
                },
                isLoading: _isLoading,
                onGeneratePressed: _generateQuestion,

                // 一般/状況設定
                domainItems: domainList,
                selectedDomain: domainList.contains(_selectedDomain)
                    ? _selectedDomain
                    : (domainList.isNotEmpty ? domainList.first : _selectedDomain),
                onDomainChanged: (val) => _resetGeneralMajorAndMid(val),

                majorItems: CategoryRepository.generalMajorsOf(_selectedDomain),
                selectedMajor: _selectedMajor,
                onMajorChanged: (val) {
                  final mids = CategoryRepository.generalMidsOf(_selectedDomain, val);
                  setState(() {
                    _selectedMajor = val;
                    _selectedMid = mids.isNotEmpty ? mids.first : null;
                  });
                },

                useMid: _useMid,
                onUseMidChanged: (v) => setState(() => _useMid = v),

                midItems: CategoryRepository.generalMidsOf(_selectedDomain, _selectedMajor),
                selectedMid: _selectedMid,
                onMidChanged: (val) => setState(() => _selectedMid = val),

                // 必修
                hisshuMajorItems: hisshuMajorItems,
                selectedHisshuMajor: hisshuMajorItems.contains(_selectedHisshuMajor)
                    ? _selectedHisshuMajor
                    : (hisshuMajorItems.isNotEmpty ? hisshuMajorItems.first : ''),
                onHisshuMajorChanged: (val) =>
                    setState(() => _selectedHisshuMajor = val),

                // 状況設定
                scenarioAspects: _scenarioAspects,
                selectedScenarioAspectCode: _selectedScenarioAspectCode,
                onScenarioAspectChanged: (val) =>
                    setState(() => _selectedScenarioAspectCode = val),
              ),

              const SizedBox(height: 24),

              // ====== 出題ブロック（表示専用） ======
              if (_questionText != null && _choices != null)
                QuestionBlock(
                  questionText: _questionText!,
                  choices: _choices!,
                  selectedLabel: _userAnswer,
                  onSelect: (label) => setState(() => _userAnswer = label),
                  onSubmit: _submitAnswer,
                ),
            ],
          ),
        ),
      ),
    );
  }
}