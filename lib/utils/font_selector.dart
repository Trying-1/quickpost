import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_theme.dart';
import '../services/google_font_service.dart';
export '../services/google_font_service.dart';
import '../services/favorite_fonts_manager.dart';
import '../widgets/google_font_picker_sheet.dart';
import 'custom_font_manager.dart';

class FontInfo {
  final String family;
  final String displayName;
  final FontWeight? weight;
  final FontStyle? style;
  final bool isCustom;
  final String? filePath; // absolute path for custom fonts
  final String? assetPath; // relative path within assets/ folder

  const FontInfo({
    required this.family,
    required this.displayName,
    this.weight,
    this.style,
    this.isCustom = false,
    this.filePath,
    this.assetPath,
  });

  Map<String, dynamic> toMap() {
    return {
      'family': family,
      'displayName': displayName,
      'weight': weight?.value,
      'style': style?.index,
      'isCustom': isCustom,
      'filePath': filePath,
      'assetPath': assetPath,
    };
  }

  factory FontInfo.fromMap(Map<String, dynamic> map) {
    return FontInfo(
      family: map['family'] as String? ?? 'Roboto',
      displayName: map['displayName'] as String? ?? 'Roboto',
      weight: map['weight'] != null ? FontWeight.values.firstWhere((e) => e.value == map['weight'], orElse: () => FontWeight.normal) : null,
      style: map['style'] != null ? FontStyle.values[map['style'] as int] : null,
      isCustom: map['isCustom'] as bool? ?? false,
      filePath: map['filePath'] as String?,
      assetPath: map['assetPath'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FontInfo &&
          runtimeType == other.runtimeType &&
          family == other.family &&
          weight == other.weight &&
          style == other.style;

  @override
  int get hashCode => family.hashCode ^ weight.hashCode ^ style.hashCode;

  static FontInfo? getFontByFamily(String family) {
    if (family.isEmpty) return null;
    try {
      final all = getAllFonts();
      for (final f in all) {
        if (f.family == family || f.displayName == family ||
            f.family.toLowerCase() == family.toLowerCase() ||
            f.displayName.toLowerCase() == family.toLowerCase()) {
          return f;
        }
      }
    } catch (_) {}

    // Fallback direct check in GoogleFontService catalog
    final gService = GoogleFontService();
    if (gService.isAsset(family)) {
      return FontInfo(
        family: family,
        displayName: family,
        isCustom: false,
        assetPath: gService.getCatalogAssetPath(family),
      );
    }
    if (gService.isDownloaded(family)) {
      return FontInfo(
        family: family,
        displayName: family,
        isCustom: !gService.isAsset(family),
        filePath: gService.getFilePath(family),
        assetPath: gService.getCatalogAssetPath(family),
      );
    }

    // Direct check in availableFonts
    for (final f in availableFonts) {
      if (f.family == family || f.displayName == family ||
          f.family.toLowerCase() == family.toLowerCase() ||
          f.displayName.toLowerCase() == family.toLowerCase()) {
        return f;
      }
    }

    return null;
  }

  static const List<FontInfo> availableFonts = [
    // Default system fonts
    FontInfo(family: 'Roboto', displayName: 'Roboto', assetPath: 'assets/fonts/Roboto.ttf'),
    FontInfo(family: 'Roboto', displayName: 'Roboto Bold', weight: FontWeight.bold, assetPath: 'assets/fonts/Roboto.ttf'),
    FontInfo(family: 'Roboto', displayName: 'Roboto Italic', style: FontStyle.italic, assetPath: 'assets/fonts/Roboto.ttf'),
    FontInfo(family: 'Roboto', displayName: 'Roboto Bold Italic', weight: FontWeight.bold, style: FontStyle.italic, assetPath: 'assets/fonts/Roboto.ttf'),
    
    // Custom fonts
    FontInfo(family: 'Bokor', displayName: 'Bokor', assetPath: 'assets/fonts/Bokor-Regular.ttf'),
    FontInfo(family: 'BungeeHairline', displayName: 'Bungee Hairline', assetPath: 'assets/fonts/BungeeHairline-Regular.ttf'),
    FontInfo(family: 'Caramel', displayName: 'Caramel', assetPath: 'assets/fonts/Caramel-Regular.ttf'),
    FontInfo(family: 'Explora', displayName: 'Explora', assetPath: 'assets/fonts/Explora-Regular.ttf'),
    FontInfo(family: 'GrandifloraOne', displayName: 'Grandiflora One', assetPath: 'assets/fonts/GrandifloraOne-Regular.ttf'),
    FontInfo(family: 'KleeOne', displayName: 'Klee One SemiBold', weight: FontWeight.w600, assetPath: 'assets/fonts/KleeOne-SemiBold.ttf'),
    FontInfo(family: 'Lacquer', displayName: 'Lacquer', assetPath: 'assets/fonts/Lacquer-Regular.ttf'),
    FontInfo(family: 'LibreBarcode39Text', displayName: 'Libre Barcode 39 Text', assetPath: 'assets/fonts/LibreBarcode39Text-Regular.ttf'),
    FontInfo(family: 'LuckiestGuy', displayName: 'Luckiest Guy', assetPath: 'assets/fonts/LuckiestGuy-Regular.ttf'),
    FontInfo(family: 'MajorMonoDisplay', displayName: 'Major Mono Display', assetPath: 'assets/fonts/MajorMonoDisplay-Regular.ttf'),
    FontInfo(family: 'Metrophobic', displayName: 'Metrophobic', assetPath: 'assets/fonts/Metrophobic-Regular.ttf'),
    FontInfo(family: 'Michroma', displayName: 'Michroma', assetPath: 'assets/fonts/Michroma-Regular.ttf'),
    FontInfo(family: 'NewRocker', displayName: 'New Rocker', assetPath: 'assets/fonts/NewRocker-Regular.ttf'),
    FontInfo(family: 'NewTegomin', displayName: 'New Tegomin', assetPath: 'assets/fonts/NewTegomin-Regular.ttf'),
    FontInfo(family: 'Poppins', displayName: 'Poppins', assetPath: 'assets/fonts/Poppins-Regular.ttf'),
    FontInfo(family: 'Poppins-Bold', displayName: 'Poppins Bold', weight: FontWeight.bold, assetPath: 'assets/fonts/Poppins-Bold.ttf'),
    FontInfo(family: 'Poppins-Black', displayName: 'Poppins Black', weight: FontWeight.w900, assetPath: 'assets/fonts/Poppins-Black.ttf'),
    FontInfo(family: 'Poppins-Light', displayName: 'Poppins Light', weight: FontWeight.w300, assetPath: 'assets/fonts/Poppins-Light.ttf'),
    FontInfo(family: 'Poppins-Medium', displayName: 'Poppins Medium', weight: FontWeight.w500, assetPath: 'assets/fonts/Poppins-Medium.ttf'),
    FontInfo(family: 'Poppins-SemiBold', displayName: 'Poppins SemiBold', weight: FontWeight.w600, assetPath: 'assets/fonts/Poppins-SemiBold.ttf'),
    FontInfo(family: 'Poppins-Thin', displayName: 'Poppins Thin', weight: FontWeight.w100, assetPath: 'assets/fonts/Poppins-Thin.ttf'),
    FontInfo(family: 'Poppins-ExtraLight', displayName: 'Poppins ExtraLight', weight: FontWeight.w200, assetPath: 'assets/fonts/Poppins-ExtraLight.ttf'),
    FontInfo(family: 'Poppins-ExtraBold', displayName: 'Poppins ExtraBold', weight: FontWeight.w800, assetPath: 'assets/fonts/Poppins-ExtraBold.ttf'),
    FontInfo(family: 'Poppins-Italic', displayName: 'Poppins Italic', style: FontStyle.italic, assetPath: 'assets/fonts/Poppins-Italic.ttf'),
    FontInfo(family: 'ProtestRevolution', displayName: 'Protest Revolution', assetPath: 'assets/fonts/ProtestRevolution-Regular.ttf'),
    FontInfo(family: 'SourGummy', displayName: 'Sour Gummy', assetPath: 'assets/fonts/SourGummy-VariableFont_wdth,wght.ttf'),
    FontInfo(family: 'KodeMono', displayName: 'Kode Mono', assetPath: 'assets/fonts/KodeMono-Regular.ttf'),
  ];

  /// Resolves the font to an absolute file path.
  /// Copies built-in assets to a temporary file if needed, so native C++/Kotlin
  /// code (OpenGLWatermarkProcessor.kt) can load it via Typeface.createFromFile(fontPath).
  static Future<String> getFontFilePath(FontInfo font) async {
    // 1. Direct file on disk (custom user font or downloaded Google font)
    if (font.filePath != null && font.filePath!.isNotEmpty) {
      final f = File(font.filePath!);
      if (await f.exists() && await f.length() > 0) {
        return f.path;
      }
    }

    // Also check if GoogleFontService has a downloaded file path for this family
    final googleFilePath = GoogleFontService().getFilePath(font.family);
    if (googleFilePath != null && googleFilePath.isNotEmpty) {
      final f = File(googleFilePath);
      if (await f.exists() && await f.length() > 0) {
        return f.path;
      }
    }

    // 2. Built-in font: copy from assets if we have an assetPath or catalog path
    String? assetPath = font.assetPath;
    if (assetPath == null || assetPath.isEmpty) {
      assetPath = GoogleFontService().getCatalogAssetPath(font.family);
    }
    if (assetPath == null || assetPath.isEmpty) {
      final match = availableFonts.where((f) =>
        f.family == font.family ||
        f.displayName == font.displayName ||
        f.family.toLowerCase() == font.family.toLowerCase()
      ).firstOrNull;
      assetPath = match?.assetPath;
    }

    if (assetPath != null && assetPath.isNotEmpty) {
      try {
        final tempDir = await getTemporaryDirectory();
        final filename = assetPath.split('/').last;
        final safeFamily = font.family.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
        final targetFile = File('${tempDir.path}/font_${safeFamily}_$filename');

        if (await targetFile.exists() && await targetFile.length() > 0) {
          return targetFile.path;
        }

        final normalizedAssetKey = assetPath.startsWith('assets/') ? assetPath : 'assets/$assetPath';
        final byteData = await rootBundle.load(normalizedAssetKey);
        await targetFile.writeAsBytes(
          byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
          flush: true,
        );
        return targetFile.path;
      } catch (e) {
        debugPrint('[FontResolver] Failed to extract asset font "${font.family}" ($assetPath): $e');
      }
    }

    // 3. Fallback: try guaranteed default asset KleeOne
    try {
      final tempDir = await getTemporaryDirectory();
      const fallbackAsset = 'assets/fonts/KleeOne-SemiBold.ttf';
      final fallbackFile = File('${tempDir.path}/font_fallback_KleeOne-SemiBold.ttf');
      if (await fallbackFile.exists() && await fallbackFile.length() > 0) {
        return fallbackFile.path;
      }
      final byteData = await rootBundle.load(fallbackAsset);
      await fallbackFile.writeAsBytes(
        byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
        flush: true,
      );
      return fallbackFile.path;
    } catch (e) {
      debugPrint('[FontResolver] Fallback font extraction failed: $e');
      return '/system/fonts/Roboto-Regular.ttf';
    }
  }
}

class FontSelector extends StatefulWidget {
  final FontInfo? selectedFont;
  final Function(FontInfo) onFontSelected;
  final String previewText;

  const FontSelector({
    super.key,
    this.selectedFont,
    required this.onFontSelected,
    this.previewText = 'The quick brown fox jumps',
  });

  @override
  State<FontSelector> createState() => _FontSelectorState();
}

class _FontSelectorState extends State<FontSelector> {
  FontInfo? _hoveredFont;
  bool _isImporting = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<String> _recentFontFamilies = [];

  @override
  void initState() {
    super.initState();
    _loadRecents();
  }

  Future<void> _loadRecents() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentFontFamilies = prefs.getStringList('recent_fonts') ?? [];
    });
  }

