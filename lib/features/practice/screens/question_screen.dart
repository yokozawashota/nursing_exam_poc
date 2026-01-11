// lib/features/practice/screens/question_screen.dart
import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../shared/widgets/base_scaffold.dart';
import '../widgets/question_block.dart';
import '../widgets/question_controls.dart';

import '../../../shared/services/category_repository.dart';
import '../../../data/categories.dart';
import '../services/question_service.dart';
import '../../../shared/models/answer_history.dart';
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
    'D': 'D. 発災からの経過に応じて被災者に提供されている診療や支援を促進するための看護',
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

  // ==========================
  // ローディングUI（生成中コメント＋擬似進捗）
  // ==========================
  Timer? _loadingMessageTimer;
  Timer? _loadingProgressTimer;

  int _loadingMessageIndex = 0;
  double _loadingProgress = 0.0;

  static const List<String> _loadingMessages = [
    '問題を生成しています…',
    '選択肢の整合性をチェック中…',
    '国試っぽい文章に整形中…',
    '正答と解説を最終確認中…',
    'まもなく表示します…',
  ];

  @override
  void initState() {
    super.initState();
    _selectedHisshuMajor =
    hisshuMajorItems.isNotEmpty ? hisshuMajorItems.first : '';
    _resetGeneralMajorAndMid(_selectedDomain);
  }

  @override
  void dispose() {
    _stopLoadingUi();
    super.dispose();
  }

  void _startLoadingUi() {
    _stopLoadingUi();

    _loadingMessageIndex = 0;
    _loadingProgress = 0.0;

    // コメントは「1周で止める」：最後まで行ったら固定
    _loadingMessageTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted || !_isLoading) return;
      if (_loadingMessageIndex < _loadingMessages.length - 1) {
        setState(() => _loadingMessageIndex++);
      }
    });

    // 擬似進捗は単調増加（0→99%で止める）
    _loadingProgressTimer =
        Timer.periodic(const Duration(milliseconds: 80), (_) {
          if (!mounted || !_isLoading) return;

          // 99%まではじわじわ増える（速すぎない体感）
          if (_loadingProgress < 0.99) {
            final next = _loadingProgress + 0.008; // 0.8%/tickくらい
            setState(() => _loadingProgress = next.clamp(0.0, 0.99));
          } else {
            // 99%到達後は固定
            _loadingProgress = 0.99;
          }
        });
  }

  void _stopLoadingUi() {
    _loadingMessageTimer?.cancel();
    _loadingMessageTimer = null;

    _loadingProgressTimer?.cancel();
    _loadingProgressTimer = null;
  }

  Future<void> _completeLoadingAndWait() async {
    if (!mounted) return;

    // タイマーを止めて、以降は絶対に進捗が戻らないようにする
    _stopLoadingUi();

    // コメントは最後に固定
    setState(() {
      _loadingMessageIndex = _loadingMessages.length - 1;
      _loadingProgress = 1.0; // 100%固定
    });

    // 500ms待ってから表示（心理的に気持ちいい）
    await Future.delayed(const Duration(milliseconds: 500));
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
  // ==========================
  _ResolvedCategory _resolveCategoryForGeneration() {
    if (_mode == modeHisshu) {
      return _ResolvedCategory('必修', _selectedHisshuMajor, null);
    }

    final List<String> domainList =
    _mode == modeSituational ? situationalDomains : CategoryRepository.generalDomains();

    final rand = Random(DateTime.now().microsecondsSinceEpoch);

    final bool domainRandomRequested = _selectedDomain == kRandomDomainId;
    final bool majorRandomRequested = _selectedMajor == kRandomMajorId;

    // ---- 分野 ----
    String domain = _selectedDomain;
    if (domainRandomRequested || !domainList.contains(domain)) {
      domain = domainList.isNotEmpty ? domainList[rand.nextInt(domainList.length)] : '';
    }

    // ---- 大項目 ----
    final majorsOfDomain = CategoryRepository.generalMajorsOf(domain);
    String major = _selectedMajor;
    if (majorRandomRequested || major.isEmpty || !majorsOfDomain.contains(major)) {
      major = majorsOfDomain.isNotEmpty ? majorsOfDomain[rand.nextInt(majorsOfDomain.length)] : '';
    }

    // ---- 中項目 ----
    String? mid;
    bool midRandomUsed = false;
    if (_useMid) {
      final mids = CategoryRepository.generalMidsOf(domain, major);
      if (_selectedMid != null && _selectedMid!.isNotEmpty && mids.contains(_selectedMid)) {
        mid = _selectedMid;
      } else if (mids.isNotEmpty) {
        midRandomUsed = true;
        mid = mids[rand.nextInt(mids.length)];
      }
    } else {
      mid = null;
    }

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

      _loadingMessageIndex = 0;
      _loadingProgress = 0.0;
    });

    _startLoadingUi();

    Map<String, dynamic>? data;

    try {
      final difficulty = _mode;

      late final String domainArg;
      late final String majorArg;
      String? midArg;
      String? scenarioAspectCode;

      if (_mode == modeHisshu) {
        domainArg = '必修';
        majorArg = _selectedHisshuMajor;
        midArg = null;

        debugPrint(
          '[log] [QS] category resolved (hisshu) => '
              'mode=$_mode | domain=$domainArg | major=$majorArg | mid=(none)',
        );
      } else {
        final resolved = _resolveCategoryForGeneration();
        domainArg = resolved.domain;
        majorArg = resolved.major;
        midArg = resolved.mid;

        if (_mode == modeSituational) {
          final bool wasRandomAspect = _selectedScenarioAspectCode == null;
          scenarioAspectCode = _selectedScenarioAspectCode ?? _randomScenarioAspectCode();

          debugPrint(
            '[log] [QS] scenarioAspect resolved => '
                'mode=$_mode | aspect=$scenarioAspectCode'
                '${wasRandomAspect ? " (random)" : " (selected)"}',
          );
        }
      }

      data = await QuestionService.fetchQuestion(
        difficulty: difficulty,
        domain: domainArg,
        major: majorArg,
        mid: midArg,
        scenarioAspect: scenarioAspectCode,
      );

      // ✅ ここで100%にして固定 → 500ms待つ
      await _completeLoadingAndWait();

      if (!mounted) return;

      final d = data;

      setState(() {
        _questionText = (d?['question'] as String?)?.trim();

        final rawChoices = d?['choices'] as Map?;
        _choices = rawChoices?.map((k, v) => MapEntry(k.toString(), v.toString()));

        _correctAnswers = (d?['correctAnswers'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
            [(d?['correct'] ?? '').toString()];

        _questionKind = (d?['questionKind'] as String?) ?? 'single';

        _explanation = (d?['explanation'] as String?) ?? '';
        final rawRat = d?['rationales'] as Map?;
        _rationales = rawRat?.map((k, v) => MapEntry(k.toString(), v.toString()));

        final rawMeta = d?['meta'] as Map?;
        _meta = rawMeta?.map((k, v) => MapEntry(k.toString(), v));

        _isLoading = false;
      });
    } catch (e) {
      _stopLoadingUi();
      if (!mounted) return;
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('問題の生成に失敗しました：$e')),
      );
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

  Widget _buildGeneratingCard() {
    final msg = _loadingMessages[
    _loadingMessageIndex.clamp(0, _loadingMessages.length - 1)];

    final percent = (_loadingProgress * 100).clamp(0, 100).toInt();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: const [
          BoxShadow(
            blurRadius: 10,
            offset: Offset(0, 6),
            color: Color(0x12000000),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // ✅ カード内のくるくるは「残してOK」なので残す
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  msg,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$percent%',
                style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: _loadingProgress.clamp(0.0, 1.0),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '※通信状況やモデルにより数秒〜数十秒かかることがあります',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final domainList = _mode == modeSituational
        ? situationalDomains
        : CategoryRepository.generalDomains();

    final bool isMulti = _questionKind == 'multiple' ||
        _questionKind == 'select_incorrect' ||
        (_correctAnswers?.length ?? 0) >= 2;

    // ✅ 上部の大きいくるくる対策：
    // ローディング中は QuestionControls 側の isLoading 表示を使わず、
    // こちらのカードだけで表示する（操作はIgnorePointerで禁止）
    final controls = IgnorePointer(
      ignoring: _isLoading,
      child: QuestionControls(
        mode: _mode,
        onModeChanged: (val) {
          if (_isLoading) return;
          setState(() {
            _mode = val;
            if (_mode != modeHisshu) {
              final useList = _mode == modeSituational
                  ? situationalDomains
                  : CategoryRepository.generalDomains();
              final dom = useList.contains(_selectedDomain)
                  ? _selectedDomain
                  : (useList.isNotEmpty ? useList.first : _selectedDomain);
              _resetGeneralMajorAndMid(dom);
            }
          });
        },
        // ★ここがポイント：ローディング中でも「controls側のくるくる」を出さない
        isLoading: false,
        onGeneratePressed: _isLoading ? () {} : _generateQuestion,

        domainItems: domainList,
        selectedDomain: domainList.contains(_selectedDomain)
            ? _selectedDomain
            : (domainList.isNotEmpty ? domainList.first : _selectedDomain),
        onDomainChanged: (val) {
          if (_isLoading) return;
          _resetGeneralMajorAndMid(val);
        },
        majorItems: CategoryRepository.generalMajorsOf(_selectedDomain),
        selectedMajor: _selectedMajor,
        onMajorChanged: (val) {
          if (_isLoading) return;
          final mids = CategoryRepository.generalMidsOf(_selectedDomain, val);
          setState(() {
            _selectedMajor = val;
            _selectedMid = mids.isNotEmpty ? mids.first : null;
          });
        },
        useMid: _useMid,
        onUseMidChanged: (v) {
          if (_isLoading) return;
          setState(() => _useMid = v);
        },
        midItems: CategoryRepository.generalMidsOf(_selectedDomain, _selectedMajor),
        selectedMid: _selectedMid,
        onMidChanged: (val) {
          if (_isLoading) return;
          setState(() => _selectedMid = val);
        },

        hisshuMajorItems: hisshuMajorItems,
        selectedHisshuMajor: hisshuMajorItems.contains(_selectedHisshuMajor)
            ? _selectedHisshuMajor
            : (hisshuMajorItems.isNotEmpty ? hisshuMajorItems.first : ''),
        onHisshuMajorChanged: (val) {
          if (_isLoading) return;
          setState(() => _selectedHisshuMajor = val);
        },

        scenarioAspects: _scenarioAspects,
        selectedScenarioAspectCode: _selectedScenarioAspectCode,
        onScenarioAspectChanged: (val) {
          if (_isLoading) return;
          setState(() => _selectedScenarioAspectCode = val);
        },
      ),
    );

    return BaseScaffold(
      title: '出題',
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              controls,
              const SizedBox(height: 16),

              if (_isLoading) _buildGeneratingCard(),
              if (_isLoading) const SizedBox(height: 16),

              if (_questionText != null && _choices != null)
                QuestionBlock(
                  questionText: _questionText!,
                  choices: _choices!,
                  questionKind: _questionKind,

                  selectedLabel: !isMulti && _userAnswers.isNotEmpty
                      ? _userAnswers.first
                      : null,
                  onSelect: !isMulti
                      ? (val) => setState(() => _userAnswers = {val})
                      : null,

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