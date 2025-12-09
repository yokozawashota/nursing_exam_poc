// lib/screens/question_screen.dart
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../widgets/base_scaffold.dart';
import '../widgets/question_block.dart';
import '../widgets/question_controls.dart';

import '../services/category_repository.dart'; // 候補取得
import '../data/categories.dart'; // situationalDomains
import '../services/question_service.dart';
import '../models/answer_history.dart'; // 履歴保存
import 'result_screen.dart';

// ランダム指定用の内部ID（QuestionControls 側と揃える想定）
const String kRandomDomainId = '__RANDOM_DOMAIN__';
const String kRandomMajorId = '__RANDOM_MAJOR__';

// 分野・大項目・中項目をまとめて返すための小さな内部モデル
class _ResolvedCategory {
  final String domain;
  final String major;
  final String? mid;
  const _ResolvedCategory(this.domain, this.major, this.mid);
}

class QuestionScreen extends StatefulWidget {
  const QuestionScreen({super.key});
  @override
  State<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends State<QuestionScreen> {
  // 出題形式
  static const String modeHisshu = '必修問題';
  static const String modeGeneral = '一般問題';
  static const String modeSituational = '状況設定問題';

  // 状況設定の観点
  static const Map<String, String> _scenarioAspects = {
    'A': 'A. 対象や家族に切れ目のない支援を提供するための継続した看護',
    'B': 'B. 複合的な状況にある対象や、複合的に提供されている看護の状況を判断し、危険を回避する取組み',
    'C': 'C. 看護の提供者が、看護場面において自身の安全を確保するための総合的な判断や対応',
    'D': 'D. 発災からの経過に応じて被災者に提供される診療や支援を促進するための看護',
    'E': 'E. A～Dを促進するための多職種連携',
  };

  String _mode = modeHisshu;

  // 一般／状況設定 共通の選択（UI 上の値）
  String _selectedDomain = CategoryRepository.generalDomains().isNotEmpty
      ? CategoryRepository.generalDomains().first
      : '';
  String _selectedMajor = CategoryRepository.generalMajorsOf(
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

  // 状況設定：観点
  String? _selectedScenarioAspectCode;

  // 画面状態
  bool _isLoading = false;

  // 出題中データ
  String? _questionText;
  Map<String, String>? _choices;
  List<String>? _correctAnswers; // 複数対応
  String? _explanation;
  Map<String, String>? _rationales;
  Set<String> _userAnswers = {}; // 複数対応
  String _questionKind = 'single'; // 'single' | 'multiple' | 'select_incorrect'

  // 中項目を明示指定するか
  bool _useMid = false;

  // 履歴保存用メタ
  Map<String, dynamic>? _meta;

  @override
  void initState() {
    super.initState();
    _selectedHisshuMajor =
    hisshuMajorItems.isNotEmpty ? hisshuMajorItems.first : '';
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

  // ==========================
  // 分野・大項目・中項目の最終決定
  // （ランダムで決まった結果もここで確定させる）
  // ==========================
  _ResolvedCategory _resolveCategoryForGeneration() {
    // 必修はこの関数は経由しない想定（_generateQuestion 側で処理）
    if (_mode == modeHisshu) {
      return _ResolvedCategory('必修', _selectedHisshuMajor, null);
    }

    final List<String> domainList = _mode == modeSituational
        ? situationalDomains
        : CategoryRepository.generalDomains();

    final rand = Random(DateTime.now().microsecondsSinceEpoch);

    // ↓ ユーザーが「ランダム」を選んだかどうかのフラグ
    final bool domainRandomRequested = _selectedDomain == kRandomDomainId;
    final bool majorRandomRequested = _selectedMajor == kRandomMajorId;

    // ---- 分野 ----
    String domain = _selectedDomain;
    if (domainRandomRequested || !domainList.contains(domain)) {
      if (domainList.isNotEmpty) {
        domain = domainList[rand.nextInt(domainList.length)];
      } else {
        domain = '';
      }
    }

    // ---- 大項目 ----
    final majorsOfDomain = CategoryRepository.generalMajorsOf(domain);
    String major = _selectedMajor;
    if (majorRandomRequested ||
        major.isEmpty ||
        !majorsOfDomain.contains(major)) {
      if (majorsOfDomain.isNotEmpty) {
        major = majorsOfDomain[rand.nextInt(majorsOfDomain.length)];
      } else {
        major = '';
      }
    }

    // ---- 中項目 ----
    String? mid;
    bool midRandomUsed = false;
    if (_useMid) {
      final mids = CategoryRepository.generalMidsOf(domain, major);
      if (_selectedMid != null &&
          _selectedMid!.isNotEmpty &&
          mids.contains(_selectedMid)) {
        mid = _selectedMid;
      } else if (mids.isNotEmpty) {
        midRandomUsed = true;
        mid = mids[rand.nextInt(mids.length)];
      }
    } else {
      mid = null;
    }

    // ▼ ログ出力（ランダム指定がどう解決されたかを確認できる）
    debugPrint(
      '[log] [QSCREEN] resolved category '
          '(mode=$_mode, domainRandom=$domainRandomRequested, '
          'majorRandom=$majorRandomRequested, midRandom=$midRandomUsed) '
          '=> domain="$domain", major="$major", mid="${mid ?? '(none)'}"',
    );

    return _ResolvedCategory(domain, major, mid);
  }

  Future<void> _generateQuestion() async {
    setState(() {
      _isLoading = true;
      _questionText = null;
      _choices = null;
      _correctAnswers = null;
      _explanation = null;
      _rationales = null;
      _userAnswers = {};
      _questionKind = 'single';
      _meta = null;
    });

    try {
      final difficulty = _mode;

      late final String domainArg;
      late final String majorArg;
      String? midArg;
      String? scenarioAspectCode;

      if (_mode == modeHisshu) {
        // 必修は分野「必修」、大項目は UI 選択値そのまま
        domainArg = '必修';
        majorArg = _selectedHisshuMajor;
        midArg = null;

        debugPrint(
          '[log] [QS] category resolved (hisshu) => '
              'mode=$_mode | domain=$domainArg | major=$majorArg | mid=(none)',
        );
      } else {
        // 一般／状況設定はランダム指定を解決
        final resolved = _resolveCategoryForGeneration();
        domainArg = resolved.domain;
        majorArg = resolved.major;
        midArg = resolved.mid;

        if (_mode == modeSituational) {
          final bool wasRandomAspect = _selectedScenarioAspectCode == null;
          scenarioAspectCode =
              _selectedScenarioAspectCode ?? _randomScenarioAspectCode();

          debugPrint(
            '[log] [QS] scenarioAspect resolved => '
                'mode=$_mode | aspect=$scenarioAspectCode'
                '${wasRandomAspect ? " (random)" : " (selected)"}',
          );
        }
      }

      final data = await QuestionService.fetchQuestion(
        difficulty: difficulty,
        domain: domainArg,
        major: majorArg,
        mid: midArg,
        scenarioAspect: scenarioAspectCode,
      );

      setState(() {
        _questionText = (data['question'] as String?)?.trim();

        // choices（Map<String,String>）へ正規化
        final rawChoices = data['choices'] as Map?;
        _choices =
            rawChoices?.map((k, v) => MapEntry(k.toString(), v.toString()));

        // 正解（複数対応）
        _correctAnswers = (data['correctAnswers'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
            [(data['correct'] ?? '').toString()];

        // 問題タイプ
        _questionKind = (data['questionKind'] as String?) ?? 'single';

        _explanation = (data['explanation'] as String?) ?? '';
        final rawRat = data['rationales'] as Map?;
        _rationales =
            rawRat?.map((k, v) => MapEntry(k.toString(), v.toString()));

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
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitAnswer() async {
    if (_questionText == null || _choices == null || _correctAnswers == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('問題を生成してから解答してください。')),
      );
      return;
    }
    if (_userAnswers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('選択肢を選んでください。')),
      );
      return;
    }

    // 履歴保存（複数解答対応）
    try {
      final rec = AnswerRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        ts: DateTime.now(),
        difficulty: _mode,
        domain: (_meta?['domain'] as String?) ?? _selectedDomain,
        major: (_meta?['major'] as String?) ?? _selectedMajor,
        mid: (_meta?['mid'] as String?) ?? (_useMid ? _selectedMid : null),
        topic: _meta?['topic'] as String?,
        question: _questionText!,
        choices: _choices!,
        explanation: _explanation,
        rationales: _rationales,
        choiceCount: _choices!.length,
        questionKind: _questionKind,
        userAnswers: _userAnswers.toList()..sort(),
        correctAnswers: _correctAnswers!..sort(),
      );
      await AnswerHistory.instance.add(rec);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('履歴の保存に失敗しました：$e')),
        );
      }
    }

    if (!mounted) return;

    // 結果画面へ
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          question: _questionText!,
          choices: _choices!,
          selectedAnswers: _userAnswers.toList(),
          correctAnswers: _correctAnswers!,
          explanation: _explanation ?? '',
          rationales: _rationales,
          onGenerateNext: _generateQuestion,
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
    final domainList = _mode == modeSituational
        ? situationalDomains
        : CategoryRepository.generalDomains();

    // select_incorrect も含めて「正答が複数」ならチェックボックスモード
    final bool isMulti = _questionKind == 'multiple' ||
        _questionKind == 'select_incorrect' ||
        (_correctAnswers?.length ?? 0) >= 2;

    return BaseScaffold(
      title: '出題',
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ====== コントロール部 ======
              QuestionControls(
                mode: _mode,
                onModeChanged: (val) {
                  setState(() {
                    _mode = val;
                    if (_mode != modeHisshu) {
                      final useList = _mode == modeSituational
                          ? situationalDomains
                          : CategoryRepository.generalDomains();
                      final dom = useList.contains(_selectedDomain)
                          ? _selectedDomain
                          : (useList.isNotEmpty
                          ? useList.first
                          : _selectedDomain);
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
                    : (domainList.isNotEmpty
                    ? domainList.first
                    : _selectedDomain),
                onDomainChanged: (val) => _resetGeneralMajorAndMid(val),
                majorItems:
                CategoryRepository.generalMajorsOf(_selectedDomain),
                selectedMajor: _selectedMajor,
                onMajorChanged: (val) {
                  final mids =
                  CategoryRepository.generalMidsOf(_selectedDomain, val);
                  setState(() {
                    _selectedMajor = val;
                    _selectedMid = mids.isNotEmpty ? mids.first : null;
                  });
                },
                useMid: _useMid,
                onUseMidChanged: (v) => setState(() => _useMid = v),
                midItems: CategoryRepository.generalMidsOf(
                    _selectedDomain, _selectedMajor),
                selectedMid: _selectedMid,
                onMidChanged: (val) => setState(() => _selectedMid = val),

                // 必修
                hisshuMajorItems: hisshuMajorItems,
                selectedHisshuMajor:
                hisshuMajorItems.contains(_selectedHisshuMajor)
                    ? _selectedHisshuMajor
                    : (hisshuMajorItems.isNotEmpty
                    ? hisshuMajorItems.first
                    : ''),
                onHisshuMajorChanged: (val) =>
                    setState(() => _selectedHisshuMajor = val),

                // 状況設定
                scenarioAspects: _scenarioAspects,
                selectedScenarioAspectCode: _selectedScenarioAspectCode,
                onScenarioAspectChanged: (val) =>
                    setState(() => _selectedScenarioAspectCode = val),
              ),

              const SizedBox(height: 24),

              // ====== 出題ブロック ======
              if (_questionText != null && _choices != null)
                QuestionBlock(
                  questionText: _questionText!,
                  choices: _choices!,
                  questionKind: _questionKind,

                  // 単一選択
                  selectedLabel: !isMulti && _userAnswers.isNotEmpty
                      ? _userAnswers.first
                      : null,
                  onSelect: !isMulti
                      ? (val) => setState(() => _userAnswers = {val})
                      : null,

                  // 複数選択（select_incorrect を含む）
                  selectedLabels: isMulti ? _userAnswers.toList() : null,
                  onToggle: isMulti
                      ? (val) {
                    setState(() {
                      if (_userAnswers.contains(val)) {
                        _userAnswers.remove(val);
                      } else {
                        _userAnswers.add(val);
                      }
                    });
                  }
                      : null,

                  onSubmit: _submitAnswer,
                ),
            ],
          ),
        ),
      ),
    );
  }
}