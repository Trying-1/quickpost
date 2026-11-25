import 'package:flutter/material.dart';
import '../models/grid_layout_type.dart';

/// Overlays dashed/solid split lines and Instagram upload order badges over the image preview.
class GridPreviewOverlay extends StatelessWidget {
  final GridLayoutType layout;
  final bool showBadges;

  const GridPreviewOverlay({
    super.key,
    required this.layout,
    this.showBadges = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final totalHeight = constraints.maxHeight;
        final tileWidth = totalWidth / layout.cols;
        final tileHeight = totalHeight / layout.rows;

        return Stack(
          children: [
            // Outer bounding frame
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.5),
                ),
              ),
            ),

            // Vertical divider lines
            for (int c = 1; c < layout.cols; c++)
              Positioned(
                left: c * tileWidth,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 1.5,
                  color: Colors.white.withOpacity(0.85),
                ),
              ),

            // Horizontal divider lines
            for (int r = 1; r < layout.rows; r++)
              Positioned(
                top: r * tileHeight,
                left: 0,
                right: 0,
                child: Container(
                  height: 1.5,
                  color: Colors.white.withOpacity(0.85),
                ),
              ),

            // Numbering & Instagram Posting Order Badges
            if (showBadges)
              for (int r = 0; r < layout.rows; r++)
                for (int c = 0; c < layout.cols; c++) ...[
                  Builder(
                    builder: (context) {
                      final tileIndex = (r * layout.cols) + c;
                      final postingOrder = layout.getPostingOrder(tileIndex);

                      return Positioned(
                        left: c * tileWidth + 8,
                        top: r * tileHeight + 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: postingOrder == 1
                                  ? const Color(0xFFD81B60)
                                  : Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Post #$postingOrder',
                                style: TextStyle(
                                  color: postingOrder == 1
                                      ? const Color(0xFFFF4081)
                                      : Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                'Tile ${tileIndex + 1}',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
          ],
        );
      },
    );
  }
}

