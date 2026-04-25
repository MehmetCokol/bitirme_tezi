import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class ApiException implements Exception {
  ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ApiService {
  const ApiService();

  static const String _baseUrl = 'http://10.0.2.2:8000';
  static const String _captionEndpoint = '$_baseUrl/caption';
  static const Duration _requestTimeout = Duration(seconds: 30);

  Future<Map<String, dynamic>> uploadImageForCaption(String imagePath) async {
    final file = File(imagePath);

    if (!await file.exists()) {
      throw ApiException('Görüntü dosyası bulunamadı.');
    }

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(_captionEndpoint),
      );

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imagePath,
          contentType: MediaType('image', 'jpeg'),
        ),
      );

      debugLog('--- API REQUEST START ---');
      debugLog('POST $_captionEndpoint');
      debugLog('Image path: $imagePath');

      final streamedResponse =
      await request.send().timeout(_requestTimeout);

      final response = await http.Response.fromStream(streamedResponse);

      debugLog('Status code: ${response.statusCode}');
      debugLog('Response body: ${response.body}');
      debugLog('--- API REQUEST END ---');

      if (response.statusCode != 200) {
        final serverMessage = _tryExtractErrorMessage(response.body);

        switch (response.statusCode) {
          case 400:
            throw ApiException(
              serverMessage ?? 'Geçersiz istek gönderildi.',
            );
          case 404:
            throw ApiException('Caption servisi bulunamadı.');
          case 500:
            throw ApiException('Backend tarafında sunucu hatası oluştu.');
          default:
            throw ApiException(
              serverMessage ??
                  'Caption isteği başarısız oldu. Kod: ${response.statusCode}',
            );
        }
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw ApiException('Backend geçersiz veri döndürdü.');
      }

      return decoded;
    } on TimeoutException {
      throw ApiException(
        'Backend yanıtı zaman aşımına uğradı. Sunucu yavaş olabilir.',
      );
    } on SocketException {
      throw ApiException(
        'Backend bağlantısı kurulamadı. Sunucu kapalı olabilir.',
      );
    } on FormatException {
      throw ApiException('Backend cevabı okunamadı.');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Beklenmeyen bir ağ hatası oluştu: $e');
    }
  }

  String? _tryExtractErrorMessage(String body) {
    try {
      final decoded = jsonDecode(body);

      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];
        if (detail != null) {
          return detail.toString();
        }

        final message = decoded['message'];
        if (message != null) {
          return message.toString();
        }
      }
    } catch (_) {
      // Body JSON değilse sessizce geç.
    }

    return null;
  }

  void debugLog(String message) {
    // İstersen sonra debugPrint'e çevirebiliriz.
    print(message);
  }
}
