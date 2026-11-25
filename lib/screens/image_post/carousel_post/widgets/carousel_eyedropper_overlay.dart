import 'package:flutter/material.dart';

/// Full-canvas touch overlay displaying a magnified live swatch for color picking.
class CarouselEyeDropperOverlay extends StatelessWidget {
  final bool visible;
  final Offset? indicatorPosition;
  final Color pickedColor;
  final void Function(Offset localPos, Size bounds) onPick;
  final VoidCallback onDone;

  const CarouselEyeDropperOverlay({
    super.key,
    required this.visible,
    required this.indicatorPosition,
    required this.pickedColor,
    required this.onPick,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    final String hexLabel =
        '#${pickedColor.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase().substring(2)}';

    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return GestureDetector(
            onPanUpdate: (details) => onPick(details.localPosition, size),
            onPanDown: (details) => onPick(details.localPosition, size),
            onPanEnd: (_) => onDone(),
            child: Container(
              color: Colors.transparent,
              child: Stack(
                children: [
                  if (indicatorPosition != null)
                    Positioned(
                      left: indicatorPosition!.dx - 40,
                      top: indicatorPosition!.dy - 100,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: const [
                                BoxShadow(
                                    color: Colors.black26, blurRadius: 10),
                              ],
                            ),
                            child: ClipOval(
                              child: Container(
                                color: pickedColor,
                                child: Center(
                                  child: Container(
                                    width: 4,
                                    height: 4,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              hexLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Positioned(
                    bottom: 40,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C63FF),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 10),
                          ],
                        ),
                        child: const Text(
                          'Drag to pick color from image',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

