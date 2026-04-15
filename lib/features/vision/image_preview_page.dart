import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:dartcv4/dartcv.dart' as cv;
import 'package:flutter/material.dart';
import 'package:logbook_app_080/features/vision/services/image_processor.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// ImagePreviewPage - Halaman preview dan pengolahan citra hasil capture
///
/// Fitur:
/// - Tampilkan hasil capture dari kamera
/// - Apply PCD operations (contrast, histogram, blur, sharpen, edge)
/// - Save processed image
/// - Share image
///
/// Referensi: chat-di-grup-pcd.md - diskusi PCD operations
class ImagePreviewPage extends StatefulWidget {
  final String imagePath;

  const ImagePreviewPage({super.key, required this.imagePath});

  @override
  State<ImagePreviewPage> createState() => _ImagePreviewPageState();
}

class _ImagePreviewPageState extends State<ImagePreviewPage> {
  Uint8List? _originalBytes;
  Uint8List? _processedBytes;
  cv.Mat? _currentMat;
  bool _isProcessing = false;
  String? _currentOperation;

  // Parameters untuk operations
  double _contrastAlpha = 1.0;
  double _contrastBeta = 0;
  double _blurKernelSize = 5;
  double _edgeThreshold1 = 50;
  double _edgeThreshold2 = 150;
  double _thresholdValue = 127;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void dispose() {
    _currentMat?.dispose();
    super.dispose();
  }

