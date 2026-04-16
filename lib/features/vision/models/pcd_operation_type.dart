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
