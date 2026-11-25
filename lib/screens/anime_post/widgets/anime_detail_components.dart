import 'package:flutter/material.dart';
import '../models/anime_template_theme.dart';
import 'anime_metadata_pill.dart';
import 'preview/outlined_text.dart';

/// Individual modular component for displaying Anime Rating (e.g. ⭐ 8.9 / 10).
/// Can be placed anywhere individually in any slide layout.
class AnimeRatingComponent extends StatelessWidget {
  final String rating;
  final Color accentColor;
  final String? fontFamily;
  final MetadataPillStyle style;
  final bool isDarkBackground;
  final bool isGlass;
  final bool isVisible;
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

  const AnimeRatingComponent({
    super.key,
    required this.rating,
    this.accentColor = const Color(0xFFFFB800),
    this.fontFamily,
    this.style = MetadataPillStyle.frostedGlass,
    this.isDarkBackground = true,
    this.isGlass = true,
    this.isVisible = true,
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

  factory AnimeRatingComponent.fromTheme({
    Key? key,
    required String rating,
    required AnimeTemplateTheme theme,
    required bool isDarkBackground,
  }) {
    return AnimeRatingComponent(
      key: key,
      rating: rating,
      accentColor: theme.getColorForComponent('rating', defaultColor: const Color(0xFFFFB800))!,
      fontFamily: theme.getFontForComponent('rating', defaultFont: theme.bodyFontFamily),
      style: theme.metadataPillStyle,
      isDarkBackground: isDarkBackground,
      isVisible: theme.showRating,
      customBorderColor: theme.getBorderColorForComponent('rating'),
      customBorderWidth: theme.getBorderWidthForComponent('rating'),
      customBgColor: theme.getBgColorForComponent('rating'),
      customBgOpacity: theme.getBgOpacityForComponent('rating'),
      customBorderRadius: theme.getBorderRadiusForComponent('rating'),
      customFontSize: theme.getFontSizeForComponent('rating'),
      customFontWeight: theme.getFontWeightForComponent('rating'),
      customLetterSpacing: theme.getLetterSpacingForComponent('rating'),
      customPadding: theme.getPaddingForComponent('rating'),
      customShadow: theme.hasShadowForComponent('rating'),
      customTextColor: theme.getColorForComponent('rating'),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isVisible || rating.trim().isEmpty) return const SizedBox.shrink();

    return AnimeMetadataPill(
      icon: Icons.star_rounded,
      label: rating,
      iconColor: const Color(0xFFFFB800),
      accentColor: accentColor,
      fontFamily: fontFamily,
      style: style,
      isGlass: isGlass,
      isDarkBackground: isDarkBackground,
      customBorderColor: customBorderColor,
      customBorderWidth: customBorderWidth,
      customBgColor: customBgColor,
      customBgOpacity: customBgOpacity,
      customBorderRadius: customBorderRadius,
      customFontSize: customFontSize,
      customFontWeight: customFontWeight,
      customLetterSpacing: customLetterSpacing,
      customPadding: customPadding,
      customShadow: customShadow,
      customTextColor: customTextColor,
    );
  }
}

/// Individual modular component for displaying Total Seasons (e.g. 4 Seasons).
/// Can be placed anywhere individually in any slide layout.
class AnimeSeasonsComponent extends StatelessWidget {
  final String seasons;
  final Color accentColor;
  final String? fontFamily;
  final MetadataPillStyle style;
  final bool isDarkBackground;
  final bool isGlass;
  final bool isVisible;
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

  const AnimeSeasonsComponent({
    super.key,
    required this.seasons,
    this.accentColor = const Color(0xFFFF3366),
    this.fontFamily,
    this.style = MetadataPillStyle.frostedGlass,
    this.isDarkBackground = true,
    this.isGlass = true,
    this.isVisible = true,
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

  factory AnimeSeasonsComponent.fromTheme({
    Key? key,
    required String seasons,
    required AnimeTemplateTheme theme,
    required bool isDarkBackground,
  }) {
    return AnimeSeasonsComponent(
      key: key,
      seasons: seasons,
      accentColor: theme.getColorForComponent('seasons', defaultColor: theme.accentColor)!,
      fontFamily: theme.getFontForComponent('seasons', defaultFont: theme.bodyFontFamily),
      style: theme.metadataPillStyle,
      isDarkBackground: isDarkBackground,
      isVisible: theme.showSeasons,
      customBorderColor: theme.getBorderColorForComponent('seasons'),
      customBorderWidth: theme.getBorderWidthForComponent('seasons'),
      customBgColor: theme.getBgColorForComponent('seasons'),
      customBgOpacity: theme.getBgOpacityForComponent('seasons'),
      customBorderRadius: theme.getBorderRadiusForComponent('seasons'),
      customFontSize: theme.getFontSizeForComponent('seasons'),
      customFontWeight: theme.getFontWeightForComponent('seasons'),
      customLetterSpacing: theme.getLetterSpacingForComponent('seasons'),
      customPadding: theme.getPaddingForComponent('seasons'),
      customShadow: theme.hasShadowForComponent('seasons'),
      customTextColor: theme.getColorForComponent('seasons'),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isVisible || seasons.trim().isEmpty) return const SizedBox.shrink();

    return AnimeMetadataPill(
      icon: Icons.layers_rounded,
      label: seasons,
      accentColor: accentColor,
      fontFamily: fontFamily,
      style: style,
      isGlass: isGlass,
      isDarkBackground: isDarkBackground,
      customBorderColor: customBorderColor,
      customBorderWidth: customBorderWidth,
      customBgColor: customBgColor,
      customBgOpacity: customBgOpacity,
      customBorderRadius: customBorderRadius,
      customFontSize: customFontSize,
      customFontWeight: customFontWeight,
      customLetterSpacing: customLetterSpacing,
      customPadding: customPadding,
      customShadow: customShadow,
      customTextColor: customTextColor,
    );
  }
}

/// Individual modular component for displaying Total Episodes (e.g. 55 Episodes).
/// Can be placed anywhere individually in any slide layout.
class AnimeEpisodesComponent extends StatelessWidget {
  final String episodes;
  final Color accentColor;
  final String? fontFamily;
  final MetadataPillStyle style;
  final bool isDarkBackground;
  final bool isGlass;
  final bool isVisible;
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

  const AnimeEpisodesComponent({
    super.key,
    required this.episodes,
    this.accentColor = const Color(0xFFFF3366),
    this.fontFamily,
    this.style = MetadataPillStyle.frostedGlass,
    this.isDarkBackground = true,
    this.isGlass = true,
    this.isVisible = true,
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

  factory AnimeEpisodesComponent.fromTheme({
    Key? key,
    required String episodes,
    required AnimeTemplateTheme theme,
    required bool isDarkBackground,
  }) {
    return AnimeEpisodesComponent(
      key: key,
      episodes: episodes,
      accentColor: theme.getColorForComponent('episodes', defaultColor: theme.accentColor)!,
      fontFamily: theme.getFontForComponent('episodes', defaultFont: theme.bodyFontFamily),
      style: theme.metadataPillStyle,
      isDarkBackground: isDarkBackground,
      isVisible: theme.showEpisodes,
      customBorderColor: theme.getBorderColorForComponent('episodes'),
      customBorderWidth: theme.getBorderWidthForComponent('episodes'),
      customBgColor: theme.getBgColorForComponent('episodes'),
      customBgOpacity: theme.getBgOpacityForComponent('episodes'),
      customBorderRadius: theme.getBorderRadiusForComponent('episodes'),
      customFontSize: theme.getFontSizeForComponent('episodes'),
      customFontWeight: theme.getFontWeightForComponent('episodes'),
      customLetterSpacing: theme.getLetterSpacingForComponent('episodes'),
      customPadding: theme.getPaddingForComponent('episodes'),
      customShadow: theme.hasShadowForComponent('episodes'),
      customTextColor: theme.getColorForComponent('episodes'),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isVisible || episodes.trim().isEmpty) return const SizedBox.shrink();

    return AnimeMetadataPill(
      icon: Icons.play_circle_outline_rounded,
      label: episodes,
      accentColor: accentColor,
      fontFamily: fontFamily,
      style: style,
      isGlass: isGlass,
      isDarkBackground: isDarkBackground,
      customBorderColor: customBorderColor,
      customBorderWidth: customBorderWidth,
      customBgColor: customBgColor,
      customBgOpacity: customBgOpacity,
      customBorderRadius: customBorderRadius,
      customFontSize: customFontSize,
      customFontWeight: customFontWeight,
      customLetterSpacing: customLetterSpacing,
      customPadding: customPadding,
      customShadow: customShadow,
      customTextColor: customTextColor,
    );
  }
}

/// Individual modular component for displaying Animation Studio (e.g. Ufotable, MAPPA).
/// Can be placed anywhere individually in any slide layout.
class AnimeStudioComponent extends StatelessWidget {
  final String studio;
  final Color accentColor;
  final String? fontFamily;
  final MetadataPillStyle style;
  final bool isDarkBackground;
  final bool isGlass;
  final bool isVisible;
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

  const AnimeStudioComponent({
    super.key,
    required this.studio,
    this.accentColor = const Color(0xFFFF3366),
    this.fontFamily,
    this.style = MetadataPillStyle.frostedGlass,
    this.isDarkBackground = true,
    this.isGlass = true,
    this.isVisible = true,
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

  factory AnimeStudioComponent.fromTheme({
    Key? key,
    required String studio,
    required AnimeTemplateTheme theme,
    required bool isDarkBackground,
  }) {
    return AnimeStudioComponent(
      key: key,
      studio: studio,
      accentColor: theme.getColorForComponent('studio', defaultColor: theme.accentColor)!,
      fontFamily: theme.getFontForComponent('studio', defaultFont: theme.bodyFontFamily),
      style: theme.metadataPillStyle,
      isDarkBackground: isDarkBackground,
      isVisible: theme.showStudio,
      customBorderColor: theme.getBorderColorForComponent('studio'),
      customBorderWidth: theme.getBorderWidthForComponent('studio'),
      customBgColor: theme.getBgColorForComponent('studio'),
      customBgOpacity: theme.getBgOpacityForComponent('studio'),
      customBorderRadius: theme.getBorderRadiusForComponent('studio'),
      customFontSize: theme.getFontSizeForComponent('studio'),
      customFontWeight: theme.getFontWeightForComponent('studio'),
      customLetterSpacing: theme.getLetterSpacingForComponent('studio'),
      customPadding: theme.getPaddingForComponent('studio'),
      customShadow: theme.hasShadowForComponent('studio'),
      customTextColor: theme.getColorForComponent('studio'),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isVisible || studio.trim().isEmpty) return const SizedBox.shrink();

    return AnimeMetadataPill(
      icon: Icons.movie_creation_outlined,
      label: studio,
      accentColor: accentColor,
      fontFamily: fontFamily,
      style: style,
      isGlass: isGlass,
      isDarkBackground: isDarkBackground,
      customBorderColor: customBorderColor,
      customBorderWidth: customBorderWidth,
      customBgColor: customBgColor,
      customBgOpacity: customBgOpacity,
      customBorderRadius: customBorderRadius,
      customFontSize: customFontSize,
      customFontWeight: customFontWeight,
      customLetterSpacing: customLetterSpacing,
      customPadding: customPadding,
      customShadow: customShadow,
      customTextColor: customTextColor,
    );
  }
}


/// Individual modular component for displaying Rank Badge (e.g. #01).
/// Can be placed anywhere individually in any slide layout.
class AnimeRankBadgeComponent extends StatelessWidget {
  final int rank;
  final RankBadgeStyle style;
  final Color accentColor;
  final String? fontFamily;
  final bool isDarkBackground;
  final bool isVisible;
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

  const AnimeRankBadgeComponent({
    super.key,
    required this.rank,
    this.style = RankBadgeStyle.modernGradient,
    this.accentColor = const Color(0xFFFF3366),
    this.fontFamily,
    this.isDarkBackground = true,
    this.isVisible = true,
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

  factory AnimeRankBadgeComponent.fromTheme({
    Key? key,
    required int rank,
    required AnimeTemplateTheme theme,
    required bool isDarkBackground,
  }) {
    return AnimeRankBadgeComponent(
      key: key,
      rank: rank,
      style: theme.rankBadgeStyle,
      accentColor: theme.getColorForComponent('rankBadge', defaultColor: theme.accentColor)!,
      fontFamily: theme.getFontForComponent('rankBadge', defaultFont: theme.titleFontFamily),
      isDarkBackground: isDarkBackground,
      isVisible: theme.showRankBadge,
      customBorderColor: theme.getBorderColorForComponent('rankBadge'),
      customBorderWidth: theme.getBorderWidthForComponent('rankBadge'),
      customBgColor: theme.getBgColorForComponent('rankBadge'),
      customBgOpacity: theme.getBgOpacityForComponent('rankBadge'),
      customBorderRadius: theme.getBorderRadiusForComponent('rankBadge'),
      customFontSize: theme.getFontSizeForComponent('rankBadge'),
      customFontWeight: theme.getFontWeightForComponent('rankBadge'),
      customLetterSpacing: theme.getLetterSpacingForComponent('rankBadge'),
      customPadding: theme.getPaddingForComponent('rankBadge'),
      customShadow: theme.hasShadowForComponent('rankBadge'),
      customTextColor: theme.getColorForComponent('rankBadge'),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    final rankText = '#${rank.toString().padLeft(2, '0')}';
    final effectiveBorderColor = customBorderColor ?? accentColor;
    final effectiveBorderWidth = customBorderWidth ?? 1.5;

    final Color? effectiveBg = customBgColor?.withValues(alpha: (customBgOpacity ?? 1.0).clamp(0.0, 1.0));
    double effectiveRadius = customBorderRadius ?? 8.0;
    EdgeInsets effectivePadding = customPadding != null
        ? EdgeInsets.symmetric(horizontal: customPadding!, vertical: (customPadding! * 0.4).clamp(2.0, 16.0))
        : const EdgeInsets.symmetric(horizontal: 10, vertical: 4);
    Color effectiveText = customTextColor ?? accentColor;
    double effectiveTextSize = customFontSize ?? 13.0;
    FontWeight effectiveWeight = customFontWeight ?? FontWeight.w900;
    double effectiveSpacing = customLetterSpacing ?? 0.5;
    List<BoxShadow>? effectiveShadow = customShadow == true
        ? [BoxShadow(color: Colors.black.withValues(alpha: isDarkBackground ? 0.35 : 0.15), blurRadius: 6, offset: const Offset(0, 2))]
        : null;

    switch (style) {
      case RankBadgeStyle.minimalOutlined:
        return Container(
          padding: customPadding != null ? effectivePadding : const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
          decoration: BoxDecoration(
            color: effectiveBg ?? Colors.transparent,
            borderRadius: BorderRadius.circular(customBorderRadius ?? 6.0),
            border: Border.all(
              color: effectiveBorderColor,
              width: effectiveBorderWidth,
            ),
            boxShadow: effectiveShadow,
          ),
          child: Text(
            rankText,
            style: TextStyle(
              fontFamily: fontFamily,
              color: effectiveText,
              fontWeight: effectiveWeight,
              fontSize: effectiveTextSize,
              letterSpacing: effectiveSpacing,
            ),
          ),
        );

      case RankBadgeStyle.glassPill:
        return Container(
          padding: customPadding != null ? effectivePadding : const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: effectiveBg ??
                (isDarkBackground
                    ? Colors.white.withValues(alpha: 0.14)
                    : Colors.black.withValues(alpha: 0.08)),
            borderRadius: BorderRadius.circular(customBorderRadius ?? 20.0),
            border: Border.all(
              color: customBorderColor ??
                  (isDarkBackground
                      ? Colors.white.withValues(alpha: 0.25)
                      : Colors.black.withValues(alpha: 0.15)),
              width: customBorderWidth ?? 1.0,
            ),
            boxShadow: effectiveShadow,
          ),
          child: Text(
            rankText,
            style: TextStyle(
              fontFamily: fontFamily,
              color: customTextColor ?? (isDarkBackground ? Colors.white : const Color(0xFF0F172A)),
              fontWeight: effectiveWeight,
              fontSize: effectiveTextSize,
              letterSpacing: effectiveSpacing,
            ),
          ),
        );

      case RankBadgeStyle.boldRibbon:
        return Container(
          padding: customPadding != null ? effectivePadding : const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: effectiveBg ?? accentColor,
            borderRadius: BorderRadius.circular(customBorderRadius ?? 3.0),
            border: (customBorderWidth != null && customBorderWidth! > 0)
                ? Border.all(color: effectiveBorderColor, width: effectiveBorderWidth)
                : null,
            boxShadow: effectiveShadow,
          ),
          child: Text(
            rankText,
            style: TextStyle(
              fontFamily: fontFamily,
              color: customTextColor ?? Colors.white,
              fontWeight: effectiveWeight,
              fontSize: effectiveTextSize,
              letterSpacing: effectiveSpacing,
            ),
          ),
        );

      case RankBadgeStyle.circularStamp:
        return Container(
          width: (effectiveTextSize * 2.5).clamp(28.0, 56.0),
          height: (effectiveTextSize * 2.5).clamp(28.0, 56.0),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: effectiveBg ?? (isDarkBackground ? const Color(0xFF0F172A) : Colors.white),
            border: Border.all(color: effectiveBorderColor, width: customBorderWidth ?? 2.0),
            boxShadow: effectiveShadow,
          ),
          child: Text(
            rankText,
            style: TextStyle(
              fontFamily: fontFamily,
              color: customTextColor ?? accentColor,
              fontWeight: effectiveWeight,
              fontSize: customFontSize ?? 11.0,
            ),
          ),
        );

      case RankBadgeStyle.modernGradient:
        return Container(
          padding: customPadding != null ? effectivePadding : const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: effectiveBg,
            gradient: effectiveBg == null
                ? LinearGradient(
                    colors: [
                      accentColor,
                      accentColor.withValues(alpha: 0.75),
                    ],
                  )
                : null,
            borderRadius: BorderRadius.circular(effectiveRadius),
            border: (customBorderWidth != null && customBorderWidth! > 0)
                ? Border.all(color: effectiveBorderColor, width: effectiveBorderWidth)
                : null,
            boxShadow: effectiveShadow ??
                const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
          ),
          child: Text(
            rankText,
            style: TextStyle(
              fontFamily: fontFamily,
              color: customTextColor ?? Colors.white,
              fontWeight: effectiveWeight,
              fontSize: effectiveTextSize,
              letterSpacing: effectiveSpacing,
            ),
          ),
        );
    }
  }
}

/// Individual modular component for displaying Anime Genres.
/// Supports multiple styles: Pills, Bullet Row, Outlined Tags, and Gradient Capsules.
class AnimeGenresComponent extends StatelessWidget {
  final List<String> genres;
  final Color accentColor;
  final String? fontFamily;
  final GenreStyle style;
  final bool isDarkBackground;
  final bool isVisible;
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

  const AnimeGenresComponent({
    super.key,
    required this.genres,
    this.accentColor = const Color(0xFFFF3366),
    this.fontFamily,
    this.style = GenreStyle.pills,
    this.isDarkBackground = true,
    this.isVisible = true,
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

  factory AnimeGenresComponent.fromTheme({
    Key? key,
    required List<String> genres,
    required AnimeTemplateTheme theme,
    required bool isDarkBackground,
  }) {
    return AnimeGenresComponent(
      key: key,
      genres: genres,
      accentColor: theme.getColorForComponent('genres', defaultColor: theme.accentColor)!,
      fontFamily: theme.getFontForComponent('genres', defaultFont: theme.bodyFontFamily),
      style: theme.genreStyle,
      isDarkBackground: isDarkBackground,
      isVisible: theme.showGenres,
      customBorderColor: theme.getBorderColorForComponent('genres'),
      customBorderWidth: theme.getBorderWidthForComponent('genres'),
      customBgColor: theme.getBgColorForComponent('genres'),
      customBgOpacity: theme.getBgOpacityForComponent('genres'),
      customBorderRadius: theme.getBorderRadiusForComponent('genres'),
      customFontSize: theme.getFontSizeForComponent('genres'),
      customFontWeight: theme.getFontWeightForComponent('genres'),
      customLetterSpacing: theme.getLetterSpacingForComponent('genres'),
      customPadding: theme.getPaddingForComponent('genres'),
      customShadow: theme.hasShadowForComponent('genres'),
      customTextColor: theme.getColorForComponent('genres'),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isVisible || genres.isEmpty) return const SizedBox.shrink();

    final effectiveColor = customTextColor ?? accentColor;
    final effectiveFontSize = customFontSize ?? 9.5;
    final effectiveFontWeight = customFontWeight ?? FontWeight.w600;
    final effectiveLetterSpacing = customLetterSpacing ?? 0.4;
    final effectiveRadius = customBorderRadius ?? 20.0;
    final effectivePadding = customPadding != null
        ? EdgeInsets.symmetric(horizontal: customPadding!, vertical: (customPadding! * 0.4).clamp(2.0, 14.0))
        : const EdgeInsets.symmetric(horizontal: 8, vertical: 3);
    final effectiveBg = customBgColor?.withValues(alpha: (customBgOpacity ?? 1.0).clamp(0.0, 1.0));
    final effectiveShadow = customShadow == true
        ? [BoxShadow(color: Colors.black.withValues(alpha: isDarkBackground ? 0.35 : 0.12), blurRadius: 6, offset: const Offset(0, 2))]
        : null;

    switch (style) {
      case GenreStyle.bulletRow:
        return Text(
          genres.join('  •  ').toUpperCase(),
          style: TextStyle(
            fontFamily: fontFamily,
            color: effectiveColor.withValues(alpha: 0.95),
            fontSize: (customFontSize ?? 10.0),
            fontWeight: customFontWeight ?? FontWeight.w700,
            letterSpacing: customLetterSpacing ?? 0.8,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );

      case GenreStyle.outlineTags:
        return Wrap(
          spacing: 5,
          runSpacing: 4,
          children: genres.take(4).map((genre) {
            return Container(
              padding: customPadding != null ? effectivePadding : const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(customBorderRadius ?? 4.0),
                border: Border.all(
                  color: customBorderColor ??
                      (isDarkBackground
                          ? Colors.white.withValues(alpha: 0.25)
                          : Colors.grey.shade400),
                  width: customBorderWidth ?? 0.8,
                ),
                color: effectiveBg ??
                    (isDarkBackground
                        ? Colors.black.withValues(alpha: 0.3)
                        : Colors.white),
                boxShadow: effectiveShadow,
              ),
              child: Text(
                genre.toUpperCase(),
                style: TextStyle(
                  fontFamily: fontFamily,
                  color: customTextColor ?? (isDarkBackground ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF334155)),
                  fontSize: effectiveFontSize,
                  fontWeight: effectiveFontWeight,
                  letterSpacing: effectiveLetterSpacing,
                ),
              ),
            );
          }).toList(),
        );

      case GenreStyle.gradientCapsules:
        return Wrap(
          spacing: 6,
          runSpacing: 5,
          children: genres.take(4).map((genre) {
            return Container(
              padding: customPadding != null ? effectivePadding : const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(customBorderRadius ?? 12.0),
                color: effectiveBg,
                gradient: effectiveBg == null
                    ? LinearGradient(
                        colors: [
                          accentColor.withValues(alpha: 0.3),
                          accentColor.withValues(alpha: 0.12),
                        ],
                      )
                    : null,
                border: Border.all(
                  color: customBorderColor ?? accentColor.withValues(alpha: 0.6),
                  width: customBorderWidth ?? 0.8,
                ),
                boxShadow: effectiveShadow,
              ),
              child: Text(
                genre.toUpperCase(),
                style: TextStyle(
                  fontFamily: fontFamily,
                  color: customTextColor ?? (isDarkBackground ? Colors.white : accentColor),
                  fontSize: effectiveFontSize,
                  fontWeight: customFontWeight ?? FontWeight.w700,
                  letterSpacing: effectiveLetterSpacing,
                ),
              ),
            );
          }).toList(),
        );

      case GenreStyle.pills:
        return Wrap(
          spacing: 6,
          runSpacing: 5,
          children: genres.take(4).map((genre) {
            return Container(
              padding: effectivePadding,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(effectiveRadius),
                color: effectiveBg ??
                    (isDarkBackground
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.grey.shade100),
                border: Border.all(
                  color: customBorderColor ??
                      (isDarkBackground
                          ? Colors.white.withValues(alpha: 0.15)
                          : Colors.grey.shade300),
                  width: customBorderWidth ?? 0.8,
                ),
                boxShadow: effectiveShadow,
              ),
              child: Text(
                genre.toUpperCase(),
                style: TextStyle(
                  fontFamily: fontFamily,
                  color: customTextColor ?? (isDarkBackground ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF475569)),
                  fontSize: effectiveFontSize,
                  fontWeight: effectiveFontWeight,
                  letterSpacing: effectiveLetterSpacing,
                ),
              ),
            );
          }).toList(),
        );
    }
  }
}

/// Dedicated modular component for Page Handle / Watermark badge.
/// Can be positioned anywhere on the slide or canvas with multiple stylish presets.
class AnimePageHandleComponent extends StatelessWidget {
  final String handle;
  final HandleStyle style;
  final Color accentColor;
  final String? fontFamily;
  final bool isVerified;
  final bool isDarkBackground;
  final bool isVisible;
  final bool isStrokeOnly;
  final double strokeWidth;
  final Color? strokeColor;
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

  const AnimePageHandleComponent({
    super.key,
    required this.handle,
    this.style = HandleStyle.pillBadge,
    this.accentColor = const Color(0xFFFF3366),
    this.fontFamily,
    this.isVerified = true,
    this.isDarkBackground = true,
    this.isVisible = true,
    this.isStrokeOnly = false,
    this.strokeWidth = 0.0,
    this.strokeColor,
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

  factory AnimePageHandleComponent.fromTheme({
    Key? key,
    required AnimeTemplateTheme theme,
    required bool isDarkBackground,
  }) {
    final strokeOnly = theme.isTextStrokeOnly('pageHandle');
    return AnimePageHandleComponent(
      key: key,
      handle: theme.watermarkText,
      style: theme.handleStyle,
      accentColor: theme.getColorForComponent('pageHandle', defaultColor: theme.accentColor)!,
      fontFamily: theme.getFontForComponent('pageHandle', defaultFont: theme.bodyFontFamily),
      isVerified: theme.isVerified,
      isDarkBackground: isDarkBackground,
      isVisible: theme.showWatermark,
      isStrokeOnly: strokeOnly,
      strokeWidth: theme.getTextStrokeWidth('pageHandle', defaultWidth: strokeOnly ? 1.2 : 0.0),
      strokeColor: theme.getTextStrokeColor('pageHandle', defaultColor: theme.accentColor),
      customBorderColor: theme.getBorderColorForComponent('pageHandle'),
      customBorderWidth: theme.getBorderWidthForComponent('pageHandle'),
      customBgColor: theme.getBgColorForComponent('pageHandle'),
      customBgOpacity: theme.getBgOpacityForComponent('pageHandle'),
      customBorderRadius: theme.getBorderRadiusForComponent('pageHandle'),
      customFontSize: theme.getFontSizeForComponent('pageHandle'),
      customFontWeight: theme.getFontWeightForComponent('pageHandle'),
      customLetterSpacing: theme.getLetterSpacingForComponent('pageHandle'),
      customPadding: theme.getPaddingForComponent('pageHandle'),
      customShadow: theme.hasShadowForComponent('pageHandle'),
      customTextColor: theme.getColorForComponent('pageHandle'),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isVisible || handle.trim().isEmpty) return const SizedBox.shrink();

    final badgeBg = customBgColor != null
        ? customBgColor!.withValues(alpha: (customBgOpacity ?? 1.0).clamp(0.0, 1.0))
        : (isDarkBackground
            ? Colors.black.withValues(alpha: 0.45)
            : Colors.grey.shade100);
    final badgeBorder = customBorderColor ??
        (isDarkBackground
            ? Colors.white.withValues(alpha: 0.14)
            : Colors.grey.shade300);
    final badgeTextColor = customTextColor ??
        (isDarkBackground
            ? Colors.white.withValues(alpha: 0.95)
            : const Color(0xFF1E293B));
    final effectiveBorderWidth = customBorderWidth ?? 0.8;
    final effectiveRadius = customBorderRadius ?? 20.0;
    final effectivePadding = customPadding != null
        ? EdgeInsets.symmetric(horizontal: customPadding!, vertical: (customPadding! * 0.5).clamp(2.0, 14.0))
        : const EdgeInsets.symmetric(horizontal: 10, vertical: 5);
    final effectiveShadow = customShadow == true
        ? [BoxShadow(color: Colors.black.withValues(alpha: isDarkBackground ? 0.35 : 0.12), blurRadius: 6, offset: const Offset(0, 2))]
        : null;

    final effectiveStrokeColor = strokeColor ?? accentColor;

    Widget buildHandleText({Color? defaultColor, double fontSize = 11.5, FontWeight fontWeight = FontWeight.w700}) {
      return OutlinedText(
        text: '@$handle',
        style: TextStyle(
          fontFamily: fontFamily,
          fontSize: customFontSize ?? fontSize,
          fontWeight: customFontWeight ?? fontWeight,
          letterSpacing: customLetterSpacing ?? 0.3,
        ),
        fillColor: customTextColor ?? defaultColor ?? badgeTextColor,
        strokeOnly: isStrokeOnly,
        strokeWidth: strokeWidth,
        strokeColor: effectiveStrokeColor,
      );
    }

    switch (style) {
      case HandleStyle.minimalText:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            buildHandleText(),
            if (isVerified) ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.verified_rounded,
                color: Color(0xFF3897F0),
                size: 13,
              ),
            ],
          ],
        );

      case HandleStyle.gradientChip:
        return Container(
          padding: effectivePadding,
          decoration: BoxDecoration(
            color: customBgColor != null ? badgeBg : null,
            gradient: customBgColor == null
                ? LinearGradient(
                    colors: [
                      accentColor,
                      accentColor.withValues(alpha: 0.7),
                    ],
                  )
                : null,
            borderRadius: BorderRadius.circular(effectiveRadius),
            border: (customBorderWidth != null && customBorderWidth! > 0)
                ? Border.all(color: badgeBorder, width: effectiveBorderWidth)
                : null,
            boxShadow: effectiveShadow ??
                [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.bolt_rounded,
                color: Colors.white,
                size: 13,
              ),
              const SizedBox(width: 4),
              buildHandleText(defaultColor: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            ],
          ),
        );

      case HandleStyle.glassChip:
        return Container(
          padding: effectivePadding,
          decoration: BoxDecoration(
            color: badgeBg,
            borderRadius: BorderRadius.circular(effectiveRadius),
            border: effectiveBorderWidth > 0
                ? Border.all(
                    color: badgeBorder,
                    width: effectiveBorderWidth,
                  )
                : null,
            boxShadow: effectiveShadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              buildHandleText(fontSize: 11, fontWeight: FontWeight.w600),
              if (isVerified) ...[
                const SizedBox(width: 4),
                const Icon(
                  Icons.verified_rounded,
                  color: Color(0xFF3897F0),
                  size: 13,
                ),
              ],
            ],
          ),
        );

      case HandleStyle.pillBadge:
        return Container(
          padding: effectivePadding,
          decoration: BoxDecoration(
            color: badgeBg,
            borderRadius: BorderRadius.circular(effectiveRadius),
            border: effectiveBorderWidth > 0
                ? Border.all(
                    color: badgeBorder,
                    width: effectiveBorderWidth,
                  )
                : null,
            boxShadow: effectiveShadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 17,
                height: 17,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      accentColor,
                      accentColor.withValues(alpha: 0.6),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: Colors.white,
                  size: 11,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '@$handle',
                style: TextStyle(
                  fontFamily: fontFamily,
                  color: customTextColor ?? badgeTextColor,
                  fontSize: customFontSize ?? 11,
                  fontWeight: customFontWeight ?? FontWeight.w600,
                  letterSpacing: customLetterSpacing ?? 0.3,
                ),
              ),
              if (isVerified) ...[
                const SizedBox(width: 4),
                const Icon(
                  Icons.verified_rounded,
                  color: Color(0xFF3897F0),
                  size: 13,
                ),
              ],
            ],
          ),
        );
    }
  }
}

