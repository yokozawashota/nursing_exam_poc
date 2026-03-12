// lib/questioning/services/question_generation_options_resolver.dart
import 'dart:math';

import '../../features/settings/services/settings_service.dart';

class QuestionGenerationOptions {
  final String choiceMode;
  final int probFiveChoice;
  final int probMultiple;
  final int probIncorrect;
  final int desiredChoiceCount;
  final String desiredKind;
  final int requiredCorrectCount;

  const QuestionGenerationOptions({
    required this.choiceMode,
    required this.probFiveChoice,
    required this.probMultiple,
    required this.probIncorrect,
    required this.desiredChoiceCount,
    required this.desiredKind,
    required this.requiredCorrectCount,
  });
}

class QuestionGenerationOptionsResolver {
  const QuestionGenerationOptionsResolver._();

  static Future<QuestionGenerationOptions> resolve() async {
    final choiceMode = await SettingsService.getChoiceMode() ?? 'auto';
    final probFiveChoice =
        (await SettingsService.getFiveChoiceProbability()) ?? 0;
    final probMultiple =
        (await SettingsService.getMultipleKindProbability()) ?? 0;
    final probIncorrect =
        (await SettingsService.getIncorrectKindProbability()) ?? 0;

    final rand = Random(DateTime.now().microsecondsSinceEpoch);

    final int desiredChoiceCount;
    switch (choiceMode) {
      case 'force4':
        desiredChoiceCount = 4;
        break;
      case 'force5':
        desiredChoiceCount = 5;
        break;
      default:
        desiredChoiceCount = rand.nextInt(100) < probFiveChoice ? 5 : 4;
        break;
    }

    final bool wantMultiple = rand.nextInt(100) < probMultiple;
    final bool wantIncorrect = rand.nextInt(100) < probIncorrect;

    final String desiredKind;
    final int requiredCorrectCount;

    if (wantIncorrect && wantMultiple) {
      desiredKind = 'select_incorrect';
      requiredCorrectCount = 2;
    } else if (wantIncorrect) {
      desiredKind = 'select_incorrect';
      requiredCorrectCount = 1;
    } else if (wantMultiple) {
      desiredKind = 'multiple';
      requiredCorrectCount = 2;
    } else {
      desiredKind = 'single';
      requiredCorrectCount = 1;
    }

    return QuestionGenerationOptions(
      choiceMode: choiceMode,
      probFiveChoice: probFiveChoice,
      probMultiple: probMultiple,
      probIncorrect: probIncorrect,
      desiredChoiceCount: desiredChoiceCount,
      desiredKind: desiredKind,
      requiredCorrectCount: requiredCorrectCount,
    );
  }
}