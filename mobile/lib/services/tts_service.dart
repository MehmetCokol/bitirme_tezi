import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  TtsService() : _flutterTts = FlutterTts();

  final FlutterTts _flutterTts;

  Future<void> init() async {
    await _flutterTts.setLanguage('tr-TR');
    await _flutterTts.setSpeechRate(0.45);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.awaitSpeakCompletion(true);
  }

  Future<void> speak(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    await _flutterTts.stop();
    await _flutterTts.speak(trimmed);
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }
}