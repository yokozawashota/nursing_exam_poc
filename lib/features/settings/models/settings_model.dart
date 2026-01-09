// lib/features/settings/models/ssettings_model.dart
  class SettingsModel {
  final String choiceMode;        // 'auto' | 'force4' | 'force5'
  final int fiveChoiceProb;       // 0..100
  final int multipleProb;         // 0..100
  final int incorrectProb;        // 0..100
  final String? apiKey;
  final String? model;            // e.g. 'gpt-4o-mini'

  SettingsModel({
    required this.choiceMode,
    required this.fiveChoiceProb,
    required this.multipleProb,
    required this.incorrectProb,
    required this.apiKey,
    required this.model,
  });

  SettingsModel copyWith({
    String? choiceMode,
    int? fiveChoiceProb,
    int? multipleProb,
    int? incorrectProb,
    String? apiKey,
    String? model,
  }) => SettingsModel(
    choiceMode: choiceMode ?? this.choiceMode,
    fiveChoiceProb: fiveChoiceProb ?? this.fiveChoiceProb,
    multipleProb: multipleProb ?? this.multipleProb,
    incorrectProb: incorrectProb ?? this.incorrectProb,
    apiKey: apiKey ?? this.apiKey,
    model: model ?? this.model,
  );
}