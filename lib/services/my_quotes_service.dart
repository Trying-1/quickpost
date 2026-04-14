import 'dart:convert';
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

  static Future<String> exportQuotesJson() async {
    final quotes = getAllQuotes();
    final List<Map<String, dynamic>> list = quotes.map((q) => q.toMap()).toList();
    return jsonEncode(list);
  }

  static Future<int> importQuotesJson(String jsonStr) async {
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is! List) return 0;
      int imported = 0;
      for (final item in decoded) {
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          final quote = QuoteItem.fromMap(map);
          await saveQuote(quote);
          imported++;
        }
      }
      return imported;
    } catch (e) {
      return 0;
    }
  }
}
