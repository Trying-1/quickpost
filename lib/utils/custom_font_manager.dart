import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Singleton that manages user-uploaded custom fonts.
/// Call [init] once at app startup to re-register persisted fonts.
class CustomFontManager {
  CustomFontManager._();
  static final CustomFontManager _instance = CustomFontManager._();
  factory CustomFontManager() => _instance;

  static const _prefsKey = 'custom_fonts_json';

  final List<CustomFontEntry> _fonts = [];
  List<CustomFontEntry> get fonts => List.unmodifiable(_fonts);

  /// Initialize — load persisted metadata and register all custom fonts.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return;

    try {
      final List<dynamic> list = jsonDecode(raw);
      for (final item in list) {
        final entry = CustomFontEntry.fromJson(item);
        final file = File(entry.filePath);
        if (await file.exists()) {
          await _registerFont(entry);
          _fonts.add(entry);
        }
      }
    } catch (_) {}
  }

  /// Pick and import a font file. Returns the new entry, or null on failure.
  Future<CustomFontEntry?> addFont(File sourceFile) async {
    final dir = await _fontsDir();
    final fileName = sourceFile.path.split('/').last;
    final destPath = '${dir.path}/$fileName';
    await sourceFile.copy(destPath);

    // Derive family name from file name (strip extension)
    final familyName = fileName.replaceAll(RegExp(r'\.(ttf|otf|TTF|OTF)$'), '');

    final entry = CustomFontEntry(
      familyName: familyName,
      displayName: familyName.replaceAll(RegExp(r'[-_]'), ' '),
      filePath: destPath,
      originalFileName: fileName,
    );

    await _registerFont(entry);
    _fonts.add(entry);
    await _persist();
    return entry;
  }

  /// Remove a custom font by its familyName.
  Future<void> removeFont(String familyName) async {
    final idx = _fonts.indexWhere((f) => f.familyName == familyName);
    if (idx == -1) return;
    final entry = _fonts.removeAt(idx);
    try {
      final file = File(entry.filePath);
      if (await file.exists()) await file.delete();
    } catch (_) {}
    await _persist();
  }

  // ── Internal ──────────────────────────────────────────────────────

  Future<void> _registerFont(CustomFontEntry entry) async {
    try {
      final file = File(entry.filePath);
      final bytes = await file.readAsBytes();
      final loader = FontLoader(entry.familyName);
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
    } catch (_) {}
  }

  Future<Directory> _fontsDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/custom_fonts');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _fonts.map((f) => f.toJson()).toList();
    await prefs.setString(_prefsKey, jsonEncode(list));
  }
}

class CustomFontEntry {
  final String familyName;
  final String displayName;
  final String filePath;
  final String originalFileName;

  const CustomFontEntry({
    required this.familyName,
    required this.displayName,
    required this.filePath,
    required this.originalFileName,
  });

  Map<String, dynamic> toJson() => {
    'familyName': familyName,
    'displayName': displayName,
    'filePath': filePath,
    'originalFileName': originalFileName,
  };

  factory CustomFontEntry.fromJson(Map<String, dynamic> json) => CustomFontEntry(
    familyName: json['familyName'],
    displayName: json['displayName'],
    filePath: json['filePath'],
    originalFileName: json['originalFileName'],
  );
}
