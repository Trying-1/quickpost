import 'dart:convert';
import 'package:flutter/material.dart';
import 'anime_template_theme.dart';

/// Represents a user-created, reusable layout configuration
/// storing element coordinates, offsets, visibility toggles, and card styling.
class AnimeCustomLayout {
  final String id;
  final String name;
  final DateTime createdAt;

  // Group offsets
  final double contentOffsetX;
  final double contentOffsetY;
  final double headerOffsetY;

  // Individual component coordinates (componentId -> Offset)
  final Map<String, Offset> componentOffsets;

  // Element visibility flags
  final bool showRankBadge;
  final bool showRating;
  final bool showSeasons;
  final bool showEpisodes;
  final bool showStudio;
  final bool showGenres;
  final bool showSynopsis;
  final bool showWatermark;
  final bool showSlideCounter;
  final bool showHookTag;
  final bool showJapaneseTitle;

  // Card & element styling
  final SlideLayout slideLayout;
  final CardStyle cardStyle;
  final bool showCardBackdrop;
  final bool showCardBorder;
  final RankBadgeStyle rankBadgeStyle;
  final MetadataPillStyle metadataPillStyle;
  final SynopsisCardStyle synopsisCardStyle;
  final TitleCardStyle titleCardStyle;
  // Element font & color overrides
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

  // Atmospheric & Lighting Effects
  final bool enableAmbientGlow;
  final double ambientGlowIntensity;
  final double ambientGlowBlur;
  final double ambientGlowSpread;
  final bool enableFilmGrain;
  final double filmGrainIntensity;
  final bool enableVignette;
  final double vignetteIntensity;

  const AnimeCustomLayout({
    required this.id,
    required this.name,
    required this.createdAt,
    this.contentOffsetX = 0.0,
    this.contentOffsetY = 0.0,
    this.headerOffsetY = 0.0,
    this.componentOffsets = const {},
    this.showRankBadge = false,
    this.showRating = false,
    this.showSeasons = false,
    this.showEpisodes = true,
    this.showStudio = false,
    this.showGenres = false,
    this.showSynopsis = false,
    this.showWatermark = false,
    this.showSlideCounter = false,
    this.showHookTag = false,
    this.showJapaneseTitle = false,
    this.slideLayout = SlideLayout.defaultLayout,
    this.cardStyle = CardStyle.none,
    this.showCardBackdrop = false,
    this.showCardBorder = true,
    this.rankBadgeStyle = RankBadgeStyle.modernGradient,
    this.metadataPillStyle = MetadataPillStyle.frostedGlass,
    this.synopsisCardStyle = SynopsisCardStyle.accentBorderLeft,
    this.titleCardStyle = TitleCardStyle.pureText,
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
    this.enableAmbientGlow = true,
    this.ambientGlowIntensity = 0.45,
    this.ambientGlowBlur = 28.0,
    this.ambientGlowSpread = 8.0,
    this.enableFilmGrain = false,
    this.filmGrainIntensity = 0.05,
    this.enableVignette = false,
    this.vignetteIntensity = 0.35,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'contentOffsetX': contentOffsetX,
      'contentOffsetY': contentOffsetY,
      'headerOffsetY': headerOffsetY,
      'componentOffsets': componentOffsets.map(
        (key, offset) => MapEntry(key, {'dx': offset.dx, 'dy': offset.dy}),
      ),
      'showRankBadge': showRankBadge,
      'showRating': showRating,
      'showSeasons': showSeasons,
      'showEpisodes': showEpisodes,
      'showStudio': showStudio,
      'showGenres': showGenres,
      'showSynopsis': showSynopsis,
      'showWatermark': showWatermark,
      'showSlideCounter': showSlideCounter,
      'showHookTag': showHookTag,
      'showJapaneseTitle': showJapaneseTitle,
      'slideLayout': slideLayout.name,
      'cardStyle': cardStyle.name,
      'showCardBackdrop': showCardBackdrop,
      'showCardBorder': showCardBorder,
      'rankBadgeStyle': rankBadgeStyle.name,
      'metadataPillStyle': metadataPillStyle.name,
      'synopsisCardStyle': synopsisCardStyle.name,
      'titleCardStyle': titleCardStyle.name,
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
      'enableAmbientGlow': enableAmbientGlow,
      'ambientGlowIntensity': ambientGlowIntensity,
      'ambientGlowBlur': ambientGlowBlur,
      'ambientGlowSpread': ambientGlowSpread,
      'enableFilmGrain': enableFilmGrain,
      'filmGrainIntensity': filmGrainIntensity,
      'enableVignette': enableVignette,
      'vignetteIntensity': vignetteIntensity,
    };
  }

