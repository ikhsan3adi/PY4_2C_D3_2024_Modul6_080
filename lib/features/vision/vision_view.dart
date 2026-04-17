import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'damage_painter.dart';
import 'image_preview_page.dart';
import 'vision_controller.dart';

/// VisionPage implements the layered stack architecture
/// for Smart Patrol System.
///
/// Architecture:
/// - Layer 1 (Bottom): CameraPreview - Live video feed from hardware
/// - Layer 2 (Top): CustomPaint - Digital overlay for detection boxes
///
/// This follows Separation of Concerns principle:
/// - VisionController: Manages camera lifecycle and detection logic
/// - VisionPage: Manages UI layout and user interactions
/// - DamagePainter: Manages drawing logic
class VisionView extends StatefulWidget {
  const VisionView({super.key});

  @override
  State<VisionView> createState() => _VisionViewState();
}

class _VisionViewState extends State<VisionView> {
  // Initialize controller locally for this page
  late VisionController _visionController;

  @override
  void initState() {
    super.initState();
    _visionController = VisionController();

    // Start mock detection
    _visionController.startMockDetection();
  }

  @override
  void dispose() {
    // MANDATORY: Disconnect camera when navigating away
    // This prevents memory leaks and battery drain
    _visionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart-Patrol Vision'),
        actions: [
          // Flashlight toggle
          IconButton(
            icon: Icon(
              _visionController.isFlashlightOn
                  ? Icons.flash_on
                  : Icons.flash_off,
            ),
            onPressed: _visionController.toggleFlashlight,
            tooltip: 'Toggle Flashlight',
          ),
          // Overlay visibility toggle
          IconButton(
            icon: Icon(
              _visionController.isOverlayVisible
                  ? Icons.visibility
                  : Icons.visibility_off,
            ),
            onPressed: _visionController.toggleOverlay,
            tooltip: 'Toggle Overlay',
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _visionController,
        builder: (context, child) {
          // Show loading if camera is initializing
          if (!_visionController.isInitialized) {
            return _buildLoadingState();
          }

          // Continue to Stack structure
          return _buildVisionStack();
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Upload from gallery button
          FloatingActionButton.small(
            heroTag: 'upload',
            onPressed: () async {
              final ImagePicker picker = ImagePicker();
              final XFile? pickedFile = await picker.pickImage(
                source: ImageSource.gallery,
              );
              if (pickedFile != null && context.mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ImagePreviewPage(imagePath: pickedFile.path),
                  ),
                );
              }
            },
            tooltip: 'Upload Image',
            child: const Icon(Icons.photo_library),
          ),
          const SizedBox(height: 8),
          // Capture photo button
          FloatingActionButton(
            heroTag: 'capture',
            onPressed: () async {
              final image = await _visionController.takePhoto();
              if (image != null && context.mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ImagePreviewPage(imagePath: image.path),
                  ),
                );
              }
            },
            tooltip: 'Capture Photo',
            child: const Icon(Icons.camera),
          ),
        ],
      ),
    );
  }

  /// Build loading state with informative message
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          const Text(
            'Menghubungkan ke Sensor Visual...',
            style: TextStyle(fontSize: 16),
          ),
          if (_visionController.errorMessage != null) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _visionController.errorMessage!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => openAppSettings(),
              child: const Text('Open Settings'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVisionStack() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // LAYER 1: Hardware Preview
        Center(child: CameraPreview(_visionController.controller!)),

        // LAYER 2: Digital Overlay (Canvas)
        // This layer is transparent and sits exactly above camera
        // DamagePainter will draw detection boxes here
        if (_visionController.isOverlayVisible)
          Positioned.fill(
            child: CustomPaint(
              painter: DamagePainter(_visionController.currentDetections),
            ),
          ),
      ],
    );
  }
}
