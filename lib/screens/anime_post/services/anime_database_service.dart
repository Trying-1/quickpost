import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/anime_db_entry.dart';
import 'anime_asset_storage_service.dart';

enum AnimeDbMergeMode { skipExisting, updateExisting }

class AnimeDbImportResult {
  final int added;
  final int updated;
  final int skipped;
  final int invalid;
  const AnimeDbImportResult({this.added = 0, this.updated = 0, this.skipped = 0, this.invalid = 0});

  int get total => added + updated + skipped + invalid;
  String get summary =>
      '$added added, $updated updated, $skipped skipped${invalid > 0 ? ', $invalid invalid' : ''}';
}

/// Local anime database: persistence, CRUD, search, import/export.
/// Listen to this notifier to refresh UI after any change.
class AnimeDatabaseService extends ChangeNotifier {
  AnimeDatabaseService._();
  static final AnimeDatabaseService instance = AnimeDatabaseService._();

  static const String _storageKey = 'anime_database_entries_v1';

  List<AnimeDbEntry>? _cache;

  Future<List<AnimeDbEntry>> getAll() async {
    if (_cache != null) return List.unmodifiable(_cache!);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    final list = <AnimeDbEntry>[];
    if (raw != null && raw.isNotEmpty) {
      try {
        for (final item in jsonDecode(raw) as List) {
          if (item is Map) {
            final e = AnimeDbEntry.fromLooseMap(Map<String, dynamic>.from(item));
            if (e != null) list.add(e);
          }
        }
      } catch (e) {
        debugPrint('AnimeDatabaseService load error: $e');
      }
    }
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _cache = list;
    return List.unmodifiable(list);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_cache!.map((e) => e.toMap()).toList()));
    notifyListeners();
  }

  Future<List<String>> getNames() async => (await getAll()).map((e) => e.name).toList();

  Future<List<AnimeDbEntry>> search(String query) async {
    final all = await getAll();
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((e) {
      return e.name.toLowerCase().contains(q) ||
          e.japaneseName.toLowerCase().contains(q) ||
          e.studio.toLowerCase().contains(q) ||
          e.genres.toLowerCase().contains(q);
    }).toList();
  }

  /// Exact (normalized) match first, then the same fuzzy matching used by image tags.
  Future<AnimeDbEntry?> findByName(String name) async {
    final all = await getAll();
    final key = AnimeDbEntry.normalizeKey(name);
    if (key.isEmpty) return null;
    for (final e in all) {
      if (e.key == key) return e;
    }
    for (final e in all) {
      if (AnimeAssetStorageService.isAnimeMatch(e.name, name) ||
          (e.japaneseName.isNotEmpty && AnimeAssetStorageService.isAnimeMatch(e.japaneseName, name))) {
        return e;
      }
    }
    return null;
  }

  /// Insert or update. Entries are de-duplicated by normalized name.
  Future<void> upsert(AnimeDbEntry entry) async {
    await getAll();
    final list = _cache!;
    var idx = list.indexWhere((e) => e.id == entry.id);
    if (idx < 0) idx = list.indexWhere((e) => e.key == entry.key);
    if (idx >= 0) {
      list[idx] = entry.copyWith();
    } else {
      list.add(entry.copyWith());
    }
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    await _persist();
  }

  Future<void> delete(String id) async {
    await getAll();
    _cache!.removeWhere((e) => e.id == id);
    await _persist();
  }

  Future<void> deleteBatch(List<String> ids) async {
    if (ids.isEmpty) return;
    await getAll();
    final set = ids.toSet();
    _cache!.removeWhere((e) => set.contains(e.id));
    await _persist();
  }

  Future<void> clearAll() async {
    _cache = [];
    await _persist();
  }

  Future<void> setVerified(String id, bool verified) async {
    await getAll();
    final idx = _cache!.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    _cache![idx] = _cache![idx].copyWith(verified: verified);
    await _persist();
  }

  Future<void> setVerifiedBatch(List<String> ids, bool verified) async {
    if (ids.isEmpty) return;
    await getAll();
    final set = ids.toSet();
    bool changed = false;
    for (int i = 0; i < _cache!.length; i++) {
      if (set.contains(_cache![i].id)) {
        _cache![i] = _cache![i].copyWith(verified: verified);
        changed = true;
      }
    }
    if (changed) await _persist();
  }

  /// Appends or replaces the database with given anime entries.
  Future<int> importEntries(List<AnimeDbEntry> entries, {bool replace = false}) async {
    await getAll();
    if (replace) {
      _cache = List.from(entries);
      _cache!.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      await _persist();
      return entries.length;
    }
    int added = 0;
    for (final entry in entries) {
      final exists = _cache!.any((e) => e.key == entry.key);
      if (!exists) {
        _cache!.add(entry.copyWith());
        added++;
      }
    }
    _cache!.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (added > 0) await _persist();
    return added;
  }

  /// Aggregates all genres present in the database with their anime counts.
  Future<Map<String, int>> getGenreDistribution() async {
    final all = await getAll();
    final map = <String, int>{};
    for (final e in all) {
      if (e.genres.trim().isEmpty) continue;
      final parts = e.genres.split(RegExp(r'[,/•|]'));
      for (var p in parts) {
        p = p.trim();
        if (p.isNotEmpty) {
          map[p] = (map[p] ?? 0) + 1;
        }
      }
    }
    return map;
  }

  /// Aggregates all studios present in the database with their anime counts.
  Future<Map<String, int>> getStudioDistribution() async {
    final all = await getAll();
    final map = <String, int>{};
    for (final e in all) {
      final s = e.studio.trim();
      if (s.isNotEmpty) {
        map[s] = (map[s] ?? 0) + 1;
      }
    }
    return map;
  }

  // ===================== IMPORT / EXPORT =====================

  /// Extracts a list of raw maps from messy LLM output (code fences, wrapper objects, prose).
  static List<Map<String, dynamic>> parseJsonText(String text) {
    var t = text.trim();
    t = t.replaceAll(RegExp(r'```[a-zA-Z]*'), '').replaceAll('```', '').trim();
    final start = t.indexOf(RegExp(r'[\[{]'));
    if (start < 0) throw const FormatException('No JSON found in the pasted text.');
    final isArray = t[start] == '[';
    final end = t.lastIndexOf(isArray ? ']' : '}');
    if (end <= start) throw const FormatException('JSON looks incomplete (missing closing bracket).');
    final decoded = jsonDecode(t.substring(start, end + 1));

    dynamic list = decoded;
    if (decoded is Map) {
      list = decoded['anime'] ?? decoded['animes'] ?? decoded['data'] ?? decoded['items'] ?? decoded['entries'] ?? decoded['list'];
      list ??= [decoded];
    }
    if (list is! List) throw const FormatException('Expected a JSON array of anime.');
    return list.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
  }

  Future<AnimeDbImportResult> importJsonText(
    String text, {
    AnimeDbMergeMode mode = AnimeDbMergeMode.updateExisting,
  }) async {
    final rows = parseJsonText(text);
    await getAll();
    final list = _cache!;
    int added = 0, updated = 0, skipped = 0, invalid = 0;
    final now = DateTime.now().microsecondsSinceEpoch;

    for (int i = 0; i < rows.length; i++) {
      final row = Map<String, dynamic>.from(rows[i])..remove('id');
      final e = AnimeDbEntry.fromLooseMap(row, fallbackId: 'db_${now}_$i');
      if (e == null) {
        invalid++;
        continue;
      }
      final idx = list.indexWhere((x) => x.key == e.key);
      if (idx < 0) {
        list.add(e);
        added++;
      } else if (mode == AnimeDbMergeMode.updateExisting) {
        final old = list[idx];
        // Only overwrite with non-empty incoming values; keep verified flag.
        list[idx] = AnimeDbEntry(
          id: old.id,
          name: e.name,
          japaneseName: e.japaneseName.isNotEmpty ? e.japaneseName : old.japaneseName,
          rating: e.rating.isNotEmpty ? e.rating : old.rating,
          seasons: e.seasons.isNotEmpty ? e.seasons : old.seasons,
          episodes: e.episodes.isNotEmpty ? e.episodes : old.episodes,
          studio: e.studio.isNotEmpty ? e.studio : old.studio,
          genres: e.genres.isNotEmpty ? e.genres : old.genres,
          characters: e.characters.isNotEmpty ? e.characters : old.characters,
          synopsis: e.synopsis.isNotEmpty ? e.synopsis : old.synopsis,
          year: e.year ?? old.year,
          verified: old.verified,
          updatedAt: DateTime.now(),
        );
        updated++;
      } else {
        skipped++;
      }
    }
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (added + updated > 0) await _persist();
    return AnimeDbImportResult(added: added, updated: updated, skipped: skipped, invalid: invalid);
  }

  Future<AnimeDbImportResult?> importFromFile({AnimeDbMergeMode mode = AnimeDbMergeMode.updateExisting}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'txt'],
      dialogTitle: 'Select anime database JSON',
    );
    final path = result?.files.single.path;
    if (path == null) return null;
    final text = await File(path).readAsString();
    return importJsonText(text, mode: mode);
  }

  Future<String> exportJsonText() async {
    final all = await getAll();
    return exportEntriesJson(all);
  }

  static String exportEntriesJson(List<AnimeDbEntry> entries) {
    final rows = entries.map((e) {
      final m = e.toMap()..remove('id');
      return m;
    }).toList();
    return const JsonEncoder.withIndent('  ').convert(rows);
  }

  /// Writes the database to a temp .json file and opens the share sheet.
  Future<String?> exportAndShare() async {
    final all = await getAll();
    if (all.isEmpty) return null;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/anime_database_${DateTime.now().millisecondsSinceEpoch}.json');
    await file.writeAsString(await exportJsonText());
    await Share.shareXFiles([XFile(file.path)], subject: 'Anime Database (${all.length})');
    return file.path;
  }
}
