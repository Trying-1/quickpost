import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/shape_mask_model.dart';

/// Solved raster closed-region map and hardware alpha mask texture.
class SolvedMaskData {
  final ui.Image maskAlphaImage;
  final Int32List regionIds;
  final List<bool> regionVisible;
  final int gridW;
  final int gridH;

  const SolvedMaskData({
    required this.maskAlphaImage,
    required this.regionIds,
    required this.regionVisible,
    required this.gridW,
    required this.gridH,
  });

  /// Looks up the closed region ID at a normalized `(0..1, 0..1)` coordinate.
  int regionIdAt(Offset normPos) {
    final int cx = (normPos.dx * (gridW - 1)).round().clamp(1, gridW - 2);
    final int cy = (normPos.dy * (gridH - 1)).round().clamp(1, gridH - 2);
    final int centerRid = regionIds[cy * gridW + cx];
    if (centerRid > 0) return centerRid;

    for (int dy = -2; dy <= 2; dy++) {
      for (int dx = -2; dx <= 2; dx++) {
        final int nx = (cx + dx).clamp(1, gridW - 2);
        final int ny = (cy + dy).clamp(1, gridH - 2);
        final int rid = regionIds[ny * gridW + nx];
        if (rid > 0) return rid;
      }
    }
    return -1;
  }

  bool isVisibleAt(Offset normPos) {
    final int rid = regionIdAt(normPos);
    if (rid > 0 && rid < regionVisible.length) {
      return regionVisible[rid];
    }
    return false;
  }
}

/// Service powering the Shape Mask Studio:
/// - Gallery image loading & built-in demo photo generator
/// - Quick geometric stamp generators (Star, Diamond, Hexagon, Triangle, Pill)
/// - Watertight rotation-aware supercover vector rasterization & BFS closed-region solver
/// - High-res PNG capture (preserving alpha transparency) & MediaStore saving
class ShapeMaskService {
  static final ShapeMaskService _instance = ShapeMaskService._internal();
  factory ShapeMaskService() => _instance;
  ShapeMaskService._internal();

  static const MethodChannel _channel = MethodChannel('com.quickpost.app/processor');
  final ImagePicker _picker = ImagePicker();

