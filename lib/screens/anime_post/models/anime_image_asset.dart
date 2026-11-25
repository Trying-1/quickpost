import 'dart:convert';

/// Represents a stored image asset categorized and tagged under anime titles
/// for rapid access and automatic slide population in Anime Post Maker.
class AnimeImageAsset {
  final String id;
  final String filePath;
  final String animeName;
  final List<String> tags;
  final DateTime addedAt;
  final int? fileSizeBytes;
  final int? width;
  final int? height;

  const AnimeImageAsset({
    required this.id,
    required this.filePath,
    required this.animeName,
    this.tags = const [],
    required this.addedAt,
    this.fileSizeBytes,
    this.width,
    this.height,
  });

  String get displayName => filePath.split('/').last;

  /// Returns unique normalized tags including the primary anime name
  List<String> get allTags {
    final set = <String>{};
    if (animeName.trim().isNotEmpty) set.add(animeName.trim());
    for (final t in tags) {
      if (t.trim().isNotEmpty) set.add(t.trim());
    }
    return set.toList();
  }

  AnimeImageAsset copyWith({
    String? id,
    String? filePath,
    String? animeName,
    List<String>? tags,
    DateTime? addedAt,
    int? fileSizeBytes,
    int? width,
    int? height,
  }) {
    return AnimeImageAsset(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      animeName: animeName ?? this.animeName,
      tags: tags ?? this.tags,
      addedAt: addedAt ?? this.addedAt,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'filePath': filePath,
      'animeName': animeName,
      'tags': tags,
      'addedAt': addedAt.toIso8601String(),
      'fileSizeBytes': fileSizeBytes,
      'width': width,
      'height': height,
    };
  }

  factory AnimeImageAsset.fromMap(Map<String, dynamic> map) {
    final rawTags = map['tags'];
    List<String> parsedTags = [];
    if (rawTags is List) {
      parsedTags = rawTags.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    }

    final anime = map['animeName'] as String? ?? 'General';

    return AnimeImageAsset(
      id: map['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      filePath: map['filePath'] as String? ?? '',
      animeName: anime,
      tags: parsedTags,
      addedAt: map['addedAt'] != null
          ? DateTime.tryParse(map['addedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      fileSizeBytes: map['fileSizeBytes'] as int?,
      width: map['width'] as int?,
      height: map['height'] as int?,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory AnimeImageAsset.fromJson(String source) =>
      AnimeImageAsset.fromMap(jsonDecode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AnimeImageAsset && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
