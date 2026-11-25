import 'package:flutter/material.dart';
import '../models/anime_template_theme.dart';

class AnimeMetadataPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final Color accentColor;
  final Color? iconColor;
  final String? fontFamily;
  final MetadataPillStyle style;
  final bool isGlass;
  final bool isDarkBackground;
  final Color? customBorderColor;
  final double? customBorderWidth;
  final Color? customBgColor;
  final double? customBgOpacity;
  final double? customBorderRadius;
  final double? customFontSize;
  final FontWeight? customFontWeight;
  final double? customLetterSpacing;
  final double? customPadding;
  final bool? customShadow;
  final Color? customTextColor;

  const AnimeMetadataPill({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.accentColor = const Color(0xFFFF4081),
    this.iconColor,
    this.fontFamily,
    this.style = MetadataPillStyle.frostedGlass,
    this.isGlass = true,
    this.isDarkBackground = true,
    this.customBorderColor,
    this.customBorderWidth,
    this.customBgColor,
    this.customBgOpacity,
    this.customBorderRadius,
    this.customFontSize,
    this.customFontWeight,
    this.customLetterSpacing,
    this.customPadding,
    this.customShadow,
    this.customTextColor,
  });

  @override
  Widget build(BuildContext context) {
    final displayText = (value != null && value!.trim().isNotEmpty)
        ? (label.isNotEmpty ? '$label: $value' : value!)
        : label;

    if (displayText.trim().isEmpty) return const SizedBox.shrink();

    Color bgColor;
    Color borderColor;
    double borderWidth = 0.8;
    Color textColor;
    Color effectiveIconColor = iconColor ?? accentColor;
    double radius = 8.0;
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 5);

    switch (style) {
      case MetadataPillStyle.solidAccent:
        bgColor = accentColor;
        borderColor = Colors.transparent;
        borderWidth = 0.0;
        textColor = Colors.white;
        effectiveIconColor = Colors.white;
        radius = 8.0;
        break;

      case MetadataPillStyle.minimalClean:
        bgColor = Colors.transparent;
        borderColor = Colors.transparent;
        borderWidth = 0.0;
        textColor = isDarkBackground
            ? Colors.white.withValues(alpha: 0.9)
            : const Color(0xFF334155);
        padding = const EdgeInsets.symmetric(horizontal: 4, vertical: 3);
        radius = 4.0;
        break;

      case MetadataPillStyle.outlinedChip:
        bgColor = Colors.transparent;
        borderColor = isDarkBackground
            ? Colors.white.withValues(alpha: 0.45)
            : const Color(0xFF64748B);
        borderWidth = 1.2;
        textColor = isDarkBackground
            ? Colors.white
            : const Color(0xFF1E293B);
        radius = 6.0;
        break;

      case MetadataPillStyle.darkContrast:
        bgColor = const Color(0xFF0F172A).withValues(alpha: 0.85);
        borderColor = const Color(0xFF334155);
        borderWidth = 1.0;
        textColor = Colors.white;
        radius = 8.0;
        break;

      case MetadataPillStyle.frostedGlass:
        bgColor = isDarkBackground
            ? (isGlass ? Colors.white.withValues(alpha: 0.10) : Colors.black87)
            : Colors.grey.shade100;
        borderColor = isDarkBackground
            ? (isGlass ? Colors.white.withValues(alpha: 0.20) : Colors.white24)
            : Colors.grey.shade300;
        borderWidth = 0.8;
        textColor = isDarkBackground
            ? Colors.white
            : const Color(0xFF1E293B);
        radius = 8.0;
        break;
    }

    if (customBgColor != null) {
      bgColor = customBgColor!.withValues(alpha: (customBgOpacity ?? 1.0).clamp(0.0, 1.0));
    }
    if (customBorderRadius != null) {
      radius = customBorderRadius!;
    }
    if (customTextColor != null) {
      textColor = customTextColor!;
      effectiveIconColor = customTextColor!;
    }
    if (customPadding != null) {
      padding = EdgeInsets.symmetric(horizontal: customPadding!, vertical: (customPadding! * 0.5).clamp(2.0, 16.0));
    }
    if (customBorderColor != null) {
      borderColor = customBorderColor!;
    }
    if (customBorderWidth != null) {
      borderWidth = customBorderWidth!;
      if (borderWidth > 0 && borderColor == Colors.transparent) {
        borderColor = customBorderColor ?? (isDarkBackground ? Colors.white.withValues(alpha: 0.35) : accentColor);
      }
    }

    final hasShadow = customShadow == true;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(radius),
        border: borderWidth > 0
            ? Border.all(
                color: borderColor,
                width: borderWidth,
              )
            : null,
        boxShadow: hasShadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDarkBackground ? 0.35 : 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: (customFontSize ?? 11) + 2, color: effectiveIconColor),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              displayText,
              style: TextStyle(
                fontFamily: fontFamily,
                fontSize: customFontSize ?? 11,
                fontWeight: customFontWeight ?? FontWeight.w600,
                letterSpacing: customLetterSpacing ?? 0.0,
                color: textColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
