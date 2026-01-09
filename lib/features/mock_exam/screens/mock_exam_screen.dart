// lib/features/mock_exam/screens/mock_exam_screen.dart
import 'dart:async';
import 'dart:math';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../../../shared/widgets/base_scaffold.dart';
import '../../practice/widgets/question_block.dart';

import '../../practice/services/question_service.dart';
import '../../../shared/services/category_repository.dart';
import '../../../data/categories.dart';
import '../../../data/hisshu_categories.dart';
import '../../../shared/models/answer_history.dart';
import '../../../shared/theme/app_theme.dart';

class MockExamScreen extends StatefulWidget {
  const MockExamScreen({
    super.key,
    required this.questionCount,
    required this.examType, // 'mix' / '必修' など（ラベル）
  });

  final int questionCount;
  final String examType;

  @override
  State<MockExamScreen> createState() => _MockExamScreenState();
}

class _MockExamScreenState extends State<MockExamScreen> {
  final Random _rand = Random();

  // 進行状況
  int _currentIndex = 0;

  // 出題パラメータ（履歴保存にも使う）
  String? _currentDifficulty;
  String? _currentDomain;
  String? _currentMajor;
  String? _currentMid;
  String? _currentScenarioAspect;

  // 問題データ
  String? _questionText;
  Map<String, String>? _choices;
  List<String>? _correctAnswers;
  String? _explanation;
  Map<String, String>? _rationales;
  String _questionKind = 'single';
  Set<String> _userAnswers = {};
  Map<String, dynamic>? _meta;

  bool _isLoading = false;
  bool _finished = false;

  // タイマー
  Timer? _timer;
  late int _totalSeconds;
  int _remainingSeconds = 0;

  // 模試内の全解答
  final List<AnswerRecord> _records = [];

