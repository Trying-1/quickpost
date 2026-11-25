import 'dart:convert';
import 'package:flutter/material.dart';

enum CardStyle {
  none,                // Clean canvas / floating without card backing
  glassmorphismBottom, // Frosted glass blur container
  modernFloatingPill,  // Rounded floating card with soft shadow
  cleanMinimalCenter,  // Solid minimal card with sleek subtle border
  neonCyberpunk,       // Dark card with glowing accent border
  editorialMagazine,   // Elegant borderless tinted backdrop
}

extension CardStyleExt on CardStyle {
  String get label {
    switch (this) {
      case CardStyle.none:
        return 'No Card (Clean)';
      case CardStyle.glassmorphismBottom:
        return 'Frosted Glass';
      case CardStyle.modernFloatingPill:
        return 'Floating Card';
      case CardStyle.cleanMinimalCenter:
        return 'Clean Minimal';
      case CardStyle.neonCyberpunk:
        return 'Accent Border';
      case CardStyle.editorialMagazine:
        return 'Editorial Mag';
    }
  }
}

enum SlideLayout {
  defaultLayout, // Standard stack with customizable element positions & cards
}

extension SlideLayoutExt on SlideLayout {
  String get label {
    switch (this) {
      case SlideLayout.defaultLayout:
        return 'Default Layout';
    }
  }

  String get description {
    switch (this) {
      case SlideLayout.defaultLayout:
        return 'Standard stack with customizable element positions & cards';
    }
  }
}

enum HandleStyle {
  pillBadge,     // Curved pill with icon, text and verified badge
  minimalText,   // Clean minimalist text @handle with checkmark
  gradientChip,  // Vibrant neon gradient background chip
  glassChip,     // Frosted glass translucent badge
}

extension HandleStyleExt on HandleStyle {
  String get label {
    switch (this) {
      case HandleStyle.pillBadge:
        return 'Pill Badge';
      case HandleStyle.minimalText:
        return 'Minimal Text';
      case HandleStyle.gradientChip:
        return 'Gradient Chip';
      case HandleStyle.glassChip:
        return 'Frosted Glass';
    }
  }
}

enum SlideCounterStyle {
  fractionPill,  // 01 / 07 inside a pill container
  minimalSlash,  // 01/07 clean modern typography
  dotsIndicator, // Modern carousel dot indicators
  accentBadge,   // Vibrant accent badge (#01)
}

extension SlideCounterStyleExt on SlideCounterStyle {
  String get label {
    switch (this) {
      case SlideCounterStyle.fractionPill:
        return 'Fraction Pill (01 / 07)';
      case SlideCounterStyle.minimalSlash:
        return 'Minimal Slash (01/07)';
      case SlideCounterStyle.dotsIndicator:
        return 'Dots Carousel';
      case SlideCounterStyle.accentBadge:
        return 'Accent Badge (#01)';
    }
  }
}

enum HookTagStyle {
  neonGlow,      // Neon accent color with soft glow
  solidAccent,   // Bold punchy solid accent with white text
  minimalBorder, // Clean thin outline tag
  fireBadge,     // Tag with badge icon
}

extension HookTagStyleExt on HookTagStyle {
  String get label {
    switch (this) {
      case HookTagStyle.neonGlow:
        return 'Tinted Capsule';
      case HookTagStyle.solidAccent:
        return 'Solid Accent';
      case HookTagStyle.minimalBorder:
        return 'Outlined Minimal';
      case HookTagStyle.fireBadge:
        return 'Badge Icon';
    }
  }
}

enum RankBadgeStyle {
  modernGradient, // Smooth subtle gradient pill with clean drop shadow
  minimalOutlined, // Clean 1.5px outline with crisp typography
  glassPill,       // Translucent frosted glass with subtle border
  boldRibbon,      // Sharp angular solid bookmark/ribbon badge
  circularStamp,   // Clean circular badge (#01)
}

