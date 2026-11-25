import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import '../../../services/anime_post_preset_service.dart';
import '../models/anime_carousel_project.dart';
import '../models/anime_carousel_slide.dart';
import '../models/anime_template_theme.dart';

/// Service for importing, exporting, and converting Anime Carousel posts to/from JSON.
/// Designed for seamless integration with LLMs (Gemini, ChatGPT, Claude) to automate slide creation.
class AnimePostJsonService {
  /// Robustly extracts and decodes a JSON Map or List from raw text.
  /// Handles LLM markdown blocks (```json ... ```), preamble text, and loose whitespace.
  static dynamic parseLlmJson(String rawText) {
    String cleaned = rawText.trim();

    // 1. Strip markdown fences if present
    if (cleaned.contains('```')) {
      final regExp = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```', caseSensitive: false);
      final match = regExp.firstMatch(cleaned);
      if (match != null && match.group(1) != null) {
        cleaned = match.group(1)!.trim();
      }
    }

    // 2. If text still contains non-JSON prefix/suffix, locate first '{' or '[' and last '}' or ']'
    final firstObj = cleaned.indexOf('{');
    final firstArr = cleaned.indexOf('[');

    int startIdx = -1;
    int endIdx = -1;

    if (firstObj != -1 && (firstArr == -1 || firstObj < firstArr)) {
      startIdx = firstObj;
      endIdx = cleaned.lastIndexOf('}');
    } else if (firstArr != -1) {
      startIdx = firstArr;
      endIdx = cleaned.lastIndexOf(']');
    }

    if (startIdx != -1 && endIdx != -1 && endIdx > startIdx) {
      cleaned = cleaned.substring(startIdx, endIdx + 1).trim();
    }

    return json.decode(cleaned);
  }

  /// Converts parsed JSON data (Map or List) into a fully populated [AnimeCarouselProject].
  /// Optionally preserves existing slide image paths matching the slide index.
  static AnimeCarouselProject createProjectFromJson({
    required dynamic jsonData,
    AnimeTemplateTheme? existingTheme,
    List<AnimeCarouselSlide>? existingSlides,
    bool preserveImages = true,
  }) {
    // Map of existing images by index (0: cover, 1..N: anime, N+1: cta)
    final Map<int, String> existingImagePaths = {};
    if (preserveImages && existingSlides != null) {
      for (int i = 0; i < existingSlides.length; i++) {
        final img = existingSlides[i].imagePath;
        if (img != null && img.isNotEmpty) {
          existingImagePaths[i] = img;
        }
      }
    }

    // Case 1: Direct AnimeCarouselProject.toMap() output
    if (jsonData is Map<String, dynamic> && jsonData.containsKey('slides') && jsonData['slides'] is List) {
      final project = AnimeCarouselProject.fromMap(jsonData);
      if (preserveImages && existingImagePaths.isNotEmpty) {
        final updated = List<AnimeCarouselSlide>.from(project.slides);
        for (int i = 0; i < updated.length; i++) {
          if (existingImagePaths.containsKey(i)) {
            updated[i] = updated[i].copyWith(imagePath: existingImagePaths[i]);
          }
        }
        return project.copyWith(slides: updated);
      }
      return project;
    }

    // Case 2: Standard Structured Object { title, cover, anime: [...], cta }
    if (jsonData is Map) {
      final map = Map<String, dynamic>.from(jsonData);
      final title = map['title']?.toString() ?? 'Anime Carousel Recommendations';

      // 1. Cover Slide
      final coverData = map['cover'] is Map ? Map<String, dynamic>.from(map['cover'] as Map) : null;
      final coverTag = coverData?['tag']?.toString() ?? coverData?['hookTag']?.toString() ?? 'RECOMMENDATION';
      final coverTitle = coverData?['title']?.toString() ?? title.toUpperCase();
      final coverSubtitle = coverData?['subtitle']?.toString() ?? 'Must-watch series for your anime watchlist';

      final coverSlide = AnimeCarouselSlide(
        id: 'slide_cover_${DateTime.now().millisecondsSinceEpoch}',
        type: SlideType.cover,
        bgImagePath: existingImagePaths[0],
        coverTag: coverTag,
        coverTitle: coverTitle,
        coverSubtitle: coverSubtitle,
      );

      // 2. Anime Slides
      final rawAnimeList = (map['anime'] ?? map['items'] ?? map['list'] ?? map['shows'] ?? []) as List;
      final animeSlides = <AnimeCarouselSlide>[];

      for (int i = 0; i < rawAnimeList.length; i++) {
        final item = rawAnimeList[i];
        if (item is Map) {
          final animeSlide = _parseAnimeSlide(
            map: Map<String, dynamic>.from(item),
            defaultRank: i + 1,
            existingImagePath: existingImagePaths[i + 1],
          );
          animeSlides.add(animeSlide);
        }
      }

      // If no anime items found in structured map, check if any list key exists
      if (animeSlides.isEmpty) {
        for (final entry in map.entries) {
          if (entry.value is List && (entry.value as List).isNotEmpty) {
            final list = entry.value as List;
            if (list.first is Map) {
              for (int i = 0; i < list.length; i++) {
                animeSlides.add(_parseAnimeSlide(
                  map: Map<String, dynamic>.from(list[i] as Map),
                  defaultRank: i + 1,
                  existingImagePath: existingImagePaths[i + 1],
                ));
              }
              break;
            }
          }
        }
      }

      // 3. CTA Slide
      final ctaData = map['cta'] is Map ? Map<String, dynamic>.from(map['cta'] as Map) : null;
      final ctaIndex = animeSlides.length + 1;
      final ctaSlide = AnimeCarouselSlide(
        id: 'slide_cta_${DateTime.now().millisecondsSinceEpoch}',
        type: SlideType.cta,
        bgImagePath: existingImagePaths[ctaIndex],
        ctaHeadline: ctaData?['headline']?.toString() ?? 'Which one is your favorite?',
        ctaSubheadline: ctaData?['subheadline']?.toString() ?? 'Share your top pick in the comments & save for later!',
        ctaTag: ctaData?['tag']?.toString() ?? 'SAVE & FOLLOW',
      );

      return AnimeCarouselProject(
        id: 'proj_${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        theme: existingTheme ?? const AnimeTemplateTheme(),
        slides: [coverSlide, ...animeSlides, ctaSlide],
      );
    }

    // Case 3: Simple List of Anime Items [{...}, {...}]
    if (jsonData is List) {
      final list = jsonData;
      final animeSlides = <AnimeCarouselSlide>[];

      for (int i = 0; i < list.length; i++) {
        if (list[i] is Map) {
          animeSlides.add(_parseAnimeSlide(
            map: Map<String, dynamic>.from(list[i] as Map),
            defaultRank: i + 1,
            existingImagePath: existingImagePaths[i + 1],
          ));
        }
      }

      final count = animeSlides.length;
      final title = 'TOP $count ANIME RECOMMENDATIONS';

      final coverSlide = AnimeCarouselSlide(
        id: 'slide_cover_${DateTime.now().millisecondsSinceEpoch}',
        type: SlideType.cover,
        bgImagePath: existingImagePaths[0],
        coverTag: 'RECOMMENDATION',
        coverTitle: title,
        coverSubtitle: 'Masterpiece series you must watch before 2026',
      );

      final ctaIndex = animeSlides.length + 1;
      final ctaSlide = AnimeCarouselSlide(
        id: 'slide_cta_${DateTime.now().millisecondsSinceEpoch}',
        type: SlideType.cta,
        bgImagePath: existingImagePaths[ctaIndex],
        ctaHeadline: 'Which one is your favorite?',
        ctaSubheadline: 'Save this post for later & drop your thoughts below!',
        ctaTag: 'SAVE & SHARE',
      );

      return AnimeCarouselProject(
        id: 'proj_${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        theme: existingTheme ?? const AnimeTemplateTheme(),
        slides: [coverSlide, ...animeSlides, ctaSlide],
      );
    }

    throw const FormatException('Unsupported JSON format. Expected a JSON Object or Array.');
  }

  static AnimeCarouselSlide _parseAnimeSlide({
    required Map<String, dynamic> map,
    required int defaultRank,
    String? existingImagePath,
  }) {
    // Tolerant key mapping for various LLM output patterns
    final rank = (map['rank'] as num?)?.toInt() ?? (map['id'] as num?)?.toInt() ?? defaultRank;
    final name = map['name'] ?? map['title'] ?? map['animeName'] ?? map['anime'] ?? 'Anime #$defaultRank';
    final jpName = map['japaneseName'] ?? map['japaneseTitle'] ?? map['japanese'] ?? map['romaji'] ?? '';
    final rating = map['rating'] ?? map['score'] ?? map['malScore'] ?? '8.5 / 10';
    final seasons = map['seasons'] ?? map['seasonCount'] ?? '1 Season';
    final episodes = map['episodes'] ?? map['episodeCount'] ?? map['eps'] ?? '12 Episodes';
    final studio = map['studio'] ?? map['animationStudio'] ?? '';

    dynamic rawGenres = map['genres'] ?? map['genre'] ?? map['tags'] ?? 'Action, Fantasy';
    String genresStr;
    if (rawGenres is List) {
      genresStr = rawGenres.map((e) => e.toString().trim()).join(', ');
    } else {
      genresStr = rawGenres.toString();
    }

    final synopsis = map['synopsis'] ?? map['description'] ?? map['plot'] ?? map['summary'] ?? '';

    return AnimeCarouselSlide(
      id: 'slide_anime_${DateTime.now().millisecondsSinceEpoch}_$defaultRank',
      type: SlideType.anime,
      bgImagePath: existingImagePath,
      rank: rank,
      animeName: name.toString(),
      japaneseName: jpName.toString(),
      rating: rating.toString(),
      seasons: seasons.toString(),
      episodes: episodes.toString(),
      studio: studio.toString(),
      genres: genresStr,
      synopsis: synopsis.toString(),
    );
  }

  /// Generates the prompt tailored for ChatGPT, Claude, and Gemini with:
  /// - [title]: The custom topic or title (e.g. "Top 5 Action Anime")
  /// - [count]: The number variable for how many anime recommendations to generate
  /// - Explicit instruction to wrap output strictly in a ```json ``` codeblock for 1-click copying.
  static String getAiPromptTemplate({
    String title = 'Top 5 Action Anime of All Time',
    int count = 5,
  }) {
    final cleanTitle = title.trim().isEmpty ? 'Top $count Anime of All Time' : title.trim();
    return '''
Generate carousel post content for an Instagram/TikTok anime carousel post about: "$cleanTitle" featuring exactly $count anime recommendations.

CRITICAL FORMATTING INSTRUCTIONS:
1. Output the JSON STRICTLY inside a markdown ```json ``` codeblock so I can copy it with 1 click using the "Copy code" button.
2. Do not write any explanations, greetings, or notes outside the ```json codeblock.
3. Include exactly $count anime items inside the "anime" array, numbered with ranks 1 through $count.

Structure to follow:
```json
{
  "title": "$cleanTitle",
  "cover": {
    "tag": "MUST WATCH",
    "title": "${cleanTitle.toUpperCase()}",
    "subtitle": "Mind-blowing anime series you won't be able to stop watching"
  },
  "anime": [
    {
      "rank": 1,
      "name": "Anime Name",
      "japaneseName": "Japanese Title in Kanji/Katakana",
      "rating": "8.9 / 10",
      "seasons": "2 Seasons",
      "episodes": "24 Episodes",
      "studio": "Studio Name (e.g. MAPPA, Ufotable)",
      "genres": "Action, Dark Fantasy, Shonen",
      "synopsis": "A punchy 1-2 sentence hook describing the premise."
    }
  ],
  "cta": {
    "headline": "Which one is your favorite?",
    "subheadline": "Save this post for later & comment your top pick below!",
    "tag": "SAVE & FOLLOW"
  }
}
```
'''.trim();
  }

  /// Exports the carousel project to a formatted JSON file in Downloads/Quick Post Backup/
  static Future<String> exportProjectToJsonFile(AnimeCarouselProject project) async {
    final jsonStr = const JsonEncoder.withIndent('  ').convert(project.toMap());
    final backupDir = await AnimePostPresetService.getBackupDirectory();
    final sanitizedTitle = project.title.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final fileName = 'anime_post_${sanitizedTitle}_${DateTime.now().millisecondsSinceEpoch}.json';
    final file = File('${backupDir.path}/$fileName');
    await file.writeAsString(jsonStr);

    try {
      const MethodChannel('com.quickpost.app/processor').invokeMethod('scanMediaFile', {
        'filePath': file.path,
        'mimeType': 'application/json',
      });
    } catch (_) {}

    return file.path;
  }

  /// Opens the device file picker to select a .json file and returns its text content.
  static Future<String?> pickJsonFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'txt'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      return await file.readAsString();
    }
    return null;
  }

  /// Pre-built sample presets ready to test in 1 click
  static final Map<String, String> samplePresets = {
    'Top 5 Psychological Thrillers': '''
{
  "title": "Top 5 Psychological Thriller Anime",
  "cover": {
    "tag": "MIND BENDING",
    "title": "TOP 5 PSYCHOLOGICAL THRILLERS",
    "subtitle": "Masterpieces that will test your mind & question your sanity"
  },
  "anime": [
    {
      "rank": 1,
      "name": "Death Note",
      "japaneseName": "デスノート",
      "rating": "9.0 / 10",
      "seasons": "1 Season",
      "episodes": "37 Episodes",
      "studio": "Madhouse",
      "genres": "Psychological, Supernatural, Mystery",
      "synopsis": "A genius student discovers a supernatural notebook granting power over life and death, sparking an epic cat-and-mouse game with world-class detective L."
    },
    {
      "rank": 2,
      "name": "Steins;Gate",
      "japaneseName": "シュタインズ・ゲート",
      "rating": "9.1 / 10",
      "seasons": "1 Season",
      "episodes": "24 Episodes",
      "studio": "White Fox",
      "genres": "Sci-Fi, Psychological, Thriller",
      "synopsis": "An eccentric self-proclaimed mad scientist accidentally creates a microwave capable of sending text messages to the past with dire consequences."
    },
    {
      "rank": 3,
      "name": "Monster",
      "japaneseName": "モンスター",
      "rating": "8.9 / 10",
      "seasons": "1 Season",
      "episodes": "74 Episodes",
      "studio": "Madhouse",
      "genres": "Psychological, Mystery, Crime Drama",
      "synopsis": "A brilliant brain surgeon risks his career to save a young boy, only to discover years later that he inadvertently unleashed a charismatic sociopath."
    },
    {
      "rank": 4,
      "name": "Psycho-Pass",
      "japaneseName": "サイコパス",
      "rating": "8.4 / 10",
      "seasons": "3 Seasons",
      "episodes": "41 Episodes",
      "studio": "Production I.G",
      "genres": "Cyberpunk, Sci-Fi, Action",
      "synopsis": "In a future where minds are judged by an automated Sibyl System, an idealistic detective uncovers the chilling truth behind criminal intent."
    },
    {
      "rank": 5,
      "name": "Erased",
      "japaneseName": "僕だけがいない街",
      "rating": "8.3 / 10",
      "seasons": "1 Season",
      "episodes": "12 Episodes",
      "studio": "A-1 Pictures",
      "genres": "Mystery, Psychological, Supernatural",
      "synopsis": "A struggling manga artist with the ability to rewind time is sent back 18 years to his childhood to prevent the abduction of his classmate."
    }
  ],
  "cta": {
    "headline": "Which mind game had you hooked?",
    "subheadline": "Save this post for your weekend binge & drop your top pick in the comments!",
    "tag": "SAVE THIS POST"
  }
}
''',
    'Top 5 Isekai Masterpieces': '''
{
  "title": "Top 5 Isekai Masterpieces",
  "cover": {
    "tag": "ANOTHER WORLD",
    "title": "TOP 5 ISEKAI MASTERPIECES",
    "subtitle": "Transported into another world: fantasy realms you will fall in love with"
  },
  "anime": [
    {
      "rank": 1,
      "name": "Re:Zero − Starting Life in Another World",
      "japaneseName": "Re:ゼロから始める異世界生活",
      "rating": "8.3 / 10",
      "seasons": "3 Seasons",
      "episodes": "50+ Episodes",
      "studio": "White Fox",
      "genres": "Psychological, Dark Fantasy, Isekai",
      "synopsis": "Subaru is summoned to a fantasy world with only one harrowing ability: Return by Death, forcing him through emotional agony to save those he loves."
    },
    {
      "rank": 2,
      "name": "Mushoku Tensei: Jobless Reincarnation",
      "japaneseName": "無職転生 〜異世界行ったら本気だす〜",
      "rating": "8.8 / 10",
      "seasons": "2 Seasons",
      "episodes": "48 Episodes",
      "studio": "Studio Bind",
      "genres": "Adventure, Drama, Fantasy",
      "synopsis": "Reincarnated into a magical world as a prodigy child named Rudeus, a former recluse resolves to live life without regrets."
    },
    {
      "rank": 3,
      "name": "That Time I Got Reincarnated as a Slime",
      "japaneseName": "転生したらスライムだった件",
      "rating": "8.2 / 10",
      "seasons": "3 Seasons",
      "episodes": "72 Episodes",
      "studio": "8bit",
      "genres": "Fantasy, Comedy, Shonen",
      "synopsis": "A corporate salaryman is reborn in a fantasy realm as a sentient slime named Rimuru, quickly building a united nation of monsters."
    },
    {
      "rank": 4,
      "name": "Overlord",
      "japaneseName": "オーバーロード",
      "rating": "8.0 / 10",
      "seasons": "4 Seasons",
      "episodes": "52 Episodes",
      "studio": "Madhouse",
      "genres": "Dark Fantasy, Game, Supernatural",
      "synopsis": "Trapped as his skeletal guildmaster avatar Ainz Ooal Gown when his favorite MMORPG shuts down, a player conquers a mysterious new world."
    },
    {
      "rank": 5,
      "name": "KonoSuba: God's Blessing on this Wonderful World!",
      "japaneseName": "この素晴らしい世界に祝福を！",
      "rating": "8.2 / 10",
      "seasons": "3 Seasons",
      "episodes": "31 Episodes",
      "studio": "Drive / Studio Deen",
      "genres": "Comedy, Fantasy, Parody",
      "synopsis": "Kazuma is sent to a fantasy world alongside a useless water goddess, forming the most dysfunctional, hilarious adventuring party in history."
    }
  ],
  "cta": {
    "headline": "Which world would you get isekai'd to?",
    "subheadline": "Save this carousel for your watchlist & share your favorite in the comments!",
    "tag": "SAVE & SHARE"
  }
}
'''
  };
}
