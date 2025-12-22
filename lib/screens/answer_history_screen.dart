// lib/screens/answer_history_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../widgets/base_scaffold.dart';
import '../models/answer_history.dart';
import '../theme/app_theme.dart';
import '../ai_analysis/domain_analysis.dart';
import 'history_detail_screen.dart';

/// 履歴一覧の並び替えオプション
enum HistorySortOption {
  newest, // 新しい順
  oldest, // 古い順
}

class AnswerHistoryScreen extends StatefulWidget {
  const AnswerHistoryScreen({super.key});

  @override
  State<AnswerHistoryScreen> createState() => _AnswerHistoryScreenState();
}

class _AnswerHistoryScreenState extends State<AnswerHistoryScreen> {
  // 検索キーワード
  String _searchKeyword = '';

  // 並び順
  HistorySortOption _sortOption = HistorySortOption.newest;

  // 分野フィルタ（「すべて」 or DomainAnalysis.domainOptions のいずれか）
  String _selectedDomain = 'すべて';

  /// 分野フィルタ用の選択肢
  List<String> get _domainFilterOptions =>
      ['すべて', ...DomainAnalysis.domainOptions];

  // ===== ちらつき対策：TextFieldの状態を保持 =====
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;

  Timer? _debounce;

  // ===== 読み込みを build() でやらない（FutureBuilderをやめる） =====
  bool _loading = true;
  List<AnswerRecord> _allRecords = const [];

  // version変更に追従
  late final VoidCallback _versionListener;

  @override
  void initState() {
    super.initState();

    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();

    _versionListener = () {
      // 履歴に変更が入ったら再読込（スワイプ削除でもここが動く）
      _load();
    };
    AnswerHistory.instance.versionListenable.addListener(_versionListener);

    _load();
  }

