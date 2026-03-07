import 'package:google_mlkit_translation/google_mlkit_translation.dart';

class TranslationService {
  TranslationService()
      : _translator = OnDeviceTranslator(
    sourceLanguage: TranslateLanguage.english,
    targetLanguage: TranslateLanguage.turkish,
  ),
        _modelManager = OnDeviceTranslatorModelManager();

  final OnDeviceTranslator _translator;
  final OnDeviceTranslatorModelManager _modelManager;

  Future<void> ensureModelsDownloaded() async {
    final sourceCode = TranslateLanguage.english.bcpCode;
    final targetCode = TranslateLanguage.turkish.bcpCode;

    final isEnglishDownloaded =
    await _modelManager.isModelDownloaded(sourceCode);
    if (!isEnglishDownloaded) {
      final success = await _modelManager.downloadModel(sourceCode);
      if (!success) {
        throw Exception('English translation model could not be downloaded.');
      }
    }

    final isTurkishDownloaded =
    await _modelManager.isModelDownloaded(targetCode);
    if (!isTurkishDownloaded) {
      final success = await _modelManager.downloadModel(targetCode);
      if (!success) {
        throw Exception('Turkish translation model could not be downloaded.');
      }
    }
  }

  Future<String> translateEnToTr(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    await ensureModelsDownloaded();
    return _translator.translateText(trimmed);
  }

  void dispose() {
    _translator.close();
  }
}