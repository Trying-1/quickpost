import 'dart:convert';

class CaptionVariant {
  final String id;
  final String name;
  final String content;

  CaptionVariant({
    required this.id,
    required this.name,
    required this.content,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'content': content,
    };
  }

  factory CaptionVariant.fromMap(Map<String, dynamic> map) {
    return CaptionVariant(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      content: map['content'] ?? '',
    );
  }

  String toJson() => json.encode(toMap());

  factory CaptionVariant.fromJson(String source) => CaptionVariant.fromMap(json.decode(source));
}

class CaptionGroup {
  final String id;
  final String title;
  final List<CaptionVariant> variants;
  final String? category;
  final DateTime createdAt;

  CaptionGroup({
    required this.id,
    required this.title,
    required this.variants,
    this.category,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'variants': json.encode(variants.map((x) => x.toMap()).toList()),
      'category': category,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CaptionGroup.fromMap(Map<String, dynamic> map) {
    return CaptionGroup(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      variants: List<CaptionVariant>.from(
        (json.decode(map['variants']) as List).map((x) => CaptionVariant.fromMap(x)),
      ),
      category: map['category'],
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
}
