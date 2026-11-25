import 'dart:ui';
import 'anime_template_theme.dart';

enum SlideType { cover, anime, cta }

/// Standard component identifiers for individual positioning and dragging.
class SlideComponentId {
  static const String allContent = 'allContent';
  static const String cardBackdrop = 'cardBackdrop';
  static const String title = 'title';
  static const String rankBadge = 'rankBadge';
  static const String japaneseTitle = 'japaneseTitle';
  static const String rating = 'rating';
  static const String seasons = 'seasons';
  static const String episodes = 'episodes';
  static const String studio = 'studio';
  static const String genres = 'genres';
  static const String synopsis = 'synopsis';
  static const String hookTag = 'hookTag';
  static const String pageHandle = 'pageHandle';
  static const String slideCounter = 'slideCounter';
  static const String swipeIndicator = 'swipeIndicator';
  static const String heroVisual = 'heroVisual';
  static const String screenshots = 'screenshots';

  static const List<String> animeComponents = [
    allContent,
    title,
    rankBadge,
    japaneseTitle,
    rating,
    seasons,
    episodes,
    studio,
    genres,
    synopsis,
    hookTag,
    pageHandle,
    slideCounter,
    heroVisual,
    screenshots,
  ];

  static const List<String> coverComponents = [
    allContent,
    hookTag,
    title,
    synopsis,
    swipeIndicator,
    pageHandle,
    slideCounter,
    heroVisual,
  ];

  static const List<String> ctaComponents = [
    allContent,
    title,
    synopsis,
    swipeIndicator,
    pageHandle,
    slideCounter,
  ];

  static String getLabel(String key) {
    switch (key) {
      case allContent:
        return 'All Content (Group)';
      case cardBackdrop:
        return 'Backdrop Card';
      case title:
        return 'Anime Title';
      case rankBadge:
        return 'Rank Badge';
      case japaneseTitle:
        return 'Japanese Subtitle';
      case rating:
        return 'Rating';
      case seasons:
        return 'Seasons';
      case episodes:
        return 'Episodes';
      case studio:
        return 'Animation Studio';
      case genres:
        return 'Genres';
      case synopsis:
        return 'Synopsis / Story';
      case hookTag:
        return 'Hook Tag';
      case pageHandle:
        return 'Watermark / Handle';
      case slideCounter:
        return 'Slide Counter';
      case swipeIndicator:
        return 'Swipe Indicator';
      case heroVisual:
        return 'Hero Image Card';
      case screenshots:
        return 'Screenshots Grid';
      default:
        return key;
    }
  }
}

class AnimeCarouselSlide {
  final String id;
  SlideType type;

  // Background visual
  String? bgImagePath;
  double bgBrightness; // 0.0 to 1.5
  double bgBlur;       // 0.0 to 10.0
  final List<String> secondaryImagePaths; // Optional extra screenshots / gallery images

  // 1. Cover Slide Specifics
  String coverTag;         // e.g. "RECOMMENDATION"
  String coverTitle;       // e.g. "TOP 5 ACTION ANIME OF ALL TIME"
  String coverSubtitle;    // e.g. "You won't be able to stop watching!"

  // 2. Anime Content Slide Specifics
  int rank;                // e.g. 1
  String animeName;        // e.g. "Demon Slayer: Kimetsu no Yaiba"
  String japaneseName;     // e.g. "鬼滅の刃"
  String rating;           // e.g. "8.9 / 10"
  String seasons;          // e.g. "4 Seasons"
  String episodes;         // e.g. "55 Episodes"
  String studio;           // e.g. "Ufotable"
  String genres;           // e.g. "Action, Dark Fantasy"
  String synopsis;         // e.g. "Tanjiro fights demons to save his sister."

  // 3. CTA Slide Specifics
  String ctaHeadline;      // e.g. "Which one is your favorite?"
  String ctaSubheadline;   // e.g. "Drop your thoughts in the comments below!"
  String ctaTag;           // e.g. "SAVE THIS POST"

