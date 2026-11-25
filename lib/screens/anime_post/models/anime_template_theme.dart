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
  defaultLayout,      // Standard layout with full-bleed art, draggable elements & bottom card
  layout1,            // Layout 1: Landscape hero card with dual screenshots grid & tagline (assets/images/layout1.jpg)
  layout2,            // Layout 2: Multi-line bold headline with centered character spotlight (assets/images/layout2.jpg)
  layout3,            // Layout 3: Floating portrait poster with MAL rating pill & minimalist slate (assets/images/layout3.jpg)
  layout4,            // Layout 4: Editorial Magazine with vertical Japanese typography & asymmetric poster
  layout5,            // Layout 5: Cinematic Letterbox with 35mm widescreen frame & movie subtitles
  layout6,            // Layout 6: Polaroid Minimalist with washi tape accent & archive metadata
  layout7,            // Layout 7: Minimal Split with oversized rank watermark & Swiss data slate
}

extension SlideLayoutExt on SlideLayout {
  String get label {
    switch (this) {
      case SlideLayout.defaultLayout:
        return 'Standard Stack';
      case SlideLayout.layout1:
        return 'Layout 1 (Showcase)';
      case SlideLayout.layout2:
        return 'Layout 2 (Headline)';
      case SlideLayout.layout3:
        return 'Layout 3 (Floating)';
      case SlideLayout.layout4:
        return 'Layout 4 (Editorial)';
      case SlideLayout.layout5:
        return 'Layout 5 (Cinematic)';
      case SlideLayout.layout6:
        return 'Layout 6 (Polaroid)';
      case SlideLayout.layout7:
        return 'Layout 7 (Minimal Split)';
    }
  }

  String get description {
    switch (this) {
      case SlideLayout.defaultLayout:
        return 'Full-bleed poster with bottom metadata cards and synopsis';
      case SlideLayout.layout1:
        return 'Landscape hero card with dual screenshots grid and tagline';
      case SlideLayout.layout2:
        return 'Multi-line massive punchy headline with centered character spotlight';
      case SlideLayout.layout3:
        return 'Floating portrait poster card with MAL rating badge and minimalist slate';
      case SlideLayout.layout4:
        return 'Editorial magazine spread with vertical Japanese typography & asymmetric poster';
      case SlideLayout.layout5:
        return 'Cinematic 35mm widescreen letterbox frame with movie subtitle styling';
      case SlideLayout.layout6:
        return 'Minimalist polaroid archive card with washi tape accent & clean captions';
      case SlideLayout.layout7:
        return 'Modern Swiss typographic layout with oversized rank watermark & 3-column slate';
    }
  }

  IconData get icon {
    switch (this) {
      case SlideLayout.defaultLayout:
        return Icons.dashboard_rounded;
      case SlideLayout.layout1:
        return Icons.photo_library_rounded;
      case SlideLayout.layout2:
        return Icons.featured_play_list_rounded;
      case SlideLayout.layout3:
        return Icons.portrait_rounded;
      case SlideLayout.layout4:
        return Icons.auto_stories_rounded;
      case SlideLayout.layout5:
        return Icons.movie_filter_rounded;
      case SlideLayout.layout6:
        return Icons.filter_frames_rounded;
      case SlideLayout.layout7:
        return Icons.view_quilt_rounded;
    }
  }

  String get badgeText {
    switch (this) {
      case SlideLayout.defaultLayout:
        return 'DEFAULT';
      case SlideLayout.layout1:
        return 'LAYOUT 1';
      case SlideLayout.layout2:
        return 'LAYOUT 2';
      case SlideLayout.layout3:
        return 'LAYOUT 3';
      case SlideLayout.layout4:
        return 'LAYOUT 4';
      case SlideLayout.layout5:
        return 'LAYOUT 5';
      case SlideLayout.layout6:
        return 'LAYOUT 6';
      case SlideLayout.layout7:
        return 'LAYOUT 7';
    }
  }

