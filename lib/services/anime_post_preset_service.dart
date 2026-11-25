import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import '../models/anime_post_preset.dart';
import '../utils/custom_font_manager.dart';

class AnimePostPresetService {
  static const String _boxName = 'anime_post_presets_v1';

  static Future<void> init() async {
    await Hive.openBox(_boxName);
  }

  static Box get _box => Hive.box(_boxName);

  static List<AnimePostPreset> getAllPresets() {
    return _box.values
        .map((val) => Map<String, dynamic>.from(val as Map))
        .where((map) => map['id'] != 'latest_preset_auto')
        .map((map) => AnimePostPreset.fromMap(map))
        .toList();
  }

  static Future<Directory> getBackupDirectory() async {
    if (Platform.isAndroid) {
      final dir = Directory('/storage/emulated/0/Download/Quick Post Backup');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }

    final dir = Directory('${Directory.current.path}/Quick Post Backup');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<String> exportPresetsToFile({String? customFileName}) async {
    final zipData = await exportPresetsZip();
    if (zipData == null) {
      throw Exception('ZIP generation failed');
    }
    final backupDir = await getBackupDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = customFileName ?? 'animepost_presets_$timestamp.zip';
    final file = File('${backupDir.path}/$fileName');
    await file.writeAsBytes(zipData);

    try {
      const MethodChannel('com.quickpost.app/processor').invokeMethod('scanMediaFile', {
        'filePath': file.path,
        'mimeType': 'application/zip',
      });
    } catch (_) {}

    return file.path;
  }

  static Future<int> importPresetsFromFile({String? filePath}) async {
    String? path = filePath;
    if (path == null) {
      path = await const MethodChannel('com.quickpost.app/processor').invokeMethod<String>('importFile', {
        'mimeType': '*/*',
      });
    }
    if (path == null) return 0;
    final file = File(path);
    if (!await file.exists()) return 0;

    final ext = path.split('.').last.toLowerCase();
    if (ext == 'zip') {
      final bytes = await file.readAsBytes();
      return await importPresetsZip(bytes);
    } else {
      final jsonStr = await file.readAsString();
      return await importPresetsJson(jsonStr);
    }
  }

  static Future<String> exportPresetsJson() async {
    final presets = getAllPresets();
    final List<Map<String, dynamic>> maps = [];
    
    for (final p in presets) {
      final map = p.toMap();
      if (p.profileImagePath != null) {
        final file = File(p.profileImagePath!);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          map['profileImageBase64'] = base64Encode(bytes);
          map['profileImageExt'] = p.profileImagePath!.split('.').last;
        }
      }
      maps.add(map);
    }
    return jsonEncode(maps);
  }

  static Future<int> importPresetsJson(String jsonStr) async {
    try {
      print('[AnimePostPresetService] Importing presets from JSON of length: ${jsonStr.length}');
      final decoded = jsonDecode(jsonStr);
      if (decoded is! List) {
        print('[AnimePostPresetService] Error: Decoded JSON is not a List, but ${decoded.runtimeType}');
        return 0;
      }
      
      final List<dynamic> list = decoded;
      final directory = await getApplicationDocumentsDirectory();
      final iconDir = Directory('${directory.path}/anime_watermark_icons');
      if (!await iconDir.exists()) {
        await iconDir.create(recursive: true);
      }

      int imported = 0;
      for (final item in list) {
        if (item is Map) {
          final Map<String, dynamic> map = Map<String, dynamic>.from(item);
          final preset = AnimePostPreset.fromMap(map);
          
          if (map['profileImageBase64'] != null) {
            final String base64Str = map['profileImageBase64'];
            final String ext = map['profileImageExt'] ?? 'png';
            final bytes = base64Decode(base64Str);
            final fileName = 'icon_${preset.id}_${DateTime.now().millisecondsSinceEpoch}.$ext';
            final file = File('${iconDir.path}/$fileName');
            await file.writeAsBytes(bytes);
            preset.profileImagePath = file.path;
          }
          
          await savePreset(preset);
          imported++;
        } else {
           print('[AnimePostPresetService] Row skipped - not a Map: $item');
        }
      }
      print('[AnimePostPresetService] Successfully imported $imported presets.');
      return imported;
    } catch (e) {
      print('[AnimePostPresetService] Critical import error: $e');
      return 0;
    }
  }

