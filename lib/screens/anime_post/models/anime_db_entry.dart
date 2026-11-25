import 'dart:convert';

/// A single record in the local anime database.
class AnimeDbEntry {
  final String id;
  final String name;
  final String japaneseName;
  final String rating; // e.g. "8.9 / 10"
  final String seasons; // e.g. "4 Seasons"
  final String episodes; // e.g. "55 Episodes"
  final String studio;
  final String genres; // comma separated
  final String characters; // comma separated main/popular characters
  final String synopsis;
  final int? year;
  final bool verified; // user double-checked this entry
  final DateTime updatedAt;

  const AnimeDbEntry({
    required this.id,
    required this.name,
    this.japaneseName = '',
    this.rating = '',
    this.seasons = '',
    this.episodes = '',
    this.studio = '',
    this.genres = '',
    this.characters = '',
    this.synopsis = '',
    this.year,
    this.verified = false,
    required this.updatedAt,
  });

  /// Stable key used for de-duplication (case/punctuation-insensitive).
  String get key => normalizeKey(name);

  static String normalizeKey(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  AnimeDbEntry copyWith({
    String? name,
    String? japaneseName,
    String? rating,
    String? seasons,
    String? episodes,
    String? studio,
    String? genres,
    String? characters,
    String? synopsis,
    int? year,
    bool clearYear = false,
    bool? verified,
    DateTime? updatedAt,
  }) {
    return AnimeDbEntry(
      id: id,
      name: name ?? this.name,
      japaneseName: japaneseName ?? this.japaneseName,
      rating: rating ?? this.rating,
      seasons: seasons ?? this.seasons,
      episodes: episodes ?? this.episodes,
      studio: studio ?? this.studio,
      genres: genres ?? this.genres,
      characters: characters ?? this.characters,
      synopsis: synopsis ?? this.synopsis,
      year: clearYear ? null : (year ?? this.year),
      verified: verified ?? this.verified,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'japaneseName': japaneseName,
        'rating': rating,
        'seasons': seasons,
        'episodes': episodes,
        'studio': studio,
        'genres': genres,
        'characters': characters,
        'synopsis': synopsis,
        'year': year,
        'verified': verified,
        'updatedAt': updatedAt.toIso8601String(),
      };

  /// Lenient parser: accepts LLM-style JSON with varied key names/types.
  /// Returns null if no usable name is found.
  static AnimeDbEntry? fromLooseMap(Map<String, dynamic> m, {String? fallbackId}) {
    String s(List<String> keys) {
      for (final k in keys) {
        final v = m[k];
        if (v == null) continue;
        if (v is List) return v.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).join(', ');
        final t = v.toString().trim();
        if (t.isNotEmpty && t != 'null') return t;
      }
      return '';
    }

    final name = s(['name', 'title', 'animeName', 'anime_name', 'english', 'titleEnglish']);
    if (name.isEmpty) return null;

    String rating = s(['rating', 'score', 'mal_score', 'malScore']);
    if (rating.isNotEmpty && double.tryParse(rating) != null) rating = '$rating / 10';

    String seasons = s(['seasons', 'season_count', 'seasonCount']);
    if (seasons.isNotEmpty && int.tryParse(seasons) != null) {
      seasons = '$seasons Season${seasons == '1' ? '' : 's'}';
    }

    String episodes = s(['episodes', 'episode_count', 'episodeCount', 'eps']);
    if (episodes.isNotEmpty && int.tryParse(episodes) != null) {
      episodes = '$episodes Episode${episodes == '1' ? '' : 's'}';
    }

    final yearRaw = s(['year', 'releaseYear', 'release_year', 'aired']);
    final year = int.tryParse(RegExp(r'\d{4}').firstMatch(yearRaw)?.group(0) ?? '');

    final updated = DateTime.tryParse(s(['updatedAt'])) ?? DateTime.now();

    return AnimeDbEntry(
      id: s(['id']).isNotEmpty
          ? s(['id'])
          : (fallbackId ?? 'db_${DateTime.now().microsecondsSinceEpoch}'),
      name: name,
      japaneseName: s(['japaneseName', 'japanese_name', 'japanese', 'alt_name', 'altName', 'titleJapanese']),
      rating: rating,
      seasons: seasons,
      episodes: episodes,
      studio: s(['studio', 'studios']),
      genres: s(['genres', 'genre']),
      characters: s(['characters', 'mainCharacters', 'main_characters', 'cast', 'popularCharacters', 'popular_characters', 'characterList', 'popularCast']),
      synopsis: s(['synopsis', 'description', 'summary', 'plot']),
      year: year,
      verified: m['verified'] == true,
      updatedAt: updated,
    );
  }

  factory AnimeDbEntry.fromMap(Map<String, dynamic> m) =>
      fromLooseMap(m) ??
      AnimeDbEntry(id: 'db_${DateTime.now().microsecondsSinceEpoch}', name: 'Unknown', updatedAt: DateTime.now());

  String toJson() => jsonEncode(toMap());
  factory AnimeDbEntry.fromJson(String source) =>
      AnimeDbEntry.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