  bool get usesFullBleedBackground {
    switch (this) {
      case SlideLayout.defaultLayout:
        return true;
      case SlideLayout.layout1:
      case SlideLayout.layout2:
      case SlideLayout.layout3:
      case SlideLayout.layout4:
      case SlideLayout.layout5:
      case SlideLayout.layout6:
      case SlideLayout.layout7:
        return false;
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

enum GenreStyle {
  pills,            // Individual glowing capsule pills
  bulletRow,        // Dot-separated uppercase text (ACTION • SHONEN)
  outlineTags,      // Sharp outlined anime tags
  gradientCapsules, // Gradient background mini capsules
}

extension GenreStyleExt on GenreStyle {
  String get label {
    switch (this) {
      case GenreStyle.pills:
        return 'Capsule Pills';
      case GenreStyle.bulletRow:
        return 'Bullet Row';
      case GenreStyle.outlineTags:
        return 'Outlined Tags';
      case GenreStyle.gradientCapsules:
        return 'Gradient Pills';
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
  glassPill, // Translucent frosted glass with subtle border
  boldRibbon, // Sharp angular solid bookmark/ribbon badge
  circularStamp, // Clean circular badge (#01)
}

extension RankBadgeStyleExt on RankBadgeStyle {
  String get label {
    switch (this) {
      case RankBadgeStyle.modernGradient:
        return 'Gradient Pill';
      case RankBadgeStyle.minimalOutlined:
        return 'Outlined';
      case RankBadgeStyle.glassPill:
        return 'Frosted Glass';
      case RankBadgeStyle.boldRibbon:
        return 'Bold Ribbon';
      case RankBadgeStyle.circularStamp:
        return 'Circular Stamp';
    }
  }
}

enum MetadataPillStyle {
  frostedGlass, // Translucent glass with fine hairline border
  solidAccent, // Solid accent tint with white icon and text
  minimalClean, // Flat borderless typography with accent icon
  outlinedChip, // Crisp 1px outline with transparent interior
  darkContrast, // Deep solid charcoal pill with high contrast
}

extension MetadataPillStyleExt on MetadataPillStyle {
  String get label {
    switch (this) {
      case MetadataPillStyle.frostedGlass:
        return 'Frosted Glass';
      case MetadataPillStyle.solidAccent:
        return 'Solid Accent';
      case MetadataPillStyle.minimalClean:
        return 'Minimal Clean';
      case MetadataPillStyle.outlinedChip:
        return 'Outlined Chip';
      case MetadataPillStyle.darkContrast:
        return 'Dark Contrast';
    }
  }
}

enum SynopsisCardStyle {
  accentBorderLeft, // Clean dark translucent card with vertical accent bar on left
  frostedGlassCard, // Frosted glass container with rounded corners and border
  cleanMinimalQuote, // Borderless clean quote with quotation mark icon
  cardElevated, // Solid elevated card with subtle ambient shadow
  editorialStrip, // Editorial card with top and bottom divider lines
}

extension SynopsisCardStyleExt on SynopsisCardStyle {
  String get label {
    switch (this) {
      case SynopsisCardStyle.accentBorderLeft:
        return 'Accent Left Bar';
      case SynopsisCardStyle.frostedGlassCard:
        return 'Frosted Glass Card';
      case SynopsisCardStyle.cleanMinimalQuote:
        return 'Minimal Quote';
      case SynopsisCardStyle.cardElevated:
        return 'Floating Elevated';
      case SynopsisCardStyle.editorialStrip:
        return 'Editorial Strip';
    }
  }
}

enum TitleCardStyle {
  pureText, // Crisp typography with natural drop shadow
  accentUnderline, // Sleek solid accent underline bar beneath the title
  glassBackplate, // Frosted glass backplate container enclosing title
  editorialTag, // Solid contrast banner behind title
}

extension TitleCardStyleExt on TitleCardStyle {
  String get label {
    switch (this) {
      case TitleCardStyle.pureText:
        return 'Clean Text';
      case TitleCardStyle.accentUnderline:
        return 'Accent Underline';
      case TitleCardStyle.glassBackplate:
        return 'Frosted Backplate';
      case TitleCardStyle.editorialTag:
        return 'Editorial Banner';
    }
  }
}

enum AspectRatioPreset {
  portrait4x5, // 1080 x 1350 - Ideal for Instagram Carousels
  square1x1,   // 1080 x 1080 - Square
}

extension AspectRatioPresetExt on AspectRatioPreset {
  String get label {
    switch (this) {
      case AspectRatioPreset.portrait4x5:
        return '4:5 Portrait';
      case AspectRatioPreset.square1x1:
        return '1:1 Square';
    }
  }

  double get aspectValue {
    switch (this) {
      case AspectRatioPreset.portrait4x5:
        return 4 / 5;
      case AspectRatioPreset.square1x1:
        return 1.0;
    }
  }

  int get exportWidth => 1080;

  int get exportHeight {
    switch (this) {
      case AspectRatioPreset.portrait4x5:
        return 1350;
      case AspectRatioPreset.square1x1:
        return 1080;
    }
  }
}

class AnimeTemplateTheme {
  final CardStyle cardStyle;
  final bool showCardBackdrop;
  final SlideLayout slideLayout;
  final AspectRatioPreset aspectRatio;
  final Color canvasBgColor;
  final Color accentColor;
  final Color cardBgColor;
  final double cardOpacity;
  final double cardBlur;
  final double backgroundBlur;
  final double cardBorderRadius;
  final double cardBorderWidth;
  final Color? cardBorderColor;
  final bool showCardBorder;
  final double gradientDarkness;

  // Typography & Font Controls
  final String titleFontFamily;
  final String bodyFontFamily;
  final double titleFontSize;
  final double bodyFontSize;
  final FontWeight titleFontWeight;

  // Text Color Controls (null = auto adaptive contrast based on background)
  final Color? titleTextColor;
  final Color? bodyTextColor;

  // Component Style Presets
  final HandleStyle handleStyle;
  final SlideCounterStyle counterStyle;
  final GenreStyle genreStyle;
  final HookTagStyle tagStyle;
  final RankBadgeStyle rankBadgeStyle;
  final MetadataPillStyle metadataPillStyle;
  final SynopsisCardStyle synopsisCardStyle;
  final TitleCardStyle titleCardStyle;

  // Visibility Toggles
  final bool showRankBadge;
  final bool showRating;
  final bool showSeasons;
  final bool showEpisodes;
  final bool showStudio;
  final bool showGenres;
  final bool showSynopsis;
  final bool showSlideCounter;
  final bool showHookTag;
  final bool showSwipeIndicator;
  final bool showJapaneseTitle;

  // Synchronization toggle across all anime slides
  final bool syncAnimeSlideLayoutAndPosition;

  // Atmospheric & Lighting Effects
  final bool enableAmbientGlow;
  final double ambientGlowIntensity;
  final double ambientGlowBlur;
  final double ambientGlowSpread;
  final bool enableFilmGrain;
  final double filmGrainIntensity;
  final bool enableVignette;
  final double vignetteIntensity;

  // Watermark / Brand
  final bool showWatermark;
  final String watermarkHandle;
  final String? watermarkLogoPath;
  final bool isVerified;

  // Per-Element Custom Font and Color Maps (componentKey -> value)
  final Map<String, String> componentFonts;
  final Map<String, Color> componentColors;
  final Map<String, Color> componentBgColors;
  final Map<String, double> componentBgOpacities;
  final Map<String, Color> componentBorderColors;
  final Map<String, double> componentBorderWidths;
  final Map<String, double> componentBorderRadii;
  final Map<String, double> componentFontSizes;
  final Map<String, int> componentFontWeights;
  final Map<String, double> componentLetterSpacings;
  final Map<String, double> componentPaddings;
  final Map<String, bool> componentShadows;
  final Map<String, bool> componentTextStrokeOnly;
  final Map<String, double> componentTextStrokeWidths;
  final Map<String, Color> componentTextStrokeColors;

  const AnimeTemplateTheme({
    this.cardStyle = CardStyle.none,
    this.showCardBackdrop = false,
    this.slideLayout = SlideLayout.defaultLayout,
    this.aspectRatio = AspectRatioPreset.portrait4x5,
    this.canvasBgColor = Colors.white,
    this.accentColor = const Color(0xFFFF3366),
    this.cardBgColor = const Color(0xFF0D0D12),
    this.cardOpacity = 0.85,
    this.cardBlur = 12.0,
    this.backgroundBlur = 0.0, // Default crisp and unblurred
    this.cardBorderRadius = 18.0,
    this.cardBorderWidth = 1.0,
    this.cardBorderColor,
    this.showCardBorder = true,
    this.gradientDarkness = 0.75,
    this.titleFontFamily = 'Poppins',
    this.bodyFontFamily = 'Poppins',
    this.titleFontSize = 20.0,
    this.bodyFontSize = 11.5,
    this.titleFontWeight = FontWeight.w800,
    this.titleTextColor,
    this.bodyTextColor,
    this.componentFonts = const {},
    this.componentColors = const {},
    this.componentBgColors = const {},
    this.componentBgOpacities = const {},
    this.componentBorderColors = const {},
    this.componentBorderWidths = const {},
    this.componentBorderRadii = const {},
    this.componentFontSizes = const {},
    this.componentFontWeights = const {},
    this.componentLetterSpacings = const {},
    this.componentPaddings = const {},
    this.componentShadows = const {},
    this.componentTextStrokeOnly = const {},
    this.componentTextStrokeWidths = const {},
    this.componentTextStrokeColors = const {},
    this.handleStyle = HandleStyle.pillBadge,
    this.counterStyle = SlideCounterStyle.fractionPill,
    this.genreStyle = GenreStyle.pills,
    this.tagStyle = HookTagStyle.neonGlow,
    this.rankBadgeStyle = RankBadgeStyle.modernGradient,
    this.metadataPillStyle = MetadataPillStyle.frostedGlass,
    this.synopsisCardStyle = SynopsisCardStyle.accentBorderLeft,
    this.titleCardStyle = TitleCardStyle.pureText,
    this.showRankBadge = false,
    this.showRating = false,
    this.showSeasons = false,
    this.showEpisodes = true,
    this.showStudio = false,
    this.showGenres = false,
    this.showSynopsis = false,
    this.showSlideCounter = false,
    this.showHookTag = false,
    this.showSwipeIndicator = false,
    this.showJapaneseTitle = false,
    this.syncAnimeSlideLayoutAndPosition = true,
    this.enableAmbientGlow = true,
    this.ambientGlowIntensity = 0.45,
    this.ambientGlowBlur = 28.0,
    this.ambientGlowSpread = 8.0,
    this.enableFilmGrain = false,
    this.filmGrainIntensity = 0.05,
    this.enableVignette = false,
    this.vignetteIntensity = 0.35,
    this.showWatermark = false,
    this.watermarkHandle = '@app.quickpost',
    this.watermarkLogoPath,
    this.isVerified = true,
  });

  AspectRatioPreset get aspectRatioPreset => aspectRatio;
  double get aspectValue => aspectRatio.aspectValue;
  int get exportWidth => aspectRatio.exportWidth;
  int get exportHeight => aspectRatio.exportHeight;
  String get fontFamily => titleFontFamily;
  String get watermarkText => watermarkHandle.replaceFirst('@', '');

  /// Returns element-specific font if set, falling back to title or body font family
  String getFontForComponent(String key, {String? defaultFont}) {
    if (componentFonts.containsKey(key) && componentFonts[key] != null && componentFonts[key]!.isNotEmpty) {
      return componentFonts[key]!;
    }
    if (key == 'title') {
      return titleFontFamily;
    }
    return defaultFont ?? bodyFontFamily;
  }

  /// Returns element-specific color if set, falling back to defaultColor or accentColor
  Color? getColorForComponent(String key, {Color? defaultColor}) {
    if (componentColors.containsKey(key) && componentColors[key] != null) {
      return componentColors[key];
    }
    if (key == 'title') {
      return titleTextColor ?? defaultColor;
    }
    if (key == 'synopsis') {
      return bodyTextColor ?? defaultColor;
    }
    return defaultColor ?? accentColor;
  }

  /// Immutably creates a new theme with font updated solely for the target element
  AnimeTemplateTheme copyWithComponentFont(String key, String fontFamily) {
    final updated = Map<String, String>.from(componentFonts);
    updated[key] = fontFamily;
    return copyWith(
      componentFonts: updated,
      titleFontFamily: key == 'title' ? fontFamily : null,
    );
  }

  /// Immutably creates a new theme with color updated solely for the target element
  AnimeTemplateTheme copyWithComponentColor(String key, Color? color) {
    final updated = Map<String, Color>.from(componentColors);
    if (color == null) {
      updated.remove(key);
    } else {
      updated[key] = color;
    }
    return copyWith(
      componentColors: updated,
      titleTextColor: key == 'title' ? color : null,
      clearTitleTextColor: key == 'title' && color == null,
      bodyTextColor: key == 'synopsis' ? color : null,
      clearBodyTextColor: key == 'synopsis' && color == null,
    );
  }

  /// Returns element-specific border/outline color if set, falling back to defaultColor
  Color? getBorderColorForComponent(String key, {Color? defaultColor}) {
    if (componentBorderColors.containsKey(key) && componentBorderColors[key] != null) {
      return componentBorderColors[key];
    }
    return defaultColor;
  }

  /// Returns element-specific border/outline width if set, falling back to defaultWidth
  double? getBorderWidthForComponent(String key, {double? defaultWidth}) {
    if (componentBorderWidths.containsKey(key) && componentBorderWidths[key] != null) {
      return componentBorderWidths[key];
    }
    return defaultWidth;
  }

  /// Immutably creates a new theme with border/outline color updated for the target element
  AnimeTemplateTheme copyWithComponentBorderColor(String key, Color? color) {
    final updated = Map<String, Color>.from(componentBorderColors);
    if (color == null) {
      updated.remove(key);
    } else {
      updated[key] = color;
    }
    return copyWith(componentBorderColors: updated);
  }

  /// Immutably creates a new theme with border/outline width updated for the target element
  AnimeTemplateTheme copyWithComponentBorderWidth(String key, double? width) {
    final updated = Map<String, double>.from(componentBorderWidths);
    if (width == null) {
      updated.remove(key);
    } else {
      updated[key] = width;
    }
    return copyWith(componentBorderWidths: updated);
  }

  /// Checks whether a text component is set to outline only (hollow text with no solid fill)
  bool isTextStrokeOnly(String key) {
    return componentTextStrokeOnly[key] ?? false;
  }

  /// Returns text outline stroke width for the target element
  double getTextStrokeWidth(String key, {double defaultWidth = 1.5}) {
    return componentTextStrokeWidths[key] ?? defaultWidth;
  }

  /// Returns text outline stroke color for the target element
  Color getTextStrokeColor(String key, {Color? defaultColor}) {
    return componentTextStrokeColors[key] ?? defaultColor ?? accentColor;
  }

  /// Immutably sets whether text fill is disabled (outline only) for a component
  AnimeTemplateTheme copyWithTextStrokeOnly(String key, bool? strokeOnly) {
    final updated = Map<String, bool>.from(componentTextStrokeOnly);
    if (strokeOnly == null) {
      updated.remove(key);
    } else {
      updated[key] = strokeOnly;
    }
    return copyWith(componentTextStrokeOnly: updated);
  }

  /// Immutably sets text outline stroke width for a component
  AnimeTemplateTheme copyWithTextStrokeWidth(String key, double? width) {
    final updated = Map<String, double>.from(componentTextStrokeWidths);
    if (width == null) {
      updated.remove(key);
    } else {
      updated[key] = width;
    }
    return copyWith(componentTextStrokeWidths: updated);
  }

  /// Immutably sets text outline stroke color for a component
  AnimeTemplateTheme copyWithTextStrokeColor(String key, Color? color) {
    final updated = Map<String, Color>.from(componentTextStrokeColors);
    if (color == null) {
      updated.remove(key);
    } else {
      updated[key] = color;
    }
    return copyWith(componentTextStrokeColors: updated);
  }

  AnimeTemplateTheme copyWithComponentTextStrokeOnly(String key, bool? strokeOnly) =>
      copyWithTextStrokeOnly(key, strokeOnly);

  AnimeTemplateTheme copyWithComponentTextStrokeWidth(String key, double? width) =>
      copyWithTextStrokeWidth(key, width);

  AnimeTemplateTheme copyWithComponentTextStrokeColor(String key, Color? color) =>
      copyWithTextStrokeColor(key, color);

  /// Returns element-specific background color if set
  Color? getBgColorForComponent(String key, {Color? defaultColor}) {
    return componentBgColors[key] ?? defaultColor;
  }

  /// Returns element-specific background opacity (0.0 to 1.0)
  double getBgOpacityForComponent(String key, {double defaultOpacity = 1.0}) {
    return componentBgOpacities[key] ?? defaultOpacity;
  }

  /// Returns effective background color computed from color and opacity
  Color? getEffectiveBgColor(String key, {Color? defaultColor}) {
    final baseColor = getBgColorForComponent(key, defaultColor: defaultColor);
    if (baseColor == null) return null;
    final opacity = getBgOpacityForComponent(key).clamp(0.0, 1.0);
    return baseColor.withValues(alpha: opacity);
  }

  /// Returns element-specific border radius / corner roundness
  double getBorderRadiusForComponent(String key, {double defaultRadius = 8.0}) {
    return componentBorderRadii[key] ?? defaultRadius;
  }

  /// Returns element-specific font size
  double getFontSizeForComponent(String key, {double defaultSize = 13.0}) {
    if (componentFontSizes.containsKey(key)) {
      return componentFontSizes[key]!;
    }
    if (key == 'title') return titleFontSize;
    if (key == 'synopsis') return bodyFontSize;
    return defaultSize;
  }

  /// Returns element-specific font weight
  FontWeight getFontWeightForComponent(String key, {FontWeight defaultWeight = FontWeight.w600}) {
    if (componentFontWeights.containsKey(key)) {
      final idx = componentFontWeights[key]!.clamp(0, FontWeight.values.length - 1);
      return FontWeight.values[idx];
    }
    if (key == 'title') return titleFontWeight;
    return defaultWeight;
  }

  /// Returns element-specific tracking / letter spacing
  double getLetterSpacingForComponent(String key, {double defaultSpacing = 0.0}) {
    return componentLetterSpacings[key] ?? defaultSpacing;
  }

  /// Returns element-specific padding
  double getPaddingForComponent(String key, {double defaultPadding = 8.0}) {
    return componentPaddings[key] ?? defaultPadding;
  }

  /// Returns whether element-specific drop shadow is enabled
  bool hasShadowForComponent(String key, {bool defaultShadow = false}) {
    return componentShadows[key] ?? defaultShadow;
  }

  AnimeTemplateTheme copyWithComponentBgColor(String key, Color? color) {
    final updated = Map<String, Color>.from(componentBgColors);
    if (color == null) {
      updated.remove(key);
    } else {
      updated[key] = color;
    }
    return copyWith(componentBgColors: updated);
  }

  AnimeTemplateTheme copyWithComponentBgOpacity(String key, double? opacity) {
    final updated = Map<String, double>.from(componentBgOpacities);
    if (opacity == null) {
      updated.remove(key);
    } else {
      updated[key] = opacity;
    }
    return copyWith(componentBgOpacities: updated);
  }

  AnimeTemplateTheme copyWithComponentBorderRadius(String key, double? radius) {
    final updated = Map<String, double>.from(componentBorderRadii);
    if (radius == null) {
      updated.remove(key);
    } else {
      updated[key] = radius;
    }
    return copyWith(componentBorderRadii: updated);
  }

  AnimeTemplateTheme copyWithComponentFontSize(String key, double? size) {
    final updated = Map<String, double>.from(componentFontSizes);
    if (size == null) {
      updated.remove(key);
    } else {
      updated[key] = size;
    }
    return copyWith(
      componentFontSizes: updated,
      titleFontSize: key == 'title' && size != null ? size : null,
      bodyFontSize: key == 'synopsis' && size != null ? size : null,
    );
  }

  AnimeTemplateTheme copyWithComponentFontWeight(String key, FontWeight? weight) {
    final updated = Map<String, int>.from(componentFontWeights);
    if (weight == null) {
      updated.remove(key);
    } else {
      updated[key] = FontWeight.values.indexOf(weight);
    }
    return copyWith(
      componentFontWeights: updated,
      titleFontWeight: key == 'title' && weight != null ? weight : null,
    );
  }

  AnimeTemplateTheme copyWithComponentLetterSpacing(String key, double? spacing) {
    final updated = Map<String, double>.from(componentLetterSpacings);
    if (spacing == null) {
      updated.remove(key);
    } else {
      updated[key] = spacing;
    }
    return copyWith(componentLetterSpacings: updated);
  }

  AnimeTemplateTheme copyWithComponentPadding(String key, double? padding) {
    final updated = Map<String, double>.from(componentPaddings);
    if (padding == null) {
      updated.remove(key);
    } else {
      updated[key] = padding;
    }
    return copyWith(componentPaddings: updated);
  }

  AnimeTemplateTheme copyWithComponentShadow(String key, bool? hasShadow) {
    final updated = Map<String, bool>.from(componentShadows);
    if (hasShadow == null) {
      updated.remove(key);
    } else {
      updated[key] = hasShadow;
    }
    return copyWith(componentShadows: updated);
  }

  /// Resets all element UI customization overrides back to default for the target component
  AnimeTemplateTheme resetComponentAllStyles(String key) {
    final fonts = Map<String, String>.from(componentFonts)..remove(key);
    final colors = Map<String, Color>.from(componentColors)..remove(key);
    final bgColors = Map<String, Color>.from(componentBgColors)..remove(key);
    final bgOpacities = Map<String, double>.from(componentBgOpacities)..remove(key);
    final borderColors = Map<String, Color>.from(componentBorderColors)..remove(key);
    final borderWidths = Map<String, double>.from(componentBorderWidths)..remove(key);
    final borderRadii = Map<String, double>.from(componentBorderRadii)..remove(key);
    final fontSizes = Map<String, double>.from(componentFontSizes)..remove(key);
    final fontWeights = Map<String, int>.from(componentFontWeights)..remove(key);
    final letterSpacings = Map<String, double>.from(componentLetterSpacings)..remove(key);
    final paddings = Map<String, double>.from(componentPaddings)..remove(key);
    final shadows = Map<String, bool>.from(componentShadows)..remove(key);
    final textStrokeOnly = Map<String, bool>.from(componentTextStrokeOnly)..remove(key);
    final textStrokeWidths = Map<String, double>.from(componentTextStrokeWidths)..remove(key);
    final textStrokeColors = Map<String, Color>.from(componentTextStrokeColors)..remove(key);

    return copyWith(
      componentFonts: fonts,
      componentColors: colors,
      componentBgColors: bgColors,
      componentBgOpacities: bgOpacities,
      componentBorderColors: borderColors,
      componentBorderWidths: borderWidths,
      componentBorderRadii: borderRadii,
      componentFontSizes: fontSizes,
      componentFontWeights: fontWeights,
      componentLetterSpacings: letterSpacings,
      componentPaddings: paddings,
      componentShadows: shadows,
      componentTextStrokeOnly: textStrokeOnly,
      componentTextStrokeWidths: textStrokeWidths,
      componentTextStrokeColors: textStrokeColors,
      clearTitleTextColor: key == 'title',
      clearBodyTextColor: key == 'synopsis',
    );
  }

  /// Checks whether a slide component is currently enabled based on theme visibility toggles
  bool isComponentEnabled(String componentKey) {
    switch (componentKey) {
      case 'allContent':
        return true;
      case 'title':
        return true;
      case 'rankBadge':
        return showRankBadge;
      case 'rating':
        return showRating;
      case 'seasons':
        return showSeasons;
      case 'episodes':
        return showEpisodes;
      case 'studio':
        return showStudio;
      case 'genres':
        return showGenres;
      case 'synopsis':
        return showSynopsis;
      case 'japaneseTitle':
        return showJapaneseTitle;
      case 'hookTag':
        return showHookTag;
      case 'pageHandle':
        return showWatermark;
      case 'slideCounter':
        return showSlideCounter;
      case 'swipeIndicator':
        return showSwipeIndicator;
      default:
        return true;
    }
  }

  AnimeTemplateTheme copyWith({
    CardStyle? cardStyle,
    bool? showCardBackdrop,
    SlideLayout? slideLayout,
    AspectRatioPreset? aspectRatio,
    AspectRatioPreset? aspectRatioPreset,
    Color? canvasBgColor,
    Color? accentColor,
    Color? cardBgColor,
    double? cardOpacity,
    double? cardBlur,
    double? backgroundBlur,
    double? cardBorderRadius,
    double? cardBorderWidth,
    Color? cardBorderColor,
    bool clearCardBorderColor = false,
    bool? showCardBorder,
    double? gradientDarkness,
    String? titleFontFamily,
    String? bodyFontFamily,
    double? titleFontSize,
    double? bodyFontSize,
    FontWeight? titleFontWeight,
    Color? titleTextColor,
    bool clearTitleTextColor = false,
    Color? bodyTextColor,
    bool clearBodyTextColor = false,
    Map<String, String>? componentFonts,
    Map<String, Color>? componentColors,
    Map<String, Color>? componentBgColors,
    Map<String, double>? componentBgOpacities,
    Map<String, Color>? componentBorderColors,
    Map<String, double>? componentBorderWidths,
    Map<String, double>? componentBorderRadii,
    Map<String, double>? componentFontSizes,
    Map<String, int>? componentFontWeights,
    Map<String, double>? componentLetterSpacings,
    Map<String, double>? componentPaddings,
    Map<String, bool>? componentShadows,
    Map<String, bool>? componentTextStrokeOnly,
    Map<String, double>? componentTextStrokeWidths,
    Map<String, Color>? componentTextStrokeColors,
    HandleStyle? handleStyle,
    SlideCounterStyle? counterStyle,
    GenreStyle? genreStyle,
    HookTagStyle? tagStyle,
    RankBadgeStyle? rankBadgeStyle,
    MetadataPillStyle? metadataPillStyle,
    SynopsisCardStyle? synopsisCardStyle,
    TitleCardStyle? titleCardStyle,
    bool? showRankBadge,
    bool? showRating,
    bool? showSeasons,
    bool? showEpisodes,
    bool? showStudio,
    bool? showGenres,
    bool? showSynopsis,
    bool? showSlideCounter,
    bool? showHookTag,
    bool? showSwipeIndicator,
    bool? showJapaneseTitle,
    bool? syncAnimeSlideLayoutAndPosition,
    bool? enableAmbientGlow,
    double? ambientGlowIntensity,
    double? ambientGlowBlur,
    double? ambientGlowSpread,
    bool? enableFilmGrain,
    double? filmGrainIntensity,
    bool? enableVignette,
    double? vignetteIntensity,
    bool? showWatermark,
    String? watermarkHandle,
    String? watermarkText,
    String? watermarkLogoPath,
    bool? isVerified,
  }) {
    final effectiveWatermark = watermarkText != null
        ? (watermarkText.startsWith('@') ? watermarkText : '@$watermarkText')
        : (watermarkHandle ?? this.watermarkHandle);

    return AnimeTemplateTheme(
      cardStyle: cardStyle ?? this.cardStyle,
      showCardBackdrop: showCardBackdrop ?? this.showCardBackdrop,
      slideLayout: slideLayout ?? this.slideLayout,
      aspectRatio: aspectRatioPreset ?? aspectRatio ?? this.aspectRatio,
      canvasBgColor: canvasBgColor ?? this.canvasBgColor,
      accentColor: accentColor ?? this.accentColor,
      cardBgColor: cardBgColor ?? this.cardBgColor,
      cardOpacity: cardOpacity ?? this.cardOpacity,
      cardBlur: cardBlur ?? this.cardBlur,
      backgroundBlur: backgroundBlur ?? this.backgroundBlur,
      cardBorderRadius: cardBorderRadius ?? this.cardBorderRadius,
      cardBorderWidth: cardBorderWidth ?? this.cardBorderWidth,
      cardBorderColor: clearCardBorderColor ? null : (cardBorderColor ?? this.cardBorderColor),
      showCardBorder: showCardBorder ?? this.showCardBorder,
      gradientDarkness: gradientDarkness ?? this.gradientDarkness,
      titleFontFamily: titleFontFamily ?? this.titleFontFamily,
      bodyFontFamily: bodyFontFamily ?? this.bodyFontFamily,
      titleFontSize: titleFontSize ?? this.titleFontSize,
      bodyFontSize: bodyFontSize ?? this.bodyFontSize,
      titleFontWeight: titleFontWeight ?? this.titleFontWeight,
      titleTextColor: clearTitleTextColor ? null : (titleTextColor ?? this.titleTextColor),
      bodyTextColor: clearBodyTextColor ? null : (bodyTextColor ?? this.bodyTextColor),
      componentFonts: componentFonts ?? this.componentFonts,
      componentColors: componentColors ?? this.componentColors,
      componentBgColors: componentBgColors ?? this.componentBgColors,
      componentBgOpacities: componentBgOpacities ?? this.componentBgOpacities,
      componentBorderColors: componentBorderColors ?? this.componentBorderColors,
      componentBorderWidths: componentBorderWidths ?? this.componentBorderWidths,
      componentBorderRadii: componentBorderRadii ?? this.componentBorderRadii,
      componentFontSizes: componentFontSizes ?? this.componentFontSizes,
      componentFontWeights: componentFontWeights ?? this.componentFontWeights,
      componentLetterSpacings: componentLetterSpacings ?? this.componentLetterSpacings,
      componentPaddings: componentPaddings ?? this.componentPaddings,
      componentShadows: componentShadows ?? this.componentShadows,
      componentTextStrokeOnly: componentTextStrokeOnly ?? this.componentTextStrokeOnly,
      componentTextStrokeWidths: componentTextStrokeWidths ?? this.componentTextStrokeWidths,
      componentTextStrokeColors: componentTextStrokeColors ?? this.componentTextStrokeColors,
      handleStyle: handleStyle ?? this.handleStyle,
      counterStyle: counterStyle ?? this.counterStyle,
      genreStyle: genreStyle ?? this.genreStyle,
      tagStyle: tagStyle ?? this.tagStyle,
      rankBadgeStyle: rankBadgeStyle ?? this.rankBadgeStyle,
      metadataPillStyle: metadataPillStyle ?? this.metadataPillStyle,
      synopsisCardStyle: synopsisCardStyle ?? this.synopsisCardStyle,
      titleCardStyle: titleCardStyle ?? this.titleCardStyle,
      showRankBadge: showRankBadge ?? this.showRankBadge,
      showRating: showRating ?? this.showRating,
      showSeasons: showSeasons ?? this.showSeasons,
      showEpisodes: showEpisodes ?? this.showEpisodes,
      showStudio: showStudio ?? this.showStudio,
      showGenres: showGenres ?? this.showGenres,
      showSynopsis: showSynopsis ?? this.showSynopsis,
      showSlideCounter: showSlideCounter ?? this.showSlideCounter,
      showHookTag: showHookTag ?? this.showHookTag,
      showSwipeIndicator: showSwipeIndicator ?? this.showSwipeIndicator,
      showJapaneseTitle: showJapaneseTitle ?? this.showJapaneseTitle,
      syncAnimeSlideLayoutAndPosition: syncAnimeSlideLayoutAndPosition ?? this.syncAnimeSlideLayoutAndPosition,
      enableAmbientGlow: enableAmbientGlow ?? this.enableAmbientGlow,
      ambientGlowIntensity: ambientGlowIntensity ?? this.ambientGlowIntensity,
      ambientGlowBlur: ambientGlowBlur ?? this.ambientGlowBlur,
      ambientGlowSpread: ambientGlowSpread ?? this.ambientGlowSpread,
      enableFilmGrain: enableFilmGrain ?? this.enableFilmGrain,
      filmGrainIntensity: filmGrainIntensity ?? this.filmGrainIntensity,
      enableVignette: enableVignette ?? this.enableVignette,
      vignetteIntensity: vignetteIntensity ?? this.vignetteIntensity,
      showWatermark: showWatermark ?? this.showWatermark,
      watermarkHandle: effectiveWatermark,
      watermarkLogoPath: watermarkLogoPath ?? this.watermarkLogoPath,
      isVerified: isVerified ?? this.isVerified,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'cardStyle': cardStyle.name,
      'showCardBackdrop': showCardBackdrop,
      'slideLayout': slideLayout.name,
      'aspectRatio': aspectRatio.name,
      'canvasBgColor': canvasBgColor.toARGB32(),
      'accentColor': accentColor.toARGB32(),
      'cardBgColor': cardBgColor.toARGB32(),
      'cardOpacity': cardOpacity,
      'cardBlur': cardBlur,
      'backgroundBlur': backgroundBlur,
      'cardBorderRadius': cardBorderRadius,
      'cardBorderWidth': cardBorderWidth,
      'cardBorderColor': cardBorderColor?.toARGB32(),
      'showCardBorder': showCardBorder,
      'gradientDarkness': gradientDarkness,
      'titleFontFamily': titleFontFamily,
      'bodyFontFamily': bodyFontFamily,
      'titleFontSize': titleFontSize,
      'bodyFontSize': bodyFontSize,
      'titleFontWeight': titleFontWeight.value,
      'titleTextColor': titleTextColor?.toARGB32(),
      'bodyTextColor': bodyTextColor?.toARGB32(),
      'componentFonts': componentFonts,
      'componentColors': componentColors.map((k, v) => MapEntry(k, v.toARGB32())),
      'componentBgColors': componentBgColors.map((k, v) => MapEntry(k, v.toARGB32())),
      'componentBgOpacities': componentBgOpacities,
      'componentBorderColors': componentBorderColors.map((k, v) => MapEntry(k, v.toARGB32())),
      'componentBorderWidths': componentBorderWidths,
      'componentBorderRadii': componentBorderRadii,
      'componentFontSizes': componentFontSizes,
      'componentFontWeights': componentFontWeights,
      'componentLetterSpacings': componentLetterSpacings,
      'componentPaddings': componentPaddings,
      'componentShadows': componentShadows,
      'componentTextStrokeOnly': componentTextStrokeOnly,
      'componentTextStrokeWidths': componentTextStrokeWidths,
      'componentTextStrokeColors': componentTextStrokeColors.map((k, v) => MapEntry(k, v.toARGB32())),
      'handleStyle': handleStyle.name,
      'counterStyle': counterStyle.name,
      'genreStyle': genreStyle.name,
      'tagStyle': tagStyle.name,
      'rankBadgeStyle': rankBadgeStyle.name,
      'metadataPillStyle': metadataPillStyle.name,
      'synopsisCardStyle': synopsisCardStyle.name,
      'titleCardStyle': titleCardStyle.name,
      'showRankBadge': showRankBadge,
      'showRating': showRating,
      'showSeasons': showSeasons,
      'showEpisodes': showEpisodes,
      'showStudio': showStudio,
      'showGenres': showGenres,
      'showSynopsis': showSynopsis,
      'showSlideCounter': showSlideCounter,
      'showHookTag': showHookTag,
      'showSwipeIndicator': showSwipeIndicator,
      'showJapaneseTitle': showJapaneseTitle,
      'syncAnimeSlideLayoutAndPosition': syncAnimeSlideLayoutAndPosition,
      'enableAmbientGlow': enableAmbientGlow,
      'ambientGlowIntensity': ambientGlowIntensity,
      'ambientGlowBlur': ambientGlowBlur,
      'ambientGlowSpread': ambientGlowSpread,
      'enableFilmGrain': enableFilmGrain,
      'filmGrainIntensity': filmGrainIntensity,
      'enableVignette': enableVignette,
      'vignetteIntensity': vignetteIntensity,
      'showWatermark': showWatermark,
      'watermarkHandle': watermarkHandle,
      'watermarkLogoPath': watermarkLogoPath,
      'isVerified': isVerified,
    };
  }

  factory AnimeTemplateTheme.fromMap(Map<String, dynamic> map) {
    return AnimeTemplateTheme(
      cardStyle: CardStyle.values.firstWhere(
        (e) => e.name == map['cardStyle'],
        orElse: () => CardStyle.none,
      ),
      showCardBackdrop: map['showCardBackdrop'] as bool? ?? false,
      slideLayout: () {
        final layoutStr = map['slideLayout'] as String?;
        if (layoutStr == 'showcaseGallery') return SlideLayout.layout1;
        if (layoutStr == 'boldHeadline') return SlideLayout.layout2;
        if (layoutStr == 'floatingPoster') return SlideLayout.layout3;
        return SlideLayout.values.firstWhere(
          (e) => e.name == layoutStr,
          orElse: () => SlideLayout.defaultLayout,
        );
      }(),
      aspectRatio: AspectRatioPreset.values.firstWhere(
        (e) => e.name == map['aspectRatio'],
        orElse: () => AspectRatioPreset.portrait4x5,
      ),
      canvasBgColor: Color(map['canvasBgColor'] as int? ?? 0xFFFFFFFF),
      accentColor: Color(map['accentColor'] as int? ?? 0xFFFF3366),
      cardBgColor: Color(map['cardBgColor'] as int? ?? 0xFF0D0D12),
      cardOpacity: (map['cardOpacity'] as num?)?.toDouble() ?? 0.85,
      cardBlur: (map['cardBlur'] as num?)?.toDouble() ?? 12.0,
      backgroundBlur: (map['backgroundBlur'] as num?)?.toDouble() ?? 0.0,
      cardBorderRadius: (map['cardBorderRadius'] as num?)?.toDouble() ?? 18.0,
      cardBorderWidth: (map['cardBorderWidth'] as num?)?.toDouble() ?? 1.0,
      cardBorderColor: map['cardBorderColor'] != null ? Color(map['cardBorderColor'] as int) : null,
      showCardBorder: map['showCardBorder'] as bool? ?? true,
      gradientDarkness: (map['gradientDarkness'] as num?)?.toDouble() ?? 0.75,
      titleFontFamily: map['titleFontFamily'] as String? ?? 'Poppins',
      bodyFontFamily: map['bodyFontFamily'] as String? ?? 'Poppins',
      titleFontSize: (map['titleFontSize'] as num?)?.toDouble() ?? 20.0,
      bodyFontSize: (map['bodyFontSize'] as num?)?.toDouble() ?? 11.5,
      titleFontWeight: map['titleFontWeight'] != null
          ? (FontWeight.values.cast<FontWeight?>().firstWhere(
              (fw) => fw?.value == map['titleFontWeight'],
              orElse: () => (map['titleFontWeight'] is int && (map['titleFontWeight'] as int) < FontWeight.values.length
                  ? FontWeight.values[map['titleFontWeight'] as int]
                  : FontWeight.w800),
            ) ?? FontWeight.w800)
          : FontWeight.w800,
      titleTextColor: map['titleTextColor'] != null ? Color(map['titleTextColor'] as int) : null,
      bodyTextColor: map['bodyTextColor'] != null ? Color(map['bodyTextColor'] as int) : null,
      componentFonts: (map['componentFonts'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v.toString()),
          ) ?? const {},
      componentColors: (map['componentColors'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, Color(v as int)),
          ) ?? const {},
      componentBgColors: (map['componentBgColors'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, Color(v as int)),
          ) ?? const {},
      componentBgOpacities: (map['componentBgOpacities'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ) ?? const {},
      componentBorderColors: (map['componentBorderColors'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, Color(v as int)),
          ) ?? const {},
      componentBorderWidths: (map['componentBorderWidths'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ) ?? const {},
      componentBorderRadii: (map['componentBorderRadii'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ) ?? const {},
      componentFontSizes: (map['componentFontSizes'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ) ?? const {},
      componentFontWeights: (map['componentFontWeights'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toInt()),
          ) ?? const {},
      componentLetterSpacings: (map['componentLetterSpacings'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ) ?? const {},
      componentPaddings: (map['componentPaddings'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ) ?? const {},
      componentShadows: (map['componentShadows'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v as bool),
          ) ?? const {},
      componentTextStrokeOnly: (map['componentTextStrokeOnly'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v as bool),
          ) ?? const {},
      componentTextStrokeWidths: (map['componentTextStrokeWidths'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ) ?? const {},
      componentTextStrokeColors: (map['componentTextStrokeColors'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, Color(v as int)),
          ) ?? const {},
      handleStyle: HandleStyle.values.firstWhere(
        (e) => e.name == map['handleStyle'],
        orElse: () => HandleStyle.pillBadge,
      ),
      counterStyle: SlideCounterStyle.values.firstWhere(
        (e) => e.name == map['counterStyle'],
        orElse: () => SlideCounterStyle.fractionPill,
      ),
      genreStyle: GenreStyle.values.firstWhere(
        (e) => e.name == map['genreStyle'],
        orElse: () => GenreStyle.pills,
      ),
      tagStyle: HookTagStyle.values.firstWhere(
        (e) => e.name == map['tagStyle'],
        orElse: () => HookTagStyle.neonGlow,
      ),
      rankBadgeStyle: RankBadgeStyle.values.firstWhere(
        (e) => e.name == map['rankBadgeStyle'],
        orElse: () => RankBadgeStyle.modernGradient,
      ),
      metadataPillStyle: MetadataPillStyle.values.firstWhere(
        (e) => e.name == map['metadataPillStyle'],
        orElse: () => MetadataPillStyle.frostedGlass,
      ),
      synopsisCardStyle: SynopsisCardStyle.values.firstWhere(
        (e) => e.name == map['synopsisCardStyle'],
        orElse: () => SynopsisCardStyle.accentBorderLeft,
      ),
      titleCardStyle: TitleCardStyle.values.firstWhere(
        (e) => e.name == map['titleCardStyle'],
        orElse: () => TitleCardStyle.pureText,
      ),
      showRankBadge: map['showRankBadge'] as bool? ?? false,
      showRating: map['showRating'] as bool? ?? false,
      showSeasons: map['showSeasons'] as bool? ?? false,
      showEpisodes: map['showEpisodes'] as bool? ?? true,
      showStudio: map['showStudio'] as bool? ?? false,
      showGenres: map['showGenres'] as bool? ?? false,
      showSynopsis: map['showSynopsis'] as bool? ?? false,
      showSlideCounter: map['showSlideCounter'] as bool? ?? false,
      showHookTag: map['showHookTag'] as bool? ?? false,
      showSwipeIndicator: map['showSwipeIndicator'] as bool? ?? false,
      showJapaneseTitle: map['showJapaneseTitle'] as bool? ?? false,
      syncAnimeSlideLayoutAndPosition: map['syncAnimeSlideLayoutAndPosition'] as bool? ?? true,
      enableAmbientGlow: map['enableAmbientGlow'] as bool? ?? true,
      ambientGlowIntensity: (map['ambientGlowIntensity'] as num?)?.toDouble() ?? 0.45,
      ambientGlowBlur: (map['ambientGlowBlur'] as num?)?.toDouble() ?? 28.0,
      ambientGlowSpread: (map['ambientGlowSpread'] as num?)?.toDouble() ?? 8.0,
      enableFilmGrain: map['enableFilmGrain'] as bool? ?? false,
      filmGrainIntensity: (map['filmGrainIntensity'] as num?)?.toDouble() ?? 0.05,
      enableVignette: map['enableVignette'] as bool? ?? false,
      vignetteIntensity: (map['vignetteIntensity'] as num?)?.toDouble() ?? 0.35,
      showWatermark: map['showWatermark'] as bool? ?? false,
      watermarkHandle: map['watermarkHandle'] as String? ?? '@app.quickpost',
      watermarkLogoPath: map['watermarkLogoPath'] as String?,
      isVerified: map['isVerified'] as bool? ?? true,
    );
  }

  String toJson() => json.encode(toMap());

  factory AnimeTemplateTheme.fromJson(String source) =>
      AnimeTemplateTheme.fromMap(json.decode(source) as Map<String, dynamic>);
}
