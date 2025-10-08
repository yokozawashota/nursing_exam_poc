import 'package:flutter/material.dart';
import 'app_buttons.dart';

/// 出題コントロール一式（表示専用コンポーネント）
/// - 画面の見た目と導線は question_screen.dart と同一になるよう再現
/// - ロジック/状態は親（QuestionScreen）で保持し、ここはイベント通知のみ行う
class QuestionControls extends StatelessWidget {
  const QuestionControls({
    super.key,
    // 共通
    required this.mode, // '必修問題' / '一般問題' / '状況設定問題'
    required this.onModeChanged,
    required this.isLoading,
    required this.onGeneratePressed,

    // 一般/状況設定 共通
    required this.domainItems,
    required this.selectedDomain,
    required this.onDomainChanged,

    required this.majorItems,
    required this.selectedMajor,
    required this.onMajorChanged,

    required this.useMid,
    required this.onUseMidChanged,

    required this.midItems,
    required this.selectedMid,
    required this.onMidChanged,

    // 必修
    required this.hisshuMajorItems,
    required this.selectedHisshuMajor,
    required this.onHisshuMajorChanged,

    // 状況設定 追加
    required this.scenarioAspects, // Map<'A'..'E', 'A. ...'>
    required this.selectedScenarioAspectCode, // String? 'A'..'E'
    required this.onScenarioAspectChanged,
  });

  // ===== プロパティ =====

  // 共通
  final String mode;
  final ValueChanged<String> onModeChanged;
  final bool isLoading;
  final VoidCallback onGeneratePressed;

  // 一般/状況設定 共通
  final List<String> domainItems;
  final String selectedDomain;
  final ValueChanged<String> onDomainChanged;

  final List<String> majorItems;
  final String selectedMajor;
  final ValueChanged<String> onMajorChanged;

  final bool useMid;
  final ValueChanged<bool> onUseMidChanged;

  final List<String> midItems;
  final String? selectedMid;
  final ValueChanged<String?> onMidChanged;

  // 必修
  final List<String> hisshuMajorItems;
  final String selectedHisshuMajor;
  final ValueChanged<String> onHisshuMajorChanged;

  // 状況設定
  final Map<String, String> scenarioAspects;
  final String? selectedScenarioAspectCode;
  final ValueChanged<String?> onScenarioAspectChanged;

  static const String modeHisshu = '必修問題';
  static const String modeGeneral = '一般問題';
  static const String modeSituational = '状況設定問題';

  @override
  Widget build(BuildContext context) {
    final isGeneral = mode == modeGeneral || mode == modeSituational;
    final isSituational = mode == modeSituational;

    // ▼ ドロップダウン表示を「太字ではなく通常」に統一
    final TextStyle? ddStyle =
    Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w400);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 出題形式
        _LabeledBox(
          label: '出題形式',
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: mode,
              isExpanded: true,
              style: ddStyle,
              items: const [
                DropdownMenuItem(value: modeHisshu, child: Text(modeHisshu)),
                DropdownMenuItem(value: modeGeneral, child: Text(modeGeneral)),
                DropdownMenuItem(value: modeSituational, child: Text(modeSituational)),
              ],
              onChanged: (val) {
                if (val == null) return;
                onModeChanged(val);
              },
            ),
          ),
        ),
        const SizedBox(height: 12),

        if (isGeneral) ...[
          // 分野
          _LabeledBox(
            label: '分野',
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: domainItems.contains(selectedDomain)
                    ? selectedDomain
                    : (domainItems.isNotEmpty ? domainItems.first : null),
                isExpanded: true,
                style: ddStyle,
                items: domainItems
                    .map((e) => DropdownMenuItem(value: e, child: Text(e, style: ddStyle)))
                    .toList(),
                onChanged: (val) {
                  if (val == null) return;
                  onDomainChanged(val);
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 大項目
          _LabeledBox(
            label: '大項目',
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedMajor.isNotEmpty ? selectedMajor : null,
                isExpanded: true,
                style: ddStyle,
                items: majorItems
                    .map((e) => DropdownMenuItem(value: e, child: Text(e, style: ddStyle)))
                    .toList(),
                onChanged: (val) {
                  if (val == null) return;
                  onMajorChanged(val);
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 状況設定の観点（A〜E）
          if (isSituational) ...[
            _LabeledBox(
              label: '状況設定の観点',
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: selectedScenarioAspectCode,
                  isExpanded: true,
                  style: ddStyle,
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text('（未選択／ランダム）', style: ddStyle),
                    ),
                    ...scenarioAspects.entries.map(
                          (e) => DropdownMenuItem<String?>(
                        value: e.key,
                        child: Text(e.value, style: ddStyle),
                      ),
                    ),
                  ],
                  onChanged: onScenarioAspectChanged,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // 中項目スイッチ
          Row(
            children: [
              Switch(
                value: useMid,
                onChanged: onUseMidChanged,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('中項目を指定する（オフなら裏でランダム選択）'),
              ),
            ],
          ),

          // 中項目
          if (useMid) ...[
            const SizedBox(height: 8),
            _LabeledBox(
              label: '中項目',
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedMid,
                  isExpanded: true,
                  style: ddStyle,
                  items: midItems
                      .map((e) => DropdownMenuItem(value: e, child: Text(e, style: ddStyle)))
                      .toList(),
                  onChanged: onMidChanged,
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
                value: hisshuMajorItems.contains(selectedHisshuMajor)
                    ? selectedHisshuMajor
                    : (hisshuMajorItems.isNotEmpty ? hisshuMajorItems.first : null),
                isExpanded: true,
                style: ddStyle,
                items: hisshuMajorItems
                    .map((e) => DropdownMenuItem(value: e, child: Text(e, style: ddStyle)))
                    .toList(),
                onChanged: (val) => onHisshuMajorChanged(val ?? ''),
              ),
            ),
          ),
        ],

        const SizedBox(height: 16),
        isLoading
            ? const Center(child: CircularProgressIndicator())
            : AppButtons.primary(
          label: '問題を生成',
          icon: Icons.auto_awesome,
          onPressed: onGeneratePressed,
        ),
      ],
    );
  }
}

/// ラベル付きの箱型コンテナ（question_screenの見た目を踏襲）
class _LabeledBox extends StatelessWidget {
  final String label;
  final Widget child;
  const _LabeledBox({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: '',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ).copyWith(
        labelText: label,
        // ラベル側も通常ウェイトに
        labelStyle: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
      ),
      child: child,
    );
  }
}