import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import '../models/image_post_preset.dart';
import '../utils/custom_font_manager.dart';

class ImagePostPresetService {
  static const String _boxName = 'image_post_presets_v2';

  static Future<void> init() async {
    await Hive.openBox(_boxName);
  }

  static Box get _box => Hive.box(_boxName);

  static List<ImagePostPreset> getAllPresets() {
    return _box.values
        .map((val) => Map<String, dynamic>.from(val as Map))
        .where((map) => map['id'] != 'latest_preset_auto')
        .map((map) => ImagePostPreset.fromMap(map))
        .toList();
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
      print('[ImagePostPresetService] Importing presets from JSON of length: ${jsonStr.length}');
      final decoded = jsonDecode(jsonStr);
      if (decoded is! List) {
        print('[ImagePostPresetService] Error: Decoded JSON is not a List, but ${decoded.runtimeType}');
        return 0;
      }
      
      final List<dynamic> list = decoded;
      final directory = await getApplicationDocumentsDirectory();
      final iconDir = Directory('${directory.path}/image_post_icons');
      if (!await iconDir.exists()) {
        await iconDir.create(recursive: true);
      }

      int imported = 0;
      for (final item in list) {
        if (item is Map) {
          final Map<String, dynamic> map = Map<String, dynamic>.from(item);
          final preset = ImagePostPreset.fromMap(map);
          
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
           print('[ImagePostPresetService] Row skipped - not a Map: $item');
        }
      }
      print('[ImagePostPresetService] Successfully imported $imported presets.');
      return imported;
    } catch (e) {
      print('[ImagePostPresetService] Critical import error: $e');
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
      print('[ImagePostPresetService] Export to ZIP failed: $e');
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
        final presetId = map['id'] as String? ?? 'imported_${DateTime.now().millisecondsSinceEpoch}';

        // Recreate directory for this preset's assets
        final destDir = Directory('${appDir.path}/image_post_presets_assets/$presetId');
        if (await destDir.exists()) {
          try {
            await destDir.delete(recursive: true);
          } catch (_) {}
        }
        await destDir.create(recursive: true);

        // Helper to extract file
        Future<String?> extractFile(String? zipPath, String destFileName) async {
          if (zipPath == null) return null;
          final archFile = archive.findFile(zipPath);
          if (archFile == null) return null;
          final file = File('${destDir.path}/$destFileName');
          // Ensure subdirectories exist
          final parentDir = file.parent;
          if (!await parentDir.exists()) {
            await parentDir.create(recursive: true);
          }
          await file.writeAsBytes(archFile.content as List<int>);
          return file.path;
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
                print('[ImagePostPresetService] Error registering custom font: $e');
              }
            }
          }
          resolvedFonts.add(cf);
        }
        map['customFonts'] = resolvedFonts;

        // Save preset
        final preset = ImagePostPreset.fromMap(map);
        await savePreset(preset);
        imported++;
      }
      return imported;
    } catch (e) {
      print('[ImagePostPresetService] Import from ZIP failed: $e');
      return 0;
    }
  }

  static ImagePostPreset? getLatestPreset() {
    if (_box.isEmpty) return null;
    final val = _box.get('latest_preset_auto') ?? _box.values.firstWhere(
      (element) => (Map<String, dynamic>.from(element as Map))['id'] != 'latest_preset_auto',
      orElse: () => _box.values.last,
    );
    if (val == null) return null;
    final Map<String, dynamic> map = Map<String, dynamic>.from(val as Map);
    return ImagePostPreset.fromMap(map);
  }

  static Future<void> savePreset(ImagePostPreset preset) async {
    await _box.put(preset.id, preset.toMap());
  }

  static Future<void> deletePreset(String id) async {
    await _box.delete(id);
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final destDir = Directory('${appDir.path}/image_post_presets_assets/$id');
      if (await destDir.exists()) {
        await destDir.delete(recursive: true);
      }
    } catch (_) {}
  }
}
