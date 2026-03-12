// lib/features/mock_exam/screens/mock_exam_config_screen.dart
import 'package:flutter/material.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/base_scaffold.dart';
import 'mock_exam_screen.dart';

class MockExamConfigScreen extends StatefulWidget {
  const MockExamConfigScreen({super.key});

  @override
  State<MockExamConfigScreen> createState() => _MockExamConfigScreenState();
}

class _MockExamConfigScreenState extends State<MockExamConfigScreen> {
  // mix / hisshu / ippan / jokyo
  String _examType = 'mix';

  // 10 / 30 / 60
  int _questionCount = 30;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BaseScaffold(
      title: "模試モード",
      showBack: true,
      showFooter: false,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '本番さながらに連続して問題を解き、最後にまとめて成績を表示します。',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),

            _buildCard(),
            const SizedBox(height: 28),

            _buildStartButton(context),
            const SizedBox(height: 12),

            _buildNotes(theme.textTheme),
          ],
        ),
      ),
    );
  }

  // -----------------------
  // 出題設定カード
  // -----------------------
  Widget _buildCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "出題形式",
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),

          // 出題形式 2×2（列幅は完全に揃える）
          Column(
            children: [
              Row(
                children: [
                  Expanded(child: _selectChip("mix", "総合（ミックス）")),
                  const SizedBox(width: 12),
                  Expanded(child: _selectChip("hisshu", "必修のみ")),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _selectChip("ippan", "一般のみ")),
                  const SizedBox(width: 12),
                  Expanded(child: _selectChip("jokyo", "状況設定のみ")),
                ],
              ),
            ],
          ),

          const SizedBox(height: 28),

          const Text(
            "問題数",
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),

          // 問題数 3列（幅そろえ）
          Row(
            children: [
              Expanded(child: _countChip(10)),
              const SizedBox(width: 12),
              Expanded(child: _countChip(30)),
              const SizedBox(width: 12),
              Expanded(child: _countChip(60)),
            ],
          ),
        ],
      ),
    );
  }

  // -----------------------
  // 出題形式用：フル幅カード風ボタン
  // -----------------------
  Widget _selectChip(String type, String label) {
    final selected = (_examType == type);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => _examType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.18) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.black12,
            width: 1.2,
          ),
        ),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.primaryDark : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  // -----------------------
  // 問題数用：フル幅カード風ボタン
  // -----------------------
  Widget _countChip(int count) {
    final selected = (_questionCount == count);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => _questionCount = count),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.18) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.black12,
            width: 1.2,
          ),
        ),
        child: Center(
          child: Text(
            "$count問",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.primaryDark : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  // -----------------------
  // 模試開始ボタン
  // -----------------------
  Widget _buildStartButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.play_arrow_rounded),
        label: Text("${_questionCount}問の模試を開始する"),
        style: AppStyles.ctaButton(context),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MockExamScreen(
                questionCount: _questionCount,
                examType: _examType, // ★ MockExamScreen 側が String を受ける前提
              ),
            ),
          );
        },
      ),
    );
  }

  // -----------------------
  // 注意書き
  // -----------------------
  Widget _buildNotes(TextTheme theme) {
    return Text(
      "※ 模試中にアプリを閉じると進行状況は失われますが、解答した問題は解答履歴・スコアに反映されます。\n"
          "※ 出題オプション（5択・誤答選択・複数選択）の出題確率は「設定」画面で変更できます。",
      style: theme.bodySmall?.copyWith(color: Colors.grey[700]),
    );
  }
}