  // 4. Drag & Slider Positioning Offsets (px)
  double contentOffsetX;
  double contentOffsetY;
  double headerOffsetY;

  // 5. Individual Component Positioning Offsets (px)
  final Map<String, Offset> componentOffsets;

  // 6. Optional Per-Slide Custom Layout override (when syncAnimeSlideLayoutAndPosition is false)
  final SlideLayout? customLayout;

  AnimeCarouselSlide({
    required this.id,
    required this.type,
    String? bgImagePath,
    String? imagePath,
    this.customLayout,
    this.bgBrightness = 1.0,
    this.bgBlur = 0.0,
    this.coverTag = 'TOP PICKS',
    this.coverTitle = 'TOP 5 ANIME RECOMMENDATIONS',
    this.coverSubtitle = 'Masterpiece shows you must binge-watch right now',
    this.rank = 1,
    this.animeName = 'Anime Title',
    this.japaneseName = 'サブタイトル',
    this.rating = '9.0 / 10',
    this.seasons = '2 Seasons',
    this.episodes = '24 Episodes',
    this.studio = 'Studio Name',
    this.genres = 'Action, Adventure, Fantasy',
    this.synopsis = 'A compelling story of adventure, unforgettable bonds, and epic challenges.',
    this.ctaHeadline = 'Which one is your favorite?',
    this.ctaSubheadline = 'Share your top pick in the comments & save for your weekend binge!',
    this.ctaTag = 'SAVE & SHARE',
    this.contentOffsetX = 0.0,
    this.contentOffsetY = 0.0,
    this.headerOffsetY = 0.0,
    List<String>? secondaryImagePaths,
    Map<String, Offset>? componentOffsets,
  })  : bgImagePath = imagePath ?? bgImagePath,
        secondaryImagePaths = secondaryImagePaths != null
            ? List.unmodifiable(secondaryImagePaths)
            : const [],
        componentOffsets = componentOffsets != null
            ? Map.unmodifiable(componentOffsets)
            : const {};

  /// Resolves the layout to use for this slide based on the global theme sync toggle.
  SlideLayout getEffectiveLayout(AnimeTemplateTheme theme) {
    if (theme.syncAnimeSlideLayoutAndPosition) {
      return theme.slideLayout;
    }
    return customLayout ?? theme.slideLayout;
  }

  Offset getComponentOffset(String key) {
    if (componentOffsets.containsKey(key)) {
      return componentOffsets[key]!;
    }
    if (key == SlideComponentId.allContent) {
      return Offset(contentOffsetX, contentOffsetY);
    }
    if (key == SlideComponentId.pageHandle || key == SlideComponentId.slideCounter) {
      return Offset(0.0, headerOffsetY);
    }
    return Offset.zero;
  }

  AnimeCarouselSlide copyWithComponentOffset(String key, Offset offset) {
    final updated = Map<String, Offset>.from(componentOffsets);
    updated[key] = offset;

    double newContentX = contentOffsetX;
    double newContentY = contentOffsetY;
    double newHeaderY = headerOffsetY;

    if (key == SlideComponentId.allContent) {
      newContentX = offset.dx;
      newContentY = offset.dy;
    } else if (key == SlideComponentId.pageHandle || key == SlideComponentId.slideCounter) {
      newHeaderY = offset.dy;
    }

    return copyWith(
      componentOffsets: updated,
      contentOffsetX: newContentX,
      contentOffsetY: newContentY,
      headerOffsetY: newHeaderY,
    );
  }

  AnimeCarouselSlide copyWithResetOffsets({String? specificKey}) {
    if (specificKey != null) {
      final updated = Map<String, Offset>.from(componentOffsets);
      updated.remove(specificKey);
      double newContentX = contentOffsetX;
      double newContentY = contentOffsetY;
      double newHeaderY = headerOffsetY;
      if (specificKey == SlideComponentId.allContent) {
        newContentX = 0.0;
        newContentY = 0.0;
      } else if (specificKey == SlideComponentId.pageHandle || specificKey == SlideComponentId.slideCounter) {
        newHeaderY = 0.0;
      }
      return copyWith(
        componentOffsets: updated,
        contentOffsetX: newContentX,
        contentOffsetY: newContentY,
        headerOffsetY: newHeaderY,
      );
    }

    return copyWith(
      componentOffsets: const {},
      contentOffsetX: 0.0,
      contentOffsetY: 0.0,
      headerOffsetY: 0.0,
    );
  }

