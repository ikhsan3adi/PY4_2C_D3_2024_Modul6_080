import 'dart:math' as math;
import 'dart:typed_data';

import 'package:opencv_dart/opencv_dart.dart' as cv;

/// ImageProcessor service untuk pengolahan citra digital (PCD)
///
/// Menggunakan opencv_dart (dartcv4) untuk operasi native OpenCV:
/// - Contrast adjustment (alpha/beta)
/// - Histogram equalization
/// - Convolution (blur, sharpen, edge detection)
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
  static cv.Mat applyHistogramEqualization(cv.Mat src) {
    if (src.channels == 1) {
      return cv.equalizeHist(src);
    }

    // Color image: convert to HSV, equalize V channel
    final hsv = cv.cvtColor(src, cv.COLOR_BGR2HSV);
    final channels = cv.split(hsv);

    // Equalize V channel (index 2)
    final equalizedV = cv.equalizeHist(channels.elementAt(2));

    // Merge channels back
    final mergedVec = cv.VecMat.fromList([
      channels.elementAt(0),
      channels.elementAt(1),
      equalizedV,
    ]);
    final merged = cv.merge(mergedVec);

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
    final blurred = applyGaussianBlur(src, kernelSize: 5, sigma: 1.0);
    return cv.addWeighted(src, 1.5, blurred, -0.5, 0);
  }

  /// Apply edge detection menggunakan Canny
  /// [threshold1], [threshold2] = thresholds untuk edge detection
  static cv.Mat applyEdgeDetection(
    cv.Mat src, {
    double threshold1 = 50,
    double threshold2 = 150,
  }) {
    final gray = src.channels == 1 ? src : cv.cvtColor(src, cv.COLOR_BGR2GRAY);
    return cv.canny(gray, threshold1, threshold2);
  }

  /// Apply thresholding (binary/mask)
  static cv.Mat applyThreshold(cv.Mat src, double thresh, {int maxval = 255}) {
    final gray = src.channels == 1 ? src : cv.cvtColor(src, cv.COLOR_BGR2GRAY);
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

  /// Apply Fourier Transform dan return magnitude spectrum untuk visualisasi
  static cv.Mat applyFourierTransform(cv.Mat src) {
    final gray = cv.cvtColor(src, cv.COLOR_BGR2GRAY);

    // Convert ke tipe float32
    final floatGray = gray.convertTo(cv.MatType.CV_32FC1);

    // Eksekusi Discrete Fourier Transform (DFT)
    final dft = cv.dft(floatGray, flags: cv.DFT_COMPLEX_OUTPUT);
    final channels = cv.split(dft);

    if (channels.length >= 2) {
      // Hitung magnitude dari Real (index 0) dan Imaginary (index 1)
      cv.Mat mag = cv.magnitude(channels.elementAt(0), channels.elementAt(1));

      // FFT Shift: swap quadran untuk center DC
      mag = mag.region(cv.Rect(0, 0, mag.cols & -2, mag.rows & -2));

      // titik tengah
      final cx = mag.cols ~/ 2;
      final cy = mag.rows ~/ 2;

      // Bagi menjadi 4 kuadran
      final q0 = mag.region(cv.Rect(0, 0, cx, cy)); // Top-Left
      final q1 = mag.region(cv.Rect(cx, 0, cx, cy)); // Top-Right
      final q2 = mag.region(cv.Rect(0, cy, cx, cy)); // Bottom-Left
      final q3 = mag.region(cv.Rect(cx, cy, cx, cy)); // Bottom-Right

      final tmp = q0.clone();
      q3.copyTo(q0);
      tmp.copyTo(q3);

      final tmp2 = q1.clone();
      q2.copyTo(q1);
      tmp2.copyTo(q2);

      // Transformasi ke skala Logaritmik (mag = log(1 + mag))
      final ones = cv.Mat.ones(mag.rows, mag.cols, cv.MatType.CV_32FC1);
      mag = cv.add(mag, ones);
      mag = cv.log(mag);

      // Normalisasi ke rentang 0-255 agar dapat divisualisasikan
      final dst = cv.Mat.empty();

      return cv.normalize(
        mag,
        dst,
        alpha: 0,
        beta: 255,
        normType: cv.NORM_MINMAX,
        dtype: cv.MatType.CV_8UC1.value,
      );
    }

    return gray;
  }

  /// Apply Median Filter untuk denoising
  static cv.Mat applyMedianFilter(cv.Mat src, {int kernelSize = 5}) {
    final kSize = (kernelSize ~/ 2) * 2 + 1;
    return cv.medianBlur(src, kSize);
  }

  /// Apply Gamma Correction dengan LUT
  /// Formula: output = 255 * (input/255)^gamma
  static cv.Mat applyGammaCorrection(cv.Mat src, double gamma) {
    final invGamma = 1.0 / gamma;

    final lutBytes = Uint8List(256);
    for (int i = 0; i < 256; i++) {
      lutBytes[i] = (math.pow(i / 255.0, invGamma) * 255.0).toInt().clamp(
        0,
        255,
      );
    }

    final lutMat = cv.Mat.fromList(1, 256, cv.MatType.CV_8UC1, lutBytes);

    return cv.LUT(src, lutMat);
  }
}

/// Enum untuk jenis operasi PCD yang tersedia
enum PcdOperationType {
  contrast('Brightness & Contrast', 'Adjust contrast & brightness'),
  histogram('Histogram Equalization', 'Histogram equalization'),
  gaussianBlur('Gaussian Blur', 'Smoothing with Gaussian Blur'),
  sharpen('Sharpen', 'Unsharp mask sharpening'),
  edgeDetection('Edge Detection', 'Canny edge detection'),
  threshold('Threshold', 'Binary thresholding'),
  fourier('Fourier Transform', 'Frequency domain visualization'),
  medianFilter('Median Filter', 'Denoising with median filter'),
  gamma('Gamma', 'Gamma correction');

  final String label;
  final String description;

  const PcdOperationType(this.label, this.description);
}
