import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/google_font_model.dart';

/// Singleton service managing on-demand Google Fonts downloading,
/// local persistence, and runtime FontLoader registration.
class GoogleFontService extends ChangeNotifier {
  GoogleFontService._();
  static final GoogleFontService _instance = GoogleFontService._();
  factory GoogleFontService() => _instance;

  static const String _prefsKey = 'google_fonts_downloaded_items_v1';

  /// Pre-packaged font files present in assets/fonts/
  static const Map<String, String> _assetFontPaths = {
    'Abril Fatface': 'assets/fonts/AbrilFatface.ttf',
    'Alex Brush': 'assets/fonts/AlexBrush.ttf',
    'Alfa Slab One': 'assets/fonts/AlfaSlabOne.ttf',
    'Allura': 'assets/fonts/Allura.ttf',
    'Amatic SC': 'assets/fonts/AmaticSC.ttf',
    'Anton': 'assets/fonts/Anton.ttf',
    'Archivo Black': 'assets/fonts/ArchivoBlack.ttf',
    'Audiowide': 'assets/fonts/Audiowide.ttf',
    'Bangers': 'assets/fonts/Bangers.ttf',
    'Barlow': 'assets/fonts/Barlow.ttf',
    'Bebas Neue': 'assets/fonts/BebasNeue.ttf',
    'Black Han Sans': 'assets/fonts/BlackHanSans.ttf',
    'Black Ops One': 'assets/fonts/BlackOpsOne.ttf',
    'Bodoni Moda': 'assets/fonts/BodoniModa.ttf',
    'Bungee': 'assets/fonts/Bungee.ttf',
    'Bungee Shade': 'assets/fonts/BungeeShade.ttf',
    'Caveat': 'assets/fonts/Caveat.ttf',
    'Chakra Petch': 'assets/fonts/ChakraPetch.ttf',
    'Chango': 'assets/fonts/Chango.ttf',
    'Chivo': 'assets/fonts/Chivo.ttf',
    'Cinzel': 'assets/fonts/Cinzel.ttf',
    'Comfortaa': 'assets/fonts/Comfortaa.ttf',
    'Cookie': 'assets/fonts/Cookie.ttf',
    'Cormorant Garamond': 'assets/fonts/CormorantGaramond.ttf',
    'Courgette': 'assets/fonts/Courgette.ttf',
    'Covered By Your Grace': 'assets/fonts/CoveredByYourGrace.ttf',
    'Creepster': 'assets/fonts/Creepster.ttf',
    'DM Sans': 'assets/fonts/DMSans.ttf',
    'DM Serif Display': 'assets/fonts/DMSerifDisplay.ttf',
    'Dancing Script': 'assets/fonts/DancingScript.ttf',
    'Electrolize': 'assets/fonts/Electrolize.ttf',
    'Exo 2': 'assets/fonts/Exo2.ttf',
    'Fredoka': 'assets/fonts/Fredoka.ttf',
    'Fugaz One': 'assets/fonts/FugazOne.ttf',
    'Gochi Hand': 'assets/fonts/GochiHand.ttf',
    'Goldman': 'assets/fonts/Goldman.ttf',
    'Great Vibes': 'assets/fonts/GreatVibes.ttf',
    'Indie Flower': 'assets/fonts/IndieFlower.ttf',
    'Inter': 'assets/fonts/Inter.ttf',
    'Italiana': 'assets/fonts/Italiana.ttf',
    'Josefin Sans': 'assets/fonts/JosefinSans.ttf',
    'Kalam': 'assets/fonts/Kalam.ttf',
    'Kode Mono': 'assets/fonts/KodeMono-Regular.ttf',
    'KodeMono': 'assets/fonts/KodeMono-Regular.ttf',
    'Kanit': 'assets/fonts/Kanit.ttf',
    'Kaushan Script': 'assets/fonts/KaushanScript.ttf',
    'League Spartan': 'assets/fonts/LeagueSpartan.ttf',
    'Lilita One': 'assets/fonts/LilitaOne.ttf',
    'Lobster': 'assets/fonts/Lobster.ttf',
    'Londrina Solid': 'assets/fonts/LondrinaSolid.ttf',
    'Manrope': 'assets/fonts/Manrope.ttf',
    'Marcellus': 'assets/fonts/Marcellus.ttf',
    'Modak': 'assets/fonts/Modak.ttf',
    'Monoton': 'assets/fonts/Monoton.ttf',
    'Montserrat': 'assets/fonts/Montserrat.ttf',
    'Nosifer': 'assets/fonts/Nosifer.ttf',
    'Nunito': 'assets/fonts/Nunito.ttf',
    'Orbitron': 'assets/fonts/Orbitron.ttf',
    'Oswald': 'assets/fonts/Oswald.ttf',
    'Outfit': 'assets/fonts/Outfit.ttf',
    'Oxanium': 'assets/fonts/Oxanium.ttf',
    'Pacifico': 'assets/fonts/Pacifico.ttf',
    'Parisienne': 'assets/fonts/Parisienne.ttf',
    'Passion One': 'assets/fonts/PassionOne.ttf',
    'Patrick Hand': 'assets/fonts/PatrickHand.ttf',
    'Paytone One': 'assets/fonts/PaytoneOne.ttf',
    'Permanent Marker': 'assets/fonts/PermanentMarker.ttf',
    'Playfair Display': 'assets/fonts/PlayfairDisplay.ttf',
    'Plus Jakarta Sans': 'assets/fonts/PlusJakartaSans.ttf',
    'Prata': 'assets/fonts/Prata.ttf',
    'Press Start 2P': 'assets/fonts/PressStart2P.ttf',
    'Quicksand': 'assets/fonts/Quicksand.ttf',
    'Raleway': 'assets/fonts/Raleway.ttf',
    'Righteous': 'assets/fonts/Righteous.ttf',
    'Roboto': 'assets/fonts/Roboto.ttf',
    'Rock Salt': 'assets/fonts/RockSalt.ttf',
    'Rowdies': 'assets/fonts/Rowdies.ttf',
    'Rubik': 'assets/fonts/Rubik.ttf',
    'Russo One': 'assets/fonts/RussoOne.ttf',
    'Sacramento': 'assets/fonts/Sacramento.ttf',
    'Saira': 'assets/fonts/Saira.ttf',
    'Satisfy': 'assets/fonts/Satisfy.ttf',
    'Shadows Into Light': 'assets/fonts/ShadowsIntoLight.ttf',
    'Share Tech Mono': 'assets/fonts/ShareTechMono-Regular.ttf',
    'Shrikhand': 'assets/fonts/Shrikhand.ttf',
    'Silkscreen': 'assets/fonts/Silkscreen.ttf',
    'Sora': 'assets/fonts/Sora.ttf',
    'Space Grotesk': 'assets/fonts/SpaceGrotesk.ttf',
    'Spectral': 'assets/fonts/Spectral.ttf',
    'Spicy Rice': 'assets/fonts/SpicyRice.ttf',
    'Syne': 'assets/fonts/Syne.ttf',
    'Teko': 'assets/fonts/Teko.ttf',
    'Titan One': 'assets/fonts/TitanOne.ttf',
    'Ultra': 'assets/fonts/Ultra.ttf',
    'Urbanist': 'assets/fonts/Urbanist.ttf',
    'VT323': 'assets/fonts/VT323.ttf',
    'Work Sans': 'assets/fonts/WorkSans.ttf',
    'Yellowtail': 'assets/fonts/Yellowtail.ttf',
    'Yeseva One': 'assets/fonts/YesevaOne.ttf',
  };

