import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum AutoStatus { idle, starting, capturing, waiting, stopped, error }

class _HomeScreenState extends State<HomeScreen> {
  CameraController? _controller;
  bool _cameraReady = false;

  bool _autoEnabled = false;
  bool _busy = false;

  int _captureCount = 0;
  String? _lastCapturePath;
  DateTime? _lastCaptureTime;

  AutoStatus _status = AutoStatus.idle;
  String? _error;

  static const Duration cycleDelay = Duration(seconds: 15);

  @override
  void initState() {
    super.initState();
    _initCamera();
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

      // External storage'a kopyala (görünür olsun)
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        final picturesDir = Directory(p.join(extDir.path, "Pictures"));
        if (!await picturesDir.exists()) {
          await picturesDir.create(recursive: true);
        }

        final filename =
            "cap_${DateTime.now().millisecondsSinceEpoch}.jpg";
        final savedPath = p.join(picturesDir.path, filename);

        await File(file.path).copy(savedPath);

        setState(() {
          _captureCount++;
          _lastCapturePath = savedPath;
          _lastCaptureTime = DateTime.now();
        });

        debugPrint("Saved: $savedPath");
      }
    } catch (e) {
      setState(() {
        _status = AutoStatus.error;
        _error = "Capture failed: $e";
        _autoEnabled = false;
      });
    } finally {
      _busy = false;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
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
      appBar: AppBar(title: const Text("Auto Caption (V1)")),
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
              children: [
                Text("Status: ${_statusText(_status)}"),
                Text("Captured: $_captureCount"),
                if (_lastCaptureTime != null)
                  Text("Last: ${_lastCaptureTime!.toIso8601String()}"),
                if (_lastCapturePath != null)
                  Text(
                    _lastCapturePath!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: (!_autoEnabled && _cameraReady)
                      ? _startAuto
                      : null,
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