  @override
  void initState() {
    super.initState();
    _setupTimer();
    _loadNextQuestion();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _setupTimer() {
    // 問題数に応じたざっくり時間
    if (widget.questionCount == 10) {
      _totalSeconds = 15 * 60;
    } else if (widget.questionCount == 30) {
      _totalSeconds = 45 * 60;
    } else if (widget.questionCount == 60) {
      _totalSeconds = 90 * 60;
    } else {
      _totalSeconds = max(5 * 60, widget.questionCount * 3 * 60);
    }
    _remainingSeconds = _totalSeconds;

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _finished) {
        t.cancel();
        return;
      }
      if (_remainingSeconds <= 0) {
        t.cancel();
        _finishExam(byTimeout: true);
      } else {
        setState(() {
          _remainingSeconds--;
        });
      }
    });
  }

  /// examType から「必修問題 / 一般問題 / 状況設定問題 / mix」を決める
  String _pickDifficulty() {
    final t = widget.examType;

    // ① まず内部IDで判定（hisshu / general / situational / mix など）
    if (t == 'hisshu') {
      return '必修問題';
    }
    if (t == 'general') {
      return '一般問題';
    }
    if (t == 'situational') {
      return '状況設定問題';
    }

    // ② 念のため日本語ラベルでも判定（将来ラベルが変わってもだいたい対応できるように）
    if (t.contains('必修')) {
      return '必修問題';
    }
    if (t.contains('一般')) {
      return '一般問題';
    }
    if (t.contains('状況')) {
      return '状況設定問題';
    }

    // ③ それ以外は完全ミックス
    const diffs = ['必修問題', '一般問題', '状況設定問題'];
    return diffs[_rand.nextInt(diffs.length)];
  }

  String _randomScenarioAspectCode() {
    const keys = ['A', 'B', 'C', 'D', 'E'];
    return keys[_rand.nextInt(keys.length)];
  }

  Future<void> _loadNextQuestion() async {
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
      // ★ ここで examType → difficulty を一意に決定
      final difficulty = _pickDifficulty();

      String domain;
      String major;
      String? mid;
      String? scenarioAspect;

      if (difficulty == '必修問題') {
        domain = kHisshuCategory;
        final majors = CategoryRepository.hisshuMajorItems();
        if (majors.isEmpty) {
          throw StateError('必修の大項目が定義されていません。');
        }
        major = majors[_rand.nextInt(majors.length)];
        mid = null;
        scenarioAspect = null;
      } else {
        // 一般 / 状況設定
        final List<String> domainList = (difficulty == '状況設定問題')
            ? situationalDomains
            : CategoryRepository.generalDomains();

        if (domainList.isEmpty) {
          throw StateError('一般/状況設定の分野が定義されていません。');
        }
        domain = domainList[_rand.nextInt(domainList.length)];

        final majors = CategoryRepository.generalMajorsOf(domain);
        if (majors.isEmpty) {
          throw StateError('分野 "$domain" の大項目が定義されていません。');
        }
        major = majors[_rand.nextInt(majors.length)];
        mid = null;
        scenarioAspect =
        (difficulty == '状況設定問題') ? _randomScenarioAspectCode() : null;
      }

      // ★ ログ出力：どの条件で出題しているか確認用
      debugPrint(
          '[log] [MOCK] Q${_currentIndex + 1}: examType="${widget.examType}" '
              '=> difficulty=$difficulty, domain=$domain, major=$major, scenarioAspect=$scenarioAspect');

      final data = await QuestionService.fetchQuestion(
        difficulty: difficulty,
        domain: domain,
        major: major,
        mid: mid,
        scenarioAspect: scenarioAspect,
      );

      setState(() {
        _currentDifficulty = difficulty;
        _currentDomain = domain;
        _currentMajor = major;
        _currentMid = mid;
        _currentScenarioAspect = scenarioAspect;

        _questionText = (data['question'] as String?)?.trim();

        final rawChoices = data['choices'] as Map?;
        _choices =
            rawChoices?.map((k, v) => MapEntry(k.toString(), v.toString()));

        _correctAnswers = (data['correctAnswers'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
            [(data['correct'] ?? '').toString()];

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
        SnackBar(content: Text('問題の取得に失敗しました：$e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitCurrent() async {
    if (_questionText == null || _choices == null || _correctAnswers == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('問題を読み込んでから解答してください。')),
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
        difficulty:
        _currentDifficulty ?? (_meta?['difficulty']?.toString() ?? ''),
        domain: (_meta?['domain'] as String?) ?? _currentDomain,
        major: (_meta?['major'] as String?) ?? _currentMajor,
        mid: (_meta?['mid'] as String?) ?? _currentMid,
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

      _records.add(rec);
      await AnswerHistory.instance.add(rec);

      // ★ ログ：履歴に保存された difficulty を確認
      debugPrint(
          '[log] [MOCK] saved record: difficulty=${rec.difficulty}, domain=${rec.domain}, major=${rec.major}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('履歴の保存に失敗しました：$e')),
        );
      }
    }

    if (!mounted || _finished) return;

    if (_currentIndex + 1 >= widget.questionCount) {
      _finishExam(byTimeout: false);
    } else {
      setState(() {
        _currentIndex++;
      });
      await _loadNextQuestion();
    }
  }

  void _finishExam({required bool byTimeout}) {
    if (_finished) return;
    _finished = true;
    _timer?.cancel();

    final usedSeconds = _totalSeconds - _remainingSeconds;
    final correct = _records.where((r) => r.isCorrect).length;
    final answered = _records.length;

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MockExamResultScreen(
          records: _records,
          totalPlanned: widget.questionCount,
          answeredCount: answered,
          correctCount: correct,
          usedSeconds: usedSeconds,
          timeLimitSeconds: _totalSeconds,
          finishedByTimeout: byTimeout,
        ),
      ),
    );
  }

  String _formatTime(int sec) {
    if (sec < 0) sec = 0;
    final m = sec ~/ 60;
    final s = sec % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final progressTime = _totalSeconds == 0
        ? 0.0
        : (1.0 - _remainingSeconds / _totalSeconds).clamp(0.0, 1.0);

    final title = '模試 (${_currentIndex + 1} / ${widget.questionCount})';

    return BaseScaffold(
      title: title,
      showBack: true,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ヘッダー（タグ + 残り時間）
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '模試モード',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Q${_currentIndex + 1} / ${widget.questionCount}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const Spacer(),
                  const Icon(Icons.timer_outlined, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    _formatTime(_remainingSeconds),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progressTime,
                minHeight: 6,
                backgroundColor:
                theme.colorScheme.primary.withOpacity(0.1),
              ),
              const SizedBox(height: 16),

              // 本文
              Expanded(
                child: _isLoading && _questionText == null
                    ? const Center(child: CircularProgressIndicator())
                    : (_questionText == null || _choices == null)
                    ? Center(
                  child: Text(
                    '問題を読み込めませんでした。',
                    style: theme.textTheme.bodyMedium,
                  ),
                )
                    : SingleChildScrollView(
                  child: QuestionBlock(
                    questionText: _questionText!,
                    choices: _choices!,
                    questionKind: _questionKind,
                    // 単一選択
                    selectedLabel:
                    (_questionKind == 'multiple' ||
                        _questionKind == 'select_incorrect')
                        ? null
                        : (_userAnswers.isNotEmpty
                        ? _userAnswers.first
                        : null),
                    onSelect:
                    (_questionKind == 'multiple' ||
                        _questionKind == 'select_incorrect')
                        ? null
                        : (val) {
                      setState(() {
                        _userAnswers = {val};
                      });
                    },
                    // 複数選択
                    selectedLabels:
                    (_questionKind == 'multiple' ||
                        _questionKind == 'select_incorrect')
                        ? _userAnswers.toList()
                        : null,
                    onToggle:
                    (_questionKind == 'multiple' ||
                        _questionKind == 'select_incorrect')
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
                    onSubmit: _submitCurrent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// === 結果画面（ここは前回と同じ） ===
class MockExamResultScreen extends StatelessWidget {
  const MockExamResultScreen({
    super.key,
    required this.records,
    required this.totalPlanned,
    required this.answeredCount,
    required this.correctCount,
    required this.usedSeconds,
    required this.timeLimitSeconds,
    required this.finishedByTimeout,
  });

  final List<AnswerRecord> records;
  final int totalPlanned;
  final int answeredCount;
  final int correctCount;
  final int usedSeconds;
  final int timeLimitSeconds;
  final bool finishedByTimeout;

  String _formatTime(int sec) {
    if (sec < 0) sec = 0;
    final m = sec ~/ 60;
    final s = sec % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final total = answeredCount;
    final rate = total == 0 ? 0.0 : correctCount / total;

    return BaseScaffold(
      title: '模試結果',
      showBack: false,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'おつかれさまでした！',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),

              // 成績カード
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'スコア',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$correctCount',
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ],
                          ),
                        ),
                        Text(
                          ' / $totalPlanned 問',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${(rate * 100).toStringAsFixed(1)}%',
                          style:
                          theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '解答済み: $answeredCount 問',
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (finishedByTimeout)
                      Text(
                        '※ 制限時間に達したため終了しました',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.red),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 時間カード
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('時間', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      '使用時間: ${_formatTime(usedSeconds)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFeatures: const [
                          FontFeature.tabularFigures()
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '制限時間: ${_formatTime(timeLimitSeconds)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontFeatures: const [
                          FontFeature.tabularFigures()
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: AppStyles.ctaButton(context),
                  icon: const Icon(Icons.home_rounded),
                  label: const Text('ホームに戻る'),
                  onPressed: () {
                    Navigator.of(context)
                        .popUntil((route) => route.isFirst);
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  style: AppStyles.outlinedButton,
                  icon: const Icon(Icons.history_rounded),
                  label: const Text('解答履歴で詳細を見る'),
                  onPressed: () {
                    Navigator.of(context)
                        .popUntil((route) => route.isFirst);
                    // AnswerHistoryScreen 側から履歴を参照
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}