  static Future<List<int>?> exportPresetsZip() async {
    try {
      final presets = getAllPresets();
      final archive = Archive();
      final List<Map<String, dynamic>> maps = [];

      for (final p in presets) {
        final map = p.toMap();

        // 1. Profile Image
        if (p.profileImagePath != null) {
          final file = File(p.profileImagePath!);
          if (await file.exists()) {
            final ext = p.profileImagePath!.split('.').last;
            final zipPath = 'assets/${p.id}/profile_image.$ext';
            final bytes = await file.readAsBytes();
            archive.addFile(ArchiveFile(zipPath, bytes.length, bytes));
            map['profileImagePath'] = zipPath;
          } else {
            map['profileImagePath'] = null;
          }
        }

        // 2. Background Image
        if (p.bgImagePath != null) {
          final file = File(p.bgImagePath!);
          if (await file.exists()) {
            final ext = p.bgImagePath!.split('.').last;
            final zipPath = 'assets/${p.id}/bg_image.$ext';
            final bytes = await file.readAsBytes();
            archive.addFile(ArchiveFile(zipPath, bytes.length, bytes));
            map['bgImagePath'] = zipPath;
          } else {
            map['bgImagePath'] = null;
          }
        }

        // 3. Selected Image
        if (p.selectedImagePath != null) {
          final file = File(p.selectedImagePath!);
          if (await file.exists()) {
            final ext = p.selectedImagePath!.split('.').last;
            final zipPath = 'assets/${p.id}/selected_image.$ext';
            final bytes = await file.readAsBytes();
            archive.addFile(ArchiveFile(zipPath, bytes.length, bytes));
            map['selectedImagePath'] = zipPath;
          } else {
            map['selectedImagePath'] = null;
          }
        }

        // 4. Image Overlays
        final List<Map<String, dynamic>> resolvedOverlays = [];
        for (int i = 0; i < p.imageOverlays.length; i++) {
          final io = p.imageOverlays[i];
          final path = io['path'] as String?;
          if (path != null) {
            final file = File(path);
            if (await file.exists()) {
              final ext = path.split('.').last;
              final zipPath = 'assets/${p.id}/overlay_$i.$ext';
              final bytes = await file.readAsBytes();
              archive.addFile(ArchiveFile(zipPath, bytes.length, bytes));
              
              final ioCopy = Map<String, dynamic>.from(io);
              ioCopy['path'] = zipPath;
              resolvedOverlays.add(ioCopy);
              continue;
            }
          }
        }
        map['imageOverlays'] = resolvedOverlays;

        // 5. Custom Fonts
        final List<Map<String, dynamic>> resolvedFonts = [];
        for (int i = 0; i < p.customFonts.length; i++) {
          final cf = p.customFonts[i];
          final filePath = cf['filePath'] as String?;
          if (filePath != null) {
            final file = File(filePath);
            if (await file.exists()) {
              final ext = filePath.split('.').last;
              final zipPath = 'assets/${p.id}/fonts/${cf['family']}.$ext';
              final bytes = await file.readAsBytes();
              archive.addFile(ArchiveFile(zipPath, bytes.length, bytes));

              final cfCopy = Map<String, dynamic>.from(cf);
              cfCopy['filePath'] = zipPath;
              resolvedFonts.add(cfCopy);
              continue;
            }
          }
        }
        map['customFonts'] = resolvedFonts;

        maps.add(map);
      }

      final jsonStr = jsonEncode(maps);
      final jsonBytes = utf8.encode(jsonStr);
      archive.addFile(ArchiveFile('presets.json', jsonBytes.length, jsonBytes));

      final zipEncoder = ZipEncoder();
      return zipEncoder.encode(archive);
    } catch (e) {
      print('[AnimePostPresetService] Export to ZIP failed: $e');
      return null;
    }
  }