  Future<void> _saveRecent(FontInfo font) async {
    final prefs = await SharedPreferences.getInstance();
    final recents = prefs.getStringList('recent_fonts') ?? [];
    recents.remove(font.family);
    recents.insert(0, font.family);
    if (recents.length > 5) {
      recents.removeLast();
    }
    await prefs.setStringList('recent_fonts', recents);
  }

  Future<void> _importCustomFont() async {
    setState(() => _isImporting = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
      );
      if (result != null && result.files.isNotEmpty) {
        bool anyImported = false;
        for (final xFile in result.files) {
          if (xFile.path == null) continue;
          final path = xFile.path!;
          if (!path.toLowerCase().endsWith('.ttf') && !path.toLowerCase().endsWith('.otf')) {
            continue;
          }
          final file = File(path);
          final entry = await CustomFontManager().addFont(file);
          if (entry != null) anyImported = true;
        }
        
        if (anyImported && mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Imported ${result.files.length} font(s)')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to import font: $e')),
        );
      }
    }
    if (mounted) setState(() => _isImporting = false);
  }

  Future<void> _deleteCustomFont(CustomFontEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Font?'),
        content: Text('Remove "${entry.displayName}" from your library?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await CustomFontManager().removeFont(entry.familyName);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final customFonts = CustomFontManager().fonts;
    final googleService = GoogleFontService();
    final googleFontInfos = googleService.downloadedFonts.map((item) {
      final isAsset = googleService.isAsset(item.family);
      return FontInfo(
        family: item.family,
        displayName: item.family,
        isCustom: !isAsset,
        filePath: isAsset ? null : googleService.getFilePath(item.family),
        assetPath: isAsset ? googleService.getCatalogAssetPath(item.family) : null,
      );
    }).toList();
    final allFonts = <dynamic>[]; 
    
    final customFontInfos = customFonts.map((e) => FontInfo(
      family: e.familyName,
      displayName: e.displayName,
      isCustom: true,
      filePath: e.filePath,
    )).toList();
    
    final allAvailableFonts = [...googleFontInfos, ...customFontInfos, ...FontInfo.availableFonts];
    
    final filteredFonts = allAvailableFonts.where((f) => 
        f.displayName.toLowerCase().contains(_searchQuery.toLowerCase()) || 
        f.family.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();

    if (_searchQuery.isNotEmpty) {
      allFonts.addAll(filteredFonts);
    } else {
      final favManager = FavoriteFontsManager();
      final favFonts = allAvailableFonts.where((f) => favManager.isFavorite(f.family)).toList();
      if (favFonts.isNotEmpty) {
        allFonts.add('__favorite_header__');
        allFonts.addAll(favFonts);
      }

      if (_recentFontFamilies.isNotEmpty) {
        allFonts.add('__recent_header__');
        for (final family in _recentFontFamilies) {
          try {
            allFonts.add(allAvailableFonts.firstWhere((f) => f.family == family));
          } catch (_) {}
        }
      }
      
      if (googleFontInfos.isNotEmpty) {
        allFonts.add('__google_header__');
        allFonts.addAll(googleFontInfos);
      }

      if (customFonts.isNotEmpty) {
        allFonts.add('__custom_header__');
        allFonts.addAll(customFonts);
      }
      
      allFonts.add('__builtin_header__');
      allFonts.addAll(FontInfo.availableFonts);
    }

    final double maxHeight = MediaQuery.of(context).size.height * 0.8;
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 600,
            maxHeight: maxHeight,
            minHeight: 240,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.font_download, color: AppColors.primary),
                      const SizedBox(width: 8),
                      const Text(
                        'Select Font',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      // Google Fonts button
                      IconButton(
                        onPressed: () async {
                          final nav = Navigator.of(context);
                          final selectedItem = await GoogleFontPickerSheet.show(context, previewText: widget.previewText);
                          if (selectedItem != null && mounted) {
                            final isAsset = GoogleFontService().isAsset(selectedItem.family);
                            final selected = FontInfo(
                              family: selectedItem.family,
                              displayName: selectedItem.family,
                              isCustom: !isAsset,
                              filePath: isAsset ? null : GoogleFontService().getFilePath(selectedItem.family),
                              assetPath: isAsset ? GoogleFontService().getCatalogAssetPath(selectedItem.family) : null,
                            );
                            _saveRecent(selected);
                            widget.onFontSelected(selected);
                            nav.pop();
                          }
                        },
                        icon: const Icon(Icons.cloud_download_outlined, color: AppColors.primary),
                        tooltip: 'Google Fonts (90+)',
                      ),
                      // Add Font button
                      _isImporting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : IconButton(
                              onPressed: _importCustomFont,
                              icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                              tooltip: 'Add Custom Font',
                            ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Search fonts...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty 
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20), 
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            })
                        : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    ),
                  ),
                ),
                // Live Preview
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Preview:',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          widget.previewText,
                          style: TextStyle(
                            fontFamily: (_hoveredFont ?? widget.selectedFont)?.family,
                            fontWeight: (_hoveredFont ?? widget.selectedFont)?.weight ?? FontWeight.normal,
                            fontStyle: (_hoveredFont ?? widget.selectedFont)?.style ?? FontStyle.normal,
                            fontSize: 24,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Center(
                        child: Text(
                          (_hoveredFont ?? widget.selectedFont)?.displayName ?? 'No font selected',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Font List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: allFonts.length,
                    itemBuilder: (context, index) {
                      final item = allFonts[index];
                      
                      // Section headers
                      if (item == '__favorite_header__') {
                        return const Padding(
                          padding: EdgeInsets.fromLTRB(12, 8, 12, 4),
                          child: Row(
                            children: [
                              Icon(Icons.favorite, size: 14, color: Colors.redAccent),
                              SizedBox(width: 6),
                              Text('FAVORITE FONTS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.redAccent, letterSpacing: 1)),
                            ],
                          ),
                        );
                      }
                      if (item == '__recent_header__') {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                          child: Row(
                            children: [
                              Icon(Icons.history, size: 14, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Text('RECENT FONTS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary, letterSpacing: 1)),
                            ],
                          ),
                        );
                      }
                      if (item == '__google_header__') {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                          child: Row(
                            children: [
                              Icon(Icons.cloud_done_rounded, size: 14, color: Colors.blue[700]),
                              const SizedBox(width: 6),
                              Text('GOOGLE FONTS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.blue[800], letterSpacing: 1)),
                            ],
                          ),
                        );
                      }
                      if (item == '__custom_header__') {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                          child: Row(
                            children: [
                              Icon(Icons.star_rounded, size: 14, color: Colors.amber[700]),
                              const SizedBox(width: 6),
                              Text('YOUR FONTS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.amber[800], letterSpacing: 1)),
                            ],
                          ),
                        );
                      }
                      if (item == '__builtin_header__') {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(12, 16, 12, 4),
                          child: Row(
                            children: [
                              Icon(Icons.auto_awesome, size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 6),
                              Text('BUILT-IN FONTS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey[600], letterSpacing: 1)),
                            ],
                          ),
                        );
                      }
                      
                      // Custom font entry
                      if (item is CustomFontEntry) {
                        final font = FontInfo(
                          family: item.familyName,
                          displayName: item.displayName,
                          isCustom: true,
                          filePath: item.filePath,
                        );
                        final isSelected = widget.selectedFont == font;
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          child: ListTile(
                            selected: isSelected,
                            selectedTileColor: AppColors.primary.withOpacity(0.1),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            title: Text(
                              font.displayName,
                              style: TextStyle(
                                fontFamily: font.family,
                                fontWeight: font.weight,
                                fontStyle: font.style,
                                color: isSelected ? AppColors.primary : Colors.black87,
                                fontSize: 16,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    FavoriteFontsManager().isFavorite(font.family)
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    size: 18,
                                    color: FavoriteFontsManager().isFavorite(font.family)
                                        ? Colors.redAccent
                                        : Colors.grey[400],
                                  ),
                                  onPressed: () {
                                    FavoriteFontsManager().toggleFavorite(font.family);
                                    setState(() {});
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                ),
                                if (isSelected) const Icon(Icons.check, color: AppColors.primary, size: 20),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: Icon(Icons.delete_outline, size: 18, color: Colors.red[300]),
                                  onPressed: () => _deleteCustomFont(item),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                ),
                              ],
                            ),
                            onTap: () {
                              _saveRecent(font);
                              widget.onFontSelected(font);
                              Navigator.of(context).pop();
                            },
                          ),
                        );
                      }
                      
                      // Built-in font entry
                      final font = item as FontInfo;
                      final isSelected = widget.selectedFont == font;
                      final isHovered = _hoveredFont == font;
                      
                      return MouseRegion(
                        onEnter: (_) {
                          setState(() {
                            _hoveredFont = font;
                          });
                        },
                        onExit: (_) {
                          setState(() {
                            _hoveredFont = null;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          child: ListTile(
                            selected: isSelected,
                            selectedTileColor: AppColors.primary.withOpacity(0.1),
                            hoverColor: Colors.grey[100],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: isHovered 
                                  ? BorderSide(color: AppColors.primaryLight, width: 2)
                                  : BorderSide.none,
                            ),
                            title: Text(
                              font.displayName,
                              style: TextStyle(
                                fontFamily: font.family,
                                fontWeight: font.weight ?? FontWeight.normal,
                                fontStyle: font.style ?? FontStyle.normal,
                                color: isSelected ? AppColors.primary : Colors.black87,
                                fontSize: 16,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    FavoriteFontsManager().isFavorite(font.family)
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    size: 18,
                                    color: FavoriteFontsManager().isFavorite(font.family)
                                        ? Colors.redAccent
                                        : Colors.grey[400],
                                  ),
                                  onPressed: () {
                                    FavoriteFontsManager().toggleFavorite(font.family);
                                    setState(() {});
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                ),
                                if (isSelected)
                                  const Icon(Icons.check, color: AppColors.primary),
                              ],
                            ),
                            onTap: () {
                              _saveRecent(font);
                              widget.onFontSelected(font);
                              Navigator.of(context).pop();
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Public helper to access fonts list outside this file
List<FontInfo> getAllFonts() {
  const builtIn = FontInfo.availableFonts;
  final custom = CustomFontManager().fonts.map((e) => FontInfo(
    family: e.familyName,
    displayName: e.displayName,
    isCustom: true,
    filePath: e.filePath,
  )).toList();
  final googleService = GoogleFontService();
  final google = googleService.downloadedFonts.map((item) {
    final isAsset = googleService.isAsset(item.family);
    return FontInfo(
      family: item.family,
      displayName: item.family,
      isCustom: !isAsset,
      filePath: isAsset ? null : googleService.getFilePath(item.family),
      assetPath: isAsset ? googleService.getCatalogAssetPath(item.family) : null,
    );
  }).toList();
  final Map<String, FontInfo> unique = {};
  for (final f in google) {
    unique[f.family] = f;
  }
  for (final f in custom) {
    unique[f.family] = f;
  }
  for (final f in builtIn) {
    unique.putIfAbsent(f.family, () => f);
  }
  return unique.values.toList();
}

class FontSelectorButton extends StatelessWidget {
  final FontInfo? selectedFont;
  final Function(FontInfo) onFontSelected;
  final String previewText;

  const FontSelectorButton({
    super.key,
    this.selectedFont,
    required this.onFontSelected,
    this.previewText = 'The quick brown fox jumps',
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: FontSelector(
              selectedFont: selectedFont,
              onFontSelected: onFontSelected,
              previewText: previewText,
            ),
          ),
        );
      },
      icon: const Icon(Icons.font_download),
      label: Text(
        selectedFont?.displayName ?? 'Select Font',
        style: TextStyle(
          fontFamily: selectedFont?.family,
          fontWeight: selectedFont?.weight ?? FontWeight.normal,
          fontStyle: selectedFont?.style ?? FontStyle.normal,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primarySurface,
        foregroundColor: AppColors.primary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: AppColors.primaryLight),
        ),
      ),
    );
  }
}

class HorizontalFontSelector extends StatefulWidget {
  final FontInfo? selectedFont;
  final Function(FontInfo) onFontSelected;

  const HorizontalFontSelector({
    super.key,
    this.selectedFont,
    required this.onFontSelected,
  });

  @override
  State<HorizontalFontSelector> createState() => _HorizontalFontSelectorState();
}

class _HorizontalFontSelectorState extends State<HorizontalFontSelector> {
  List<String> _recentFontFamilies = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadRecents();
  }

  Future<void> _loadRecents() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentFontFamilies = prefs.getStringList('recent_fonts') ?? [];
    });
  }

  Future<void> _saveRecent(FontInfo font) async {
    final prefs = await SharedPreferences.getInstance();
    final recents = prefs.getStringList('recent_fonts') ?? [];
    recents.remove(font.family);
    recents.insert(0, font.family);
    if (recents.length > 10) {
      recents.removeLast();
    }
    await prefs.setStringList('recent_fonts', recents);
    _loadRecents();
  }

  @override
  Widget build(BuildContext context) {
    final List<FontInfo> allFonts = getAllFonts();
    final googleService = GoogleFontService();
    final googleFonts = allFonts.where((f) => googleService.isDownloaded(f.family)).toList();
    final customFonts = allFonts.where((f) => f.isCustom && !googleService.isDownloaded(f.family)).toList();
    final builtinFonts = allFonts.where((f) => !f.isCustom && !googleService.isDownloaded(f.family)).toList();
    
    final recents = <FontInfo>[];
    for (final family in _recentFontFamilies) {
      try {
        recents.add(allFonts.firstWhere((f) => f.family == family));
      } catch (_) {}
    }

    final filteredGoogleFonts = googleFonts.where((f) => 
        f.displayName.toLowerCase().contains(_searchQuery.toLowerCase()) || 
        f.family.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
    final filteredCustomFonts = customFonts.where((f) => 
        f.displayName.toLowerCase().contains(_searchQuery.toLowerCase()) || 
        f.family.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
    final filteredBuiltinFonts = builtinFonts.where((f) => 
        f.displayName.toLowerCase().contains(_searchQuery.toLowerCase()) || 
        f.family.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search fonts...',
                      prefixIcon: const Icon(Icons.search, size: 16),
                      suffixIcon: _searchQuery.isNotEmpty 
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16), 
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            })
                        : null,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () async {
                  final selectedItem = await GoogleFontPickerSheet.show(context);
                  if (selectedItem != null && mounted) {
                    final isAsset = GoogleFontService().isAsset(selectedItem.family);
                    final selected = FontInfo(
                      family: selectedItem.family,
                      displayName: selectedItem.family,
                      isCustom: !isAsset,
                      filePath: isAsset ? null : GoogleFontService().getFilePath(selectedItem.family),
                      assetPath: isAsset ? GoogleFontService().getCatalogAssetPath(selectedItem.family) : null,
                    );
                    _saveRecent(selected);
                    widget.onFontSelected(selected);
                    setState(() {});
                  }
                },
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_download_outlined, size: 15, color: AppColors.primary),
                      SizedBox(width: 4),
                      Text(
                        'Google Fonts',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_searchQuery.isEmpty) ...[
          AnimatedBuilder(
            animation: FavoriteFontsManager(),
            builder: (context, _) {
              final favManager = FavoriteFontsManager();
              final favs = allFonts.where((f) => favManager.isFavorite(f.family)).toList();
              if (favs.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTinyHeader('FAVORITE FONTS (${favs.length})'),
                  _buildRow(favs),
                  const SizedBox(height: 8),
                ],
              );
            },
          ),
          _buildTinyHeader('RECENT FONTS'),
          if (recents.isNotEmpty)
            _buildRow(recents)
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text('No recent fonts yet', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
            ),
          const SizedBox(height: 8),
        ],

        if (filteredGoogleFonts.isNotEmpty) ...[
          _buildTinyHeader(_searchQuery.isEmpty ? 'GOOGLE FONTS' : 'GOOGLE FONTS (${filteredGoogleFonts.length})'),
          _buildRow(filteredGoogleFonts),
          const SizedBox(height: 8),
        ],

        if (filteredCustomFonts.isNotEmpty) ...[
          _buildTinyHeader(_searchQuery.isEmpty ? 'YOUR FONTS' : 'YOUR FONTS (${filteredCustomFonts.length})'),
          _buildRow(filteredCustomFonts),
          const SizedBox(height: 8),
        ],
        if (filteredBuiltinFonts.isNotEmpty) ...[
          _buildTinyHeader(_searchQuery.isEmpty ? 'APP FONTS' : 'APP FONTS (${filteredBuiltinFonts.length})'),
          _buildRow(filteredBuiltinFonts),
        ],
      ],
    );
  }

  Widget _buildTinyHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: Colors.grey[500],
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildRow(List<FontInfo> fonts) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: fonts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemBuilder: (context, index) {
          final font = fonts[index];
          final isSelected = widget.selectedFont == font;
          return ChoiceChip(
            label: Text(
              font.displayName,
              style: TextStyle(
                fontFamily: font.family,
                fontWeight: font.weight,
                fontStyle: font.style,
                fontSize: 12,
                color: isSelected ? AppColors.primary : Colors.black87,
              ),
            ),
            selected: isSelected,
            showCheckmark: false,
            onSelected: (val) {
              if (val) {
                _saveRecent(font);
                widget.onFontSelected(font);
              }
            },
            backgroundColor: Colors.grey[100],
            selectedColor: AppColors.primaryLight,
            checkmarkColor: AppColors.primary,
            side: BorderSide(
              color: isSelected ? AppColors.primaryLight : Colors.transparent,
              width: 1,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            labelPadding: const EdgeInsets.symmetric(horizontal: 4),
          );
        },
      ),
    );
  }
}

