import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../models/anime_template_theme.dart';

/// Renders a decorative card backdrop behind slide components
/// with support for glassmorphism blur, neon glow, minimal outlines, and editorial accents.
class AnimeCardBackdrop extends StatelessWidget {
  final AnimeTemplateTheme theme;
  final double width;
  final double height;
  final double? borderRadius;

  const AnimeCardBackdrop({
    super.key,
    required this.theme,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    if (!theme.showCardBackdrop || theme.cardStyle == CardStyle.none) {
      return const SizedBox.shrink();
    }

    final effectiveRadius = borderRadius ?? theme.cardBorderRadius;
    final hasGlass = theme.cardStyle == CardStyle.glassmorphismBottom ||
        theme.cardStyle == CardStyle.modernFloatingPill;
    final isNeon = theme.cardStyle == CardStyle.neonCyberpunk;
    final isMinimal = theme.cardStyle == CardStyle.cleanMinimalCenter;
    final isEditorial = theme.cardStyle == CardStyle.editorialMagazine;

    // Border configuration
    Border? border;
    final hasBorder = theme.showCardBorder && theme.cardBorderWidth > 0;
    if (hasBorder) {
      if (isEditorial) {
        border = Border(
          left: BorderSide(
            color: theme.cardBorderColor ?? theme.accentColor,
            width: (theme.cardBorderWidth * 2.5).clamp(2.0, 10.0),
          ),
        );
      } else {
        final borderColor = theme.cardBorderColor ??
            (isNeon
                ? theme.accentColor
                : (isMinimal
                    ? Colors.white.withValues(alpha: 0.25)
                    : Colors.white.withValues(alpha: 0.22)));
        border = Border.all(
          color: borderColor,
          width: theme.cardBorderWidth,
        );
      }
    }

    // Shadow / elevation configuration
    List<BoxShadow>? shadows;
    if (isNeon) {
      final glowColor = (theme.cardBorderColor ?? theme.accentColor).withValues(alpha: 0.35);
      shadows = [
        BoxShadow(
          color: glowColor,
          blurRadius: 18,
          spreadRadius: 1,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.4),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ];
    } else if (theme.cardStyle == CardStyle.modernFloatingPill) {
      shadows = [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];
    } else if (hasGlass) {
      shadows = [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.25),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];
    }

    final decoration = BoxDecoration(
      color: theme.cardBgColor.withValues(alpha: theme.cardOpacity),
      borderRadius: BorderRadius.circular(effectiveRadius),
      border: border,
      boxShadow: shadows,
    );

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