extension RankBadgeStyleExt on RankBadgeStyle {
  String get label {
    switch (this) {
      case RankBadgeStyle.modernGradient:
        return 'Modern Gradient';
      case RankBadgeStyle.minimalOutlined:
        return 'Minimal Outlined';
      case RankBadgeStyle.glassPill:
        return 'Glass Pill';
      case RankBadgeStyle.boldRibbon:
        return 'Bold Ribbon';
      case RankBadgeStyle.circularStamp:
        return 'Circular Stamp';
    }
  }
}

enum SynopsisCardStyle {
  quoteQuoteMark, // Large quote mark at top left with italic text
  translucentBox, // Subtle dark box with left accent border line
  cleanMinimal,   // Plain typography with subtle divider above
  floatingChip,   // Rounded container with soft shadow
}

extension SynopsisCardStyleExt on SynopsisCardStyle {
  String get label {
    switch (this) {
      case SynopsisCardStyle.quoteQuoteMark:
        return 'Clean Text';
      case SynopsisCardStyle.translucentBox:
        return 'Accent Bar Box';
      case SynopsisCardStyle.cleanMinimal:
        return 'Minimalist';
      case SynopsisCardStyle.floatingChip:
        return 'Floating Container';
    }
  }
}

enum TitleCardStyle {
  standardText,   // Clean bold title text with drop shadow
  editorialTag,   // Solid dark pill/box framing the title
  neonUnderline,  // Vibrant glowing colored accent bar below title
  gradientText,   // Modern vibrant gradient across title characters
}

extension TitleCardStyleExt on TitleCardStyle {
  String get label {
    switch (this) {
      case TitleCardStyle.standardText:
        return 'Clean Standard';
      case TitleCardStyle.editorialTag:
        return 'Solid Pill Box';
      case TitleCardStyle.neonUnderline:
        return 'Accent Underline';
      case TitleCardStyle.gradientText:
        return 'Gradient Text';
    }
  }
}

enum AspectRatioPreset {
  portrait4x5, // 1080 x 1350 (Standard Instagram feed portrait)
  square1x1,   // 1080 x 1080 (Classic Instagram square)
}

extension AspectRatioPresetExt on AspectRatioPreset {
  double get ratio {
    switch (this) {
      case AspectRatioPreset.portrait4x5:
        return 4.0 / 5.0;
      case AspectRatioPreset.square1x1:
        return 1.0 / 1.0;
    }
  }

  int get exportWidth {
    switch (this) {
      case AspectRatioPreset.portrait4x5:
      case AspectRatioPreset.square1x1:
        return 1080;
    }
  }

  int get exportHeight {
    switch (this) {
      case AspectRatioPreset.portrait4x5:
        return 1350;
      case AspectRatioPreset.square1x1:
        return 1080;
    }
  }

  String get label {
    switch (this) {
      case AspectRatioPreset.portrait4x5:
        return '4:5 Portrait (1080×1350)';
      case AspectRatioPreset.square1x1:
        return '1:1 Square (1080×1080)';
    }
  }
}

/// Simplified, aesthetic template configuration for Carousel Posts.
class CarouselTemplateTheme {
  // Canvas Configuration
  final AspectRatioPreset aspectRatioPreset;
  final Color canvasBackgroundColor;
  final double backgroundBlur;
  final double backgroundBrightness;

  // Layout & Container Style
  final SlideLayout slideLayout;
  final CardStyle cardStyle;
  final bool showCardBackdrop;
  final Color cardBackgroundColor;
  final double cardOpacity;
  final double cardBlur;
  final double cardBorderRadius;
  final Color cardBorderColor;
  final double cardBorderWidth;

  // Accent & Aesthetic Colors
  final Color accentColor;
  final Color secondaryAccentColor;
  final Color? titleTextColor;
  final Color? bodyTextColor;

  // Typography
  final String fontFamily;
  final String titleFontFamily;
  final String bodyFontFamily;
  final double titleFontSize;
  final FontWeight titleFontWeight;
  final double bodyFontSize;

  // Granular Component Font Overrides (ComponentId -> FontFamily)
  final Map<String, String> componentFonts;

  // Granular Component Color Overrides (ComponentId -> Color)
  final Map<String, Color> componentColors;

