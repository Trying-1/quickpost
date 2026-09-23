import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class BackgroundRemover {
  static const MethodChannel _channel = MethodChannel('com.quickpost.app/processor');

  /// Removes the background from an image file using ML Kit Subject Segmentation.
  /// Returns the path to the newly generated transparent PNG file.
  static Future<String?> removeBackground(
      String inputPath, {
      String? outputPath,
      double smoothing = 0.0,
      double strokeWidth = 0.0,
      int strokeColor = 0x00000000,
      int bgColor = 0x00000000,
      int edgePadding = 0,
      double scale = 1.0,
      double offsetX = 0.0,
      double offsetY = 0.0,
      int outputWidth = 0,
      int outputHeight = 0,
      double shadowRadius = 0.0,
      int shadowColor = 0x00000000,
      double shadowDx = 0.0,
      double shadowDy = 0.0,
      String? bgImagePath,
      double brightness = 0.0,
      double contrast = 1.0,
      double saturation = 1.0,
      bool autoTrim = false,
  }) async {
    try {
      if (outputPath == null) {
        final tempDir = await getTemporaryDirectory();
        final filename = 'bg_removed_${DateTime.now().millisecondsSinceEpoch}.png';
        outputPath = '${tempDir.path}/$filename';
      }

      final String? resultPath = await _channel.invokeMethod<String>(
        'removeBackground',
        {
          'inputPath': inputPath,
          'outputPath': outputPath,
          'smoothing': smoothing,
          'strokeWidth': strokeWidth,
          'strokeColor': strokeColor,
          'bgColor': bgColor,
          'edgePadding': edgePadding,
          'scale': scale,
          'offsetX': offsetX,
          'offsetY': offsetY,
          'outputWidth': outputWidth,
          'outputHeight': outputHeight,
          'shadowRadius': shadowRadius,
          'shadowColor': shadowColor,
          'shadowDx': shadowDx,
          'shadowDy': shadowDy,
          'bgImagePath': bgImagePath,
          'brightness': brightness,
          'contrast': contrast,
          'saturation': saturation,
          'autoTrim': autoTrim,
        },
      );
      
      return resultPath;
    } catch (e) {
      print('Error removing background: $e');
      return null;
    }
  }
}
