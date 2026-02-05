
import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // <--- PERBAIKAN: Import yang diperlukan ditambahkan
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tflite;
import 'package:image/image.dart' as img;

// Enum untuk mengelola state UI
enum CameraState {
  initializing,
  permissionDenied,
  ready,
  capturing,
  classifying,
  resultNotFound,
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({Key? key}) : super(key: key);

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraState _cameraState = CameraState.initializing;
  CameraController? _cameraController;
  tflite.Interpreter? _interpreter;
  List<String>? _labels;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _interpreter?.close();
    super.dispose();
  }

  Future<void> _initialize() async {
    if (await Permission.camera.request().isGranted) {
      await _initializeCamera();
      await _loadModel();
      if (mounted) setState(() => _cameraState = CameraState.ready);
    } else {
      if (mounted) setState(() => _cameraState = CameraState.permissionDenied);
    }
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;
    _cameraController = CameraController(cameras[0], ResolutionPreset.high, enableAudio: false);
    await _cameraController!.initialize();
  }

  Future<void> _loadModel() async {
    try {
      final labelsData = await rootBundle.loadString('assets/models/labels.txt');
      // PERBAIKAN: Menggunakan '\n' untuk memisahkan baris dengan benar
      _labels = labelsData.split('\n').map((label) => label.trim()).where((label) => label.isNotEmpty).toList();
      // Try several candidate model filenames found in the repo
      final candidates = [
        'assets/models/mobilenet_v2.tflite',
        'assets/models/mobilenet.tflite',
        'assets/models/MobileNet-v2_w8a8.tflite',
        'mobilenet_v2.tflite',
        'mobilenet.tflite',
      ];
      for (final name in candidates) {
        try {
          _interpreter = await tflite.Interpreter.fromAsset(name);
          debugPrint('Loaded tflite model: $name');
          break;
        } catch (_) {
          // try next
        }
      }
      if (_interpreter == null) throw Exception('No model found in assets');
    } catch (e) {
      debugPrint("Gagal memuat model atau label: $e");
    }
  }

  Future<void> _onTakePhoto() async {
    if (_cameraController == null || _interpreter == null || !mounted) return;
    setState(() => _cameraState = CameraState.capturing);
    try {
      final XFile picture = await _cameraController!.takePicture();
      if (mounted) setState(() => _cameraState = CameraState.classifying);
      final Uint8List imageBytes = await picture.readAsBytes();
      await _classifyImage(imageBytes);
    } catch (e) {
      debugPrint("Error saat mengambil atau mengklasifikasikan foto: $e");
      if (mounted) setState(() => _cameraState = CameraState.ready);
    }
  }

  Future<void> _classifyImage(Uint8List imageBytes) async {
    img.Image? originalImage = img.decodeImage(imageBytes);
    if (originalImage == null || _labels == null || !mounted) return;
    final modelInputSize = 224;
    img.Image resizedImage = img.copyResize(originalImage, width: modelInputSize, height: modelInputSize);

    // Build 4D input: [1][H][W][3]
    final input = List.generate(1, (_) => List.generate(modelInputSize, (_) => List.generate(modelInputSize, (_) => List.filled(3, 0.0))));
    for (var y = 0; y < modelInputSize; y++) {
      for (var x = 0; x < modelInputSize; x++) {
        final pixel = resizedImage.getPixel(x, y);
        final r = img.getRed(pixel);
        final g = img.getGreen(pixel);
        final b = img.getBlue(pixel);
        input[0][y][x][0] = (r - 127.5) / 127.5;
        input[0][y][x][1] = (g - 127.5) / 127.5;
        input[0][y][x][2] = (b - 127.5) / 127.5;
      }
    }

    // Output buffer [1][labels]
    final output = List.generate(1, (_) => List.filled(_labels!.length, 0.0));

    _interpreter!.run(input, output);

    final results = (output[0] as List).map((e) => (e as num).toDouble()).toList();
    double maxConfidence = 0.0;
    int maxIndex = -1;
    for (int i = 0; i < results.length; i++) {
      if (results[i] > maxConfidence) {
        maxConfidence = results[i];
        maxIndex = i;
      }
    }

    if (maxConfidence >= 0.5 && maxIndex != -1) {
      final topPredictionLabel = _labels![maxIndex];
      if (mounted) {
        context.go('/inventory?q=$topPredictionLabel');
        setState(() => _cameraState = CameraState.ready);
      }
    } else {
      if (mounted) setState(() => _cameraState = CameraState.resultNotFound);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Tool')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_cameraState) {
      case CameraState.initializing:
        return const Center(child: CircularProgressIndicator());
      case CameraState.permissionDenied:
        return _buildPermissionDeniedUI();
      case CameraState.capturing:
      case CameraState.classifying:
        return _buildCameraPreviewWithOverlay(Center(child: _buildLoaderUI()));
      case CameraState.resultNotFound:
        return _buildCameraPreviewWithOverlay(_buildResultNotFoundUI());
      case CameraState.ready:
      default:
        if (_cameraController == null || !_cameraController!.value.isInitialized) {
          return const Center(child: Text("Kamera tidak tersedia."));
        }
        return _buildCameraPreviewWithOverlay(_buildShutterButton());
    }
  }

  Widget _buildPermissionDeniedUI() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt, size: 60, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Izin Kamera Ditolak', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Untuk mengklasifikasikan alat, mohon berikan izin kamera di pengaturan.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: openAppSettings, child: const Text('Buka Pengaturan')),
            const SizedBox(height: 10),
            TextButton(onPressed: _initialize, child: const Text('Coba Lagi')),
          ],
        ),
      ),
    );
  }
  
  Widget _buildLoaderUI() {
      return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              _cameraState == CameraState.capturing ? "Mengambil gambar..." : "Menganalisis...",
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        );
  }

  Widget _buildResultNotFoundUI() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, color: Colors.white, size: 50),
            const SizedBox(height: 16),
            const Text("Alat Tidak Dikenali", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => setState(() => _cameraState = CameraState.ready),
              child: const Text("Ambil Foto Lagi"),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildShutterButton(){
       return Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: FloatingActionButton(
                onPressed: _onTakePhoto,
                child: const Icon(Icons.camera_alt, size: 36),
              ),
            ),
          );
  }

  Widget _buildCameraPreviewWithOverlay(Widget overlayWidget) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Center(child: Text("Kamera tidak tersedia."));
    }
    return Stack(fit: StackFit.expand, children: [CameraPreview(_cameraController!), overlayWidget]);
  }
}
