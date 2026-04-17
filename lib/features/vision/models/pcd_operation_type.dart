enum ImageDomain { spatial, frequency }

enum PcdOperationType {
  contrast('Brightness & Contrast', 'Adjust contrast & brightness'),
  histogram('Histogram Equalization', 'Histogram equalization'),
  gaussianBlur('Gaussian Blur', 'Smoothing with Gaussian Blur'),
  sharpen('Sharpen', 'Unsharp mask sharpening'),
  edgeDetection('Edge Detection', 'Canny edge detection'),
  threshold('Threshold', 'Binary thresholding'),
  medianFilter('Median Filter', 'Denoising with median filter'),
  gamma('Gamma', 'Gamma correction'),
  fourier(
    'Fourier Transform',
    'Frequency domain visualization',
    ImageDomain.frequency,
  ),
  inverseFourier(
    'Inverse Fourier',
    'Back to spatial domain',
    ImageDomain.frequency,
  );

  final String label;
  final String description;
  final ImageDomain domainType;

  const PcdOperationType(
    this.label,
    this.description, [
    this.domainType = ImageDomain.spatial,
  ]);

  bool get isSpatialOnly =>
      this == contrast ||
      this == histogram ||
      this == gaussianBlur ||
      this == sharpen ||
      this == edgeDetection ||
      this == threshold ||
      this == medianFilter ||
      this == gamma;

  bool get isFourierOnly => this == inverseFourier;
}
