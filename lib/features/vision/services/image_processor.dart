import 'dart:typed_data';

import 'package:dartcv4/dartcv.dart' as cv;

/// ImageProcessor service untuk pengolahan citra digital (PCD)
///
/// Menggunakan opencv_dart (dartcv4) untuk operasi native OpenCV:
/// - Contrast adjustment (alpha/beta)
/// - Histogram equalization
/// - Convolution (blur, sharpen, edge detection)
///
/// Referensi diskusi: chat-di-grup-pcd.md
/// Referensi API: https://github.com/rainyl/opencv_dart
class ImageProcessor {
  /// Load image dari file path ke cv.Mat
  /// [flags]: cv.IMREAD_COLOR (default), cv.IMREAD_GRAYSCALE, dll
  static Future<cv.Mat> loadImage(
    String path, {
    int flags = cv.IMREAD_COLOR,
  }) async {
    final mat = cv.imread(path, flags: flags);
    // Check if valid by checking dimensions
    if (mat.rows == 0 || mat.cols == 0) {
      throw Exception('Gagal load image dari path: $path');
    }
    return mat;
  }

  /// Simpan cv.Mat ke file
  static Future<void> saveImage(cv.Mat mat, String path) async {
    cv.imwrite(path, mat);
  }

  /// Convert cv.Mat ke Uint8List untuk ditampilkan di Flutter Image widget
  static Uint8List matToBytes(cv.Mat mat) {
    final encoded = cv.imencode('.jpg', mat);
    return Uint8List.fromList(encoded.$2);
  }

  /// Adjust contrast dan brightness
  /// [alpha] = contrast factor (1.0 = normal, <1.0 = darker, >1.0 = brighter)
  /// [beta] = brightness adjustment (0 = normal, positif = lebih terang)
  static cv.Mat adjustContrast(cv.Mat src, double alpha, {double beta = 0}) {
    final adjustedAlpha = alpha.clamp(0.0, 3.0);
    final adjustedBeta = beta.clamp(-100.0, 100.0);

    return cv.convertScaleAbs(src, alpha: adjustedAlpha, beta: adjustedBeta);
  }

  /// Apply histogram equalization
  /// Untuk grayscale: langsung apply
  /// Untuk color: convert ke HSV, equalize V channel, convert back
  static cv.Mat applyHistogramEqualization(cv.Mat src, {bool isColor = true}) {
    if (!isColor) {
      return cv.equalizeHist(src);
    }

    // Color image: convert to HSV, equalize V channel
    final hsv = cv.cvtColor(src, cv.COLOR_BGR2HSV);
    final channels = cv.split(hsv);

    // Equalize V channel (index 2)
    final equalizedV = cv.equalizeHist(channels[2]);
    channels[2] = equalizedV;

    // Merge channels back
    final merged = cv.merge(channels);

    // Convert back to BGR
    return cv.cvtColor(merged, cv.COLOR_HSV2BGR);
  }

  /// Apply Gaussian blur
  /// [kernelSize] harus odd number (3, 5, 7, etc)
  /// [sigma] = 0 untuk auto-calculate
  static cv.Mat applyGaussianBlur(
    cv.Mat src, {
    int kernelSize = 5,
    double sigma = 0,
  }) {
    final kSize = (kernelSize ~/ 2) * 2 + 1;
    return cv.gaussianBlur(src, (kSize, kSize), sigma);
  }

  /// Apply sharpening menggunakan unsharp mask
  static cv.Mat applySharpen(cv.Mat src) {
    // Gaussian blur
    final blurred = applyGaussianBlur(src, kernelSize: 5, sigma: 1.0);
    // Unsharp mask: src + (src - blurred) * amount
    final diff = cv.subtract(src, blurred);
    final sharpened = cv.addWeighted(src, 1.5, diff, 0.5, 0);
    return sharpened;
  }

  /// Apply edge detection menggunakan Canny
  /// [threshold1], [threshold2] = thresholds untuk edge detection
  static cv.Mat applyEdgeDetection(
    cv.Mat src, {
    double threshold1 = 50,
    double threshold2 = 150,
  }) {
    // Convert to grayscale first
    final gray = cv.cvtColor(src, cv.COLOR_BGR2GRAY);

    // Canny edge detection
    return cv.canny(gray, threshold1, threshold2);
  }

  /// Apply thresholding (binary/mask)
  static cv.Mat applyThreshold(cv.Mat src, double thresh, {int maxval = 255}) {
    final gray = cv.cvtColor(src, cv.COLOR_BGR2GRAY);
    return cv
        .threshold(gray, thresh.toDouble(), maxval.toDouble(), cv.THRESH_BINARY)
        .$2;
  }

  /// Resize image
  static cv.Mat resize(cv.Mat src, int width, int height) {
    return cv.resize(src, (width, height));
  }

  /// Rotate image
  static cv.Mat rotate(cv.Mat src, double angle) {
    final center = cv.Point2f(src.cols / 2, src.rows / 2);
    final rotMat = cv.getRotationMatrix2D(center, angle, 1.0);
    return cv.warpAffine(src, rotMat, (src.cols, src.rows));
  }
}

/// Enum untuk jenis operasi PCD yang tersedia
enum PcdOperationType {
  contrast('Kontras', 'Adjust contrast & brightness'),
  histogram('Histogram', 'Histogram equalization'),
  gaussianBlur('Gaussian Blur', 'Smoothing dengan Gaussian'),
  sharpen('Sharpen', 'Unsharp mask sharpening'),
  edgeDetection('Edge Detection', 'Canny edge detection'),
  threshold('Threshold', 'Binary thresholding');

  final String label;
  final String description;

  const PcdOperationType(this.label, this.description);
}