  // Branding & Watermark
  final bool showWatermark;
  final String watermarkHandle;
  final String? watermarkAvatarPath;
  final HandleStyle handleStyle;
  final bool showVerifiedBadge;

  // Navigation & Badges
  final bool showSlideCounter;
  final SlideCounterStyle slideCounterStyle;
  final bool showSwipeIndicator;
  final bool showHookTag;
  final HookTagStyle hookTagStyle;
  final bool showNumberBadge;
  final RankBadgeStyle rankBadgeStyle;
  final SynopsisCardStyle synopsisCardStyle;
  final TitleCardStyle titleCardStyle;

  // Essential Content Visibility Toggles
  final bool showAuthor;
  final bool showBodyText;
  final bool showTakeaway;

  // Synchronization toggle across all content slides
  final bool syncSlideLayoutAndPosition;

  const CarouselTemplateTheme({
    this.aspectRatioPreset = AspectRatioPreset.portrait4x5,
    this.canvasBackgroundColor = const Color(0xFF0A0A0C), // Sleek Matte Obsidian Black
    this.backgroundBlur = 0.0,
    this.backgroundBrightness = 0.55,
    this.slideLayout = SlideLayout.defaultLayout,
    this.cardStyle = CardStyle.none,
    this.showCardBackdrop = false,
    this.cardBackgroundColor = const Color(0xFF18181B),
    this.cardOpacity = 0.70,
    this.cardBlur = 10.0,
    this.cardBorderRadius = 16.0,
    this.cardBorderColor = Colors.white12,
    this.cardBorderWidth = 1.0,
    this.accentColor = const Color(0xFF0D9488), // Sleek Teal
    this.secondaryAccentColor = const Color(0xFF6366F1), // Royal Indigo
    this.titleTextColor,
    this.bodyTextColor,
    this.fontFamily = 'Poppins',
    this.titleFontFamily = 'Poppins-Bold',
    this.bodyFontFamily = 'Poppins',
    this.titleFontSize = 26.0,
    this.titleFontWeight = FontWeight.w700,
    this.bodyFontSize = 14.5,
    this.componentFonts = const {},
    this.componentColors = const {},
    this.showWatermark = true,
    this.watermarkHandle = '@app.quickpost',
    this.watermarkAvatarPath,
    this.handleStyle = HandleStyle.pillBadge,
    this.showVerifiedBadge = true,
    this.showSlideCounter = true,
    this.slideCounterStyle = SlideCounterStyle.fractionPill,
    this.showSwipeIndicator = true,
    this.showHookTag = false,
    this.hookTagStyle = HookTagStyle.neonGlow,
    this.showNumberBadge = false,
    this.rankBadgeStyle = RankBadgeStyle.modernGradient,
    this.synopsisCardStyle = SynopsisCardStyle.cleanMinimal,
    this.titleCardStyle = TitleCardStyle.standardText,
    this.showAuthor = false,
    this.showBodyText = true,
    this.showTakeaway = false,
    this.syncSlideLayoutAndPosition = true,
  });

  String getFontForComponent(String componentId, {String? defaultFont}) {
    if (componentFonts.containsKey(componentId)) {
      return componentFonts[componentId]!;
    }
    if (componentId == 'title') {
      return titleFontFamily;
    }
    if (componentId == 'bodyText' || componentId == 'author') {
      return bodyFontFamily;
    }
    return defaultFont ?? fontFamily;
  }

  Color getColorForComponent(String componentId, {Color? defaultColor}) {
    if (componentColors.containsKey(componentId)) {
      return componentColors[componentId]!;
    }
    if (componentId == 'canvasBackground') {
      return canvasBackgroundColor;
    }
    if (componentId == 'title' && titleTextColor != null) {
      return titleTextColor!;
    }
    if (componentId == 'bodyText' && bodyTextColor != null) {
      return bodyTextColor!;
    }
    return defaultColor ?? (titleTextColor ?? Colors.white);
  }