  Future<void> _loadImage() async {
    setState(() => _isProcessing = true);
    try {
      // Load menggunakan OpenCV
      _currentMat = await ImageProcessor.loadImage(widget.imagePath);
      _originalBytes = ImageProcessor.matToBytes(_currentMat!);
      _processedBytes = _originalBytes;
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading image: $e')));
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _applyOperation(PcdOperationType operation) async {
    if (_currentMat == null) return;

    setState(() {
      _isProcessing = true;
      _currentOperation = operation.label;
    });

    try {
      cv.Mat result;

      switch (operation) {
        case PcdOperationType.contrast:
          result = ImageProcessor.adjustContrast(
            _currentMat!,
            _contrastAlpha,
            beta: _contrastBeta,
          );
          break;
        case PcdOperationType.histogram:
          result = ImageProcessor.applyHistogramEqualization(
            _currentMat!,
            isColor: true,
          );
          break;
        case PcdOperationType.gaussianBlur:
          result = ImageProcessor.applyGaussianBlur(
            _currentMat!,
            kernelSize: _blurKernelSize.toInt(),
          );
          break;
        case PcdOperationType.sharpen:
          result = ImageProcessor.applySharpen(_currentMat!);
          break;
        case PcdOperationType.edgeDetection:
          result = ImageProcessor.applyEdgeDetection(
            _currentMat!,
            threshold1: _edgeThreshold1,
            threshold2: _edgeThreshold2,
          );
          break;
        case PcdOperationType.threshold:
          result = ImageProcessor.applyThreshold(_currentMat!, _thresholdValue);
          break;
      }

      setState(() {
        _processedBytes = ImageProcessor.matToBytes(result);
        result.dispose();
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error processing: $e')));
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _resetImage() {
    setState(() {
      _processedBytes = _originalBytes;
      _currentOperation = null;
    });
  }

  Future<void> _saveProcessedImage() async {
    if (_processedBytes == null) return;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final filename = 'processed_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = '${dir.path}/$filename';

      final file = File(path);
      await file.writeAsBytes(_processedBytes!);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Saved to: $path')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving: $e')));
    }
  }

  Future<void> _shareImage() async {
    if (_processedBytes == null) return;

    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/shared_image.jpg';

      final file = File(path);
      await file.writeAsBytes(_processedBytes!);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path)],
          text: 'Processed with Smart-Patrol Vision',
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error sharing: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview & PCD'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset',
            onPressed: _resetImage,
          ),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Save',
            onPressed: _saveProcessedImage,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share',
            onPressed: _shareImage,
          ),
        ],
      ),
      body: Column(
        children: [
          // Image Preview Area
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.black,
              child: Center(
                child: _isProcessing
                    ? const CircularProgressIndicator()
                    : _processedBytes != null
                    ? InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 4,
                        child: Image.memory(
                          _processedBytes!,
                          fit: BoxFit.contain,
                        ),
                      )
                    : const Text(
                        'No image',
                        style: TextStyle(color: Colors.white),
                      ),
              ),
            ),
          ),

          // Operation Info
          if (_currentOperation != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: Colors.indigo,
              child: Text(
                'Operation: $_currentOperation',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          // Parameters Panel (contextual based on selected operation)
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PCD Operations',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  // Parameter sliders
                  _buildParameterSliders(),

                  const SizedBox(height: 16),

                  // Operation buttons
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: PcdOperationType.values.map((op) {
                      return ActionChip(
                        avatar: _getOperationIcon(op),
                        label: Text(op.label),
                        onPressed: () => _applyOperation(op),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParameterSliders() {
    return Column(
      children: [
        // Contrast parameters
        Text(
          'Kontras: Alpha ${_contrastAlpha.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 12),
        ),
        Slider(
          value: _contrastAlpha,
          min: 0.0,
          max: 3.0,
          divisions: 30,
          onChanged: (v) => setState(() => _contrastAlpha = v),
        ),

        Text(
          'Brightness: Beta ${_contrastBeta.toStringAsFixed(1)}',
          style: const TextStyle(fontSize: 12),
        ),
        Slider(
          value: _contrastBeta,
          min: -50,
          max: 50,
          divisions: 100,
          onChanged: (v) => setState(() => _contrastBeta = v),
        ),

        const Divider(),

        // Blur kernel size
        Text(
          'Blur Kernel: ${_blurKernelSize.toInt()}',
          style: const TextStyle(fontSize: 12),
        ),
        Slider(
          value: _blurKernelSize,
          min: 3,
          max: 15,
          divisions: 6,
          onChanged: (v) => setState(() => _blurKernelSize = v),
        ),

        const Divider(),

        // Edge detection thresholds
        Text(
          'Edge Threshold1: ${_edgeThreshold1.toInt()}',
          style: const TextStyle(fontSize: 12),
        ),
        Slider(
          value: _edgeThreshold1,
          min: 0,
          max: 200,
          divisions: 20,
          onChanged: (v) => setState(() => _edgeThreshold1 = v),
        ),

        Text(
          'Edge Threshold2: ${_edgeThreshold2.toInt()}',
          style: const TextStyle(fontSize: 12),
        ),
        Slider(
          value: _edgeThreshold2,
          min: 0,
          max: 300,
          divisions: 30,
          onChanged: (v) => setState(() => _edgeThreshold2 = v),
        ),

        const Divider(),

        // Threshold value
        Text(
          'Threshold: ${_thresholdValue.toInt()}',
          style: const TextStyle(fontSize: 12),
        ),
        Slider(
          value: _thresholdValue,
          min: 0,
          max: 255,
          divisions: 25,
          onChanged: (v) => setState(() => _thresholdValue = v),
        ),
      ],
    );
  }

  Icon _getOperationIcon(PcdOperationType op) {
    switch (op) {
      case PcdOperationType.contrast:
        return const Icon(Icons.tonality, size: 18);
      case PcdOperationType.histogram:
        return const Icon(Icons.bar_chart, size: 18);
      case PcdOperationType.gaussianBlur:
        return const Icon(Icons.blur_on, size: 18);
      case PcdOperationType.sharpen:
        return const Icon(Icons.auto_fix_high, size: 18);
      case PcdOperationType.edgeDetection:
        return const Icon(Icons.line_style, size: 18);
      case PcdOperationType.threshold:
        return const Icon(Icons.contrast, size: 18);
    }
  }
}
