// lib/widgets/question_block.dart
import 'package:flutter/material.dart';
import '../widgets/app_buttons.dart';

/// 出題ブロック（問題文と選択肢）
class QuestionBlock extends StatelessWidget {
  final String questionText;
  final Map<String, String> choices; // 'A'..: '本文'

  // --- 新API（複数対応） ---
  final List<String>? selectedLabels;
  final ValueChanged<String>? onToggle;
  final String questionKind; // 'single' | 'multiple' | 'select_incorrect'

  // --- 旧API（単一）互換 ---
  final String? selectedLabel;
  final ValueChanged<String>? onSelect;

  // 解答ボタン
  final VoidCallback? onSubmit;

  const QuestionBlock({
    super.key,
    required this.questionText,
    required this.choices,
    // 新API
    this.selectedLabels,
    this.onToggle,
    this.questionKind = 'single',
    // 旧API
    this.selectedLabel,
    this.onSelect,
    // 共通
    this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final labels = choices.keys.toList()..sort();

    // 実際に使う選択状態とハンドラ（旧/新を吸収）
    final bool multiple = questionKind == 'multiple';
    final bool selectIncorrect = questionKind == 'select_incorrect';

    final Set<String> selected = multiple
        ? (selectedLabels ?? const <String>[]).toSet()
        : {if (selectedLabel != null) selectedLabel!};

    void handleTap(String k) {
      if (multiple) {
        onToggle?.call(k);
      } else {
        onSelect?.call(k);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (selectIncorrect) ...[
          Row(
            children: const [
              Icon(Icons.warning, color: Colors.orange, size: 20),
              SizedBox(width: 6),
              Text(
                '誤っているものを選べ',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],

        const Text('問題', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          questionText,
          style: const TextStyle(fontSize: 16, fontFamily: 'NotoSansJP'),
        ),
        const SizedBox(height: 16),

        ...labels.map((k) {
          final text = choices[k]!;
          final isSelected = selected.contains(k);
          return _OptionTile(
            label: k,
            text: text,
            selected: isSelected,
            multiple: multiple,
            onTap: () => handleTap(k),
          );
        }),

        const SizedBox(height: 8),
        if (onSubmit != null)
          AppButtons.success(
            label: '解答する',
            icon: Icons.check_circle,
            onPressed: onSubmit!,
          ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String label;     // 'A'..'E'
  final String text;      // 本文
  final bool selected;    // 選択中かどうか
  final bool multiple;    // 複数選択モードか
  final VoidCallback onTap;

  const _OptionTile({
    required this.label,
    required this.text,
    required this.selected,
    required this.multiple,
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
          leading: multiple
              ? Icon(
            selected ? Icons.check_box : Icons.check_box_outline_blank,
            color: selected ? Colors.teal : Colors.black54,
          )
              : Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          title: Text(text),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        ),
      ),
    );
  }
}