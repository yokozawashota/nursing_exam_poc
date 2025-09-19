import 'package:flutter/material.dart';
import 'app_buttons.dart';

/// 出題ブロック（問題文＋選択肢＋解答ボタン）
/// - 見た目とタップ通知のみ担当（正誤判定やシャッフル等のロジックは一切持たない）
/// - 既存の出題画面の見た目・導線を完全に踏襲
class QuestionBlock extends StatelessWidget {
  final String questionText;
  /// choices: {'A':'...', 'B':'...', ...}（A〜Dのうち存在するキーのみ描画）
  final Map<String, String> choices;

  /// 現在選択中のラベル（'A'..'D'）。未選択なら null
  final String? selectedLabel;

  /// ユーザーが選択肢をタップしたとき
  final void Function(String label) onSelect;

  /// 「解答する」ボタン押下時
  final VoidCallback onSubmit;

  const QuestionBlock({
    super.key,
    required this.questionText,
    required this.choices,
    required this.onSelect,
    required this.onSubmit,
    this.selectedLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32),
        const Text(
          '問題',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          questionText,
          style: const TextStyle(fontSize: 16, fontFamily: 'NotoSansJP'),
        ),
        const SizedBox(height: 16),

        // 選択肢（A〜D順。空文字は非表示）
        ...['A', 'B', 'C', 'D'].where((k) => choices.containsKey(k)).map((k) {
          final text = (choices[k] ?? '').trim();
          if (text.isEmpty) return const SizedBox.shrink();
          final selected = (selectedLabel == k);
          return _OptionTile(
            label: k,
            text: text,
            selected: selected,
            onTap: () => onSelect(k),
          );
        }),

        const SizedBox(height: 8),
        AppButtons.success(
          label: '解答する',
          icon: Icons.check_circle,
          onPressed: onSubmit,
        ),
      ],
    );
  }
}

/// 出題ページの選択肢を結果画面風カードで表示（先頭の丸囲み/右端の丸は無し）
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