  CarouselTemplateTheme copyWith({
    AspectRatioPreset? aspectRatioPreset,
    Color? canvasBackgroundColor,
    double? backgroundBlur,
    double? backgroundBrightness,
    SlideLayout? slideLayout,
    CardStyle? cardStyle,
    bool? showCardBackdrop,
    Color? cardBackgroundColor,
    double? cardOpacity,
    double? cardBlur,
    double? cardBorderRadius,
    Color? cardBorderColor,
    double? cardBorderWidth,
    Color? accentColor,
    Color? secondaryAccentColor,
    Color? titleTextColor,
    Color? bodyTextColor,
    String? fontFamily,
    String? titleFontFamily,
    String? bodyFontFamily,
    double? titleFontSize,
    FontWeight? titleFontWeight,
    double? bodyFontSize,
    Map<String, String>? componentFonts,
    Map<String, Color>? componentColors,
    bool? showWatermark,
    String? watermarkHandle,
    String? watermarkAvatarPath,
    HandleStyle? handleStyle,
    bool? showVerifiedBadge,
    bool? showSlideCounter,
    SlideCounterStyle? slideCounterStyle,
    bool? showSwipeIndicator,
    bool? showHookTag,
    HookTagStyle? hookTagStyle,
    bool? showNumberBadge,
    RankBadgeStyle? rankBadgeStyle,
    SynopsisCardStyle? synopsisCardStyle,
    TitleCardStyle? titleCardStyle,
    bool? showAuthor,
    bool? showBodyText,
    bool? showTakeaway,
    bool? syncSlideLayoutAndPosition,
  }) {
    return CarouselTemplateTheme(
      aspectRatioPreset: aspectRatioPreset ?? this.aspectRatioPreset,
      canvasBackgroundColor: canvasBackgroundColor ?? this.canvasBackgroundColor,
      backgroundBlur: backgroundBlur ?? this.backgroundBlur,
      backgroundBrightness: backgroundBrightness ?? this.backgroundBrightness,
      slideLayout: slideLayout ?? this.slideLayout,
      cardStyle: cardStyle ?? this.cardStyle,
      showCardBackdrop: showCardBackdrop ?? this.showCardBackdrop,
      cardBackgroundColor: cardBackgroundColor ?? this.cardBackgroundColor,
      cardOpacity: cardOpacity ?? this.cardOpacity,
      cardBlur: cardBlur ?? this.cardBlur,
      cardBorderRadius: cardBorderRadius ?? this.cardBorderRadius,
      cardBorderColor: cardBorderColor ?? this.cardBorderColor,
      cardBorderWidth: cardBorderWidth ?? this.cardBorderWidth,
      accentColor: accentColor ?? this.accentColor,
      secondaryAccentColor: secondaryAccentColor ?? this.secondaryAccentColor,
      titleTextColor: titleTextColor ?? this.titleTextColor,
      bodyTextColor: bodyTextColor ?? this.bodyTextColor,
      fontFamily: fontFamily ?? this.fontFamily,
      titleFontFamily: titleFontFamily ?? this.titleFontFamily,
      bodyFontFamily: bodyFontFamily ?? this.bodyFontFamily,
      titleFontSize: titleFontSize ?? this.titleFontSize,
      titleFontWeight: titleFontWeight ?? this.titleFontWeight,
      bodyFontSize: bodyFontSize ?? this.bodyFontSize,
      componentFonts: componentFonts ?? this.componentFonts,
      componentColors: componentColors ?? this.componentColors,
      showWatermark: showWatermark ?? this.showWatermark,
      watermarkHandle: watermarkHandle ?? this.watermarkHandle,
      watermarkAvatarPath: watermarkAvatarPath ?? this.watermarkAvatarPath,
      handleStyle: handleStyle ?? this.handleStyle,
      showVerifiedBadge: showVerifiedBadge ?? this.showVerifiedBadge,
      showSlideCounter: showSlideCounter ?? this.showSlideCounter,
      slideCounterStyle: slideCounterStyle ?? this.slideCounterStyle,
      showSwipeIndicator: showSwipeIndicator ?? this.showSwipeIndicator,
      showHookTag: showHookTag ?? this.showHookTag,
      hookTagStyle: hookTagStyle ?? this.hookTagStyle,
      showNumberBadge: showNumberBadge ?? this.showNumberBadge,
      rankBadgeStyle: rankBadgeStyle ?? this.rankBadgeStyle,
      synopsisCardStyle: synopsisCardStyle ?? this.synopsisCardStyle,
      titleCardStyle: titleCardStyle ?? this.titleCardStyle,
      showAuthor: showAuthor ?? this.showAuthor,
      showBodyText: showBodyText ?? this.showBodyText,
      showTakeaway: showTakeaway ?? this.showTakeaway,
      syncSlideLayoutAndPosition: syncSlideLayoutAndPosition ?? this.syncSlideLayoutAndPosition,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'aspectRatioPreset': aspectRatioPreset.index,
      'canvasBackgroundColor': canvasBackgroundColor.value,
      'backgroundBlur': backgroundBlur,
      'backgroundBrightness': backgroundBrightness,
      'slideLayout': slideLayout.index,
      'cardStyle': cardStyle.index,
      'showCardBackdrop': showCardBackdrop,
      'cardBackgroundColor': cardBackgroundColor.value,
      'cardOpacity': cardOpacity,
      'cardBlur': cardBlur,
      'cardBorderRadius': cardBorderRadius,
      'cardBorderColor': cardBorderColor.value,
      'cardBorderWidth': cardBorderWidth,
      'accentColor': accentColor.value,
      'secondaryAccentColor': secondaryAccentColor.value,
      'titleTextColor': titleTextColor?.value,
      'bodyTextColor': bodyTextColor?.value,
      'fontFamily': fontFamily,
      'titleFontFamily': titleFontFamily,
      'bodyFontFamily': bodyFontFamily,
      'titleFontSize': titleFontSize,
      'titleFontWeight': titleFontWeight.index,
      'bodyFontSize': bodyFontSize,
      'componentFonts': componentFonts,
      'componentColors': componentColors.map((k, v) => MapEntry(k, v.value)),
      'showWatermark': showWatermark,
      'watermarkHandle': watermarkHandle,
      'watermarkAvatarPath': watermarkAvatarPath,
      'handleStyle': handleStyle.index,
      'showVerifiedBadge': showVerifiedBadge,
      'showSlideCounter': showSlideCounter,
      'slideCounterStyle': slideCounterStyle.index,
      'showSwipeIndicator': showSwipeIndicator,
      'showHookTag': showHookTag,
      'hookTagStyle': hookTagStyle.index,
      'showNumberBadge': showNumberBadge,
      'rankBadgeStyle': rankBadgeStyle.index,
      'synopsisCardStyle': synopsisCardStyle.index,
      'titleCardStyle': titleCardStyle.index,
      'showAuthor': showAuthor,
      'showBodyText': showBodyText,
      'showTakeaway': showTakeaway,
      'syncSlideLayoutAndPosition': syncSlideLayoutAndPosition,
    };
  }

