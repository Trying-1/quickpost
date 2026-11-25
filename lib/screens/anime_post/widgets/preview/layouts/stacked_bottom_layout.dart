import 'package:flutter/material.dart';
import '../../../models/anime_carousel_slide.dart';
import '../../../models/anime_template_theme.dart';
import '../../anime_detail_components.dart';
import '../slide_render_context.dart';

/// Layout 1: STACKED BOTTOM
/// Traditional carousel style with anime details stacked elegantly in the lower third.
class StackedBottomLayoutBuilder {
  static List<Widget> build(SlideRenderContext context) {
    final slide = context.slide;
    final theme = context.theme;
    final hasImage = context.hasImage;
    final offX = slide.contentOffsetX;
    final offY = slide.contentOffsetY;

    final rankBadge = AnimeRankBadgeComponent.fromTheme(
      rank: slide.rank,
      theme: theme,
      isDarkBackground: hasImage,
    );

    final titleColumn = context.buildTitleColumn(centered: true);

    final ratingBadge = AnimeRatingComponent.fromTheme(
      rating: slide.rating,
      theme: theme,
      isDarkBackground: hasImage,
    );
    final seasonsBadge = AnimeSeasonsComponent.fromTheme(
      seasons: slide.seasons,
      theme: theme,
      isDarkBackground: hasImage,
    );
    final episodesBadge = AnimeEpisodesComponent.fromTheme(
      episodes: slide.episodes,
      theme: theme,
      isDarkBackground: hasImage,
    );
    final studioBadge = AnimeStudioComponent.fromTheme(
      studio: slide.studio,
      theme: theme,
      isDarkBackground: hasImage,
    );
    final genresComponent = AnimeGenresComponent.fromTheme(
      genres: slide.genresList,
      theme: theme,
      isDarkBackground: hasImage,
    );
    final synopsisComponent = AnimeSynopsisComponent.fromTheme(
      synopsis: slide.synopsis,
      theme: theme,
      isDarkBackground: hasImage,
    );

    final List<Widget> list = [];

    // Card Backdrop Container
    if (theme.showCardBackdrop && theme.cardStyle != CardStyle.none) {
      final cardLeft = (12.0 + offX).clamp(-60.0, 100.0);
      final cardRight = (12.0 - offX).clamp(-60.0, 100.0);
      final cardBottom = (12.0 - offY).clamp(0.0, 300.0);
      final cardHeight = (theme.showSynopsis ? 230.0 : 160.0).clamp(100.0, 420.0);
      list.add(
        Positioned(
          left: cardLeft,
          right: cardRight,
          bottom: cardBottom,
          height: cardHeight,
          child: context.buildCardBackdrop(
            width: double.infinity,
            height: cardHeight,
            borderRadius: theme.cardBorderRadius,
          ),
        ),
      );
    }

    // 1. Rank Badge (dedicated top-left lane below header — never shifts title)
    if (theme.showRankBadge) {
      list.add(
        context.buildPositioned(
          componentId: SlideComponentId.rankBadge,
          label: 'Rank',
          baseLeft: 20,
          baseTop: 52,
          child: rankBadge,
        ),
      );
    }

    // 2. Title & Japanese Title (fixed horizontally centered anchor)
    list.add(
      context.buildPositioned(
        componentId: SlideComponentId.title,
        label: 'Title',
        baseLeft: 20,
        baseRight: 20,
        baseBottom: 142,
        child: titleColumn,
      ),
    );

    // 3. Metadata Badges Row (Episodes always centered; Rating & Seasons flank cleanly on left/right)
    if (theme.showRating) {
      list.add(
        context.buildPositioned(
          componentId: SlideComponentId.rating,
          label: 'Rating',
          baseLeft: 20,
          baseBottom: 98,
          child: ratingBadge,
        ),
      );
    }

    if (theme.showEpisodes) {
      list.add(
        context.buildPositioned(
          componentId: SlideComponentId.episodes,
          label: 'Episodes',
          baseLeft: 20,
          baseRight: 20,
          baseBottom: 98,
          child: Center(child: episodesBadge),
        ),
      );
    }

    if (theme.showSeasons) {
      list.add(
        context.buildPositioned(
          componentId: SlideComponentId.seasons,
          label: 'Seasons',
          baseRight: 20,
          baseBottom: 98,
          child: seasonsBadge,
        ),
      );
    }

    if (theme.showStudio) {
      list.add(
        context.buildPositioned(
          componentId: SlideComponentId.studio,
          label: 'Studio',
          baseLeft: 20,
          baseRight: 20,
          baseBottom: 60,
          child: Center(child: studioBadge),
        ),
      );
    }

    // 4. Genres Component (dedicated row below Studio)
    if (slide.genresList.isNotEmpty && theme.showGenres) {
      list.add(
        context.buildPositioned(
          componentId: SlideComponentId.genres,
          label: 'Genres',
          baseLeft: 20,
          baseRight: 20,
          baseBottom: 24,
          child: Center(child: genresComponent),
        ),
      );
    }

    // 5. Synopsis Box Component (dedicated lane above Title — never shifts Title/Episodes)
    if (slide.synopsis.isNotEmpty && theme.showSynopsis) {
      list.add(
        context.buildPositioned(
          componentId: SlideComponentId.synopsis,
          label: 'Synopsis',
          baseLeft: 20,
          baseRight: 20,
          baseBottom: 206,
          child: synopsisComponent,
        ),
      );
    }

    return list;
  }
}
