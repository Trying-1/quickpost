import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Paints a rounded rectangular wireframe border with an optional cutout gap
/// (and optional endpoint dots) along one of the four edges for the wire watermark style.
class WireFramePainter extends CustomPainter {
  final double radius;
  final double width;
  final Color color;
  final double textWidth;
  final double scale;
  final bool hasCutout;
  final bool hasCutoutDots;
  final String textPosition;
  final double wireGap;

  WireFramePainter({
    required this.radius,
    required this.width,
    required this.color,
    required this.textWidth,
    required this.scale,
    required this.hasCutout,
    required this.hasCutoutDots,
    this.textPosition = 'bottom',
    this.wireGap = 16.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..isAntiAlias = true;

    const double left = 0;
    const double top = 0;
    final double right = size.width;
    final double bottom = size.height;

    final double maxRadius = math.min(size.width / 2, size.height / 2);
    final double r = radius.clamp(0, maxRadius);
    final double diameter = r * 2;

    if (!hasCutout) {
      if (r > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(left, top, right, bottom),
            Radius.circular(r),
          ),
          paint,
        );
      } else {
        canvas.drawRect(Rect.fromLTRB(left, top, right, bottom), paint);
      }
      return;
    }

    final double centerVal =
        (textPosition == 'left' || textPosition == 'right')
            ? size.height / 2
            : size.width / 2;
    final double cutoutHalf = (textWidth + (wireGap * scale)) / 2;
    final double cutoutStart = centerVal - cutoutHalf;
    final double cutoutEnd = centerVal + cutoutHalf;

    final path = Path();

    if (r <= 0) {
      _buildSharpCutoutPath(
        path,
        left: left,
        top: top,
        right: right,
        bottom: bottom,
        cutoutStart: cutoutStart,
        cutoutEnd: cutoutEnd,
      );
    } else {
      _buildRoundedCutoutPath(
        path,
        left: left,
        top: top,
        right: right,
        bottom: bottom,
        r: r,
        diameter: diameter,
        cutoutStart: cutoutStart,
        cutoutEnd: cutoutEnd,
      );
    }

    canvas.drawPath(path, paint);

