import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../models/carousel_template_theme.dart';

/// Renders a decorative card backdrop behind slide components
/// with support for glassmorphism blur, neon glow, minimal outlines, and editorial accents.
class CarouselCardBackdrop extends StatelessWidget {
  final CarouselTemplateTheme theme;
  final double width;
  final double height;
  final double? borderRadius;

  const CarouselCardBackdrop({
    super.key,
    required this.theme,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? theme.cardBorderRadius;
    final hasGlass = theme.cardStyle == CardStyle.glassmorphismBottom ||
        theme.cardStyle == CardStyle.modernFloatingPill;
    final isNeon = theme.cardStyle == CardStyle.neonCyberpunk;
    final isMinimal = theme.cardStyle == CardStyle.cleanMinimalCenter;
    final isEditorial = theme.cardStyle == CardStyle.editorialMagazine;

    BoxDecoration decoration;
    if (isNeon) {
      decoration = BoxDecoration(
        color: theme.cardBackgroundColor.withValues(alpha: theme.cardOpacity),
        borderRadius: BorderRadius.circular(effectiveRadius),
        border: Border.all(
          color: theme.accentColor,
          width: theme.cardBorderWidth,
        ),
      );
    } else if (isMinimal) {
      decoration = BoxDecoration(
        color: theme.cardBackgroundColor.withValues(alpha: theme.cardOpacity),
        borderRadius: BorderRadius.circular(effectiveRadius),
        border: Border.all(
          color: theme.cardBorderColor,
          width: theme.cardBorderWidth,
        ),
      );
    } else if (isEditorial) {
      decoration = BoxDecoration(
        color: theme.cardBackgroundColor.withValues(alpha: theme.cardOpacity),
        borderRadius: BorderRadius.circular(effectiveRadius),
        border: Border(
          left: BorderSide(
            color: theme.accentColor,
            width: 3.5,
          ),
        ),
      );
    } else {
      // Glassmorphism / Modern Floating Pill
      decoration = BoxDecoration(
        color: theme.cardBackgroundColor.withValues(alpha: theme.cardOpacity),
        borderRadius: BorderRadius.circular(effectiveRadius),
        border: Border.all(
          color: theme.cardBorderColor,
          width: theme.cardBorderWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      );
    }

    final container = Container(
      width: width,
      height: height,
      decoration: decoration,
    );

    if (theme.cardBlur > 0 && hasGlass) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(effectiveRadius),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(
            sigmaX: theme.cardBlur,
            sigmaY: theme.cardBlur,
          ),
          child: container,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(effectiveRadius),
      child: container,
    );
  }
}

