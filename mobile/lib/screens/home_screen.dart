import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

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
        _lastRequestId = null;
        _modelName = null;
      });

      debugPrint("Saved: $savedPath");

      setState(() {
        _status = AutoStatus.uploading;
      });

      final responseData = await _apiService.uploadImageForCaption(savedPath);
      final captionEn = responseData['caption_en']?.toString() ?? '';

      String captionTr = '';
      if (captionEn.trim().isNotEmpty) {
        if (!mounted) return;

        setState(() {
          _status = AutoStatus.translating;
        });

        captionTr = await _translationService.translateEnToTr(captionEn);
      }

      if (!mounted) return;

      setState(() {
        _captionEn = captionEn;
        _captionTr = captionTr;
        _lastRequestId = responseData['request_id']?.toString();
        _modelName = responseData['model_name']?.toString();
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
      appBar: AppBar(title: const Text("Auto Caption (Vers juninho)")),
      body: Column(
        children: [
          Expanded(
            child: (_cameraReady && controller != null)
                ? CameraPreview(controller)
                : Center(child: Text(_error ?? _statusText(_status))),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Status: ${_statusText(_status)}"),
                Text("Captured: $_captureCount"),
                if (_lastCaptureTime != null)
                  Text("Last capture: ${_lastCaptureTime!.toIso8601String()}"),
                if (_lastCapturePath != null)
                  Text(
                    "Path: $_lastCapturePath",
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 12),
                if (_captionEn != null)
                  Text(
                    "Caption EN: $_captionEn",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                if (_captionTr != null)
                  Text(
                    "Caption TR: $_captionTr",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                if (_modelName != null) Text("Model: $_modelName"),
                if (_lastRequestId != null)
                  Text(
                    "Request ID: $_lastRequestId",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      "Error: $_error",
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: (!_autoEnabled && _cameraReady) ? _startAuto : null,
                  child: const Text("Başlat"),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _autoEnabled ? _stopAuto : null,
                  child: const Text("Durdur"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}