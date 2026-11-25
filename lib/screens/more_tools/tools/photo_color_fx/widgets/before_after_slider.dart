import 'dart:io';
import 'package:flutter/material.dart';

/// Interactive split-screen visual wipe comparing the original photo against
/// the real-time filtered output with a draggable wipe handle.
class BeforeAfterSlider extends StatefulWidget {
  final File imageFile;
  final List<double> matrix;
  final bool showOriginalOnly;

  const BeforeAfterSlider({
    super.key,
    required this.imageFile,
    required this.matrix,
    this.showOriginalOnly = false,
  });

  @override
  State<BeforeAfterSlider> createState() => _BeforeAfterSliderState();
}

class _BeforeAfterSliderState extends State<BeforeAfterSlider> {
  double _splitPercent = 0.5; // 0.0 to 1.0 (50% split by default)

  @override
  Widget build(BuildContext context) {
    if (widget.showOriginalOnly) {
      return Image.file(
        widget.imageFile,
        fit: BoxFit.contain,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final double height = constraints.maxHeight;
        final double splitX = (width * _splitPercent).clamp(0.0, width);

        return Stack(
          fit: StackFit.expand,
          children: [
            // 1. Right Layer: Real-time Filtered Image
            ColorFiltered(
              colorFilter: ColorFilter.matrix(widget.matrix),
              child: Image.file(
                widget.imageFile,
                fit: BoxFit.contain,
              ),
            ),

            // 2. Left Layer: Original Unfiltered Image (Clipped to splitX)
            ClipRect(
              clipper: _HorizontalSplitClipper(splitX: splitX),
              child: Image.file(
                widget.imageFile,
                fit: BoxFit.contain,
              ),
            ),

            // 3. Vertical Divider Line
            Positioned(
              left: splitX - 1.5,
              top: 0,
              bottom: 0,
              child: Container(
                width: 3,
                color: Colors.white,
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 4. Center Draggable Handle
            Positioned(
              left: splitX - 18,
              top: height / 2 - 18,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanUpdate: (details) {
                  setState(() {
                    _splitPercent = (_splitPercent + (details.delta.dx / width)).clamp(0.02, 0.98);
                  });
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.arrow_left, size: 14, color: Color(0xFF0F172A)),
                      Icon(Icons.arrow_right, size: 14, color: Color(0xFF0F172A)),
                    ],
                  ),
                ),
              ),
            ),

            // 5. Drag Gesture Listener across full width
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragUpdate: (details) {
                  setState(() {
                    _splitPercent = (details.localPosition.dx / width).clamp(0.02, 0.98);
                  });
                },
              ),
            ),

            // 6. Floating "BEFORE" and "AFTER" Badges
            Positioned(
              top: 14,
              left: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Text(
                  'ORIGINAL',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ),
            Positioned(
              top: 14,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withOpacity(0.85),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'FX FILTER',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HorizontalSplitClipper extends CustomClipper<Rect> {
  final double splitX;
  const _HorizontalSplitClipper({required this.splitX});

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, splitX, size.height);
  }

  @override
  bool shouldReclip(covariant _HorizontalSplitClipper oldClipper) {
    return oldClipper.splitX != splitX;
  }
}

