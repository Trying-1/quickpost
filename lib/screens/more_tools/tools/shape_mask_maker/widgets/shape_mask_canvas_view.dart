import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/shape_mask_model.dart';
import '../services/shape_mask_service.dart';

/// Interactive zero-overflow proportional Shape Mask Canvas.
/// Supports B&W Color Pop, Frosted Blur, Solid/Gradient Matte, Transparent PNG cutouts,
/// rotation-aware vector shapes & divider lines, rule-of-thirds alignment guides, and Peek Original.
class ShapeMaskCanvasView extends StatelessWidget {
  final GlobalKey boundaryKey;
  final ui.Image? photoImage;
  final SolvedMaskData? solvedMask;
  final ShapeMaskConfig config;
  final ShapeMaskTool activeTool;
  final Set<String> selectedElementIds;
  final bool hideEditorOverlays;
  final bool isPeekingOriginal;

  // Live in-progress drawing previews (normalized 0..1)
  final Rect? draftRect;
  final Offset? draftLineStart;
  final Offset? draftLineEnd;
  final List<Offset> draftPolygonPoints;

  // Normalized interactive callbacks
  final ValueChanged<Offset>? onTapCanvas;
  final ValueChanged<Offset>? onDragStartCanvas;
  final ValueChanged<Offset>? onDragUpdateCanvas;
  final VoidCallback? onDragEndCanvas;

  const ShapeMaskCanvasView({
    super.key,
    required this.boundaryKey,
    required this.photoImage,
    required this.solvedMask,
    required this.config,
    required this.activeTool,
    this.selectedElementIds = const {},
    this.hideEditorOverlays = false,
    this.isPeekingOriginal = false,
    this.draftRect,
    this.draftLineStart,
    this.draftLineEnd,
    this.draftPolygonPoints = const [],
    this.onTapCanvas,
    this.onDragStartCanvas,
    this.onDragUpdateCanvas,
    this.onDragEndCanvas,
  });

  double _effectiveAspectRatio() {
    if (config.aspectRatio.ratio != null) {
      return config.aspectRatio.ratio!;
    }
    if (photoImage != null && photoImage!.height > 0) {
      return (photoImage!.width / photoImage!.height).clamp(0.45, 2.2);
    }
    return 4.0 / 5.0;
  }

