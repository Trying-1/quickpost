import 'package:hive_flutter/hive_flutter.dart';
import '../models/quote_item.dart';

class MyQuotesService {
  static const String _boxName = 'my_quotes_box';
  static bool _isInitialized = false;

  static Future<void> init() async {
    if (_isInitialized) return;
    await Hive.initFlutter();
    await Hive.openBox(_boxName);
    _isInitialized = true;
  }

  static Box get _box => Hive.box(_boxName);

  static List<QuoteItem> getAllQuotes() {
    return _box.values.map((item) {
      final Map<String, dynamic> map = Map<String, dynamic>.from(item);
      return QuoteItem.fromMap(map);
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  static Future<void> saveQuote(QuoteItem quote) async {
    await _box.put(quote.id, quote.toMap());
  }

  static Future<void> deleteQuote(String id) async {
    await _box.delete(id);
  }

  static Future<void> clearAll() async {
    await _box.clear();
  }

  static List<String> getAllCategories() {
    final quotes = getAllQuotes();
    final categories = quotes
        .map((e) => e.category)
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    categories.sort();
    return categories;
  }
}
