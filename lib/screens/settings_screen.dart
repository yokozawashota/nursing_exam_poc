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
  String _selectedModel = 'gpt-3.5-turbo';
  bool _saving = false;

  final models = const [
    'gpt-3.5-turbo',
    'gpt-4o',
    'gpt-4o-mini',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = await SettingsService.loadApiKey();
    final model = await SettingsService.loadModel();
    setState(() {
      _apiController.text = api ?? '';
      _selectedModel = model ?? 'gpt-3.5-turbo';
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await SettingsService.saveApiKey(_apiController.text.trim());
      await SettingsService.saveModel(_selectedModel.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存しました')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: '設定',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const Text(
            'OpenAI API キー',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _apiController,
            obscureText: true,
            decoration: InputDecoration(
              hintText: 'sk- から始まるキー',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.black12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 20),

          const Text(
            'モデル選択',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
            ),
            child: DropdownButton<String>(
              value: _selectedModel,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              items: models
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedModel = v ?? _selectedModel),
            ),
          ),

          const SizedBox(height: 24),
          AppButtons.primary(
            label: _saving ? '保存中...' : '保存する',
            icon: Icons.save,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}