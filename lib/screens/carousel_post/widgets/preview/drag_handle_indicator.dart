import 'package:flutter/material.dart';

/// Reusable drag handle indicator widget displayed on interactive canvas.
class DragHandleIndicator extends StatelessWidget {
  final bool isInteractive;
  final ValueChanged<Offset>? onDrag;
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;
  final String label;

  const DragHandleIndicator({
    super.key,
    required this.isInteractive,
    this.onDrag,
    this.onDragStart,
    this.onDragEnd,
    this.label = 'Drag to position',
  });

  @override
  Widget build(BuildContext context) {
    if (!isInteractive || onDrag == null) return const SizedBox.shrink();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) => onDragStart?.call(),
      onPanUpdate: (d) => onDrag?.call(d.delta),
      onPanEnd: (_) => onDragEnd?.call(),
      onPanCancel: () => onDragEnd?.call(),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.drag_indicator_rounded,
                  color: Colors.white70,
                  size: 13,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