  final Map<String, String> _downloadedFilePaths = {};
  final Map<String, GoogleFontItem> _downloadedItems = {};
  final Map<String, double> _downloadProgress = {};
  final Set<String> _loadedFamilies = {};

  bool _isBatchDownloading = false;
  bool get isBatchDownloading => _isBatchDownloading;
  int _batchTotal = 0;
  int _batchCompleted = 0;
  int get batchTotal => _batchTotal;
  int get batchCompleted => _batchCompleted;
  bool _cancelBatch = false;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// All catalog fonts from google_font_model.dart
  List<GoogleFontItem> get catalog => kGoogleFontsCatalog;

  /// Currently downloaded or packaged Google font items
  List<GoogleFontItem> get downloadedFonts {
    final Map<String, GoogleFontItem> all = {};
    for (final item in catalog) {
      if (isAsset(item.family)) {
        all[item.family] = item;
      }
    }
    for (final item in _downloadedItems.values) {
      all[item.family] = item;
    }
    return List.unmodifiable(all.values);
  }

  /// Currently active download progress map (family -> 0.0..1.0)
  Map<String, double> get downloadProgress => Map.unmodifiable(_downloadProgress);

  /// Initialize at app startup: checks packaged assets and local disk, registering fonts
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // 1. Register packaged Google fonts from assets
    for (final entry in _assetFontPaths.entries) {
      await _registerAssetFont(entry.key, entry.value);
    }