  factory CarouselTemplateTheme.fromMap(Map<String, dynamic> map) {
    Map<String, String> fonts = {};
    if (map['componentFonts'] is Map) {
      (map['componentFonts'] as Map).forEach((k, v) {
        if (k != null && v != null) fonts[k.toString()] = v.toString();
      });
    }

    Map<String, Color> colors = {};
    if (map['componentColors'] is Map) {
      (map['componentColors'] as Map).forEach((k, v) {
        if (k != null && v is int) colors[k.toString()] = Color(v);
      });
    }

    return CarouselTemplateTheme(
      aspectRatioPreset: AspectRatioPreset.values[
          (map['aspectRatioPreset'] as int? ?? 0).clamp(0, AspectRatioPreset.values.length - 1)],
      backgroundBlur: (map['backgroundBlur'] as num?)?.toDouble() ?? 0.0,
      backgroundBrightness: (map['backgroundBrightness'] as num?)?.toDouble() ?? 0.55,
      slideLayout: SlideLayout.values[
          (map['slideLayout'] as int? ?? 0).clamp(0, SlideLayout.values.length - 1)],
      cardStyle: CardStyle.values[
          (map['cardStyle'] as int? ?? 0).clamp(0, CardStyle.values.length - 1)],
      showCardBackdrop: map['showCardBackdrop'] as bool? ?? false,
      canvasBackgroundColor: map['canvasBackgroundColor'] != null
          ? Color(map['canvasBackgroundColor'] as int)
          : const Color(0xFF0A0A0C),
      cardBackgroundColor: Color(map['cardBackgroundColor'] as int? ?? 0xFF18181B),
      cardOpacity: (map['cardOpacity'] as num?)?.toDouble() ?? 0.70,
      cardBlur: (map['cardBlur'] as num?)?.toDouble() ?? 10.0,
      cardBorderRadius: (map['cardBorderRadius'] as num?)?.toDouble() ?? 16.0,
      cardBorderColor: Color(map['cardBorderColor'] as int? ?? Colors.white12.value),
      cardBorderWidth: (map['cardBorderWidth'] as num?)?.toDouble() ?? 1.0,
      accentColor: Color(map['accentColor'] as int? ?? 0xFF0D9488),
      secondaryAccentColor: Color(map['secondaryAccentColor'] as int? ?? 0xFF6366F1),
      titleTextColor: map['titleTextColor'] != null ? Color(map['titleTextColor'] as int) : null,
      bodyTextColor: map['bodyTextColor'] != null ? Color(map['bodyTextColor'] as int) : null,
      fontFamily: map['fontFamily'] as String? ?? 'Poppins',
      titleFontFamily: map['titleFontFamily'] as String? ?? 'Poppins-Bold',
      bodyFontFamily: map['bodyFontFamily'] as String? ?? 'Poppins',
      titleFontSize: (map['titleFontSize'] as num?)?.toDouble() ?? 26.0,
      titleFontWeight: FontWeight.values[
          (map['titleFontWeight'] as int? ?? FontWeight.w700.index).clamp(0, FontWeight.values.length - 1)],
      bodyFontSize: (map['bodyFontSize'] as num?)?.toDouble() ?? 14.5,
      componentFonts: fonts,
      componentColors: colors,
      showWatermark: map['showWatermark'] as bool? ?? true,
      watermarkHandle: map['watermarkHandle'] as String? ?? '@app.quickpost',
      watermarkAvatarPath: map['watermarkAvatarPath'] as String?,
      handleStyle: HandleStyle.values[
          (map['handleStyle'] as int? ?? 0).clamp(0, HandleStyle.values.length - 1)],
      showVerifiedBadge: map['showVerifiedBadge'] as bool? ?? true,
      showSlideCounter: map['showSlideCounter'] as bool? ?? true,
      slideCounterStyle: SlideCounterStyle.values[
          (map['slideCounterStyle'] as int? ?? 0).clamp(0, SlideCounterStyle.values.length - 1)],
      showSwipeIndicator: map['showSwipeIndicator'] as bool? ?? true,
      showHookTag: map['showHookTag'] as bool? ?? false,
      hookTagStyle: HookTagStyle.values[
          (map['hookTagStyle'] as int? ?? 0).clamp(0, HookTagStyle.values.length - 1)],
      showNumberBadge: map['showNumberBadge'] as bool? ?? (map['showRankBadge'] as bool? ?? true),
      rankBadgeStyle: RankBadgeStyle.values[
          (map['rankBadgeStyle'] as int? ?? 0).clamp(0, RankBadgeStyle.values.length - 1)],
      synopsisCardStyle: SynopsisCardStyle.values[
          (map['synopsisCardStyle'] as int? ?? 0).clamp(0, SynopsisCardStyle.values.length - 1)],
      titleCardStyle: TitleCardStyle.values[
          (map['titleCardStyle'] as int? ?? 0).clamp(0, TitleCardStyle.values.length - 1)],
      showAuthor: map['showAuthor'] as bool? ?? false,
      showBodyText: map['showBodyText'] as bool? ?? (map['showSynopsis'] as bool? ?? true),
      showTakeaway: map['showTakeaway'] as bool? ?? false,
      syncSlideLayoutAndPosition: map['syncSlideLayoutAndPosition'] as bool? ?? true,
    );
  }
}
