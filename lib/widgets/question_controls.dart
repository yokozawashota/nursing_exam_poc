import 'package:flutter/material.dart';
import 'app_buttons.dart';

class QuestionControls extends StatelessWidget {
  const QuestionControls({
    super.key,
    required this.selectedDifficulty,
    required this.selectedCategory,
    required this.difficulties,
    required this.categories,
    required this.onDifficultyChanged,
    required this.onCategoryChanged,
    required this.onGeneratePressed,
    required this.isLoading,
    this.generateIcon,
  });

  final String selectedDifficulty;
  final String selectedCategory;

  final List<String> difficulties;
  final List<String> categories;

  final ValueChanged<String> onDifficultyChanged;
  final ValueChanged<String> onCategoryChanged;

  final VoidCallback? onGeneratePressed;
  final bool isLoading;

  /// ボタンアイコンを差し替えたい時用（未指定なら app_buttons 側のデフォルト）
  final IconData? generateIcon;

  @override
  Widget build(BuildContext context) {
    final isHisshu = selectedDifficulty == '必修問題';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 出題形式
        const _Label('出題形式'),
        _Dropdown<String>(
          value: selectedDifficulty,
          items: difficulties.toSet().toList(), // 念のため重複排除
          onChanged: (v) => onDifficultyChanged(v!),
        ),

        const SizedBox(height: 16),

        // 分野（必修問題のときは固定表示）
        const _Label('分野（出題範囲）'),
        if (isHisshu)
          _DisabledBox(text: '対象外（必修問題）')
        else
          _Dropdown<String>(
            value: selectedCategory,
            items: categories.toSet().toList(),
            onChanged: (v) => onCategoryChanged(v!),
          ),

        const SizedBox(height: 24),

        // 生成ボタン（AppButtons.primary に集約）
        AppButtons.primary(
          label: isLoading ? '生成中…' : '問題を生成',
          onPressed: isLoading ? null : onGeneratePressed,
          icon: generateIcon, // ここで Icons.quiz などに差し替え可能
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Colors.black54,
        ),
      ),
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final List<T> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    // items の中に value が 1つだけ存在することを保証
    final uniqueItems = items.toSet().toList();
    final hasExactlyOne = uniqueItems.where((e) => e == value).length == 1;
    final safeValue = hasExactlyOne
        ? value
        : (uniqueItems.isNotEmpty ? uniqueItems.first : value);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButton<T>(
        value: safeValue,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        items: uniqueItems
            .map(
              (e) => DropdownMenuItem<T>(
            value: e,
            child: Text(e.toString()),
          ),
        )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class _DisabledBox extends StatelessWidget {
  const _DisabledBox({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.black38),
      ),
    );
  }
}