import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../config/app_config.dart';

class CompressedImageResult {
  final Uint8List bytes;
  final String sha256Hex;
  final String? savedPath;

  CompressedImageResult({
    required this.bytes,
    required this.sha256Hex,
    this.savedPath,
  });
}

class ImagePrep {
  /// Kompresi gambar dari file path sesuai Design Spec bagian 9.4
  static Future<CompressedImageResult> compressAndHashFile(
    String filePath, {
    bool saveToDisk = true,
  }) async {
    final bytes = await FlutterImageCompress.compressWithFile(
      filePath,
      minWidth: AppConfig.maxUploadSide,
      minHeight: AppConfig.maxUploadSide,
      quality: AppConfig.jpegQuality,
      autoCorrectionAngle: true,
      keepExif: false,
      format: CompressFormat.jpeg,
    );

    if (bytes == null || bytes.isEmpty) {
      throw Exception('Gagal melakukan kompresi gambar pada path: $filePath');
    }

    final sha256Hex = sha256.convert(bytes).toString();

    String? savedPath;
    if (saveToDisk) {
      final appDir = await getApplicationDocumentsDirectory();
      final uploadDir = Directory('${appDir.path}/upload_images');
      if (!await uploadDir.exists()) {
        await uploadDir.create(recursive: true);
      }
      final filename = '${const Uuid().v4()}.jpg';
      final file = File('${uploadDir.path}/$filename');
      await file.writeAsBytes(bytes);
      savedPath = file.path;
    }

    return CompressedImageResult(
      bytes: bytes,
      sha256Hex: sha256Hex,
      savedPath: savedPath,
    );
  }

  /// Kompresi gambar dari byte array (in-memory)
  static Future<CompressedImageResult> compressAndHashBytes(
    Uint8List inputBytes, {
    bool saveToDisk = true,
  }) async {
    final bytes = await FlutterImageCompress.compressWithList(
      inputBytes,
      minWidth: AppConfig.maxUploadSide,
      minHeight: AppConfig.maxUploadSide,
      quality: AppConfig.jpegQuality,
      autoCorrectionAngle: true,
      keepExif: false,
      format: CompressFormat.jpeg,
    );

    if (bytes.isEmpty) {
      throw Exception('Gagal melakukan kompresi gambar dari byte array');
    }

    final sha256Hex = sha256.convert(bytes).toString();

    String? savedPath;
    if (saveToDisk) {
      final appDir = await getApplicationDocumentsDirectory();
      final uploadDir = Directory('${appDir.path}/upload_images');
      if (!await uploadDir.exists()) {
        await uploadDir.create(recursive: true);
      }
      final filename = '${const Uuid().v4()}.jpg';
      final file = File('${uploadDir.path}/$filename');
      await file.writeAsBytes(bytes);
      savedPath = file.path;
    }

    return CompressedImageResult(
      bytes: bytes,
      sha256Hex: sha256Hex,
      savedPath: savedPath,
    );
  }
}
