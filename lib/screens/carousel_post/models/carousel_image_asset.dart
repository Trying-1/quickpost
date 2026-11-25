/// Represents a stored image asset categorized under topic or niche.
class CarouselImageAsset {
  final String id;
  final String name;
  final String category;
  final String localPath;
  final DateTime createdAt;
  final int? fileSizeBytes;

  const CarouselImageAsset({
    required this.id,
    required this.name,
    required this.category,
    required this.localPath,
    required this.createdAt,
    this.fileSizeBytes,
  });

  CarouselImageAsset copyWith({
    String? id,
    String? name,
    String? category,
    String? localPath,
    DateTime? createdAt,
    int? fileSizeBytes,
  }) {
    return CarouselImageAsset(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      localPath: localPath ?? this.localPath,
      createdAt: createdAt ?? this.createdAt,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'localPath': localPath,
      'createdAt': createdAt.toIso8601String(),
      'fileSizeBytes': fileSizeBytes,
    };
  }

  factory CarouselImageAsset.fromMap(Map<String, dynamic> map) {
    return CarouselImageAsset(
      id: map['id'] as String? ?? 'asset_${DateTime.now().millisecondsSinceEpoch}',
      name: map['name'] as String? ?? 'Untitled Image',
      category: map['category'] as String? ?? (map['animeName'] as String? ?? 'General'),
      localPath: map['localPath'] as String? ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      fileSizeBytes: map['fileSizeBytes'] as int?,
    );
  }
}

