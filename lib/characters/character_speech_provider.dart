// lib/characters/character_speech_provider.dart
import 'character.dart';
import 'character_speech_key.dart';

class CharacterSpeechProvider {
  CharacterSpeechProvider._();

  /// Controller から呼ばれる唯一の入口（API固定）
  static List<String> lines(
      CharacterSpeechKey key, {
        required Character character,
        DateTime? now,
      }) {
    switch (key) {
      case CharacterSpeechKey.home:
        return _homeLines(character: character, now: now ?? DateTime.now());
    }
  }

  // ===== 内部：ホーム用（時間帯で分岐） =====

  static List<String> _homeLines({
    required Character character,
    required DateTime now,
  }) {
    final bucket = _timeBucket(now);

    // キャラごとのセリフ
    switch (character.id) {
      case 'wansuke':
        return _wansukeHome(bucket);
      case 'nacco':
        return _naccoHome(bucket);
      case 'nayu':
        return _nayuHome(bucket);
      default:
      // 未登録キャラは汎用で
        return _genericHome(bucket);
    }
  }

  static _TimeBucket _timeBucket(DateTime now) {
    final h = now.hour;
    if (h >= 5 && h < 10) return _TimeBucket.morning;
    if (h >= 10 && h < 17) return _TimeBucket.day;
    if (h >= 17 && h < 22) return _TimeBucket.evening;
    return _TimeBucket.night;
  }

  // ===== キャラ別 =====

  static List<String> _wansukeHome(_TimeBucket b) {
    switch (b) {
      case _TimeBucket.morning:
        return [
          'おはよう！今日もいっしょにいこう！',
          '朝の1問、気持ちいいぞ！',
          '準備OK？まずは軽く解いてみよう！',
        ];
      case _TimeBucket.day:
        return [
          'いいペース！その調子！',
          '今のうちにコツコツ積もう！',
          '1問ずつで十分強くなる！',
        ];
      case _TimeBucket.evening:
        return [
          '今日の分、回収しよう！',
          '疲れてても1問でOK！',
          '夜は復習が伸びる時間！',
        ];
      case _TimeBucket.night:
        return [
          '無理しすぎ注意だぞ！',
          '眠くなる前に1問だけでも！',
          '休むのも実力！',
        ];
    }
  }

  static List<String> _naccoHome(_TimeBucket b) {
    switch (b) {
      case _TimeBucket.morning:
        return [
          'おはよ〜！今日もゆるっと積み上げよ〜',
          '朝は深呼吸してから1問いこっ',
          'あったかい飲み物、用意した？',
        ];
      case _TimeBucket.day:
        return [
          'いい感じ〜！焦らずいこ〜',
          'わからなくても大丈夫、解説で伸びる〜',
          'コツコツが一番強いんだよ〜',
        ];
      case _TimeBucket.evening:
        return [
          '今日もおつかれ〜！復習で仕上げよ〜',
          '夜は記憶がまとまりやすいかも〜',
          'やさしく丁寧にいこ〜',
        ];
      case _TimeBucket.night:
        return [
          '眠いときは休んでOKだよ〜',
          '無理しないのが最強〜',
          '明日の自分にバトンタッチ〜',
        ];
    }
  }

  static List<String> _nayuHome(_TimeBucket b) {
    switch (b) {
      case _TimeBucket.morning:
        return [
          'おはようにゃ！まずは1問にゃ！',
          '朝の集中力は貴重にゃ〜',
          'ゆっくりでいいにゃ、始めよ！',
        ];
      case _TimeBucket.day:
        return [
          'いい流れにゃ！',
          'その1問が合格に近づくにゃ！',
          '今日の積み上げ、偉いにゃ！',
        ];
      case _TimeBucket.evening:
        return [
          '今日の復習が効くにゃ〜',
          'ミスは伸びしろにゃ！',
          'あと少しだけ頑張るにゃ？',
        ];
      case _TimeBucket.night:
        return [
          '休むのも大事にゃ…',
          '眠いなら寝るにゃ！',
          '明日またやるにゃ！',
        ];
    }
  }

  static List<String> _genericHome(_TimeBucket b) {
    switch (b) {
      case _TimeBucket.morning:
        return ['おはよう！今日も1問いこう！'];
      case _TimeBucket.day:
        return ['いいペース！その調子！'];
      case _TimeBucket.evening:
        return ['おつかれさま！復習しよう！'];
      case _TimeBucket.night:
        return ['無理せず休もう！'];
    }
  }
}

enum _TimeBucket { morning, day, evening, night }