    // 2. Register any locally downloaded fonts from documents directory
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        final dir = await _fontsDir();
        final List<dynamic> list = jsonDecode(raw);
        for (final entry in list) {
          try {
            final item = GoogleFontItem.fromMap(Map<String, dynamic>.from(entry as Map));
            final filePath = '${dir.path}/${item.sanitizedFileName}';
            final file = File(filePath);

            if (await file.exists()) {
              _downloadedFilePaths[item.family] = filePath;
              _downloadedItems[item.family] = item;
              await _registerFont(item.family, file);
            }
          } catch (e) {
            debugPrint('Error restoring Google Font: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('GoogleFontService init error: $e');
    }
  }

  /// Returns true if the font family has been packaged as an asset, or downloaded and registered
  bool isDownloaded(String family) {
    if (isAsset(family)) return true;
    return _downloadedItems.containsKey(family);
  }

  /// Returns true if the font family is bundled in app assets
  bool isAsset(String family) {
    return _assetFontPaths.containsKey(family);
  }

  /// Returns asset path if packaged in assets (e.g. 'assets/fonts/Anton.ttf'), or null
  String? getCatalogAssetPath(String family) {
    return _assetFontPaths[family];
  }

  /// Returns true if the font is currently being downloaded
  bool isDownloading(String family) {
    return _downloadProgress.containsKey(family);
  }

  /// Returns download progress between 0.0 and 1.0, or 0.0 if not downloading
  double getDownloadProgress(String family) {
    return _downloadProgress[family] ?? 0.0;
  }

  /// Absolute file path for the downloaded or extracted asset font, or null
  String? getFilePath(String family) {
    return _downloadedFilePaths[family];
  }

  /// Resolves the absolute file path for any Google font family, whether it was
  /// downloaded to disk or bundled in assets (extracts to cache if necessary).
  Future<String?> resolveFontFilePath(String family) async {
    final dlPath = getFilePath(family);
    if (dlPath != null && dlPath.isNotEmpty) {
      final f = File(dlPath);
      if (await f.exists() && await f.length() > 0) return dlPath;
    }
    final assetPath = getCatalogAssetPath(family);
    if (assetPath != null && assetPath.isNotEmpty) {
      try {
        final cacheDir = await getTemporaryDirectory();
        final filename = assetPath.split('/').last;
        final safeFamily = family.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
        final targetFile = File('${cacheDir.path}/font_${safeFamily}_$filename');
        if (await targetFile.exists() && await targetFile.length() > 0) {
          return targetFile.path;
        }
        final normalizedKey = assetPath.startsWith('assets/') ? assetPath : 'assets/$assetPath';
        final byteData = await rootBundle.load(normalizedKey);
        await targetFile.writeAsBytes(
          byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
          flush: true,
        );
        return targetFile.path;
      } catch (e) {
        debugPrint('[GoogleFontService] Error resolving asset path for $family: $e');
      }
    }
    return null;
  }

  /// Downloads a Google font on-demand, streams progress, saves to disk,
  /// and dynamically registers it with Flutter's FontLoader
  Future<bool> downloadFont(
    GoogleFontItem item, {
    void Function(double progress)? onProgress,
  }) async {
    if (isDownloaded(item.family)) return true;
    if (isDownloading(item.family)) return false;

    _downloadProgress[item.family] = 0.01;
    notifyListeners();

    HttpClient? client;
    File? tempFile;

    try {
      final dir = await _fontsDir();
      final targetPath = '${dir.path}/${item.sanitizedFileName}';
      final tempPath = '$targetPath.tmp';
      tempFile = File(tempPath);

      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 15);
      client.idleTimeout = const Duration(seconds: 15);

      final uri = Uri.parse(item.downloadUrl);
      final request = await client.getUrl(uri);
      final response = await request.close();

      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('HTTP status ${response.statusCode}: ${response.reasonPhrase}');
      }

      final totalBytes = response.contentLength;
      final fileSink = tempFile.openWrite();
      int receivedBytes = 0;

      await for (final chunk in response) {
        fileSink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          final p = (receivedBytes / totalBytes).clamp(0.0, 1.0);
          _downloadProgress[item.family] = p;
          onProgress?.call(p);
          notifyListeners();
        }
      }