  Future<File?> pickImage() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100,
    );
    if (picked == null) return null;
    return File(picked.path);
  }

  /// Decodes gallery image to Flutter [ui.Image] (scaled max 1600px on longest side).
  Future<ui.Image?> decodeFileToUiImage(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;

      img.Image oriented = img.bakeOrientation(decoded);
      if (oriented.width > 1600 || oriented.height > 1600) {
        if (oriented.width >= oriented.height) {
          oriented = img.copyResize(oriented, width: 1600, interpolation: img.Interpolation.linear);
        } else {
          oriented = img.copyResize(oriented, height: 1600, interpolation: img.Interpolation.linear);
        }
      }

      return await _imgToUiImage(oriented);
    } catch (e) {
      debugPrint('ShapeMaskService decode error: $e');
      return null;
    }
  }

  /// Procedural sunlit architectural demo scene.
  Future<ui.Image> generateSamplePhoto({int width = 720, int height = 900}) async {
    final img.Image canvas = img.Image(width: width, height: height);

    for (int y = 0; y < height; y++) {
      final double ny = y / height;
      for (int x = 0; x < width; x++) {
        final double nx = x / width;

        double r = 34 + ny * 215;
        double g = 88 + (1.0 - (ny - 0.55).abs()) * 115;
        double b = 175 - ny * 110;

        final double dx = nx - 0.68;
        final double dy = ny - 0.28;
        if (math.sqrt(dx * dx + dy * dy) < 0.14) {
          r = 255;
          g = 236;
          b = 175;
        }

        if (nx < 0.58 && ny > 0.38) {
          r = 225 - ny * 35;
          g = 212 - ny * 35;
          b = 198 - ny * 25;
          if (nx > 0.42) {
            r *= 0.58;
            g *= 0.68;
            b *= 0.78;
          }
          final int col = ((nx * 10).floor());
          final int row = ((ny * 12).floor());
          if (nx > 0.08 && nx < 0.36 && ny > 0.44 && ny < 0.88 && (col % 2 == 1) && (row % 2 == 1)) {
            r = 20;
            g = 90;
            b = 105;
          }
        }

        if (ny > 0.78) {
          final double wave = math.sin(nx * 24 + ny * 10) * 14;
          r = (26 + wave).clamp(0, 255);
          g = (118 + wave).clamp(0, 255);
          b = (128 + wave).clamp(0, 255);
        }

        canvas.setPixelRgba(
          x,
          y,
          r.round().clamp(0, 255),
          g.round().clamp(0, 255),
          b.round().clamp(0, 255),
          255,
        );
      }
    }

    return _imgToUiImage(canvas);
  }

  Future<ui.Image> _imgToUiImage(img.Image source) async {
    final int w = source.width;
    final int h = source.height;
    final Uint8List rgba = Uint8List(w * h * 4);
    int offset = 0;

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final p = source.getPixel(x, y);
        rgba[offset++] = p.r.toInt().clamp(0, 255);
        rgba[offset++] = p.g.toInt().clamp(0, 255);
        rgba[offset++] = p.b.toInt().clamp(0, 255);
        rgba[offset++] = p.a.toInt().clamp(0, 255);
      }
    }

    final Completer<ui.Image> completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(rgba, w, h, ui.PixelFormat.rgba8888, completer.complete);
    return completer.future;
  }

  /// Creates a centered 1-tap geometric [MaskElement] corrected for [canvasAspect].
  MaskElement buildQuickStamp({
    required String id,
    required QuickStampShape shape,
    required ShapeMaskConfig config,
    required double canvasAspect,
  }) {
    if (shape == QuickStampShape.pill) {
      return MaskElement(
        id: id,
        type: MaskElementType.rectangle,
        rect: const Rect.fromLTWH(0.18, 0.34, 0.64, 0.32),
        borderColor: config.activeBorderColor,
        borderWidth: config.activeBorderWidth,
        cornerRadius: 44.0,
        strokePattern: config.activeStrokePattern,
        dashLength: config.activeDashLength,
        dashGap: config.activeDashGap,
      );
    }

    if (shape == QuickStampShape.diamond) {
      return MaskElement(
        id: id,
        type: MaskElementType.polygon,
        points: const [
          Offset(0.50, 0.22),
          Offset(0.78, 0.50),
          Offset(0.50, 0.78),
          Offset(0.22, 0.50),
        ],
        borderColor: config.activeBorderColor,
        borderWidth: config.activeBorderWidth,
        strokePattern: config.activeStrokePattern,
        dashLength: config.activeDashLength,
        dashGap: config.activeDashGap,
      );
    }

    if (shape == QuickStampShape.triangle) {
      return MaskElement(
        id: id,
        type: MaskElementType.polygon,
        points: const [
          Offset(0.50, 0.22),
          Offset(0.80, 0.74),
          Offset(0.20, 0.74),
        ],
        borderColor: config.activeBorderColor,
        borderWidth: config.activeBorderWidth,
        strokePattern: config.activeStrokePattern,
        dashLength: config.activeDashLength,
        dashGap: config.activeDashGap,
      );
    }

    if (shape == QuickStampShape.hexagon) {
      final List<Offset> pts = [];
      const double rx = 0.28;
      final double ry = rx * canvasAspect;
      for (int i = 0; i < 6; i++) {
        final double ang = (math.pi / 3.0) * i - math.pi / 2.0;
        pts.add(Offset(0.50 + math.cos(ang) * rx, 0.50 + math.sin(ang) * ry));
      }
      return MaskElement(
        id: id,
        type: MaskElementType.polygon,
        points: pts,
        borderColor: config.activeBorderColor,
        borderWidth: config.activeBorderWidth,
        strokePattern: config.activeStrokePattern,
        dashLength: config.activeDashLength,
        dashGap: config.activeDashGap,
      );
    }

    // 5-Point Star
    final List<Offset> starPts = [];
    const double outerRx = 0.32;
    final double outerRy = outerRx * canvasAspect;
    const double innerRx = 0.14;
    final double innerRy = innerRx * canvasAspect;
    for (int i = 0; i < 10; i++) {
      final double ang = (math.pi / 5.0) * i - math.pi / 2.0;
      final double rx = i.isEven ? outerRx : innerRx;
      final double ry = i.isEven ? outerRy : innerRy;
      starPts.add(Offset(0.50 + math.cos(ang) * rx, 0.50 + math.sin(ang) * ry));
    }
    return MaskElement(
      id: id,
      type: MaskElementType.polygon,
      points: starPts,
      borderColor: config.activeBorderColor,
      borderWidth: config.activeBorderWidth,
      strokePattern: config.activeStrokePattern,
      dashLength: config.activeDashLength,
      dashGap: config.activeDashGap,
    );
  }

  /// Snaps [p2] angle relative to [p1] to nearest 45° increment when within 8°.
  Offset snapLineAngle(Offset p1, Offset p2) {
    final double dx = p2.dx - p1.dx;
    final double dy = p2.dy - p1.dy;
    final double dist = math.sqrt(dx * dx + dy * dy);
    if (dist < 0.01) return p2;

    final double angle = math.atan2(dy, dx);
    const double step = math.pi / 4.0;
    final double nearest = (angle / step).round() * step;
    if ((angle - nearest).abs() < 0.14) {
      return Offset(
        (p1.dx + math.cos(nearest) * dist).clamp(0.0, 1.0),
        (p1.dy + math.sin(nearest) * dist).clamp(0.0, 1.0),
      );
    }
    return p2;
  }

  /// Extends the infinite line passing through normalized [a] and [b] to clip cleanly
  /// against the `[0..1] x [0..1]` unit canvas box.
  ({Offset p1, Offset p2}) extendLineToCanvasEdges(Offset a, Offset b) {
    final double dx = b.dx - a.dx;
    final double dy = b.dy - a.dy;
    if (dx.abs() < 1e-5 && dy.abs() < 1e-5) {
      return (p1: a, p2: b);
    }

    final List<Offset> hits = [];
    void addIfValid(Offset pt) {
      if (pt.dx >= -1e-4 && pt.dx <= 1.0001 && pt.dy >= -1e-4 && pt.dy <= 1.0001) {
        final clamped = Offset(pt.dx.clamp(0.0, 1.0), pt.dy.clamp(0.0, 1.0));
        if (!hits.any((h) => (h - clamped).distance < 1e-3)) {
          hits.add(clamped);
        }
      }
    }

    if (dx.abs() > 1e-6) {
      final double tLeft = (0.0 - a.dx) / dx;
      addIfValid(Offset(0.0, a.dy + tLeft * dy));
      final double tRight = (1.0 - a.dx) / dx;
      addIfValid(Offset(1.0, a.dy + tRight * dy));
    }
    if (dy.abs() > 1e-6) {
      final double tTop = (0.0 - a.dy) / dy;
      addIfValid(Offset(a.dx + tTop * dx, 0.0));
      final double tBottom = (1.0 - a.dy) / dy;
      addIfValid(Offset(a.dx + tBottom * dx, 1.0));
    }

    if (hits.length >= 2) {
      return (p1: hits[0], p2: hits[1]);
    }
    return (p1: a, p2: b);
  }

  /// Solves all closed compartments bounded by rotation-aware [config.elements] + outer canvas perimeter.
  Future<SolvedMaskData> solveRegionsAndMask({
    required ShapeMaskConfig config,
    required double canvasAspect,
  }) async {
    const int gridW = 460;
    final int gridH = (gridW / canvasAspect.clamp(0.45, 2.2)).round().clamp(220, 860);
    final int total = gridW * gridH;

    final Uint8List walls = Uint8List(total);

    void mark(int x, int y) {
      if (x >= 0 && x < gridW && y >= 0 && y < gridH) {
        walls[y * gridW + x] = 1;
      }
    }

    // Pixel-space supercover line drawer
    void drawGridLine(double x0d, double y0d, double x1d, double y1d) {
      int x0 = x0d.round().clamp(0, gridW - 1);
      int y0 = y0d.round().clamp(0, gridH - 1);
      final int x1 = x1d.round().clamp(0, gridW - 1);
      final int y1 = y1d.round().clamp(0, gridH - 1);

      final int dx = (x1 - x0).abs();
      final int dy = (y1 - y0).abs();
      final int sx = x0 < x1 ? 1 : -1;
      final int sy = y0 < y1 ? 1 : -1;
      int err = dx - dy;

      mark(x0, y0);
      while (x0 != x1 || y0 != y1) {
        final int e2 = 2 * err;
        final int prevX = x0;
        final int prevY = y0;
        bool movedX = false;
        bool movedY = false;

        if (e2 > -dy) {
          err -= dy;
          x0 += sx;
          movedX = true;
        }
        if (e2 < dx) {
          err += dx;
          y0 += sy;
          movedY = true;
        }

        if (movedX && movedY) {
          mark(x0, prevY);
          mark(prevX, y0);
        }
        mark(x0, y0);
      }
    }

    // Rotate normalized point around normalized center inside isotropic pixel grid space
    Offset toGridRotated(Offset normPt, Offset normCenter, double cosA, double sinA) {
      final double px = normPt.dx * (gridW - 1);
      final double py = normPt.dy * (gridH - 1);
      if (cosA == 1.0 && sinA == 0.0) return Offset(px, py);

      final double cx = normCenter.dx * (gridW - 1);
      final double cy = normCenter.dy * (gridH - 1);
      final double dx = px - cx;
      final double dy = py - cy;
      return Offset(cx + dx * cosA - dy * sinA, cy + dx * sinA + dy * cosA);
    }

    // 1. Canvas perimeter walls
    for (int x = 0; x < gridW; x++) {
      walls[x] = 1;
      walls[(gridH - 1) * gridW + x] = 1;
    }
    for (int y = 0; y < gridH; y++) {
      walls[y * gridW] = 1;
      walls[y * gridW + (gridW - 1)] = 1;
    }

    // 2. Rasterize all elements in isotropic grid coordinates
    for (final el in config.elements) {
      final double rad = el.rotationDeg * math.pi / 180.0;
      final double cosA = el.rotationDeg.abs() < 0.01 ? 1.0 : math.cos(rad);
      final double sinA = el.rotationDeg.abs() < 0.01 ? 0.0 : math.sin(rad);
      final Offset center = el.normalizedCenter;

      switch (el.type) {
        case MaskElementType.line:
          if (el.p1 != null && el.p2 != null) {
            final a = toGridRotated(el.p1!, center, cosA, sinA);
            final b = toGridRotated(el.p2!, center, cosA, sinA);
            drawGridLine(a.dx, a.dy, b.dx, b.dy);
          }
          break;

        case MaskElementType.rectangle:
          if (el.rect != null) {
            final Rect r = el.rect!;
            final List<Offset> pts = [];
            if (el.cornerRadius <= 1.0) {
              pts.addAll([r.topLeft, r.topRight, r.bottomRight, r.bottomLeft]);
            } else {
              // Match Skia RRect isotropic radius clamping in 360px physical coordinates
              final double maxPxR = math.min(r.width * 360.0, (r.height * 360.0) / canvasAspect) * 0.49;
              final double clampedPx = el.cornerRadius.clamp(0.0, math.max(0.0, maxPxR));
              final double rx = clampedPx / 360.0;
              final double ry = (clampedPx * canvasAspect) / 360.0;
              const int arcSteps = 10;

              void addArc(Offset arcCenter, double startAngle) {
                for (int i = 0; i <= arcSteps; i++) {
                  final double ang = startAngle + (math.pi / 2.0) * (i / arcSteps);
                  pts.add(Offset(arcCenter.dx + math.cos(ang) * rx, arcCenter.dy + math.sin(ang) * ry));
                }
              }

              addArc(Offset(r.right - rx, r.top + ry), -math.pi / 2);
              addArc(Offset(r.right - rx, r.bottom - ry), 0);
              addArc(Offset(r.left + rx, r.bottom - ry), math.pi / 2);
              addArc(Offset(r.left + rx, r.top + ry), math.pi);
            }

            for (int i = 0; i < pts.length; i++) {
              final a = toGridRotated(pts[i], center, cosA, sinA);
              final b = toGridRotated(pts[(i + 1) % pts.length], center, cosA, sinA);
              drawGridLine(a.dx, a.dy, b.dx, b.dy);
            }
          }
          break;

        case MaskElementType.circle:
        case MaskElementType.arc:
          if (el.rect != null && (el.type == MaskElementType.circle || el.arcCloseMaskRegion)) {
            final Rect r = el.rect!;
            final Offset rc = r.center;
            final double rx = r.width / 2.0;
            final double ry = r.height / 2.0;
            const int segments = 72;
            Offset prev = toGridRotated(Offset(rc.dx + rx, rc.dy), center, cosA, sinA);
            for (int i = 1; i <= segments; i++) {
              final double theta = (2 * math.pi * i) / segments;
              final Offset curr = toGridRotated(
                Offset(rc.dx + math.cos(theta) * rx, rc.dy + math.sin(theta) * ry),
                center,
                cosA,
                sinA,
              );
              drawGridLine(prev.dx, prev.dy, curr.dx, curr.dy);
              prev = curr;
            }
          }
          break;

        case MaskElementType.polygon:
          for (final loop in el.allPolygonLoops) {
            if (loop.length >= 2) {
              for (int i = 0; i < loop.length; i++) {
                final a = toGridRotated(loop[i], center, cosA, sinA);
                final b = toGridRotated(loop[(i + 1) % loop.length], center, cosA, sinA);
                drawGridLine(a.dx, a.dy, b.dx, b.dy);
              }
            }
          }
          break;
      }
    }

    // 3. Connected-component 4-way BFS flood fill
    final Int32List regionIds = Int32List(total);
    final Int32List queue = Int32List(total);
    int nextRegionId = 1;

    for (int i = 0; i < total; i++) {
      if (walls[i] == 1) {
        regionIds[i] = -1;
        continue;
      }
      if (regionIds[i] != 0) continue;

      final int rid = nextRegionId++;
      int head = 0;
      int tail = 0;
      regionIds[i] = rid;
      queue[tail++] = i;

      while (head < tail) {
        final int cur = queue[head++];
        final int cx = cur % gridW;
        final int cy = cur ~/ gridW;

        if (cx + 1 < gridW) {
          final int n = cur + 1;
          if (walls[n] == 0 && regionIds[n] == 0) {
            regionIds[n] = rid;
            queue[tail++] = n;
          }
        }
        if (cx - 1 >= 0) {
          final int n = cur - 1;
          if (walls[n] == 0 && regionIds[n] == 0) {
            regionIds[n] = rid;
            queue[tail++] = n;
          }
        }
        if (cy + 1 < gridH) {
          final int n = cur + gridW;
          if (walls[n] == 0 && regionIds[n] == 0) {
            regionIds[n] = rid;
            queue[tail++] = n;
          }
        }
        if (cy - 1 >= 0) {
          final int n = cur - gridW;
          if (walls[n] == 0 && regionIds[n] == 0) {
            regionIds[n] = rid;
            queue[tail++] = n;
          }
        }
      }
    }

    // 4. Evaluate visibility from seeds
    final List<bool> regionVisible = List<bool>.filled(nextRegionId, config.defaultRevealImage);
    for (final seed in config.regionSeeds) {
      final int sx = (seed.normPos.dx * (gridW - 1)).round().clamp(1, gridW - 2);
      final int sy = (seed.normPos.dy * (gridH - 1)).round().clamp(1, gridH - 2);
      int rid = regionIds[sy * gridW + sx];
      if (rid <= 0) {
        for (int dy = -2; dy <= 2 && rid <= 0; dy++) {
          for (int dx = -2; dx <= 2 && rid <= 0; dx++) {
            final int nx = (sx + dx).clamp(1, gridW - 2);
            final int ny = (sy + dy).clamp(1, gridH - 2);
            final int candidate = regionIds[ny * gridW + nx];
            if (candidate > 0) rid = candidate;
          }
        }
      }
      if (rid > 0 && rid < regionVisible.length) {
        regionVisible[rid] = seed.showImage;
      }
    }

    // 5. Generate RGBA mask bitmap
    final Uint8List maskRgba = Uint8List(total * 4);
    for (int y = 0; y < gridH; y++) {
      for (int x = 0; x < gridW; x++) {
        final int idx = y * gridW + x;
        final int rid = regionIds[idx];
        bool isVis = false;

        if (rid > 0) {
          isVis = regionVisible[rid];
        } else {
          if (x + 1 < gridW && regionIds[idx + 1] > 0 && regionVisible[regionIds[idx + 1]]) {
            isVis = true;
          } else if (x - 1 >= 0 && regionIds[idx - 1] > 0 && regionVisible[regionIds[idx - 1]]) {
            isVis = true;
          } else if (y + 1 < gridH && regionIds[idx + gridW] > 0 && regionVisible[regionIds[idx + gridW]]) {
            isVis = true;
          } else if (y - 1 >= 0 && regionIds[idx - gridW] > 0 && regionVisible[regionIds[idx - gridW]]) {
            isVis = true;
          }
        }

        final int out = idx * 4;
        maskRgba[out] = 255;
        maskRgba[out + 1] = 255;
        maskRgba[out + 2] = 255;
        maskRgba[out + 3] = isVis ? 255 : 0;
      }
    }

    final Completer<ui.Image> completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(maskRgba, gridW, gridH, ui.PixelFormat.rgba8888, completer.complete);
    final ui.Image alphaImg = await completer.future;

    return SolvedMaskData(
      maskAlphaImage: alphaImg,
      regionIds: regionIds,
      regionVisible: regionVisible,
      gridW: gridW,
      gridH: gridH,
    );
  }

  /// Rotation-aware hit-test in reverse draw order for Select & Move tool.
  MaskElement? hitTestElement(List<MaskElement> elements, Offset normPos, {double canvasAspect = 0.8}) {
    const double lineTolerance = 0.045;
    for (int i = elements.length - 1; i >= 0; i--) {
      final el = elements[i];

      // Inverse-rotate test point around normalizedCenter when rotated
      Offset testPt = normPos;
      if (el.rotationDeg.abs() > 0.1) {
        final c = el.normalizedCenter;
        final rad = -el.rotationDeg * math.pi / 180.0;
        final dx = normPos.dx - c.dx;
        final dy = (normPos.dy - c.dy) / canvasAspect;
        final rx = dx * math.cos(rad) - dy * math.sin(rad);
        final ry = (dx * math.sin(rad) + dy * math.cos(rad)) * canvasAspect;
        testPt = Offset(c.dx + rx, c.dy + ry);
      }

      if (el.type == MaskElementType.rectangle ||
          el.type == MaskElementType.circle ||
          el.type == MaskElementType.arc) {
        if (el.rect != null && el.rect!.inflate(0.025).contains(testPt)) {
          return el;
        }
      } else if (el.type == MaskElementType.line && el.p1 != null && el.p2 != null) {
        final double dist = _distancePointToSegment(testPt, el.p1!, el.p2!);
        if (dist <= lineTolerance) return el;
      } else if (el.type == MaskElementType.polygon) {
        for (final loop in el.allPolygonLoops) {
          if (loop.length >= 3 && _pointInPolygon(testPt, loop)) return el;
        }
      }
    }
    return null;
  }

  /// Computes a normalized bounding [Rect] representing a mathematically true circle
  /// centered at [centerNorm] with radius equal to distance to [edgeNorm] in physical aspect space.
  Rect buildPerfectCircleRect(Offset centerNorm, Offset edgeNorm, double canvasAspect) {
    final double dx = edgeNorm.dx - centerNorm.dx;
    final double dy = (edgeNorm.dy - centerNorm.dy) / canvasAspect;
    final double radiusX = math.sqrt(dx * dx + dy * dy);
    final double radiusY = radiusX * canvasAspect;

    return Rect.fromCenter(
      center: centerNorm,
      width: (radiusX * 2.0).clamp(0.02, 1.4),
      height: (radiusY * 2.0).clamp(0.02, 1.4),
    );
  }

  /// Merges 2+ closed vector shapes (`rectangle`, `circle`, `polygon`) into a single unified
  /// contour element using native Skia `Path.combine(PathOperation.union, ...)`.
  MaskElement? mergeElements(
    List<MaskElement> targets, {
    required double canvasAspect,
    required String newId,
  }) {
    final closedShapes = targets.where((e) => e.type != MaskElementType.line).toList();
    if (closedShapes.length < 2) return null;

    const double refW = 360.0;
    final double refH = (refW / canvasAspect.clamp(0.45, 2.2));

    Path toPhysicalPath(MaskElement el) {
      final Path p = Path();
      if (el.type == MaskElementType.rectangle && el.rect != null) {
        final Rect r = Rect.fromLTRB(
          el.rect!.left * refW,
          el.rect!.top * refH,
          el.rect!.right * refW,
          el.rect!.bottom * refH,
        );
        if (el.cornerRadius > 0.5) {
          p.addRRect(RRect.fromRectAndRadius(r, Radius.circular(el.cornerRadius)));
        } else {
          p.addRect(r);
        }
      } else if ((el.type == MaskElementType.circle || el.type == MaskElementType.arc) && el.rect != null) {
        p.addOval(Rect.fromLTRB(
          el.rect!.left * refW,
          el.rect!.top * refH,
          el.rect!.right * refW,
          el.rect!.bottom * refH,
        ));
      } else if (el.type == MaskElementType.polygon) {
        for (final loop in el.allPolygonLoops) {
          if (loop.length >= 3) {
            p.moveTo(loop.first.dx * refW, loop.first.dy * refH);
            for (int i = 1; i < loop.length; i++) {
              p.lineTo(loop[i].dx * refW, loop[i].dy * refH);
            }
            p.close();
          }
        }
      }

      if (el.rotationDeg.abs() > 0.05) {
        final Offset c = el.normalizedCenter;
        final double cx = c.dx * refW;
        final double cy = c.dy * refH;
        final Matrix4 m = Matrix4.identity()
          ..translateByDouble(cx, cy, 0.0, 1.0)
          ..rotateZ(el.rotationDeg * math.pi / 180.0)
          ..translateByDouble(-cx, -cy, 0.0, 1.0);
        return p.transform(m.storage);
      }
      return p;
    }

    Path unionPath = toPhysicalPath(closedShapes.first);
    for (int i = 1; i < closedShapes.length; i++) {
      unionPath = Path.combine(PathOperation.union, unionPath, toPhysicalPath(closedShapes[i]));
    }

    final List<List<Offset>> sampledLoops = [];
    for (final ui.PathMetric metric in unionPath.computeMetrics()) {
      if (metric.length < 4.0) continue;
      final int steps = (metric.length / 4.5).round().clamp(16, 160);
      final List<Offset> pts = [];
      for (int s = 0; s < steps; s++) {
        final tangent = metric.getTangentForOffset((metric.length * s) / steps);
        if (tangent != null) {
          pts.add(Offset(
            (tangent.position.dx / refW).clamp(0.0, 1.0),
            (tangent.position.dy / refH).clamp(0.0, 1.0),
          ));
        }
      }
      if (pts.length >= 3) sampledLoops.add(pts);
    }

    if (sampledLoops.isEmpty) return null;

    final primary = closedShapes.first;
    return MaskElement(
      id: newId,
      type: MaskElementType.polygon,
      points: sampledLoops.first,
      extraPolygons: sampledLoops.length > 1 ? sampledLoops.sublist(1) : const [],
      borderColor: primary.borderColor,
      borderWidth: primary.borderWidth,
      strokePattern: primary.strokePattern,
      dashLength: primary.dashLength,
      dashGap: primary.dashGap,
    );
  }

  double _distancePointToSegment(Offset p, Offset a, Offset b) {
    final Offset ab = b - a;
    final double lenSq = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lenSq < 1e-8) return (p - a).distance;
    final double t = (((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / lenSq).clamp(0.0, 1.0);
    final Offset proj = Offset(a.dx + t * ab.dx, a.dy + t * ab.dy);
    return (p - proj).distance;
  }

  bool _pointInPolygon(Offset p, List<Offset> poly) {
    bool inside = false;
    for (int i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      final pi = poly[i];
      final pj = poly[j];
      final bool intersect = ((pi.dy > p.dy) != (pj.dy > p.dy)) &&
          (p.dx < (pj.dx - pi.dx) * (p.dy - pi.dy) / ((pj.dy - pi.dy) + 1e-9) + pi.dx);
      if (intersect) inside = !inside;
    }
    return inside;
  }

  /// Captures the RepaintBoundary at 3.2x resolution preserving alpha when transparent.
  Future<Uint8List?> captureBoundary(GlobalKey boundaryKey, {double pixelRatio = 3.2}) async {
    try {
      final RenderRepaintBoundary? boundary =
          boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('ShapeMaskService captureBoundary error: $e');
      return null;
    }
  }

  /// Saves the shape mask graphic into Android MediaStore under "Pictures/Quick Post Shape Masks".
  Future<String?> saveShapeMaskToGallery(Uint8List pngBytes, String tagName) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeName = tagName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase();
    final fileName = 'QuickPostMask_${safeName}_$timestamp.png';

    String? finalSavedPath;
    try {
      finalSavedPath = await _channel.invokeMethod<String>('saveImageToGallery', {
        'imageBytes': pngBytes,
        'filename': fileName,
        'folderName': 'Pictures/Quick Post Shape Masks',
      });
    } catch (e) {
      debugPrint('saveImageToGallery channel error: $e');
    }

    if (finalSavedPath != null && finalSavedPath.startsWith('/')) {
      try {
        await _channel.invokeMethod('scanMediaFile', {
          'filePath': finalSavedPath,
          'mimeType': 'image/png',
        });
      } catch (_) {}
    }

    final bool mediaStoreSuccess = finalSavedPath != null &&
        (finalSavedPath.startsWith('/') || finalSavedPath.startsWith('content://'));

    if (!mediaStoreSuccess) {
      try {
        final dcimDir = Directory('/storage/emulated/0/Pictures/Quick Post Shape Masks');
        if (!await dcimDir.exists()) {
          await dcimDir.create(recursive: true);
        }
        final file = File('${dcimDir.path}/$fileName');
        await file.writeAsBytes(pngBytes, flush: true);
        finalSavedPath = file.path;

        await _channel.invokeMethod('scanMediaFile', {
          'filePath': file.path,
          'mimeType': 'image/png',
        });
      } catch (_) {}
    }

    if (finalSavedPath == null) {
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final file = File('${appDir.path}/$fileName');
        await file.writeAsBytes(pngBytes, flush: true);
        finalSavedPath = file.path;
      } catch (_) {}
    }

    return finalSavedPath;
  }

  Future<void> shareShapeMask(String filePath) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(filePath, mimeType: 'image/png')],
          text: 'Created with QuickPost Shape Mask Studio',
        ),
      );
    } catch (e) {
      debugPrint('Share shape mask error: $e');
    }
  }
}
