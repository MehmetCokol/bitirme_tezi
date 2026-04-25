import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import '../services/translation_service.dart';
import '../services/tts_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum AutoStatus {
  idle,
  starting,
  capturing,
  uploading,
  translating,
  speaking,
  waiting,
  stopped,
  error,
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = const ApiService();
  final TranslationService _translationService = TranslationService();
  final TtsService _ttsService = TtsService();

  CameraController? _controller;
  bool _cameraReady = false;

  bool _autoEnabled = false;
  bool _busy = false;

  int _captureCount = 0;
  String? _lastCapturePath;
  DateTime? _lastCaptureTime;

  String? _captionEn;
  String? _captionTr;
  String? _translationProvider;
  String? _lastRequestId;
  String? _modelName;


  AutoStatus _status = AutoStatus.idle;
  String? _error;

  static const Duration cycleDelay = Duration(seconds: 15);

  @override
  void initState() {
    super.initState();
    _initCamera();
    _initTts();
  }

  Future<void> _initTts() async {
    try {
      await _ttsService.init();
    } catch (e) {
      debugPrint('TTS init failed: $e');
    }
  }

  Future<void> _initCamera() async {
    setState(() {
      _status = AutoStatus.starting;
      _error = null;
    });

    final camStatus = await Permission.camera.request();
    if (!camStatus.isGranted) {
      setState(() {
        _status = AutoStatus.error;
        _error = "Camera permission denied.";
      });
      return;
    }

    try {
      final cameras = await availableCameras();
      final back = cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await controller.initialize();

      if (!mounted) return;

      setState(() {
        _controller = controller;
        _cameraReady = true;
        _status = AutoStatus.idle;
      });
    } catch (e) {
      setState(() {
        _status = AutoStatus.error;
        _error = "Camera init failed: $e";
      });
    }
  }

  Future<void> _startAuto() async {
    if (!_cameraReady || _controller == null) return;

    setState(() {
      _autoEnabled = true;
      _error = null;
    });

    _autoLoop();
  }

  Future<void> _stopAuto() async {
    await _ttsService.stop();

    if (!mounted) return;

    setState(() {
      _autoEnabled = false;
      _status = AutoStatus.stopped;
    });
  }

  Future<void> _autoLoop() async {
    while (_autoEnabled) {
      await _runOneCycle();

      if (!_autoEnabled) break;

      setState(() {
        _status = AutoStatus.waiting;
      });

      await Future.delayed(cycleDelay);
    }
  }

  Future<void> _runOneCycle() async {
    if (_busy || _controller == null) return;

    _busy = true;

    try {
      setState(() {
        _status = AutoStatus.capturing;
        _error = null;
      });

      final file = await _controller!.takePicture();

      final extDir = await getExternalStorageDirectory();
      if (extDir == null) {
        throw Exception("External storage directory not found.");
      }

      final picturesDir = Directory(p.join(extDir.path, "Pictures"));
      if (!await picturesDir.exists()) {
        await picturesDir.create(recursive: true);
      }

      final filename = "cap_${DateTime.now().millisecondsSinceEpoch}.jpg";
      final savedPath = p.join(picturesDir.path, filename);

      await File(file.path).copy(savedPath);

      if (!mounted) return;

      setState(() {
        _captureCount++;
        _lastCapturePath = savedPath;
        _lastCaptureTime = DateTime.now();
        _captionEn = null;
        _captionTr = null;
        _translationProvider = null;
        _lastRequestId = null;
        _modelName = null;
      });

      debugPrint("Saved: $savedPath");

      setState(() {
        _status = AutoStatus.uploading;
      });

      final responseData = await _apiService.uploadImageForCaption(savedPath);

      final captionEn = responseData['caption_en']?.toString() ?? '';
      final backendCaptionTr = responseData['caption_tr']?.toString() ?? '';
      final backendProvider = responseData['translation_provider']?.toString();

      String captionTr = '';
      String? translationProvider = backendProvider;
      String? translationError;

      if (backendCaptionTr.trim().isNotEmpty) {
        // Öncelik backend DeepL çevirisi
        captionTr = backendCaptionTr.trim();
        translationProvider = backendProvider ?? 'deepl';

        debugPrint('Translation provider: $translationProvider');
      } else if (captionEn.trim().isNotEmpty) {
        // DeepL başarısızsa ML Kit fallback
        if (!mounted) return;

        setState(() {
          _status = AutoStatus.translating;
        });

        try {
          captionTr = await _translationService.translateEnToTr(captionEn);
          translationProvider = 'mlkit_fallback';

          debugPrint('Translation provider: $translationProvider');
        } catch (e) {
          translationError = "Translation failed: $e";
          debugPrint(translationError);
          captionTr = '';
          translationProvider = 'translation_failed';
        }
      }

      if (!mounted) return;

      setState(() {
        _captionEn = captionEn;
        _captionTr = captionTr;
        _translationProvider = translationProvider;
        _lastRequestId = responseData['request_id']?.toString();
        _modelName = responseData['model_name']?.toString();
        _error = translationError;
        _status = AutoStatus.idle;
      });

      if (captionTr.trim().isNotEmpty) {
        if (!mounted) return;

        setState(() {
          _status = AutoStatus.speaking;
        });

        await _ttsService.speak(captionTr);

        if (!mounted) return;

        setState(() {
          _status = AutoStatus.idle;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _status = AutoStatus.error;
        _error = "Cycle failed: $e";
        _autoEnabled = false;
      });
    } finally {
      _busy = false;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _translationService.dispose();
    _ttsService.stop();
    super.dispose();
  }

  String _statusText(AutoStatus s) {
    switch (s) {
      case AutoStatus.idle:
        return "Idle";
      case AutoStatus.starting:
        return "Starting camera...";
      case AutoStatus.capturing:
        return "Capturing...";
      case AutoStatus.uploading:
        return "Uploading to backend...";
      case AutoStatus.translating:
        return "Translating...";
      case AutoStatus.speaking:
        return "Speaking...";
      case AutoStatus.waiting:
        return "Waiting 15s...";
      case AutoStatus.stopped:
        return "Stopped";
      case AutoStatus.error:
        return "Error";
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Auto Caption", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: (_cameraReady && controller != null)
                    ? AspectRatio(
                  aspectRatio: 3 / 4,
                  child: CameraPreview(controller),
                )
                    : AspectRatio(
                  aspectRatio: 3 / 4,
                  child: Container(
                    color: Colors.grey.shade100,
                    child: Center(
                      child: Text(
                        _error ?? _statusText(_status),
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _captionTr != null
                        ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Caption_TR",
                          style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _captionTr!,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Caption_EN",
                          style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _captionEn!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade800,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    )
                        : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 100,
                          height: 14,
                          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          height: 20,
                          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: MediaQuery.of(context).size.width * 0.6,
                          height: 20,
                          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          width: 120,
                          height: 12,
                          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: MediaQuery.of(context).size.width * 0.8,
                          height: 14,
                          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: (!_autoEnabled && _cameraReady)
                              ? () {
                            HapticFeedback.vibrate();
                            _startAuto();
                          }
                              : null,
                          icon: const Icon(Icons.play_arrow_rounded, size: 28),
                          label: const Text("Başlat", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _autoEnabled
                              ? () {
                            HapticFeedback.vibrate();
                            _stopAuto();
                          }
                              : null,
                          icon: const Icon(Icons.stop_rounded, size: 28),
                          label: const Text("Durdur", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: Colors.red.shade600,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Opacity(
                    opacity: _lastCaptureTime != null ? 1.0 : 0.0,
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          children: [
                            Text(
                              "Status: ${_statusText(_status)}  |  Captured: $_captureCount",
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                            ),
                           Text(
                              "Translation: ${_translationProvider ?? '-'}",
                              style: TextStyle(fontSize: 15, color: Colors.grey.shade400),
                            ),
                            if (_error != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  "Error: $_error",
                                  style: const TextStyle(fontSize: 10, color: Colors.redAccent, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}