  String? get imagePath => bgImagePath;

  List<String> get genresList {
    if (genres.isEmpty) return const [];
    return genres
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  AnimeCarouselSlide copyWith({
    String? id,
    SlideType? type,
    String? bgImagePath,
    String? imagePath,
    bool clearImagePath = false,
    double? bgBrightness,
    double? bgBlur,
    String? coverTag,
    String? coverTitle,
    String? coverSubtitle,
    int? rank,
    String? animeName,
    String? japaneseName,
    String? rating,
    String? seasons,
    String? episodes,
    String? studio,
    dynamic genres,
    String? synopsis,
    String? ctaHeadline,
    String? ctaSubheadline,
    String? ctaTag,
    double? contentOffsetX,
    double? contentOffsetY,
    double? headerOffsetY,
    List<String>? secondaryImagePaths,
    Map<String, Offset>? componentOffsets,
    SlideLayout? customLayout,
    bool clearCustomLayout = false,
  }) {
    String? finalImagePath;
    if (clearImagePath) {
      finalImagePath = null;
    } else {
      finalImagePath = imagePath ?? bgImagePath ?? this.bgImagePath;
    }

    String finalGenres;
    if (genres is List) {
      finalGenres = genres.map((e) => e.toString().trim()).join(', ');
    } else if (genres is String) {
      finalGenres = genres;
    } else {
      finalGenres = this.genres;
    }

    return AnimeCarouselSlide(
      id: id ?? this.id,
      type: type ?? this.type,
      bgImagePath: finalImagePath,
      bgBrightness: bgBrightness ?? this.bgBrightness,
      bgBlur: bgBlur ?? this.bgBlur,
      coverTag: coverTag ?? this.coverTag,
      coverTitle: coverTitle ?? this.coverTitle,
      coverSubtitle: coverSubtitle ?? this.coverSubtitle,
      rank: rank ?? this.rank,
      animeName: animeName ?? this.animeName,
      japaneseName: japaneseName ?? this.japaneseName,
      rating: rating ?? this.rating,
      seasons: seasons ?? this.seasons,
      episodes: episodes ?? this.episodes,
      studio: studio ?? this.studio,
      genres: finalGenres,
      synopsis: synopsis ?? this.synopsis,
      ctaHeadline: ctaHeadline ?? this.ctaHeadline,
      ctaSubheadline: ctaSubheadline ?? this.ctaSubheadline,
      ctaTag: ctaTag ?? this.ctaTag,
      contentOffsetX: contentOffsetX ?? this.contentOffsetX,
      contentOffsetY: contentOffsetY ?? this.contentOffsetY,
      headerOffsetY: headerOffsetY ?? this.headerOffsetY,
      secondaryImagePaths: secondaryImagePaths ?? this.secondaryImagePaths,
      componentOffsets: componentOffsets ?? this.componentOffsets,
      customLayout: clearCustomLayout ? null : (customLayout ?? this.customLayout),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.index,
      'bgImagePath': bgImagePath,
      'bgBrightness': bgBrightness,
      'bgBlur': bgBlur,
      'coverTag': coverTag,
      'coverTitle': coverTitle,
      'coverSubtitle': coverSubtitle,
      'rank': rank,
      'animeName': animeName,
      'japaneseName': japaneseName,
      'rating': rating,
      'seasons': seasons,
      'episodes': episodes,
      'studio': studio,
      'genres': genres,
      'synopsis': synopsis,
      'ctaHeadline': ctaHeadline,
      'ctaSubheadline': ctaSubheadline,
      'ctaTag': ctaTag,
      'contentOffsetX': contentOffsetX,
      'contentOffsetY': contentOffsetY,
      'headerOffsetY': headerOffsetY,
      'secondaryImagePaths': secondaryImagePaths,
      'componentOffsets': componentOffsets.map((k, v) => MapEntry(k, {'x': v.dx, 'y': v.dy})),
      'customLayout': customLayout?.name,
    };
  }

  factory AnimeCarouselSlide.fromMap(Map<String, dynamic> map) {
    Map<String, Offset>? parsedOffsets;
    if (map['componentOffsets'] is Map) {
      final raw = map['componentOffsets'] as Map<dynamic, dynamic>;
      parsedOffsets = raw.map((k, v) {
        final valMap = v as Map<dynamic, dynamic>;
        return MapEntry(
          k.toString(),
          Offset(
            (valMap['x'] as num?)?.toDouble() ?? 0.0,
            (valMap['y'] as num?)?.toDouble() ?? 0.0,
          ),
        );
      });
    }

    return AnimeCarouselSlide(
      id: map['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      type: SlideType.values[map['type'] as int? ?? 1],
      bgImagePath: map['bgImagePath'] as String?,
      bgBrightness: (map['bgBrightness'] as num?)?.toDouble() ?? 1.0,
      bgBlur: (map['bgBlur'] as num?)?.toDouble() ?? 0.0,
      coverTag: map['coverTag'] as String? ?? 'ANIME RECOMMENDATION',
      coverTitle: map['coverTitle'] as String? ?? 'TOP 5 ACTION ANIME OF ALL TIME',
      coverSubtitle: map['coverSubtitle'] as String? ?? '',
      rank: map['rank'] as int? ?? 1,
      animeName: map['animeName'] as String? ?? '',
      japaneseName: map['japaneseName'] as String? ?? '',
      rating: map['rating'] as String? ?? '',
      seasons: map['seasons'] as String? ?? '',
      episodes: map['episodes'] as String? ?? '',
      studio: map['studio'] as String? ?? '',
      genres: map['genres'] as String? ?? '',
      synopsis: map['synopsis'] as String? ?? '',
      ctaHeadline: map['ctaHeadline'] as String? ?? 'Which one is your favorite?',
      ctaSubheadline: map['ctaSubheadline'] as String? ?? '',
      ctaTag: map['ctaTag'] as String? ?? 'SAVE & SHARE',
      contentOffsetX: (map['contentOffsetX'] as num?)?.toDouble() ?? 0.0,
      contentOffsetY: (map['contentOffsetY'] as num?)?.toDouble() ?? 0.0,
      headerOffsetY: (map['headerOffsetY'] as num?)?.toDouble() ?? 0.0,
      secondaryImagePaths: (map['secondaryImagePaths'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      componentOffsets: parsedOffsets,
      customLayout: map['customLayout'] != null
          ? () {
              final val = map['customLayout'] as String?;
              if (val == 'showcaseGallery') return SlideLayout.layout1;
              if (val == 'boldHeadline') return SlideLayout.layout2;
              if (val == 'floatingPoster') return SlideLayout.layout3;
              return SlideLayout.values.firstWhere(
                (e) => e.name == val,
                orElse: () => SlideLayout.defaultLayout,
              );
            }()
          : null,
    );
  }
}

extension AnimeTemplateThemeSlideExt on AnimeTemplateTheme {
  /// Determines whether a component is enabled for a specific slide instance,
  /// taking into account global toggles and slide-specific content (e.g. empty coverSubtitle).
  bool isComponentEnabledForSlide(String key, AnimeCarouselSlide? slide) {
    if (slide != null) {
      if (slide.type == SlideType.cover) {
        if (key == SlideComponentId.hookTag) {
          return showHookTag && slide.coverTag.trim().isNotEmpty;
        }
        if (key == SlideComponentId.synopsis) {
          return slide.coverSubtitle.trim().isNotEmpty;
        }
      } else if (slide.type == SlideType.cta) {
        if (key == SlideComponentId.synopsis) {
          return slide.ctaSubheadline.trim().isNotEmpty;
        }
      }
    }
    return isComponentEnabled(key);
  }
}