  @override
  void dispose() {
    AnswerHistory.instance.versionListenable.removeListener(_versionListener);
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final list = await AnswerHistory.instance.all();
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

  String _formatDateTime(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$y/$m/$d $h:$min';
  }

  double _accuracyOf(Iterable<AnswerRecord> items) {
    if (items.isEmpty) return 0.0;
    final correct = items.where((r) => r.isCorrect).length;
    return correct / items.length;
  }

  String _pct(double v) => '${(v * 100).toStringAsFixed(1)}%';

  /// レコードの分野ラベル（domain が空なら DomainAnalysis から推定）
  String _domainLabelOf(AnswerRecord r) {
    if (r.domain != null && r.domain!.isNotEmpty) {
      return r.domain!;
    }
    return DomainAnalysis.domainKeyOfRecord(r);
  }

  /// 「AI生成問題の履歴かどうか」
  /// sourceType が
  ///   - 'past_exam' 以外 → AI側として扱う
  bool _isAiRecord(AnswerRecord r) {
    final t = (r.sourceType ?? '').trim();
    if (t.isEmpty) return true; // 古いデータは AI とみなす
    return t != 'past_exam';
  }

  /// 分野フィルタ＋検索＋ソートをまとめて適用
  List<AnswerRecord> _applyFilterAndSort(List<AnswerRecord> items) {
    var list = List<AnswerRecord>.from(items);

    // 分野フィルタ
    if (_selectedDomain != 'すべて') {
      list = list.where((r) => _domainLabelOf(r) == _selectedDomain).toList();
    }

    // 検索（分野名・出題形式・問題文）
    final q = _searchKeyword.trim();
    if (q.isNotEmpty) {
      list = list.where((r) {
        final domainLabel = _domainLabelOf(r);
        final difficulty = r.difficulty;
        final question = r.question;
        final haystack = '$domainLabel $difficulty $question';
        return haystack.contains(q);
      }).toList();
    }

    // 並び替え
    list.sort((a, b) {
      switch (_sortOption) {
        case HistorySortOption.newest:
          return b.ts.compareTo(a.ts);
        case HistorySortOption.oldest:
          return a.ts.compareTo(b.ts);
      }
    });

    return list;
  }

  Future<void> _confirmClearHistory(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('解答履歴を削除'),
        content: const Text('すべての解答履歴を削除します。よろしいですか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              '削除する',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (ok == true) {
      await AnswerHistory.instance.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('解答履歴を削除しました')),
      );
    }
  }

  Future<bool> _confirmDismissOne(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('この履歴を削除しますか？'),
        content: const Text('この操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              '削除する',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // すべての履歴から「AI生成分だけ」を抽出
    final aiRecords = _allRecords.where(_isAiRecord).toList();
    final items = _applyFilterAndSort(aiRecords);

    return BaseScaffold(
      title: '解答履歴',
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _confirmClearHistory(context),
        ),
      ],
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _reloadPull,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
          itemCount: (aiRecords.isEmpty ? 1 : items.length + 1),
          separatorBuilder: (_, index) {
            if (index == 0) return const SizedBox(height: 8);
            return const Divider(height: 0);
          },
          itemBuilder: (context, index) {
            // ヘッダー（常に表示）
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _headerInfo(theme, aiRecords),
                    const SizedBox(height: 12),
                    _searchAndSortBar(theme),
                    if (aiRecords.isEmpty) ...[
                      const SizedBox(height: 20),
                      Center(
                        child: Text(
                          'AI生成問題の解答履歴はまだありません',
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
                    ],
                  ],
                ),
              );
            }

            // データなしの場合はヘッダーだけで終わり
            if (aiRecords.isEmpty || items.isEmpty) {
              return const SizedBox.shrink();
            }

            final r = items[index - 1];
            final when = _formatDateTime(r.ts);

            final leadingIcon = Icon(
              r.isCorrect
                  ? Icons.check_circle_outline
                  : Icons.cancel_outlined,
              color: r.isCorrect ? Colors.green[600] : Colors.red[500],
            );

            final subtitleText = StringBuffer()
              ..write(when)
              ..write(' ・ ')
              ..write(r.difficulty);

            final domainLabel = _domainLabelOf(r);
            if (domainLabel.isNotEmpty) {
              subtitleText.write(' ・ $domainLabel');
            }

            // ✅ スワイプ削除（右→左 / 左→右 両対応にしてもOK）
            return Dismissible(
              key: ValueKey('${r.id}_${r.ts.millisecondsSinceEpoch}'),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.delete, color: Colors.red),
              ),
              confirmDismiss: (_) => _confirmDismissOne(context),
              onDismissed: (_) async {
                await AnswerHistory.instance.removeById(r.id);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('履歴を削除しました')),
                );
              },
              child: ListTile(
                leading: leadingIcon,
                title: Text(
                  r.question,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(subtitleText.toString()),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => HistoryDetailScreen(record: r),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  // ===== 下請けUI部品 =====

  /// 上部のサマリー（総解答数・総合正答率）
  Widget _headerInfo(ThemeData theme, List<AnswerRecord> all) {
    final total = all.length;
    final acc = _accuracyOf(all);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'これまでの解答履歴（AI生成）',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '解答数：$total 問   /   総合正答率：${_pct(acc)}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            '※ 行を左にスワイプすると1件削除できます',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  /// 検索バー＋分野フィルタ＋ソート
  Widget _searchAndSortBar(ThemeData theme) {
    return Column(
      children: [
        // 検索バー（controller/focusを保持して安定化）
        TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          decoration: const InputDecoration(
            hintText: '分野名・出題形式・問題文で検索',
            prefixIcon: Icon(Icons.search),
            isDense: true,
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            // ちらつき対策：debounce
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
            // 分野フィルタ
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                value: _selectedDomain,
                decoration: const InputDecoration(
                  labelText: '分野',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                isExpanded: true,
                items: _domainFilterOptions
                    .map(
                      (d) => DropdownMenuItem<String>(
                    value: d,
                    child: Text(
                      d,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                    .toList(),
                onChanged: (val) {
                  if (val == null) return;
                  setState(() => _selectedDomain = val);
                },
              ),
            ),
            const SizedBox(width: 8),
            // 並び順
            Expanded(
              flex: 1,
              child: DropdownButtonFormField<HistorySortOption>(
                value: _sortOption,
                decoration: const InputDecoration(
                  labelText: '並び順',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: HistorySortOption.newest,
                    child: Text('新しい順'),
                  ),
                  DropdownMenuItem(
                    value: HistorySortOption.oldest,
                    child: Text('古い順'),
                  ),
                ],
                onChanged: (val) {
                  if (val == null) return;
                  setState(() => _sortOption = val);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}