  factory AnimeCustomLayout.fromMap(Map<String, dynamic> map) {
    Map<String, Offset> offsets = {};
    if (map['componentOffsets'] != null && map['componentOffsets'] is Map) {
      (map['componentOffsets'] as Map).forEach((k, v) {
        if (v is Map) {
          final dx = (v['dx'] as num?)?.toDouble() ?? 0.0;
          final dy = (v['dy'] as num?)?.toDouble() ?? 0.0;
          offsets[k.toString()] = Offset(dx, dy);
        }
      });
    }

    return AnimeCustomLayout(
      id: map['id'] as String? ?? 'layout_${DateTime.now().millisecondsSinceEpoch}',
      name: map['name'] as String? ?? 'Untitled Layout',
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
          : DateTime.now(),
      contentOffsetX: (map['contentOffsetX'] as num?)?.toDouble() ?? 0.0,
      contentOffsetY: (map['contentOffsetY'] as num?)?.toDouble() ?? 0.0,
      headerOffsetY: (map['headerOffsetY'] as num?)?.toDouble() ?? 0.0,
      componentOffsets: offsets,
      showRankBadge: map['showRankBadge'] as bool? ?? false,
      showRating: map['showRating'] as bool? ?? false,
      showSeasons: map['showSeasons'] as bool? ?? false,
      showEpisodes: map['showEpisodes'] as bool? ?? true,
      showStudio: map['showStudio'] as bool? ?? false,
      showGenres: map['showGenres'] as bool? ?? false,
      showSynopsis: map['showSynopsis'] as bool? ?? false,
      showWatermark: map['showWatermark'] as bool? ?? false,
      showSlideCounter: map['showSlideCounter'] as bool? ?? false,
      showHookTag: map['showHookTag'] as bool? ?? false,
      showJapaneseTitle: map['showJapaneseTitle'] as bool? ?? false,
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
      cardStyle: CardStyle.values.firstWhere(
        (e) => e.name == map['cardStyle'],
        orElse: () => CardStyle.none,
      ),
      showCardBackdrop: map['showCardBackdrop'] as bool? ?? false,
      showCardBorder: map['showCardBorder'] as bool? ?? true,
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
      enableAmbientGlow: map['enableAmbientGlow'] as bool? ?? true,
      ambientGlowIntensity: (map['ambientGlowIntensity'] as num?)?.toDouble() ?? 0.45,
      ambientGlowBlur: (map['ambientGlowBlur'] as num?)?.toDouble() ?? 28.0,
      ambientGlowSpread: (map['ambientGlowSpread'] as num?)?.toDouble() ?? 8.0,
      enableFilmGrain: map['enableFilmGrain'] as bool? ?? false,
      filmGrainIntensity: (map['filmGrainIntensity'] as num?)?.toDouble() ?? 0.05,
      enableVignette: map['enableVignette'] as bool? ?? false,
      vignetteIntensity: (map['vignetteIntensity'] as num?)?.toDouble() ?? 0.35,
    );
  }

  String toJson() => json.encode(toMap());

  factory AnimeCustomLayout.fromJson(String source) =>
      AnimeCustomLayout.fromMap(json.decode(source) as Map<String, dynamic>);
}