/// Dedicated modular component for Slide Number / Pagination Indicator.
/// Supports Fraction Pill (01 / 07), Minimal Slash (01/07), Dots Carousel, and Accent Badge (#01).
class AnimeSlideCounterComponent extends StatelessWidget {
  final int slideIndex;
  final int totalSlides;
  final SlideCounterStyle style;
  final Color accentColor;
  final String? fontFamily;
  final bool isDarkBackground;
  final bool isVisible;
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

  const AnimeSlideCounterComponent({
    super.key,
    required this.slideIndex,
    required this.totalSlides,
    this.style = SlideCounterStyle.fractionPill,
    this.accentColor = const Color(0xFFFF3366),
    this.fontFamily,
    this.isDarkBackground = true,
    this.isVisible = true,
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

  factory AnimeSlideCounterComponent.fromTheme({
    Key? key,
    required int slideIndex,
    required int totalSlides,
    required AnimeTemplateTheme theme,
    required bool isDarkBackground,
  }) {
    return AnimeSlideCounterComponent(
      key: key,
      slideIndex: slideIndex,
      totalSlides: totalSlides,
      style: theme.counterStyle,
      accentColor: theme.getColorForComponent('slideCounter', defaultColor: theme.accentColor)!,
      fontFamily: theme.getFontForComponent('slideCounter', defaultFont: theme.bodyFontFamily),
      isDarkBackground: isDarkBackground,
      isVisible: theme.showSlideCounter,
      customBorderColor: theme.getBorderColorForComponent('slideCounter'),
      customBorderWidth: theme.getBorderWidthForComponent('slideCounter'),
      customBgColor: theme.getBgColorForComponent('slideCounter'),
      customBgOpacity: theme.getBgOpacityForComponent('slideCounter'),
      customBorderRadius: theme.getBorderRadiusForComponent('slideCounter'),
      customFontSize: theme.getFontSizeForComponent('slideCounter'),
      customFontWeight: theme.getFontWeightForComponent('slideCounter'),
      customLetterSpacing: theme.getLetterSpacingForComponent('slideCounter'),
      customPadding: theme.getPaddingForComponent('slideCounter'),
      customShadow: theme.hasShadowForComponent('slideCounter'),
      customTextColor: theme.getColorForComponent('slideCounter'),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    final badgeBg = customBgColor != null
        ? customBgColor!.withValues(alpha: (customBgOpacity ?? 1.0).clamp(0.0, 1.0))
        : (isDarkBackground
            ? Colors.black.withValues(alpha: 0.45)
            : Colors.grey.shade100);
    final badgeBorder = customBorderColor ??
        (isDarkBackground
            ? Colors.white.withValues(alpha: 0.14)
            : Colors.grey.shade300);
    final badgeTextColor = customTextColor ??
        (isDarkBackground
            ? Colors.white.withValues(alpha: 0.95)
            : const Color(0xFF1E293B));
    final effectiveBorderWidth = customBorderWidth ?? 0.8;
    final effectiveRadius = customBorderRadius ?? 20.0;
    final effectivePadding = customPadding != null
        ? EdgeInsets.symmetric(horizontal: customPadding!, vertical: (customPadding! * 0.45).clamp(2.0, 14.0))
        : const EdgeInsets.symmetric(horizontal: 10, vertical: 5);
    final effectiveFontSize = customFontSize ?? 11.0;
    final effectiveFontWeight = customFontWeight ?? FontWeight.bold;
    final effectiveLetterSpacing = customLetterSpacing ?? 1.0;
    final effectiveShadow = customShadow == true
        ? [BoxShadow(color: Colors.black.withValues(alpha: isDarkBackground ? 0.35 : 0.12), blurRadius: 6, offset: const Offset(0, 2))]
        : null;

    final currentNum = (slideIndex + 1).toString().padLeft(2, '0');
    final totalNum = totalSlides.toString().padLeft(2, '0');

    switch (style) {
      case SlideCounterStyle.minimalSlash:
        return Text(
          '$currentNum/$totalNum',
          style: TextStyle(
            fontFamily: fontFamily,
            color: badgeTextColor,
            fontSize: effectiveFontSize,
            fontWeight: effectiveFontWeight,
            letterSpacing: effectiveLetterSpacing,
          ),
        );

      case SlideCounterStyle.dotsIndicator:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(totalSlides, (idx) {
            final isActive = idx == slideIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              width: isActive ? 16 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: isActive
                    ? accentColor
                    : (isDarkBackground
                        ? Colors.white.withValues(alpha: 0.3)
                        : Colors.grey.shade400),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        );

      case SlideCounterStyle.accentBadge:
        return Container(
          padding: customPadding != null ? effectivePadding : const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: customBgColor != null ? badgeBg : accentColor,
            borderRadius: BorderRadius.circular(customBorderRadius ?? 6.0),
            border: (customBorderWidth != null && customBorderWidth! > 0)
                ? Border.all(color: badgeBorder, width: effectiveBorderWidth)
                : null,
            boxShadow: effectiveShadow,
          ),
          child: Text(
            '#$currentNum',
            style: TextStyle(
              fontFamily: fontFamily,
              color: customTextColor ?? Colors.white,
              fontSize: effectiveFontSize,
              fontWeight: effectiveFontWeight,
              letterSpacing: effectiveLetterSpacing,
            ),
          ),
        );

      case SlideCounterStyle.fractionPill:
        return Container(
          padding: effectivePadding,
          decoration: BoxDecoration(
            color: badgeBg,
            borderRadius: BorderRadius.circular(effectiveRadius),
            border: effectiveBorderWidth > 0
                ? Border.all(
                    color: badgeBorder,
                    width: effectiveBorderWidth,
                  )
                : null,
            boxShadow: effectiveShadow,
          ),
          child: Text(
            '$currentNum / $totalNum',
            style: TextStyle(
              fontFamily: fontFamily,
              color: badgeTextColor,
              fontSize: effectiveFontSize,
              fontWeight: effectiveFontWeight,
              letterSpacing: effectiveLetterSpacing,
            ),
          ),
        );
    }
  }
}

/// Dedicated modular component for Hook Tags / Category Badges (e.g. TOP RECOMMENDATION, MUST WATCH, TRENDING).
class AnimeHookTagComponent extends StatelessWidget {
  final String tag;
  final HookTagStyle style;
  final Color accentColor;
  final String? fontFamily;
  final bool isDarkBackground;
  final bool isVisible;
  final bool isStrokeOnly;
  final double strokeWidth;
  final Color? strokeColor;
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

  const AnimeHookTagComponent({
    super.key,
    required this.tag,
    this.style = HookTagStyle.neonGlow,
    this.accentColor = const Color(0xFFFF3366),
    this.fontFamily,
    this.isDarkBackground = true,
    this.isVisible = true,
    this.isStrokeOnly = false,
    this.strokeWidth = 0.0,
    this.strokeColor,
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

  factory AnimeHookTagComponent.fromTheme({
    Key? key,
    required String tag,
    required AnimeTemplateTheme theme,
    required bool isDarkBackground,
  }) {
    final strokeOnly = theme.isTextStrokeOnly('hookTag');
    return AnimeHookTagComponent(
      key: key,
      tag: tag,
      style: theme.tagStyle,
      accentColor: theme.getColorForComponent('hookTag', defaultColor: theme.accentColor)!,
      fontFamily: theme.getFontForComponent('hookTag', defaultFont: theme.bodyFontFamily),
      isDarkBackground: isDarkBackground,
      isVisible: theme.showHookTag,
      isStrokeOnly: strokeOnly,
      strokeWidth: theme.getTextStrokeWidth('hookTag', defaultWidth: strokeOnly ? 1.2 : 0.0),
      strokeColor: theme.getTextStrokeColor('hookTag', defaultColor: theme.accentColor),
      customBorderColor: theme.getBorderColorForComponent('hookTag'),
      customBorderWidth: theme.getBorderWidthForComponent('hookTag'),
      customBgColor: theme.getBgColorForComponent('hookTag'),
      customBgOpacity: theme.getBgOpacityForComponent('hookTag'),
      customBorderRadius: theme.getBorderRadiusForComponent('hookTag'),
      customFontSize: theme.getFontSizeForComponent('hookTag'),
      customFontWeight: theme.getFontWeightForComponent('hookTag'),
      customLetterSpacing: theme.getLetterSpacingForComponent('hookTag'),
      customPadding: theme.getPaddingForComponent('hookTag'),
      customShadow: theme.hasShadowForComponent('hookTag'),
      customTextColor: theme.getColorForComponent('hookTag'),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isVisible || tag.trim().isEmpty) return const SizedBox.shrink();

    final effectiveStrokeColor = strokeColor ?? accentColor;
    final effectiveFontSize = customFontSize ?? 10.0;
    final effectiveFontWeight = customFontWeight ?? FontWeight.w900;
    final effectiveLetterSpacing = customLetterSpacing ?? 1.2;
    final effectiveRadius = customBorderRadius ?? 6.0;
    final effectivePadding = customPadding != null
        ? EdgeInsets.symmetric(horizontal: customPadding!, vertical: (customPadding! * 0.45).clamp(2.0, 14.0))
        : const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5);
    final effectiveBg = customBgColor?.withValues(alpha: (customBgOpacity ?? 1.0).clamp(0.0, 1.0));
    final effectiveShadow = customShadow == true
        ? [BoxShadow(color: accentColor.withValues(alpha: 0.35), blurRadius: 6, offset: const Offset(0, 2))]
        : null;

    switch (style) {
      case HookTagStyle.solidAccent:
        return Container(
          padding: effectivePadding,
          decoration: BoxDecoration(
            color: effectiveBg ?? accentColor,
            borderRadius: BorderRadius.circular(effectiveRadius),
            border: (customBorderWidth != null && customBorderWidth! > 0)
                ? Border.all(color: customBorderColor ?? Colors.transparent, width: customBorderWidth!)
                : null,
            boxShadow: effectiveShadow ??
                [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
          ),
          child: OutlinedText(
            text: tag.toUpperCase(),
            style: TextStyle(
              fontFamily: fontFamily,
              color: customTextColor ?? Colors.white,
              fontSize: effectiveFontSize,
              fontWeight: effectiveFontWeight,
              letterSpacing: effectiveLetterSpacing,
            ),
            fillColor: customTextColor ?? Colors.white,
            strokeOnly: isStrokeOnly,
            strokeWidth: strokeWidth,
            strokeColor: effectiveStrokeColor,
          ),
        );

      case HookTagStyle.minimalBorder:
        return Container(
          padding: effectivePadding,
          decoration: BoxDecoration(
            color: effectiveBg,
            borderRadius: BorderRadius.circular(effectiveRadius),
            border: Border.all(
              color: customBorderColor ?? accentColor,
              width: customBorderWidth ?? 1.2,
            ),
            boxShadow: effectiveShadow,
          ),
          child: OutlinedText(
            text: tag.toUpperCase(),
            style: TextStyle(
              fontFamily: fontFamily,
              color: customTextColor ?? accentColor,
              fontSize: effectiveFontSize,
              fontWeight: effectiveFontWeight,
              letterSpacing: effectiveLetterSpacing,
            ),
            fillColor: customTextColor ?? accentColor,
            strokeOnly: isStrokeOnly,
            strokeWidth: strokeWidth,
            strokeColor: effectiveStrokeColor,
          ),
        );

      case HookTagStyle.fireBadge:
        return Container(
          padding: effectivePadding,
          decoration: BoxDecoration(
            color: effectiveBg ?? accentColor.withValues(alpha: isDarkBackground ? 0.25 : 0.12),
            borderRadius: BorderRadius.circular(customBorderRadius ?? 20.0),
            border: Border.all(color: customBorderColor ?? accentColor, width: customBorderWidth ?? 1.0),
            boxShadow: effectiveShadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.local_fire_department_rounded, color: customTextColor ?? accentColor, size: 13),
              const SizedBox(width: 4),
              OutlinedText(
                text: tag.toUpperCase(),
                style: TextStyle(
                  fontFamily: fontFamily,
                  color: customTextColor ?? accentColor,
                  fontSize: effectiveFontSize,
                  fontWeight: effectiveFontWeight,
                  letterSpacing: effectiveLetterSpacing,
                ),
                fillColor: customTextColor ?? accentColor,
                strokeOnly: isStrokeOnly,
                strokeWidth: strokeWidth,
                strokeColor: effectiveStrokeColor,
              ),
            ],
          ),
        );

      case HookTagStyle.neonGlow:
        return Container(
          padding: effectivePadding,
          decoration: BoxDecoration(
            color: effectiveBg ?? accentColor.withValues(alpha: isDarkBackground ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(customBorderRadius ?? 8.0),
            border: Border.all(
              color: customBorderColor ?? accentColor.withValues(alpha: 0.8),
              width: customBorderWidth ?? 1.2,
            ),
            boxShadow: effectiveShadow ??
                (isDarkBackground
                    ? [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.3),
                          blurRadius: 8,
                        ),
                      ]
                    : null),
          ),
          child: OutlinedText(
            text: tag.toUpperCase(),
            style: TextStyle(
              fontFamily: fontFamily,
              color: customTextColor ?? accentColor,
              fontSize: effectiveFontSize,
              fontWeight: effectiveFontWeight,
              letterSpacing: effectiveLetterSpacing,
            ),
            fillColor: customTextColor ?? accentColor,
            strokeOnly: isStrokeOnly,
            strokeWidth: strokeWidth,
            strokeColor: effectiveStrokeColor,
          ),
        );
    }
  }
}

/// Dedicated modular component for Swipe / Next Indicator.
class AnimeSwipeIndicatorComponent extends StatelessWidget {
  final String label;
  final Color accentColor;
  final String? fontFamily;
  final bool isDarkBackground;
  final bool isVisible;

  const AnimeSwipeIndicatorComponent({
    super.key,
    this.label = 'Swipe to start',
    this.accentColor = const Color(0xFFFF3366),
    this.fontFamily,
    this.isDarkBackground = true,
    this.isVisible = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    final textColor = isDarkBackground ? Colors.white : const Color(0xFF1E293B);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDarkBackground ? Colors.white.withValues(alpha: 0.12) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDarkBackground ? Colors.white.withValues(alpha: 0.18) : Colors.grey.shade300,
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: fontFamily,
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            Icons.arrow_forward_rounded,
            color: accentColor,
            size: 14,
          ),
        ],
      ),
    );
  }
}

