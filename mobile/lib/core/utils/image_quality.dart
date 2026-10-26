import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import '../config/app_config.dart';

class ImageQualityResult {
  final bool isValid;
  final bool isBlurPassed;
  final bool isLuminancePassed;
  final bool isTooDark;
  final bool isTooBright;
  final double blurScore;
  final double luminanceScore;
  final String? errorMessage;

  ImageQualityResult({
    required this.isValid,
    required this.isBlurPassed,
    required this.isLuminancePassed,
    required this.isTooDark,
    required this.isTooBright,
    required this.blurScore,
    required this.luminanceScore,
    this.errorMessage,
  });

  @override
  String toString() {
    return 'ImageQualityResult(valid: $isValid, blur: ${blurScore.toStringAsFixed(1)} [>=${AppConfig.blurThreshold}], lum: ${luminanceScore.toStringAsFixed(1)} [${AppConfig.minLuminance}-${AppConfig.maxLuminance}], error: $errorMessage)';
  }
}

/// Menghitung variance of Laplacian untuk mengukur ketajaman (blur) gambar
double _laplacianVariance(Uint8List gray, int w, int h) {
  if (w < 3 || h < 3) return 0.0;
  final vals = <double>[];
  for (var y = 1; y < h - 1; y++) {
    for (var x = 1; x < w - 1; x++) {
      final i = y * w + x;
      // Kernel: [[0, 1, 0], [1, -4, 1], [0, 1, 0]]
      final l = (gray[i - w] + gray[i + w] + gray[i - 1] + gray[i + 1] - 4 * gray[i]).toDouble();
      vals.add(l);
    }
  }
  if (vals.isEmpty) return 0.0;

  final mean = vals.reduce((a, b) => a + b) / vals.length;
  final variance = vals.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / vals.length;
  return variance;
}

/// Fungsi top-level yang dijalankan di Isolate via compute()
ImageQualityResult _analyzeImageQuality(Uint8List imageBytes) {
  final decoded = img.decodeImage(imageBytes);
  if (decoded == null) {
    return ImageQualityResult(
      isValid: false,
      isBlurPassed: false,
      isLuminancePassed: false,
      isTooDark: false,
      isTooBright: false,
      blurScore: 0.0,
      luminanceScore: 0.0,
      errorMessage: 'Gagal membaca format gambar',
    );
  }

  // Perkecil gambar ke lebar analysisWidth (320px) menjaga rasio aspek
  final resized = img.copyResize(decoded, width: AppConfig.analysisWidth);
  final w = resized.width;
  final h = resized.height;
  final totalPixels = w * h;

  final gray = Uint8List(totalPixels);
  double totalLuminance = 0;

  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = resized.getPixel(x, y);
      // Luminansi Y = 0.299R + 0.587G + 0.114B
      final lum = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
      gray[y * w + x] = lum.clamp(0, 255).toInt();
      totalLuminance += lum;
    }
  }

  final avgLuminance = totalPixels > 0 ? (totalLuminance / totalPixels) : 0.0;
  final blurScore = _laplacianVariance(gray, w, h);

  final isBlurPassed = blurScore >= AppConfig.blurThreshold;
  final isTooDark = avgLuminance < AppConfig.minLuminance;
  final isTooBright = avgLuminance > AppConfig.maxLuminance;
  final isLuminancePassed = !isTooDark && !isTooBright;
  final isValid = isBlurPassed && isLuminancePassed;

  String? errorMsg;
  if (!isBlurPassed) {
    errorMsg = 'Foto terlalu buram. Harap posisikan kamera dengan stabil.';
  } else if (isTooDark) {
    errorMsg = 'Pencahayaan terlalu gelap. Harap cari tempat yang lebih terang.';
  } else if (isTooBright) {
    errorMsg = 'Pencahayaan terlalu terang atau silau. Harap sesuaikan pencahayaan.';
  }

  return ImageQualityResult(
    isValid: isValid,
    isBlurPassed: isBlurPassed,
    isLuminancePassed: isLuminancePassed,
    isTooDark: isTooDark,
    isTooBright: isTooBright,
    blurScore: blurScore,
    luminanceScore: avgLuminance,
    errorMessage: errorMsg,
  );
}

/// Eksekusi pemeriksaan kualitas gambar di dalam Isolate agar tidak memblokir UI
Future<ImageQualityResult> computeImageQuality(Uint8List imageBytes) {
  return compute(_analyzeImageQuality, imageBytes);
}
