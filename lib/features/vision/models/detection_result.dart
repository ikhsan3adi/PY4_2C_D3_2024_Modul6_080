import 'package:flutter/material.dart';

/// Data Transfer Object (DTO) for detection results
class DetectionResult {
  final Rect box;
  final String label;
  final double score;

  DetectionResult({
    required this.box,
    required this.label,
    required this.score,
  });
}