  @override
  Widget build(BuildContext context) {
    if (photoImage == null) {
      return const Center(child: CircularProgressIndicator());
    }

    const double refWidth = 360.0;
    final double ratio = _effectiveAspectRatio();
    final double refHeight = (refWidth / ratio).clamp(160.0, 720.0);

    Offset toNorm(Offset local) => Offset(
          (local.dx / refWidth).clamp(0.0, 1.0),
          (local.dy / refHeight).clamp(0.0, 1.0),
        );

    return FittedBox(
      fit: BoxFit.contain,
      child: GestureDetector(
        onTapUp: onTapCanvas != null ? (d) => onTapCanvas!(toNorm(d.localPosition)) : null,
        onPanStart: onDragStartCanvas != null ? (d) => onDragStartCanvas!(toNorm(d.localPosition)) : null,
        onPanUpdate: onDragUpdateCanvas != null ? (d) => onDragUpdateCanvas!(toNorm(d.localPosition)) : null,
        onPanEnd: onDragEndCanvas != null ? (_) => onDragEndCanvas!() : null,
        child: Container(
          width: refWidth,
          height: refHeight,
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (config.backdropStyle == MaskBackdropStyle.transparentCutout && !isPeekingOriginal)
                const CustomPaint(painter: _CheckerboardPainter()),

              RepaintBoundary(
                key: boundaryKey,
                child: ClipRect(
                  child: CustomPaint(
                    size: Size(refWidth, refHeight),
                    painter: _ShapeMaskPainter(
                      photoImage: photoImage!,
                      solvedMask: solvedMask,
                      config: config,
                      activeTool: activeTool,
                      selectedElementIds: hideEditorOverlays ? const {} : selectedElementIds,
                      hideEditorOverlays: hideEditorOverlays,
                      isPeekingOriginal: isPeekingOriginal,
                      draftRect: draftRect,
                      draftLineStart: draftLineStart,
                      draftLineEnd: draftLineEnd,
                      draftPolygonPoints: draftPolygonPoints,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renders matte/blur/B&W-pop backdrop + masked photo cutouts + shadows + vector borders + guides.
class _ShapeMaskPainter extends CustomPainter {
  final ui.Image photoImage;
  final SolvedMaskData? solvedMask;
  final ShapeMaskConfig config;
  final ShapeMaskTool activeTool;
  final Set<String> selectedElementIds;
  final bool hideEditorOverlays;
  final bool isPeekingOriginal;
  final Rect? draftRect;
  final Offset? draftLineStart;
  final Offset? draftLineEnd;
  final List<Offset> draftPolygonPoints;

  static const List<double> _grayscaleMatrix = [
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ];

  _ShapeMaskPainter({
    required this.photoImage,
    required this.solvedMask,
    required this.config,
    required this.activeTool,
    this.selectedElementIds = const {},
    required this.hideEditorOverlays,
    required this.isPeekingOriginal,
    this.draftRect,
    this.draftLineStart,
    this.draftLineEnd,
    this.draftPolygonPoints = const [],
  });

  void _drawTransformedPhoto(Canvas canvas, Size size, Paint paint) {
    final double imgW = photoImage.width.toDouble();
    final double imgH = photoImage.height.toDouble();
    final double imgAspect = imgW / imgH;
    final double dstAspect = size.width / size.height;

    double coverW, coverH;
    if (imgAspect > dstAspect) {
      coverH = size.height;
      coverW = size.height * imgAspect;
    } else {
      coverW = size.width;
      coverH = size.width / imgAspect;
    }

    final double scaledW = coverW * config.imageScale;
    final double scaledH = coverH * config.imageScale;
    final double dx = (size.width - scaledW) / 2.0 + (config.imageOffset.dx * size.width);
    final double dy = (size.height - scaledH) / 2.0 + (config.imageOffset.dy * size.height);

    canvas.drawImageRect(
      photoImage,
      Rect.fromLTWH(0, 0, imgW, imgH),
      Rect.fromLTWH(dx, dy, scaledW, scaledH),
      paint,
    );
  }

  Rect _denormRect(Rect r, Size size) => Rect.fromLTRB(
        r.left * size.width,
        r.top * size.height,
        r.right * size.width,
        r.bottom * size.height,
      );

  Offset _denormOffset(Offset o, Size size) => Offset(o.dx * size.width, o.dy * size.height);

  Path _buildElementPath(MaskElement el, Size size) {
    final Path path = Path();
    switch (el.type) {
      case MaskElementType.rectangle:
        if (el.rect != null) {
          final Rect r = _denormRect(el.rect!, size);
          if (el.cornerRadius > 0.5) {
            path.addRRect(RRect.fromRectAndRadius(r, Radius.circular(el.cornerRadius)));
          } else {
            path.addRect(r);
          }
        }
        break;
      case MaskElementType.circle:
        if (el.rect != null) {
          path.addOval(_denormRect(el.rect!, size));
        }
        break;
      case MaskElementType.arc:
        if (el.rect != null) {
          final Rect r = _denormRect(el.rect!, size);
          final int count = el.arcCount.clamp(1, 12);
          final double slotAngle = (2 * math.pi) / count;
          final double sweepAngle = slotAngle * el.arcSweepRatio.clamp(0.15, 0.96);
          for (int i = 0; i < count; i++) {
            final double startAngle = (i * slotAngle) - (sweepAngle / 2);
            path.addArc(r, startAngle, sweepAngle);
          }
        }
        break;
      case MaskElementType.line:
        if (el.p1 != null && el.p2 != null) {
          final a = _denormOffset(el.p1!, size);
          final b = _denormOffset(el.p2!, size);
          path.moveTo(a.dx, a.dy);
          path.lineTo(b.dx, b.dy);
        }
        break;
      case MaskElementType.polygon:
        for (final loop in el.allPolygonLoops) {
          if (loop.isNotEmpty) {
            final first = _denormOffset(loop.first, size);
            path.moveTo(first.dx, first.dy);
            for (int i = 1; i < loop.length; i++) {
              final pt = _denormOffset(loop[i], size);
              path.lineTo(pt.dx, pt.dy);
            }
            path.close();
          }
        }
        break;
    }
    return path;
  }

  void _drawPatternedPath(
    Canvas canvas,
    Path path,
    Paint strokePaint,
    MaskStrokePattern pattern,
    double dashLen,
    double dashGap,
  ) {
    if (pattern == MaskStrokePattern.solid) {
      canvas.drawPath(path, strokePaint);
      return;
    }

    final double safeDash = dashLen.clamp(2.0, 48.0);
    final double safeGap = dashGap.clamp(2.0, 48.0);
    final Paint dotPaint = Paint()
      ..color = strokePaint.color
      ..style = PaintingStyle.fill;
    final double dotRadius = math.max(1.0, strokePaint.strokeWidth * 0.5);

    if (pattern == MaskStrokePattern.dotted) {
      final double step = safeGap + strokePaint.strokeWidth;
      for (final ui.PathMetric metric in path.computeMetrics()) {
        double distance = 0.0;
        while (distance <= metric.length) {
          final tangent = metric.getTangentForOffset(distance);
          if (tangent != null) {
            canvas.drawCircle(tangent.position, dotRadius, dotPaint);
          }
          distance += step;
        }
      }
      return;
    }

    if (pattern == MaskStrokePattern.dashDot) {
      for (final ui.PathMetric metric in path.computeMetrics()) {
        double distance = 0.0;
        while (distance < metric.length) {
          final double nextDash = math.min(distance + safeDash, metric.length);
          canvas.drawPath(metric.extractPath(distance, nextDash), strokePaint);
          distance = nextDash + safeGap;
          if (distance <= metric.length) {
            final tangent = metric.getTangentForOffset(distance);
            if (tangent != null) {
              canvas.drawCircle(tangent.position, dotRadius, dotPaint);
            }
            distance += safeGap + strokePaint.strokeWidth;
          }
        }
      }
      return;
    }

    // Dashed
    for (final ui.PathMetric metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final double next = math.min(distance + safeDash, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), strokePaint);
        distance = next + safeGap;
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Rect canvasRect = Offset.zero & size;

    // Interactive Peek Original Photo mode
    if (isPeekingOriginal) {
      _drawTransformedPhoto(canvas, size, Paint()..filterQuality = FilterQuality.high);
      return;
    }

    // ─── LAYER 1: Unmasked Backdrop / Matte Layer ───
    switch (config.backdropStyle) {
      case MaskBackdropStyle.solidWhite:
        canvas.drawRect(canvasRect, Paint()..color = Colors.white);
        break;
      case MaskBackdropStyle.solidBlack:
        canvas.drawRect(canvasRect, Paint()..color = const Color(0xFF0B0F17));
        break;
      case MaskBackdropStyle.gradientMatte:
        canvas.drawRect(
          canvasRect,
          Paint()
            ..shader = const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF004D40), Color(0xFF00796B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(canvasRect),
        );
        break;
      case MaskBackdropStyle.customColor:
        canvas.drawRect(canvasRect, Paint()..color = config.customBackdropColor);
        break;
      case MaskBackdropStyle.dimmedDark:
        _drawTransformedPhoto(canvas, size, Paint()..filterQuality = FilterQuality.medium);
        canvas.drawRect(
          canvasRect,
          Paint()..color = Colors.black.withValues(alpha: config.backdropIntensity.clamp(0.15, 0.96)),
        );
        break;
      case MaskBackdropStyle.bwColorPop:
        _drawTransformedPhoto(
          canvas,
          size,
          Paint()
            ..filterQuality = FilterQuality.medium
            ..colorFilter = const ColorFilter.matrix(_grayscaleMatrix),
        );
        final double extraDim = ((config.backdropIntensity - 0.5) * 0.6).clamp(0.0, 0.45);
        if (extraDim > 0.01) {
          canvas.drawRect(canvasRect, Paint()..color = Colors.black.withValues(alpha: extraDim));
        }
        break;
      case MaskBackdropStyle.frostedBlur:
        final double sigma = (config.backdropIntensity * 22.0).clamp(2.0, 24.0);
        canvas.saveLayer(canvasRect, Paint());
        _drawTransformedPhoto(
          canvas,
          size,
          Paint()
            ..filterQuality = FilterQuality.medium
            ..imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.clamp),
        );
        canvas.drawRect(
          canvasRect,
          Paint()..color = Colors.black.withValues(alpha: 0.14),
        );
        canvas.restore();
        break;
      case MaskBackdropStyle.transparentCutout:
        break;
    }

    // ─── LAYER 2: Revealed Closed-Area Photo Cutout Windows + Soft Elevation Shadow ───
    if (solvedMask != null) {
      final ui.Image maskImg = solvedMask!.maskAlphaImage;
      final Rect maskSrc = Rect.fromLTWH(0, 0, maskImg.width.toDouble(), maskImg.height.toDouble());

      // Optional subtle paper-cut elevation shadow behind revealed compartments
      if (config.enableWindowShadow && config.backdropStyle != MaskBackdropStyle.transparentCutout) {
        canvas.save();
        canvas.translate(0, 4);
        canvas.drawImageRect(
          maskImg,
          maskSrc,
          canvasRect,
          Paint()
            ..colorFilter = ColorFilter.mode(Colors.black.withValues(alpha: 0.28), BlendMode.srcIn)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0)
            ..filterQuality = FilterQuality.low,
        );
        canvas.restore();
      }

      canvas.saveLayer(canvasRect, Paint());
      _drawTransformedPhoto(canvas, size, Paint()..filterQuality = FilterQuality.high);
      canvas.drawImageRect(
        maskImg,
        maskSrc,
        canvasRect,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..filterQuality = FilterQuality.medium,
      );
      canvas.restore();
    }

    // ─── LAYER 3: Crisp Vector Borders for All Shapes & Divider Lines ───
    for (final el in config.elements) {
      if (el.borderWidth <= 0.05) continue;
      final Path path = _buildElementPath(el, size);
      final Paint strokePaint = Paint()
        ..color = el.borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = el.borderWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final bool isRotated = el.rotationDeg.abs() > 0.05;
      if (isRotated) {
        final c = _denormOffset(el.normalizedCenter, size);
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.rotate(el.rotationDeg * math.pi / 180.0);
        canvas.translate(-c.dx, -c.dy);
      }

      _drawPatternedPath(
        canvas,
        path,
        strokePaint,
        el.strokePattern,
        el.dashLength,
        el.dashGap,
      );

      if (isRotated) canvas.restore();
    }

    // ─── LAYER 3.5: Optional Outer Gallery Frame Border ───
    if (config.outerFrameWidth > 0.5) {
      final double fw = config.outerFrameWidth;
      canvas.drawRect(
        Rect.fromLTWH(fw / 2, fw / 2, size.width - fw, size.height - fw),
        Paint()
          ..color = config.outerFrameColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = fw,
      );
    }

    if (hideEditorOverlays) return;

    // ─── LAYER 4: Alignment Guides, Handles (NO dashed selection box), & Live Drafts ───
    if (config.showAlignGuides) {
      final Paint guidePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..strokeWidth = 0.8;
      // Rule-of-thirds & center guides
      canvas.drawLine(Offset(size.width / 3, 0), Offset(size.width / 3, size.height), guidePaint);
      canvas.drawLine(Offset(size.width * 2 / 3, 0), Offset(size.width * 2 / 3, size.height), guidePaint);
      canvas.drawLine(Offset(0, size.height / 3), Offset(size.width, size.height / 3), guidePaint);
      canvas.drawLine(Offset(0, size.height * 2 / 3), Offset(size.width, size.height * 2 / 3), guidePaint);
    }

    // Subtle corner resize / center multi-select dots ONLY in Select & Move mode (zero dashed boxes)
    if (selectedElementIds.isNotEmpty && activeTool == ShapeMaskTool.selectMove) {
      final bool isMulti = selectedElementIds.length > 1;
      for (final el in config.elements) {
        if (!selectedElementIds.contains(el.id)) continue;

        final bool isRotated = el.rotationDeg.abs() > 0.05;
        if (isRotated) {
          final c = _denormOffset(el.normalizedCenter, size);
          canvas.save();
          canvas.translate(c.dx, c.dy);
          canvas.rotate(el.rotationDeg * math.pi / 180.0);
          canvas.translate(-c.dx, -c.dy);
        }

        if (isMulti) {
          // Small center indicator dot per selected element so group/multi-selection is clear
          final cPx = _denormOffset(el.normalizedCenter, size);
          canvas.drawCircle(cPx, 6.5, Paint()..color = Colors.white);
          canvas.drawCircle(cPx, 4.5, Paint()..color = const Color(0xFF00796B));
        } else if (el.rect != null) {
          final br = _denormOffset(el.rect!.bottomRight, size);
          canvas.drawCircle(br, 7.5, Paint()..color = Colors.white);
          canvas.drawCircle(br, 5.5, Paint()..color = const Color(0xFF00796B));
        } else if (el.p1 != null && el.p2 != null) {
          final a = _denormOffset(el.p1!, size);
          final b = _denormOffset(el.p2!, size);
          for (final pt in [a, b]) {
            canvas.drawCircle(pt, 7.0, Paint()..color = Colors.white);
            canvas.drawCircle(pt, 5.0, Paint()..color = const Color(0xFF00796B));
          }
        } else {
          final cPx = _denormOffset(el.normalizedCenter, size);
          canvas.drawCircle(cPx, 6.5, Paint()..color = Colors.white);
          canvas.drawCircle(cPx, 4.5, Paint()..color = const Color(0xFF00796B));
        }

        if (isRotated) canvas.restore();
      }
    }

    // Live Draft Rect / Circle
    if (draftRect != null) {
      final Rect dr = _denormRect(draftRect!, size);
      final Paint draftPaint = Paint()
        ..color = config.activeBorderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2.0, config.activeBorderWidth);
      final Paint fillHint = Paint()
        ..color = const Color(0xFF00796B).withValues(alpha: 0.22)
        ..style = PaintingStyle.fill;

      if (activeTool == ShapeMaskTool.circle) {
        canvas.drawOval(dr, fillHint);
        canvas.drawOval(dr, draftPaint);
      } else if (activeTool == ShapeMaskTool.arc) {
        final int count = config.activeArcCount.clamp(1, 12);
        final double slot = (2 * math.pi) / count;
        final double sweep = slot * config.activeArcSweepRatio.clamp(0.15, 0.96);
        final Path arcDraft = Path();
        for (int i = 0; i < count; i++) {
          arcDraft.addArc(dr, (i * slot) - (sweep / 2), sweep);
        }
        _drawPatternedPath(
          canvas,
          arcDraft,
          draftPaint..strokeCap = StrokeCap.round,
          config.activeStrokePattern,
          config.activeDashLength,
          config.activeDashGap,
        );
      } else {
        final rrect = RRect.fromRectAndRadius(dr, Radius.circular(config.activeCornerRadius));
        canvas.drawRRect(rrect, fillHint);
        canvas.drawRRect(rrect, draftPaint);
      }
    }

    // Live Draft Line
    if (draftLineStart != null && draftLineEnd != null) {
      final Offset a = _denormOffset(draftLineStart!, size);
      final Offset b = _denormOffset(draftLineEnd!, size);
      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = config.activeBorderColor
          ..strokeWidth = math.max(2.0, config.activeBorderWidth)
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(a, 5, Paint()..color = Colors.white);
      canvas.drawCircle(a, 3.5, Paint()..color = const Color(0xFF00796B));
      canvas.drawCircle(b, 5, Paint()..color = Colors.white);
      canvas.drawCircle(b, 3.5, Paint()..color = const Color(0xFF00796B));
    }

    // Live Polygon Vertices
    if (draftPolygonPoints.isNotEmpty) {
      final Path polyPath = Path();
      final Offset first = _denormOffset(draftPolygonPoints.first, size);
      polyPath.moveTo(first.dx, first.dy);
      for (int i = 1; i < draftPolygonPoints.length; i++) {
        final pt = _denormOffset(draftPolygonPoints[i], size);
        polyPath.lineTo(pt.dx, pt.dy);
      }
      canvas.drawPath(
        polyPath,
        Paint()
          ..color = config.activeBorderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(2.5, config.activeBorderWidth)
          ..strokeCap = StrokeCap.round,
      );
      for (int i = 0; i < draftPolygonPoints.length; i++) {
        final pt = _denormOffset(draftPolygonPoints[i], size);
        canvas.drawCircle(pt, i == 0 ? 7.0 : 5.0, Paint()..color = i == 0 ? const Color(0xFFFACC15) : Colors.white);
        canvas.drawCircle(pt, i == 0 ? 4.5 : 3.0, Paint()..color = const Color(0xFF00796B));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ShapeMaskPainter oldDelegate) {
    return true;
  }
}

/// Subtle transparency grid rendered behind the canvas in Transparent PNG mode.
class _CheckerboardPainter extends CustomPainter {
  const _CheckerboardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const double cell = 14.0;
    final Paint light = Paint()..color = const Color(0xFFF1F5F9);
    final Paint dark = Paint()..color = const Color(0xFFCBD5E1);

    canvas.drawRect(Offset.zero & size, light);
    final int cols = (size.width / cell).ceil();
    final int rows = (size.height / cell).ceil();
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if ((r + c).isOdd) {
          canvas.drawRect(Rect.fromLTWH(c * cell, r * cell, cell, cell), dark);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
