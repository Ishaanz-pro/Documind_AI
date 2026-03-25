import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../providers/document_provider.dart';
import '../providers/subscription_provider.dart';
import '../services/ad_service.dart';

class ScanScreen extends StatefulWidget {
  /// When true, immediately opens the file/gallery picker instead of the camera.
  final bool pickFileOnOpen;

  const ScanScreen({super.key, this.pickFileOnOpen = false});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    if (widget.pickFileOnOpen || kIsWeb) {
      // Skip camera init and go straight to file picker after first frame.
      _isInitializing = false;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _pickFileAndProcess());
    } else {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _cameraController = CameraController(
          _cameras!.first,
          ResolutionPreset.high,
          enableAudio: false,
        );
        await _cameraController!.initialize();
      }
    } catch (e) {
      debugPrint("Camera Error: \$e");
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  // ── File / Gallery picker ───────────────────────────────────────────────────

  Future<void> _pickFileAndProcess() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      withData: true,
    );

    final selected = picked?.files.single;
    final bytes = selected?.bytes;
    if (selected == null || bytes == null) {
      // User cancelled — go back.
      if (mounted) Navigator.pop(context);
      return;
    }

    await _processBytes(bytes, selected.name);
  }

  // ── Camera capture ──────────────────────────────────────────────────────────

  Future<void> _captureAndProcess() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized)
      return;

    try {
      final XFile image = await _cameraController!.takePicture();
      if (!mounted) return;
      final bytes = await image.readAsBytes();
      await _processBytes(
        bytes,
        image.name.isEmpty ? 'document.jpg' : image.name,
      );
    } catch (e) {
      debugPrint("Capture error: \$e");
    }
  }

  // ── Shared processing ───────────────────────────────────────────────────────

  Future<void> _processBytes(Uint8List fileBytes, String fileName) async {
    if (!mounted) return;

    final docProvider = Provider.of<DocumentProvider>(context, listen: false);
    final subProvider =
        Provider.of<SubscriptionProvider>(context, listen: false);
    final adService = Provider.of<AdService>(context, listen: false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text("AI is analyzing document..."),
              ],
            ),
          ),
        ),
      ),
    );

    final result = await docProvider.processAndSaveDocument(
      fileBytes,
      fileName: fileName,
    );

    if (!mounted) return;
    Navigator.pop(context); // Close dialog

    if (result != null) {
      adService.incrementScanCountAndShowAdIfNeeded(subProvider.isPremium);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved as ${result.documentType}')),
      );
      Navigator.pop(context); // Return to gallery
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to process document.')),
      );
      if (widget.pickFileOnOpen) Navigator.pop(context);
    }
  }

  // ── UI ──────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // File-picker mode: just show a loading screen while the picker is open.
    if (widget.pickFileOnOpen) {
      return Scaffold(
        appBar: AppBar(title: const Text('Upload Document')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_isInitializing) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_cameraController == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Scan Document')),
        body: const Center(child: Text('Camera not available')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Full screen camera preview
          Positioned.fill(
            child: CameraPreview(_cameraController!),
          ),

          // UI Overlay
          SafeArea(
            child: Column(
              children: [
                // Top bar: close + pick-from-files
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: Colors.white, size: 30),
                      onPressed: () => Navigator.pop(context),
                    ),
                    TextButton.icon(
                      onPressed: _pickFileAndProcess,
                      icon: const Icon(Icons.upload_file, color: Colors.white),
                      label: const Text(
                        'Upload File',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  color: Colors.black54,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FloatingActionButton.large(
                        onPressed: _captureAndProcess,
                        backgroundColor: Colors.white,
                        child: const Icon(Icons.camera_alt,
                            color: Colors.teal, size: 40),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
