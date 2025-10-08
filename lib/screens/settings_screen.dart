// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../widgets/base_scaffold.dart';
import '../widgets/app_buttons.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiController = TextEditingController();
  String _selectedModel = 'gpt-4o-mini';

  // 確率設定
  int _fiveChoiceProb = 0;
  int _incorrectProb = 0;
  int _multipleProb = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = await SettingsService.getApiKey();
    final model = await SettingsService.getModel();

    final five = await SettingsService.getFiveChoiceProbability() ?? 0;
    final incorrect = await SettingsService.getIncorrectKindProbability() ?? 0;
    final multiple = await SettingsService.getMultipleKindProbability() ?? 0;

    setState(() {
      _apiController.text = api ?? '';
      _selectedModel = model ?? 'gpt-4o-mini';
      _fiveChoiceProb = five;
      _incorrectProb = incorrect;
      _multipleProb = multiple;
    });
  }

  Future<void> _save() async {
    await SettingsService.setApiKey(_apiController.text.trim());
    await SettingsService.setModel(_selectedModel.trim());
    await SettingsService.setFiveChoiceProbability(_fiveChoiceProb);
    await SettingsService.setIncorrectKindProbability(_incorrectProb);
    await SettingsService.setMultipleKindProbability(_multipleProb);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('設定を保存しました')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: '設定',
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ===== APIキー =====
              const Text('OpenAI APIキー', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                controller: _apiController,
                obscureText: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'sk-xxxx...',
                ),
              ),
              const SizedBox(height: 20),

              // ===== モデル選択 =====
              const Text('モデル', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedModel,
                items: const [
                  DropdownMenuItem(value: 'gpt-4o-mini', child: Text('gpt-4o-mini')),
                  DropdownMenuItem(value: 'gpt-4o', child: Text('gpt-4o')),
                  DropdownMenuItem(value: 'gpt-5.1-mini', child: Text('gpt-5.1-mini')),
                  DropdownMenuItem(value: 'gpt-5.1', child: Text('gpt-5.1')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedModel = val);
                  }
                },
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 30),

              // ===== 出題オプション =====
              const Text('出題オプション（確率設定）', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),

              _buildSlider(
                label: '5択が出る確率',
                value: _fiveChoiceProb,
                onChanged: (v) => setState(() => _fiveChoiceProb = v),
              ),
              const SizedBox(height: 20),

              _buildSlider(
                label: '誤答（間違いを選べ）問題の確率',
                value: _incorrectProb,
                onChanged: (v) => setState(() => _incorrectProb = v),
              ),
              const SizedBox(height: 20),

              _buildSlider(
                label: '複数選択（正解が2つ以上）問題の確率',
                value: _multipleProb,
                onChanged: (v) => setState(() => _multipleProb = v),
              ),
              const SizedBox(height: 40),

              // ===== 保存ボタン =====
              SizedBox(
                width: double.infinity,
                child: AppButtons.primary(
                  label: '保存',
                  icon: Icons.save,
                  onPressed: _save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        Slider(
          value: value.toDouble(),
          min: 0,
          max: 100,
          divisions: 20,
          label: '$value%',
          onChanged: (v) => onChanged(v.toInt()),
        ),
        Text('現在: $value%'),
      ],
    );
  }
}