    if (hasCutoutDots) {
      final dotPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;
      final double dotRadius = width * 1.5;
      if (textPosition == 'bottom') {
        canvas.drawCircle(Offset(cutoutStart, bottom), dotRadius, dotPaint);
        canvas.drawCircle(Offset(cutoutEnd, bottom), dotRadius, dotPaint);
      } else if (textPosition == 'top') {
        canvas.drawCircle(Offset(cutoutStart, top), dotRadius, dotPaint);
        canvas.drawCircle(Offset(cutoutEnd, top), dotRadius, dotPaint);
      } else if (textPosition == 'left') {
        canvas.drawCircle(Offset(left, cutoutStart), dotRadius, dotPaint);
        canvas.drawCircle(Offset(left, cutoutEnd), dotRadius, dotPaint);
      } else {
        canvas.drawCircle(Offset(right, cutoutStart), dotRadius, dotPaint);
        canvas.drawCircle(Offset(right, cutoutEnd), dotRadius, dotPaint);
      }
    }
  }

  void _buildSharpCutoutPath(
    Path path, {
    required double left,
    required double top,
    required double right,
    required double bottom,
    required double cutoutStart,
    required double cutoutEnd,
  }) {
    if (textPosition == 'bottom') {
      path.moveTo(left, top);
      path.lineTo(right, top);
      path.lineTo(right, bottom);
      if (cutoutEnd < right) path.lineTo(cutoutEnd, bottom);
      path.moveTo(cutoutStart, bottom);
      if (cutoutStart > left) path.lineTo(left, bottom);
      path.lineTo(left, top);
    } else if (textPosition == 'top') {
      path.moveTo(left, bottom);
      path.lineTo(left, top);
      if (cutoutStart > left) path.lineTo(cutoutStart, top);
      path.moveTo(cutoutEnd, top);
      if (cutoutEnd < right) path.lineTo(right, top);
      path.lineTo(right, bottom);
      path.lineTo(left, bottom);
    } else if (textPosition == 'left') {
      path.moveTo(right, top);
      path.lineTo(right, bottom);
      path.lineTo(left, bottom);
      if (cutoutEnd < bottom) path.lineTo(left, cutoutEnd);
      path.moveTo(left, cutoutStart);
      if (cutoutStart > top) path.lineTo(left, cutoutStart);
      path.lineTo(left, top);
      path.lineTo(right, top);
    } else {
      path.moveTo(left, top);
      path.lineTo(right, top);
      if (cutoutStart > top) path.lineTo(right, cutoutStart);
      path.moveTo(right, cutoutEnd);
      if (cutoutEnd < bottom) path.lineTo(right, bottom);
      path.lineTo(left, bottom);
      path.lineTo(left, top);
    }
  }

  void _buildRoundedCutoutPath(
    Path path, {
    required double left,
    required double top,
    required double right,
    required double bottom,
    required double r,
    required double diameter,
    required double cutoutStart,
    required double cutoutEnd,
  }) {
    const halfPi = math.pi / 2;
    const pi = math.pi;

    if (textPosition == 'bottom') {
      path.moveTo(left + r, top);
      path.lineTo(right - r, top);
      path.arcTo(
        Rect.fromLTWH(right - diameter, top, diameter, diameter),
        -halfPi,
        halfPi,
        false,
      );
      path.lineTo(right, bottom - r);
      path.arcTo(
        Rect.fromLTWH(right - diameter, bottom - diameter, diameter, diameter),
        0,
        halfPi,
        false,
      );
      if (cutoutEnd < right - r) path.lineTo(cutoutEnd, bottom);
      path.moveTo(cutoutStart, bottom);
      if (cutoutStart > left + r) path.lineTo(left + r, bottom);
      path.arcTo(
        Rect.fromLTWH(left, bottom - diameter, diameter, diameter),
        halfPi,
        halfPi,
        false,
      );
      path.lineTo(left, top + r);
      path.arcTo(
        Rect.fromLTWH(left, top, diameter, diameter),
        pi,
        halfPi,
        false,
      );
    } else if (textPosition == 'top') {
      path.moveTo(left, bottom - r);
      path.lineTo(left, top + r);
      path.arcTo(
        Rect.fromLTWH(left, top, diameter, diameter),
        pi,
        halfPi,
        false,
      );
      if (cutoutStart > left + r) path.lineTo(cutoutStart, top);
      path.moveTo(cutoutEnd, top);
      if (cutoutEnd < right - r) path.lineTo(right - r, top);
      path.arcTo(
        Rect.fromLTWH(right - diameter, top, diameter, diameter),
        -halfPi,
        halfPi,
        false,
      );
      path.lineTo(right, bottom - r);
      path.arcTo(
        Rect.fromLTWH(right - diameter, bottom - diameter, diameter, diameter),
        0,
        halfPi,
        false,
      );
      path.lineTo(left + r, bottom);
      path.arcTo(
        Rect.fromLTWH(left, bottom - diameter, diameter, diameter),
        halfPi,
        halfPi,
        false,
      );
    } else if (textPosition == 'left') {
      path.moveTo(left + r, top);
      path.lineTo(right - r, top);
      path.arcTo(
        Rect.fromLTWH(right - diameter, top, diameter, diameter),
        -halfPi,
        halfPi,
        false,
      );
      path.lineTo(right, bottom - r);
      path.arcTo(
        Rect.fromLTWH(right - diameter, bottom - diameter, diameter, diameter),
        0,
        halfPi,
        false,
      );
      path.lineTo(left + r, bottom);
      path.arcTo(
        Rect.fromLTWH(left, bottom - diameter, diameter, diameter),
        halfPi,
        halfPi,
        false,
      );
      if (cutoutEnd < bottom - r) path.lineTo(left, cutoutEnd);
      path.moveTo(left, cutoutStart);
      if (cutoutStart > top + r) path.lineTo(left, top + r);
      path.arcTo(
        Rect.fromLTWH(left, top, diameter, diameter),
        pi,
        halfPi,
        false,
      );
    } else {
      path.moveTo(right - r, bottom);
      path.lineTo(left + r, bottom);
      path.arcTo(
        Rect.fromLTWH(left, bottom - diameter, diameter, diameter),
        halfPi,
        halfPi,
        false,
      );
      path.lineTo(left, top + r);
      path.arcTo(
        Rect.fromLTWH(left, top, diameter, diameter),
        pi,
        halfPi,
        false,
      );
      path.lineTo(right - r, top);
      path.arcTo(
        Rect.fromLTWH(right - diameter, top, diameter, diameter),
        -halfPi,
        halfPi,
        false,
      );
      if (cutoutStart > top + r) path.lineTo(right, cutoutStart);
      path.moveTo(right, cutoutEnd);
      if (cutoutEnd < bottom - r) path.lineTo(right, bottom - r);
      path.arcTo(
        Rect.fromLTWH(right - diameter, bottom - diameter, diameter, diameter),
        0,
        halfPi,
        false,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WireFramePainter oldDelegate) {
    return oldDelegate.radius != radius ||
        oldDelegate.width != width ||
        oldDelegate.color != color ||
        oldDelegate.textWidth != textWidth ||
        oldDelegate.scale != scale ||
        oldDelegate.hasCutout != hasCutout ||
        oldDelegate.hasCutoutDots != hasCutoutDots ||
        oldDelegate.textPosition != textPosition ||
        oldDelegate.wireGap != wireGap;
  }
}