/// Dedicated modular component for Kanji / Japanese Title Subtitle.
class AnimeJapaneseTitleComponent extends StatelessWidget {
  final String title;
  final String? fontFamily;
  final bool isDarkBackground;
  final bool isVisible;
  final bool isStrokeOnly;
  final double strokeWidth;
  final Color? strokeColor;
  final Color? customTextColor;
  final double? customFontSize;
  final FontWeight? customFontWeight;
  final double? customLetterSpacing;

  const AnimeJapaneseTitleComponent({
    super.key,
    required this.title,
    this.fontFamily,
    this.isDarkBackground = true,
    this.isVisible = true,
    this.isStrokeOnly = false,
    this.strokeWidth = 0.0,
    this.strokeColor,
    this.customTextColor,
    this.customFontSize,
    this.customFontWeight,
    this.customLetterSpacing,
  });

  factory AnimeJapaneseTitleComponent.fromTheme({
    Key? key,
    required String title,
    required AnimeTemplateTheme theme,
    required bool isDarkBackground,
  }) {
    final strokeOnly = theme.isTextStrokeOnly('japaneseTitle');
    return AnimeJapaneseTitleComponent(
      key: key,
      title: title,
      fontFamily: theme.getFontForComponent('japaneseTitle', defaultFont: theme.bodyFontFamily),
      isDarkBackground: isDarkBackground,
      isVisible: theme.showJapaneseTitle,
      isStrokeOnly: strokeOnly,
      strokeWidth: theme.getTextStrokeWidth('japaneseTitle', defaultWidth: strokeOnly ? 1.0 : 0.0),
      strokeColor: theme.getTextStrokeColor('japaneseTitle', defaultColor: theme.accentColor),
      customTextColor: theme.getColorForComponent('japaneseTitle'),
      customFontSize: theme.getFontSizeForComponent('japaneseTitle'),
      customFontWeight: theme.getFontWeightForComponent('japaneseTitle'),
      customLetterSpacing: theme.getLetterSpacingForComponent('japaneseTitle'),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isVisible || title.trim().isEmpty) return const SizedBox.shrink();

    final subtextColor = customTextColor ??
        (isDarkBackground
            ? Colors.white.withValues(alpha: 0.7)
            : Colors.grey.shade600);

    final effectiveStrokeColor = strokeColor ?? subtextColor;

    return OutlinedText(
      text: title,
      style: TextStyle(
        fontFamily: fontFamily,
        fontSize: customFontSize ?? 11.5,
        fontWeight: customFontWeight ?? FontWeight.normal,
        fontStyle: FontStyle.italic,
        letterSpacing: customLetterSpacing ?? 0.5,
      ),
      fillColor: subtextColor,
      strokeOnly: isStrokeOnly,
      strokeWidth: strokeWidth,
      strokeColor: effectiveStrokeColor,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Individual modular component for displaying Synopsis / Review Hook box.
/// Can be placed anywhere individually in any slide layout.
class AnimeSynopsisComponent extends StatelessWidget {
  final String synopsis;
  final Color accentColor;
  final String? fontFamily;
  final double fontSize;
  final Color? textColor;
  final SynopsisCardStyle style;
  final bool isDarkBackground;
  final bool isVisible;
  final Color? customBorderColor;
  final double? customBorderWidth;
  final Color? customBgColor;
  final double? customBgOpacity;
  final double? customBorderRadius;
  final FontWeight? customFontWeight;
  final double? customLetterSpacing;
  final double? customPadding;
  final bool? customShadow;

  const AnimeSynopsisComponent({
    super.key,
    required this.synopsis,
    this.accentColor = const Color(0xFFFF3366),
    this.fontFamily,
    this.fontSize = 11.5,
    this.textColor,
    this.style = SynopsisCardStyle.accentBorderLeft,
    this.isDarkBackground = true,
    this.isVisible = true,
    this.customBorderColor,
    this.customBorderWidth,
    this.customBgColor,
    this.customBgOpacity,
    this.customBorderRadius,
    this.customFontWeight,
    this.customLetterSpacing,
    this.customPadding,
    this.customShadow,
  });

  factory AnimeSynopsisComponent.fromTheme({
    Key? key,
    required String synopsis,
    required AnimeTemplateTheme theme,
    required bool isDarkBackground,
  }) {
    return AnimeSynopsisComponent(
      key: key,
      synopsis: synopsis,
      accentColor: theme.getColorForComponent('synopsis', defaultColor: theme.accentColor)!,
      fontFamily: theme.getFontForComponent('synopsis', defaultFont: theme.bodyFontFamily),
      fontSize: theme.getFontSizeForComponent('synopsis', defaultSize: theme.bodyFontSize),
      textColor: theme.getColorForComponent('synopsis') ?? theme.bodyTextColor,
      style: theme.synopsisCardStyle,
      isDarkBackground: isDarkBackground,
      isVisible: theme.showSynopsis,
      customBorderColor: theme.getBorderColorForComponent('synopsis'),
      customBorderWidth: theme.getBorderWidthForComponent('synopsis'),
      customBgColor: theme.getBgColorForComponent('synopsis'),
      customBgOpacity: theme.getBgOpacityForComponent('synopsis'),
      customBorderRadius: theme.getBorderRadiusForComponent('synopsis'),
      customFontWeight: theme.getFontWeightForComponent('synopsis'),
      customLetterSpacing: theme.getLetterSpacingForComponent('synopsis'),
      customPadding: theme.getPaddingForComponent('synopsis'),
      customShadow: theme.hasShadowForComponent('synopsis'),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isVisible || synopsis.trim().isEmpty) return const SizedBox.shrink();

    final effectiveColor = textColor ??
        (isDarkBackground ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF334155));

    final effectiveBg = customBgColor?.withValues(alpha: (customBgOpacity ?? 1.0).clamp(0.0, 1.0));
    final effectiveRadius = customBorderRadius ?? 10.0;
    final effectivePadding = customPadding != null
        ? EdgeInsets.symmetric(horizontal: customPadding!, vertical: (customPadding! * 0.6).clamp(4.0, 20.0))
        : const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
    final effectiveShadow = customShadow == true
        ? [BoxShadow(color: Colors.black.withValues(alpha: isDarkBackground ? 0.35 : 0.12), blurRadius: 8, offset: const Offset(0, 2))]
        : null;

    final textWidget = Text(
      synopsis,
      style: TextStyle(
        fontFamily: fontFamily,
        color: effectiveColor,
        fontSize: fontSize,
        fontWeight: customFontWeight,
        letterSpacing: customLetterSpacing ?? 0.0,
        height: 1.35,
        fontStyle: style == SynopsisCardStyle.cleanMinimalQuote ? FontStyle.italic : FontStyle.normal,
      ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );

    switch (style) {
      case SynopsisCardStyle.frostedGlassCard:
        return Container(
          padding: effectivePadding,
          decoration: BoxDecoration(
            color: effectiveBg ??
                (isDarkBackground
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.white.withValues(alpha: 0.85)),
            borderRadius: BorderRadius.circular(effectiveRadius),
            border: Border.all(
              color: customBorderColor ??
                  (isDarkBackground
                      ? Colors.white.withValues(alpha: 0.20)
                      : Colors.black12),
              width: customBorderWidth ?? 1.0,
            ),
            boxShadow: effectiveShadow,
          ),
          child: textWidget,
        );

      case SynopsisCardStyle.cleanMinimalQuote:
        return Container(
          padding: customPadding != null ? effectivePadding : const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: effectiveBg,
            borderRadius: BorderRadius.circular(customBorderRadius ?? 8.0),
            border: (customBorderWidth != null && customBorderWidth! > 0)
                ? Border.all(
                    color: customBorderColor ?? accentColor.withValues(alpha: 0.5),
                    width: customBorderWidth!,
                  )
                : null,
            boxShadow: effectiveShadow,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.format_quote_rounded, color: accentColor, size: 16),
              const SizedBox(width: 4),
              Expanded(child: textWidget),
            ],
          ),
        );

      case SynopsisCardStyle.cardElevated:
        return Container(
          padding: effectivePadding,
          decoration: BoxDecoration(
            color: effectiveBg ?? (isDarkBackground ? const Color(0xFF1E293B) : Colors.white),
            borderRadius: BorderRadius.circular(effectiveRadius),
            border: (customBorderWidth != null && customBorderWidth! > 0)
                ? Border.all(
                    color: customBorderColor ?? (isDarkBackground ? Colors.white24 : Colors.grey.shade300),
                    width: customBorderWidth!,
                  )
                : null,
            boxShadow: effectiveShadow ??
                const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
          ),
          child: textWidget,
        );

      case SynopsisCardStyle.editorialStrip:
        return Container(
          padding: customPadding != null ? effectivePadding : const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: effectiveBg ?? Colors.transparent,
            border: Border(
              top: BorderSide(color: customBorderColor ?? accentColor.withValues(alpha: 0.5), width: customBorderWidth ?? 1.0),
              bottom: BorderSide(color: customBorderColor ?? accentColor.withValues(alpha: 0.5), width: customBorderWidth ?? 1.0),
            ),
            boxShadow: effectiveShadow,
          ),
          child: textWidget,
        );

      case SynopsisCardStyle.accentBorderLeft:
        return Container(
          padding: effectivePadding,
          decoration: BoxDecoration(
            color: effectiveBg ?? (isDarkBackground ? Colors.black.withValues(alpha: 0.35) : Colors.grey.shade50),
            borderRadius: BorderRadius.circular(effectiveRadius),
            border: (customBorderWidth != null && customBorderWidth! > 0 && customBorderColor != null)
                ? Border.all(color: customBorderColor!, width: customBorderWidth!)
                : Border(
                    left: BorderSide(
                      color: customBorderColor ?? accentColor,
                      width: customBorderWidth ?? 3.0,
                    ),
                  ),
            boxShadow: effectiveShadow,
          ),
          child: textWidget,
        );
    }
  }
}