  static Future<int> importPresetsZip(List<int> zipData) async {
    try {
      final archive = ZipDecoder().decodeBytes(zipData);
      final presetsJsonFile = archive.findFile('presets.json');
      if (presetsJsonFile == null) {
        throw Exception('Invalid archive: presets.json missing');
      }

      final jsonStr = utf8.decode(presetsJsonFile.content as List<int>);
      final decoded = jsonDecode(jsonStr);
      if (decoded is! List) {
        throw Exception('presets.json is not a JSON list');
      }

      final List<dynamic> list = decoded;
      final appDir = await getApplicationDocumentsDirectory();
      int imported = 0;

      for (final item in list) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final presetId = map['id'] ?? 'imported_${DateTime.now().millisecondsSinceEpoch}';

        // Extract assets for this preset
        final destDir = Directory('${appDir.path}/anime_post_presets_assets/$presetId');
        if (!await destDir.exists()) {
          await destDir.create(recursive: true);
        }

        // Helper to extract an asset
        Future<String?> extractFile(String zipPath, String destName) async {
          final archivedFile = archive.findFile(zipPath);
          if (archivedFile != null) {
            final fileData = archivedFile.content as List<int>;
            final outFile = File('${destDir.path}/$destName');
            if (destName.contains('/')) {
              await outFile.parent.create(recursive: true);
            }
            await outFile.writeAsBytes(fileData);
            return outFile.path;
          }
          return null;
        }

        // 1. Profile Image
        final profileZipPath = map['profileImagePath'] as String?;
        if (profileZipPath != null) {
          final ext = profileZipPath.split('.').last;
          map['profileImagePath'] = await extractFile(profileZipPath, 'profile_image.$ext');
        }

        // 2. Background Image
        final bgZipPath = map['bgImagePath'] as String?;
        if (bgZipPath != null) {
          final ext = bgZipPath.split('.').last;
          map['bgImagePath'] = await extractFile(bgZipPath, 'bg_image.$ext');
        }

        // 3. Selected Image
        final selectedZipPath = map['selectedImagePath'] as String?;
        if (selectedZipPath != null) {
          final ext = selectedZipPath.split('.').last;
          map['selectedImagePath'] = await extractFile(selectedZipPath, 'selected_image.$ext');
        }

        // 4. Image Overlays
        final overlays = map['imageOverlays'] as List<dynamic>? ?? [];
        final List<Map<String, dynamic>> resolvedOverlays = [];
        for (int i = 0; i < overlays.length; i++) {
          final io = Map<String, dynamic>.from(overlays[i] as Map);
          final zipPath = io['path'] as String?;
          if (zipPath != null) {
            final ext = zipPath.split('.').last;
            io['path'] = await extractFile(zipPath, 'overlay_$i.$ext');
          }
          resolvedOverlays.add(io);
        }
        map['imageOverlays'] = resolvedOverlays;

        // 5. Custom Fonts
        final fonts = map['customFonts'] as List<dynamic>? ?? [];
        final List<Map<String, dynamic>> resolvedFonts = [];
        for (int i = 0; i < fonts.length; i++) {
          final cf = Map<String, dynamic>.from(fonts[i] as Map);
          final zipPath = cf['filePath'] as String?;
          final family = cf['family'] as String? ?? 'custom';
          if (zipPath != null) {
            final ext = zipPath.split('.').last;
            final extractedPath = await extractFile(zipPath, 'fonts/$family.$ext');
            if (extractedPath != null) {
              cf['filePath'] = extractedPath;
              // Register the font in CustomFontManager
              try {
                final fontFile = File(extractedPath);
                await CustomFontManager().addFont(fontFile);
              } catch (e) {
                print('[AnimePostPresetService] Error registering custom font: $e');
              }
            }
          }
          resolvedFonts.add(cf);
        }
        map['customFonts'] = resolvedFonts;

        // Save preset
        final preset = AnimePostPreset.fromMap(map);
        await savePreset(preset);
        imported++;
      }
      return imported;
    } catch (e) {
      print('[AnimePostPresetService] Import from ZIP failed: $e');
      return 0;
    }
  }

  static AnimePostPreset? getLatestPreset() {
    if (_box.isEmpty) return null;
    final val = _box.get('latest_preset_auto') ?? _box.values.firstWhere(
      (element) => (Map<String, dynamic>.from(element as Map))['id'] != 'latest_preset_auto',
      orElse: () => _box.values.last,
    );
    if (val == null) return null;
    final Map<String, dynamic> map = Map<String, dynamic>.from(val as Map);
    return AnimePostPreset.fromMap(map);
  }

  static Future<void> savePreset(AnimePostPreset preset) async {
    await _box.put(preset.id, preset.toMap());
  }

  static Future<void> deletePreset(String id) async {
    await _box.delete(id);
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final destDir = Directory('${appDir.path}/anime_post_presets_assets/$id');
      if (await destDir.exists()) {
        await destDir.delete(recursive: true);
      }
    } catch (_) {}
  }
}
