import 'anime_carousel_slide.dart';
import 'anime_template_theme.dart';

class AnimeCarouselProject {
  final String id;
  String title;
  AnimeTemplateTheme theme;
  List<AnimeCarouselSlide> slides;

  AnimeCarouselProject({
    required this.id,
    required this.title,
    required this.theme,
    required this.slides,
  });

  AnimeCarouselProject copyWith({
    String? id,
    String? title,
    AnimeTemplateTheme? theme,
    List<AnimeCarouselSlide>? slides,
  }) {
    return AnimeCarouselProject(
      id: id ?? this.id,
      title: title ?? this.title,
      theme: theme ?? this.theme,
      slides: slides ?? this.slides,
    );
  }

  static AnimeCarouselProject createDefault() {
    return AnimeCarouselProject(
      id: 'default_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Top 5 Anime Recommendations',
      theme: const AnimeTemplateTheme(),
      slides: [
        // 1. Cover Slide
        AnimeCarouselSlide(
          id: 'slide_cover',
          type: SlideType.cover,
          coverTag: 'RECOMMENDATIONS',
          coverTitle: 'TOP 5 ANIME RECOMMENDATIONS',
          coverSubtitle: 'Must-watch series you should binge-watch next!',
        ),
        // 2. Anime Slide #1
        AnimeCarouselSlide(
          id: 'slide_anime_1',
          type: SlideType.anime,
          rank: 1,
          animeName: 'Anime Title #1',
          japaneseName: 'タイトル 1',
          rating: '9.0 / 10',
          seasons: '2 Seasons',
          episodes: '24 Episodes',
          studio: 'Animation Studio',
          genres: 'Action, Fantasy, Adventure',
          synopsis: 'An unforgettable journey filled with epic battles, determination, and discovery.',
        ),
        // 3. Anime Slide #2
        AnimeCarouselSlide(
          id: 'slide_anime_2',
          type: SlideType.anime,
          rank: 2,
          animeName: 'Anime Title #2',
          japaneseName: 'タイトル 2',
          rating: '8.8 / 10',
          seasons: '1 Season',
          episodes: '12 Episodes',
          studio: 'Animation Studio',
          genres: 'Mystery, Supernatural',
          synopsis: 'A gripping tale where secrets unfold and unexpected twists keep you on edge.',
        ),
        // 4. Anime Slide #3
        AnimeCarouselSlide(
          id: 'slide_anime_3',
          type: SlideType.anime,
          rank: 3,
          animeName: 'Anime Title #3',
          japaneseName: 'タイトル 3',
          rating: '8.7 / 10',
          seasons: '3 Seasons',
          episodes: '36 Episodes',
          studio: 'Animation Studio',
          genres: 'Drama, Psychological',
          synopsis: 'High stakes and intense mind games challenge characters to their very core.',
        ),
        // 5. Anime Slide #4
        AnimeCarouselSlide(
          id: 'slide_anime_4',
          type: SlideType.anime,
          rank: 4,
          animeName: 'Anime Title #4',
          japaneseName: 'タイトル 4',
          rating: '8.5 / 10',
          seasons: '2 Seasons',
          episodes: '24 Episodes',
          studio: 'Animation Studio',
          genres: 'Sci-Fi, Cyberpunk',
          synopsis: 'A futuristic city where technology, rebellion, and freedom collide.',
        ),
        // 6. Anime Slide #5
        AnimeCarouselSlide(
          id: 'slide_anime_5',
          type: SlideType.anime,
          rank: 5,
          animeName: 'Anime Title #5',
          japaneseName: 'タイトル 5',
          rating: '8.4 / 10',
          seasons: '1 Season',
          episodes: '12 Episodes',
          studio: 'Animation Studio',
          genres: 'Slice of Life, Comedy',
          synopsis: 'Heartwarming everyday moments and humor that will brighten your day.',
        ),
        // 7. CTA Slide
        AnimeCarouselSlide(
          id: 'slide_cta',
          type: SlideType.cta,
          ctaHeadline: 'Which one is your favorite?',
          ctaSubheadline: 'Save this post for later & share your top pick in the comments below!',
          ctaTag: 'SAVE & FOLLOW',
        ),
      ],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'theme': theme.toMap(),
      'slides': slides.map((s) => s.toMap()).toList(),
    };
  }

  factory AnimeCarouselProject.fromMap(Map<String, dynamic> map) {
    return AnimeCarouselProject(
      id: map['id'] as String? ?? 'proj_${DateTime.now().millisecondsSinceEpoch}',
      title: map['title'] as String? ?? 'Anime Carousel Project',
      theme: AnimeTemplateTheme.fromMap(Map<String, dynamic>.from(map['theme'] as Map? ?? {})),
      slides: (map['slides'] as List? ?? [])
          .map((item) => AnimeCarouselSlide.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList(),
    );
  }
}