      await fileSink.flush();
      await fileSink.close();

      // Rename temp file to final target
      final finalFile = await tempFile.rename(targetPath);

      // Register font dynamically in Flutter engine
      await _registerFont(item.family, finalFile);

      // Store in active registry
      _downloadedFilePaths[item.family] = targetPath;
      _downloadedItems[item.family] = item;
      _downloadProgress.remove(item.family);

      await _persist();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error downloading Google Font ${item.family}: $e');
      _downloadProgress.remove(item.family);
      notifyListeners();
      try {
        if (tempFile != null && await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {}
      return false;
    } finally {
      client?.close();
    }
  }

  /// Cancels an ongoing batch download
  void cancelBatchDownload() {
    _cancelBatch = true;
    _isBatchDownloading = false;
    notifyListeners();
  }

  /// Downloads all fonts in [fontList] (or entire catalog) in parallel batches
  Future<void> downloadAll({List<GoogleFontItem>? fontList}) async {
    if (_isBatchDownloading) return;
    final list = fontList ?? catalog;
    final toDownload = list.where((f) => !isDownloaded(f.family)).toList();
    if (toDownload.isEmpty) return;

    _isBatchDownloading = true;
    _cancelBatch = false;
    _batchTotal = toDownload.length;
    _batchCompleted = 0;
    notifyListeners();

    try {
      const batchSize = 3;
      for (int i = 0; i < toDownload.length; i += batchSize) {
        if (_cancelBatch) break;
        final end = (i + batchSize < toDownload.length) ? i + batchSize : toDownload.length;
        final batch = toDownload.sublist(i, end);
        await Future.wait(batch.map((font) async {
          if (_cancelBatch) return;
          final success = await downloadFont(font);
          if (success) {
            _batchCompleted++;
          }
        }));
        notifyListeners();
      }
    } finally {
      _isBatchDownloading = false;
      notifyListeners();
    }
  }

  /// Removes a downloaded Google Font from disk, unregisters it, and updates prefs
  Future<void> deleteFont(String family) async {
    final path = _downloadedFilePaths[family];
    _downloadedFilePaths.remove(family);
    _downloadedItems.remove(family);
    _downloadProgress.remove(family);

    if (path != null) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('Error deleting font file: $e');
      }
    }

    await _persist();
    notifyListeners();
  }

  // ─── Private Helpers ──────────────────────────────────────────────

  Future<void> _registerAssetFont(String family, String assetPath) async {
    if (_loadedFamilies.contains(family)) return;
    try {
      final byteData = await rootBundle.load(assetPath);
      final loader = FontLoader(family);
      loader.addFont(Future.value(byteData));
      await loader.load();
      _loadedFamilies.add(family);
    } catch (e) {
      debugPrint('Asset FontLoader registration failed for $family ($assetPath): $e');
    }
  }

  Future<void> _registerFont(String family, File file) async {
    if (_loadedFamilies.contains(family)) return;
    try {
      final bytes = await file.readAsBytes();
      final loader = FontLoader(family);
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
      _loadedFamilies.add(family);
    } catch (e) {
      debugPrint('FontLoader registration failed for $family: $e');
    }
  }

  Future<Directory> _fontsDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/google_fonts');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _downloadedItems.values.map((f) => f.toMap()).toList();
      await prefs.setString(_prefsKey, jsonEncode(list));
    } catch (e) {
      debugPrint('Error persisting Google fonts: $e');
    }
  }
}

