import 'package:flutter/material.dart';
import 'dart:math' as math;

class WarpedTextWidget extends StatelessWidget {
  final String text;
  final TextStyle style;
  final String warpType; // 'none', 'arc', 'cylinder', 'bulge'
  final double warpIntensity; // -1.0 to 1.0
  final Map<int, String>? wordColors;
  final Color? defaultColor;

  const WarpedTextWidget({
    Key? key,
    required this.text,
    required this.style,
    required this.warpType,
    this.warpIntensity = 0.0,
    this.wordColors,
    this.defaultColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (warpType == 'none' || warpIntensity == 0.0 || text.isEmpty) {
      return Text(
        text, 
        style: style, 
        textAlign: TextAlign.center,
      );
    }

    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    painter.layout();

    double extraHeight = 0;
    if (warpType == 'arc') {
      final r = (painter.width / 2) / (math.sin(warpIntensity * math.pi / 2) + 0.001).abs();
      extraHeight = (r - r * math.cos(painter.width / 2 / r)).abs();
    } else if (warpType == 'bulge') {
      extraHeight = painter.height * warpIntensity.abs();
    }

    return CustomPaint(
      size: Size(painter.width, painter.height + extraHeight * 2),
      painter: _WarpedTextPainter(
        text: text,
        style: style,
        warpType: warpType,
        warpIntensity: warpIntensity,
        wordColors: wordColors,
        defaultColor: defaultColor,
      ),
    );
  }
}

class _WarpedTextPainter extends CustomPainter {
  final String text;
  final TextStyle style;
  final String warpType;
  final double warpIntensity;
  final Map<int, String>? wordColors;
  final Color? defaultColor;

  _WarpedTextPainter({
    required this.text,
    required this.style,
    required this.warpType,
    required this.warpIntensity,
    this.wordColors,
    this.defaultColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final painter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // Measure total bounds
    painter.text = TextSpan(text: text, style: style);
    painter.layout();
    final totalWidth = painter.width;
    final totalHeight = painter.height;

    final lines = text.split('\n');
    final double lineHeight = totalHeight / math.max(1, lines.length);

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);

    double currentY = -totalHeight / 2 + lineHeight / 2;

    int currentWordIdx = 0;
    bool inWord = false;

    Color _parseColor(String hexString) {
      if (hexString.startsWith('#')) hexString = hexString.substring(1);
      if (hexString.length == 6) hexString = 'FF$hexString';
      return Color(int.parse(hexString, radix: 16));
    }

    for (final line in lines) {
      if (line.isEmpty) {
        currentY += lineHeight;
        continue;
      }

      // Measure this line
      painter.text = TextSpan(text: line, style: style);
      painter.layout();
      final lineWidth = painter.width;
      
      final chars = line.split('');
      final charWidths = <double>[];
      final charStyles = <TextStyle>[];

      for (int i = 0; i < chars.length; i++) {
        final char = chars[i];
        bool isSpace = char.trim().isEmpty;
        if (isSpace) {
          inWord = false;
        } else {
          if (!inWord) {
            inWord = true;
            if (char != chars.first || line != lines.first) {
              currentWordIdx++;
            }
          }
        }

        Color charColor = defaultColor ?? style.color ?? Colors.white;
        if (wordColors != null && wordColors!.containsKey(currentWordIdx)) {
          charColor = _parseColor(wordColors![currentWordIdx]!);
        }

        final charStyle = style.copyWith(color: charColor);
        charStyles.add(charStyle);

        // Calculate accurate character width respecting kerning and letterSpacing
        painter.text = TextSpan(text: line.substring(0, i), style: style);
        painter.layout();
        final double xStart = painter.width;
        
        painter.text = TextSpan(text: line.substring(0, i + 1), style: style);
        painter.layout();
        final double xEnd = painter.width;
        
        charWidths.add(xEnd - xStart);
      }

      double currentX = -lineWidth / 2;

      for (int i = 0; i < chars.length; i++) {
        final char = chars[i];
        final w = charWidths[i];
        final cStyle = charStyles[i];
        final charCenterX = currentX + w / 2;
        
        painter.text = TextSpan(text: char, style: cStyle);
        painter.layout();

        canvas.save();

        if (warpType == 'arc') {
          // Base the radius on the longest line (totalWidth) so all lines curve consistently
          final r = (totalWidth / 2) / (math.sin(warpIntensity * math.pi / 2) + 0.001).abs();
          final angle = charCenterX / r;
          
          final dx = r * math.sin(angle);
          final dy = warpIntensity > 0 
             ? r - r * math.cos(angle)
             : -r + r * math.cos(angle);
             
          canvas.translate(dx, dy + currentY);
          canvas.rotate(warpIntensity > 0 ? angle : -angle);
          painter.paint(canvas, Offset(-w / 2, -lineHeight / 2));
          
        } else if (warpType == 'cylinder') {
          final r = (totalWidth / 2) / (math.sin(warpIntensity.abs() * math.pi / 2) + 0.001);
          final x0 = currentX;
          final x1 = currentX + w;
          final x0p = r * math.sin(x0 / r);
          final x1p = r * math.sin(x1 / r);
          final newW = x1p - x0p;
          final scaleX = (newW / w).abs();
          final dx = (x0p + x1p) / 2;
          
          canvas.translate(dx, currentY);
          canvas.scale(scaleX > 0.001 ? scaleX : 0.001, 1.0);
          painter.paint(canvas, Offset(-w / 2, -lineHeight / 2));
          
        } else if (warpType == 'bulge') {
          final double R = totalWidth / 2 + 0.001;
          double mapX(double x) {
             final normX = (x / R).clamp(-1.0, 1.0);
             return x * (1.0 + warpIntensity * (1.0 - normX * normX));
          }
          final x0 = currentX;
          final x1 = currentX + w;
          final x0p = mapX(x0);
          final x1p = mapX(x1);
          final newW = x1p - x0p;
          final scaleX = (newW / w).abs();
          final dx = (x0p + x1p) / 2;
          
          final double R_y = totalHeight / 2 + 0.001;
          final normY = (currentY / R_y).clamp(-1.0, 1.0);
          final dy = currentY * (1.0 + warpIntensity * (1.0 - normY * normY));
          final scaleY = math.max(0.001, 1.0 + warpIntensity * (1.0 - normY * normY));
          
          canvas.translate(dx, dy);
          canvas.scale(scaleX > 0.001 ? scaleX : 0.001, scaleY);
          painter.paint(canvas, Offset(-w / 2, -lineHeight / 2));
        }

        canvas.restore();

        currentX += w;
      }
      currentY += lineHeight;
    }
    
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WarpedTextPainter oldDelegate) {
    return oldDelegate.text != text ||
           oldDelegate.style != style ||
           oldDelegate.warpType != warpType ||
           oldDelegate.warpIntensity != warpIntensity;
  }
}
