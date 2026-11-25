import 'package:flutter/material.dart';
import '../../../../config/app_theme.dart';
import '../../models/carousel_slide.dart';

/// Wraps an individual slide component with absolute coordinate placement,
/// drag gesture handling, and live selection highlight borders.
class CanvasPositionedComponent extends StatelessWidget {
  final CarouselSlide slide;
  final String componentId;
  final String label;
  final Widget child;
  final double? baseLeft;
  final double? baseRight;
  final double? baseTop;
  final double? baseBottom;
  final double? width;
  final double? height;
  final bool allowHorizontal;
  final bool allowVertical;
  final bool useGroupOffset;
  final double groupYFactor;
  final bool isInteractive;
  final String? activeComponentKey;
  final ValueChanged<String>? onSelectComponent;
  final void Function(String componentKey, Offset delta)? onDragComponent;
  final ValueChanged<Offset>? onDragContent;
  final ValueChanged<Offset>? onDragHeader;
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;

  const CanvasPositionedComponent({
    super.key,
    required this.slide,
    required this.componentId,
    required this.label,
    required this.child,
    this.baseLeft,
    this.baseRight,
    this.baseTop,
    this.baseBottom,
    this.width,
    this.height,
    this.allowHorizontal = true,
    this.allowVertical = true,
    this.useGroupOffset = true,
    this.groupYFactor = 1.0,
    this.isInteractive = false,
    this.activeComponentKey,
    this.onSelectComponent,
    this.onDragComponent,
    this.onDragContent,
    this.onDragHeader,
    this.onDragStart,
    this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    final compOff = slide.getComponentOffset(componentId);
    final groupX = useGroupOffset ? slide.contentOffsetX : 0.0;
    final groupY = useGroupOffset ? (slide.contentOffsetY * groupYFactor) : 0.0;

    double? left;
    double? right;
    double? top;
    double? bottom;

    if (baseLeft != null && baseRight != null) {
      left = (baseLeft! + groupX + compOff.dx).clamp(-120.0, 450.0);
      right = (baseRight! - groupX - compOff.dx).clamp(-120.0, 450.0);
    } else {
      if (baseLeft != null) {
        left = (baseLeft! + groupX + compOff.dx).clamp(-120.0, 450.0);
      } else if (baseRight != null) {
        right = (baseRight! - groupX - compOff.dx).clamp(-120.0, 450.0);
      }
    }

    if (baseTop != null) {
      top = (baseTop! + groupY + compOff.dy).clamp(-120.0, 600.0);
    } else if (baseBottom != null) {
      bottom = (baseBottom! - groupY - compOff.dy).clamp(-120.0, 600.0);
    }

    final interactiveChild = _buildInteractiveContent();

    return Positioned(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      width: width,
      height: height,
      child: interactiveChild,
    );
  }

  Widget _buildInteractiveContent() {
    if (!isInteractive) {
      return child;
    }

    final isSelected = activeComponentKey == componentId;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        onSelectComponent?.call(componentId);
      },
      onPanStart: (_) {
        onSelectComponent?.call(componentId);
        onDragStart?.call();
      },
      onPanUpdate: (details) {
        if (onDragComponent != null) {
          final dx = allowHorizontal ? details.delta.dx : 0.0;
          final dy = allowVertical ? details.delta.dy : 0.0;
          onDragComponent!(componentId, Offset(dx, dy));
        } else if (onDragContent != null &&
            componentId != SlideComponentId.pageHandle &&
            componentId != SlideComponentId.slideCounter) {
          onDragContent!(details.delta);
        } else if (onDragHeader != null &&
            (componentId == SlideComponentId.pageHandle ||
                componentId == SlideComponentId.slideCounter)) {
          onDragHeader!(details.delta);
        }
      },
      onPanEnd: (_) {
        onDragEnd?.call();
      },
      onPanCancel: () {
        onDragEnd?.call();
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: isSelected
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                    color: AppColors.primary.withValues(alpha: 0.08),
                  )
                : null,
            child: child,
          ),
          if (isSelected)
            Positioned(
              top: -18,
              left: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.drag_indicator_rounded,
                      color: Colors.white,
                      size: 9,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

