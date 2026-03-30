class QuoteItem {
  final String id;
  final String text;
  final String author;
  final String category;
  final DateTime createdAt;

  QuoteItem({
    required this.id,
    required this.text,
    required this.author,
    required this.category,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'author': author,
      'category': category,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory QuoteItem.fromMap(Map<String, dynamic> map) {
    return QuoteItem(
      id: map['id'] ?? '',
      text: map['text'] ?? '',
      author: map['author'] ?? '',
      category: map['category'] ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
    );
  }
}
