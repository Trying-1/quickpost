import 'package:flutter/material.dart';
import '../models/carousel_slide.dart';

/// Renders gradient or full-tint color mask overlays for a [CarouselSlide].
class CarouselMaskOverlay extends StatelessWidget {
  final CarouselSlide slide;

  const CarouselMaskOverlay({super.key, required this.slide});

  @override
  Widget build(BuildContext context) {
    if (slide.maskType == 0) return const SizedBox.shrink();

    Alignment? begin, end;
    switch (slide.maskType) {
      case 1: // Bottom
        begin = Alignment.topCenter;
        end = Alignment.bottomCenter;
        break;
      case 2: // Top
        begin = Alignment.bottomCenter;
        end = Alignment.topCenter;
        break;
      case 4: // Left
        begin = Alignment.centerRight;
        end = Alignment.centerLeft;
        break;
      case 5: // Right
        begin = Alignment.centerLeft;
        end = Alignment.centerRight;
        break;
    }

    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          color: slide.maskType == 3
              ? slide.maskColor.withValues(alpha: slide.maskOpacity)
              : null,
          gradient: (begin != null && end != null)
              ? LinearGradient(
                  begin: begin,
                  end: end,
                  colors: [
                    Colors.transparent,
                    slide.maskColor.withValues(alpha: slide.maskOpacity),
                  ],
                  stops: [
                    slide.maskStart.clamp(0.0, 1.0),
                    slide.maskEnd.clamp(0.0, 1.0),
                  ],
                )
              : null,
        ),
      ),
    );
  }
}

