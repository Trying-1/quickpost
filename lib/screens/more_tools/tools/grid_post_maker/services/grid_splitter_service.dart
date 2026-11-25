import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../models/grid_layout_type.dart';
import '../models/grid_tile.dart';

/// Service that slices high-resolution images into multi-post Instagram grids
/// using native C++ Skia hardware-accelerated decoding and canvas rendering.
class GridSplitterService {
  static const MethodChannel _channel = MethodChannel('com.quickpost.app/processor');

  /// Slices [sourceBytes] according to [layout] and saves tiles directly into the
  /// Android Gallery under "Pictures/Quick Post Grids".
  static Future<List<GridPostTile>> splitImage({
    required Uint8List sourceBytes,
    required GridLayoutType layout,
    double cropLeftPercent = 0.0,
    double cropTopPercent = 0.0,
    double cropWidthPercent = 1.0,
    double cropHeightPercent = 1.0,
    void Function(double progress, String status)? onProgress,
  }) async {
    onProgress?.call(0.15, 'Decoding image via hardware acceleration...');

    // 1. Hardware-accelerated decode using native Skia C++
    final codec = await ui.instantiateImageCodec(sourceBytes);
    final frame = await codec.getNextFrame();
    final ui.Image fullImage = frame.image;

    final int srcWidth = fullImage.width;
    final int srcHeight = fullImage.height;

    onProgress?.call(0.35, 'Calculating grid slices...');

    // 2. Crop bounds calculation matching layout aspect ratio
    final double targetRatio = layout.aspectRatio;
    final double currentRatio = srcWidth / srcHeight;

    double activeWidth, activeHeight, activeX, activeY;
    if (currentRatio > targetRatio) {
      // Image is wider than target layout: center crop sides
      activeHeight = srcHeight.toDouble();
      activeWidth = activeHeight * targetRatio;
      activeX = (srcWidth - activeWidth) / 2.0;
      activeY = 0.0;
    } else {
      // Image is taller than target layout: center crop top/bottom
      activeWidth = srcWidth.toDouble();
      activeHeight = activeWidth / targetRatio;
      activeX = 0.0;
      activeY = (srcHeight - activeHeight) / 2.0;
    }

    final double tileW = activeWidth / layout.cols;
    final double tileH = activeHeight / layout.rows;
    const double outTileSize = 1080.0; // High-res Instagram square standard

    final List<GridPostTile> tiles = [];
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final totalTiles = layout.totalTiles;

    Directory? fallbackDir;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      fallbackDir = Directory('${appDir.path}/quickpost_grids');
      if (!await fallbackDir.exists()) {
        await fallbackDir.create(recursive: true);
      }
    } catch (_) {}

    onProgress?.call(0.5, 'Slicing & saving tiles to Gallery...');

    int index = 0;
    for (int r = 0; r < layout.rows; r++) {
      for (int c = 0; c < layout.cols; c++) {
        final double tx = activeX + (c * tileW);
        final double ty = activeY + (r * tileH);

        // Native Skia crop & render to 1080x1080 canvas
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        final srcRect = Rect.fromLTWH(tx, ty, tileW, tileH);
        final dstRect = const Rect.fromLTWH(0, 0, outTileSize, outTileSize);
        final paint = Paint()..filterQuality = FilterQuality.high;

        canvas.drawImageRect(fullImage, srcRect, dstRect, paint);
        final picture = recorder.endRecording();
        final tileUiImage = await picture.toImage(outTileSize.toInt(), outTileSize.toInt());
        final byteData = await tileUiImage.toByteData(format: ui.ImageByteFormat.png);
        tileUiImage.dispose();

        final Uint8List pngBytes = byteData!.buffer.asUint8List();
        final postingOrder = layout.getPostingOrder(index);
        final fileName = 'GridPost_${layout.id}_${timestamp}_part_${index + 1}_postOrder_$postingOrder.png';

        // Save to Gallery via Android MediaStore (DCIM/Quick Post Grids)
        String? finalSavedPath;
        try {
          finalSavedPath = await _channel.invokeMethod<String>('saveImageToGallery', {
            'imageBytes': pngBytes,
            'filename': fileName,
            'folderName': 'DCIM/Quick Post Grids',
          });
        } catch (e) {
          debugPrint('saveImageToGallery channel error: $e');
        }

        // Trigger immediate MediaScanner update so OEM Gallery immediately shows the image
        if (finalSavedPath != null && finalSavedPath.startsWith('/')) {
          try {
            await _channel.invokeMethod('scanMediaFile', {
              'filePath': finalSavedPath,
              'mimeType': 'image/png',
            });
          } catch (_) {}
        }

        // Only fallback if MediaStore saving failed completely
        final bool mediaStoreSuccess = finalSavedPath != null &&
            (finalSavedPath.startsWith('/') || finalSavedPath.startsWith('content://'));

        if (!mediaStoreSuccess) {
          try {
            final dcimDir = Directory('/storage/emulated/0/DCIM/Quick Post Grids');
            if (!await dcimDir.exists()) {
              await dcimDir.create(recursive: true);
            }
            final dcimFile = File('${dcimDir.path}/$fileName');
            await dcimFile.writeAsBytes(pngBytes, flush: true);
            finalSavedPath = dcimFile.path;
            await _channel.invokeMethod('scanMediaFile', {
              'filePath': dcimFile.path,
              'mimeType': 'image/png',
            });
          } catch (_) {}
        }

        // Fallback to app documents directory if external DCIM fails
        if (finalSavedPath == null && fallbackDir != null) {
          try {
            final fallbackFile = File('${fallbackDir.path}/$fileName');
            await fallbackFile.writeAsBytes(pngBytes, flush: true);
            finalSavedPath = fallbackFile.path;
          } catch (_) {}
        }

        tiles.add(GridPostTile(
          tileIndex: index,
          row: r,
          col: c,
          postingOrder: postingOrder,
          totalTiles: totalTiles,
          imageBytes: pngBytes,
          savedPath: finalSavedPath,
        ));

        index++;
        final progress = 0.5 + (0.5 * (index / totalTiles));
        onProgress?.call(progress, 'Saved tile $index of $totalTiles to Gallery...');
      }
    }

    fullImage.dispose();
    onProgress?.call(1.0, 'Completed!');
    return tiles;
  }
}
