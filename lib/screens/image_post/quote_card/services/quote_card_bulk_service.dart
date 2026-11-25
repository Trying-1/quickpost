import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../models/quote_item.dart';
import '../../../quotes/my_quotes_screen.dart';

/// Import helpers for single quotes and bulk quote batches (My Quotes, CSV/TXT, pasted lines).
class QuoteCardBulkService {
  const QuoteCardBulkService._();

  /// Opens My Quotes in single-select mode and returns the picked [QuoteItem], if any.
  static Future<QuoteItem?> importFromMyQuotes(BuildContext context) async {
    final dynamic selected = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute<dynamic>(
        builder: (_) => const MyQuotesScreen(selectMode: true),
      ),
    );
    return selected is QuoteItem ? selected : null;
  }

  /// Opens My Quotes in multi-select mode and returns quote/author maps.
  static Future<List<Map<String, String>>> importBulkFromMyQuotes(
    BuildContext context,
  ) async {
    final dynamic selected = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute<dynamic>(
        builder: (_) => const MyQuotesScreen(multiSelectMode: true),
      ),
    );
    if (selected is List<QuoteItem> && selected.isNotEmpty) {
      return selected
          .map((q) => <String, String>{
                'quote': q.text,
                'author': q.author,
              })
          .toList();
    }
    return const [];
  }

  /// Picks a CSV or TXT file and parses `[quote, author]` rows.
  static Future<List<Map<String, String>>> importCsv(
    BuildContext context,
  ) async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
      );
      if (result == null || result.files.single.path == null) return const [];

      final file = File(result.files.single.path!);
      final input = await file.readAsString();
      final List<List<dynamic>> rows =
          const CsvToListConverter().convert(input, fieldDelimiter: ',');

      final List<Map<String, String>> loadedQuotes = [];
      for (final row in rows) {
        if (row.isNotEmpty) {
          loadedQuotes.add({
            'quote': row[0].toString(),
            'author': row.length > 1 ? row[1].toString() : '',
          });
        }
      }
      return loadedQuotes;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing file: $e')),
        );
      }
      return const [];
    }
  }

  /// Prompts the user to paste lines (`Quote | Author` or `Quote`) and parses them.
  static Future<List<Map<String, String>>> showPasteBulkDialog(
    BuildContext context,
  ) async {
    final controller = TextEditingController();
    final result = await showDialog<List<Map<String, String>>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Paste Quotes'),
        content: TextField(
          controller: controller,
          maxLines: 10,
          decoration: const InputDecoration(
            hintText:
                'Format: Quote | Author (one per line)\nOr just Quote per line.',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final lines = controller.text
                  .split('\n')
                  .where((l) => l.trim().isNotEmpty)
                  .toList();
              final List<Map<String, String>> loaded = [];
              for (final line in lines) {
                if (line.contains('|')) {
                  final parts = line.split('|');
                  loaded.add({
                    'quote': parts[0].trim(),
                    'author': parts.length > 1 ? parts[1].trim() : '',
                  });
                } else {
                  loaded.add({
                    'quote': line.trim(),
                    'author': '',
                  });
                }
              }
              Navigator.pop(dialogContext, loaded);
            },
            child: const Text('Load'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result ?? const [];
  }
}

