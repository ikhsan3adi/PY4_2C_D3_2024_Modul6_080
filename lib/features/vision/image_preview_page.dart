import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:logbook_app_080/features/vision/models/pcd_operation_type.dart';
import 'package:logbook_app_080/features/vision/services/image_processor.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// ImagePreviewPage - Halaman preview dan pengolahan citra hasil capture
///
/// Fitur:
/// - Tampilkan hasil capture dari kamera
/// - Apply PCD operations (contrast, histogram equalization, blur, sharpen, edge)
/// - Save processed image
/// - Share image
class ImagePreviewPage extends StatefulWidget {
  final String imagePath;

  const ImagePreviewPage({super.key, required this.imagePath});

  @override
  State<ImagePreviewPage> createState() => _ImagePreviewPageState();
}

class _ImagePreviewPageState extends State<ImagePreviewPage>
    with SingleTickerProviderStateMixin {
  Uint8List? _originalBytes;
  Uint8List? _processedBytes;
  cv.Mat? _currentMat;
  bool _isProcessing = false;
  String? _currentOperation;
  bool _showOriginal = false;

  late TabController _tabController;

  // Parameters untuk operations
  double _contrastAlpha = 1.0;
  double _contrastBeta = 0;
  double _blurKernelSize = 5;
  double _edgeThreshold1 = 50;
  double _edgeThreshold2 = 150;
  double _thresholdValue = 127;
  double _medianKernelSize = 5;
  double _gammaValue = 1.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: PcdOperationType.values.length,
      vsync: this,
    );
    _loadImage();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _currentMat?.dispose();
    super.dispose();
  }

  Future<void> _loadImage() async {
    setState(() => _isProcessing = true);
    try {
      _currentMat = await ImageProcessor.loadImage(widget.imagePath);
      _originalBytes = ImageProcessor.matToBytes(_currentMat!);
      _processedBytes = _originalBytes;
    } catch (e) {
      if (!mounted) return;
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
          result = ImageProcessor.applyHistogramEqualization(_currentMat!);
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
        case PcdOperationType.fourier:
          result = ImageProcessor.applyFourierTransform(_currentMat!);
          setState(() {
            _processedBytes = ImageProcessor.matToBytes(result);
            result.dispose();
          });
          setState(() => _isProcessing = false);
          return;
        case PcdOperationType.medianFilter:
          result = ImageProcessor.applyMedianFilter(
            _currentMat!,
            kernelSize: _medianKernelSize.toInt(),
          );
          break;
        case PcdOperationType.gamma:
          result = ImageProcessor.applyGammaCorrection(
            _currentMat!,
            _gammaValue,
          );
          break;
      }

      setState(() {
        _currentMat?.dispose();
        _currentMat = result;
        _processedBytes = ImageProcessor.matToBytes(result);
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error processing: $e')));
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _resetImage() async {
    _currentMat?.dispose();
    _currentMat = await ImageProcessor.loadImage(widget.imagePath);
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

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Saved to: $path')));
    } catch (e) {
      if (!mounted) return;
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
      if (!mounted) return;
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
          // Image Preview Area dengan Toggle Original
          Expanded(
            flex: 3,
            child: GestureDetector(
              onTapDown: (_) => setState(() => _showOriginal = true),
              onTapUp: (_) => setState(() => _showOriginal = false),
              onTapCancel: () => setState(() => _showOriginal = false),
              child: Container(
                color: Colors.black,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Center(
                      child: _isProcessing
                          ? const CircularProgressIndicator()
                          : _processedBytes != null
                          ? InteractiveViewer(
                              minScale: 0.5,
                              maxScale: 4,
                              child: Image.memory(
                                _showOriginal
                                    ? _originalBytes!
                                    : _processedBytes!,
                                fit: BoxFit.contain,
                              ),
                            )
                          : const Text(
                              'No image',
                              style: TextStyle(color: Colors.white),
                            ),
                    ),
                    // Hint untuk toggle
                    Positioned(
                      bottom: 16,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            _showOriginal
                                ? 'Showing Original'
                                : 'Tap & hold to see original',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
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

          // TabBar untuk PCD Operations
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: PcdOperationType.values.map((op) {
              return Tab(icon: _getOperationIcon(op), text: op.label);
            }).toList(),
          ),

          // TabBarView dengan Parameter dan Apply Button
          Expanded(
            flex: 2,
            child: TabBarView(
              controller: _tabController,
              children: PcdOperationType.values.map((op) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Parameter khusus per operasi
                      _buildTabContent(op),
                      const SizedBox(height: 16),
                      // Apply Button
                      ElevatedButton.icon(
                        onPressed: () => _applyOperation(op),
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('Apply'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onPrimary,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// Build content untuk setiap tab sesuai operasi
  Widget _buildTabContent(PcdOperationType op) {
    switch (op) {
      case PcdOperationType.contrast:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Alpha (Contrast): ${_contrastAlpha.toStringAsFixed(2)}'),
            Slider(
              value: _contrastAlpha,
              min: 0.0,
              max: 3.0,
              divisions: 30,
              onChanged: (v) => setState(() => _contrastAlpha = v),
            ),
            Text('Beta (Brightness): ${_contrastBeta.toStringAsFixed(1)}'),
            Slider(
              value: _contrastBeta,
              min: -50,
              max: 50,
              divisions: 100,
              onChanged: (v) => setState(() => _contrastBeta = v),
            ),
          ],
        );
      case PcdOperationType.histogram:
      case PcdOperationType.sharpen:
      case PcdOperationType.fourier:
        return const Center(
          child: Text(
            'No parameters needed',
            style: TextStyle(color: Colors.grey),
          ),
        );
      case PcdOperationType.gaussianBlur:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kernel Size: ${_blurKernelSize.toInt()}'),
            Slider(
              value: _blurKernelSize,
              min: 3,
              max: 15,
              divisions: 6,
              onChanged: (v) => setState(() => _blurKernelSize = v),
            ),
          ],
        );
      case PcdOperationType.edgeDetection:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Threshold 1: ${_edgeThreshold1.toInt()}'),
            Slider(
              value: _edgeThreshold1,
              min: 0,
              max: 200,
              divisions: 40,
              onChanged: (v) => setState(() => _edgeThreshold1 = v),
            ),
            Text('Threshold 2: ${_edgeThreshold2.toInt()}'),
            Slider(
              value: _edgeThreshold2,
              min: 0,
              max: 300,
              divisions: 60,
              onChanged: (v) => setState(() => _edgeThreshold2 = v),
            ),
          ],
        );
      case PcdOperationType.threshold:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Threshold Value: ${_thresholdValue.toInt()}'),
            Slider(
              value: _thresholdValue,
              min: 0,
              max: 255,
              divisions: 255,
              onChanged: (v) => setState(() => _thresholdValue = v),
            ),
          ],
        );
      case PcdOperationType.medianFilter:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kernel Size: ${_medianKernelSize.toInt()}'),
            Slider(
              value: _medianKernelSize,
              min: 3,
              max: 11,
              divisions: 4,
              onChanged: (v) => setState(() => _medianKernelSize = v),
            ),
          ],
        );
      case PcdOperationType.gamma:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Gamma: ${_gammaValue.toStringAsFixed(2)}'),
            Slider(
              value: _gammaValue,
              min: 0.1,
              max: 3.0,
              divisions: 29,
              onChanged: (v) => setState(() => _gammaValue = v),
            ),
          ],
        );
    }
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
      case PcdOperationType.fourier:
        return const Icon(Icons.waves, size: 18);
      case PcdOperationType.medianFilter:
        return const Icon(Icons.filter_list, size: 18);
      case PcdOperationType.gamma:
        return const Icon(Icons.brightness_6, size: 18);
    }
  }
}
