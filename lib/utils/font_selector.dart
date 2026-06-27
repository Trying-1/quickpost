import '../config/app_theme.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
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
    try {
      return getAllFonts().firstWhere((f) => f.family == family);
    } catch (_) {
      return null;
    }
  }

  static const List<FontInfo> availableFonts = [
    // Default system fonts
    FontInfo(family: 'Roboto', displayName: 'Roboto', assetPath: 'assets/fonts/Roboto-Regular.ttf'),
    FontInfo(family: 'Roboto', displayName: 'Roboto Bold', weight: FontWeight.bold, assetPath: 'assets/fonts/Roboto-Bold.ttf'),
    FontInfo(family: 'Roboto', displayName: 'Roboto Italic', style: FontStyle.italic, assetPath: 'assets/fonts/Roboto-Italic.ttf'),
    FontInfo(family: 'Roboto', displayName: 'Roboto Bold Italic', weight: FontWeight.bold, style: FontStyle.italic, assetPath: 'assets/fonts/Roboto-BoldItalic.ttf'),
    
    // Custom fonts
    FontInfo(family: 'AllertaStencil', displayName: 'Allerta Stencil', assetPath: 'assets/fonts/AllertaStencil-Regular.ttf'),
    FontInfo(family: 'AlmendraDisplay', displayName: 'Almendra Display', assetPath: 'assets/fonts/AlmendraDisplay-Regular.ttf'),
    FontInfo(family: 'AlumniSans', displayName: 'Alumni Sans', assetPath: 'assets/fonts/AlumniSans-Regular.ttf'),
    FontInfo(family: 'AlumniSans-Bold', displayName: 'Alumni Sans Bold', weight: FontWeight.bold, assetPath: 'assets/fonts/AlumniSans-Bold.ttf'),
    FontInfo(family: 'AlumniSans-Black', displayName: 'Alumni Sans Black', weight: FontWeight.w900, assetPath: 'assets/fonts/AlumniSans-Black.ttf'),
    FontInfo(family: 'AlumniSans-Light', displayName: 'Alumni Sans Light', weight: FontWeight.w300, assetPath: 'assets/fonts/AlumniSans-Light.ttf'),
    FontInfo(family: 'AlumniSans-Medium', displayName: 'Alumni Sans Medium', weight: FontWeight.w500, assetPath: 'assets/fonts/AlumniSans-Medium.ttf'),
    FontInfo(family: 'AlumniSans-SemiBold', displayName: 'Alumni Sans SemiBold', weight: FontWeight.w600, assetPath: 'assets/fonts/AlumniSans-SemiBold.ttf'),
    FontInfo(family: 'AlumniSans-Thin', displayName: 'Alumni Sans Thin', weight: FontWeight.w100, assetPath: 'assets/fonts/AlumniSans-Thin.ttf'),
    FontInfo(family: 'AlumniSans-ExtraLight', displayName: 'Alumni Sans ExtraLight', weight: FontWeight.w200, assetPath: 'assets/fonts/AlumniSans-ExtraLight.ttf'),
    FontInfo(family: 'AlumniSans-ExtraBold', displayName: 'Alumni Sans ExtraBold', weight: FontWeight.w800, assetPath: 'assets/fonts/AlumniSans-ExtraBold.ttf'),
    FontInfo(family: 'AlumniSans-Italic', displayName: 'Alumni Sans Italic', style: FontStyle.italic, assetPath: 'assets/fonts/AlumniSans-Italic.ttf'),
    FontInfo(family: 'AlumniSansPinstripe', displayName: 'Alumni Sans Pinstripe', assetPath: 'assets/fonts/AlumniSansPinstripe-Regular.ttf'),
    FontInfo(family: 'AlumniSansPinstripe-Italic', displayName: 'Alumni Sans Pinstripe Italic', style: FontStyle.italic, assetPath: 'assets/fonts/AlumniSansPinstripe-Italic.ttf'),
    FontInfo(family: 'Barrio', displayName: 'Barrio', assetPath: 'assets/fonts/Barrio-Regular.ttf'),
    FontInfo(family: 'Bellota', displayName: 'Bellota', assetPath: 'assets/fonts/Bellota-Regular.ttf'),
    FontInfo(family: 'Bellota-Bold', displayName: 'Bellota Bold', weight: FontWeight.bold, assetPath: 'assets/fonts/Bellota-Bold.ttf'),
    FontInfo(family: 'Bellota-Light', displayName: 'Bellota Light', weight: FontWeight.w300, assetPath: 'assets/fonts/Bellota-Light.ttf'),
    FontInfo(family: 'Bellota-Italic', displayName: 'Bellota Italic', style: FontStyle.italic, assetPath: 'assets/fonts/Bellota-Italic.ttf'),
    FontInfo(family: 'BhuTukaExpandedOne', displayName: 'BhuTuka Expanded One', assetPath: 'assets/fonts/BhuTukaExpandedOne-Regular.ttf'),
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
  ];

  /// Resolves the font to an absolute file path.
  /// Copies built-in assets to a temporary file if needed.
  static Future<String> getFontFilePath(FontInfo font) async {
    // 1. Custom uploaded font: use its absolute file path directly
    if (font.isCustom && font.filePath != null && font.filePath!.startsWith('/')) {
      if (await File(font.filePath!).exists()) {
        return font.filePath!;
      }
    }

    // 2. Built-in font: copy from assets if we have an assetPath
    final assetPath = font.assetPath;
    if (assetPath == null) {
      // Fallback for cases where assetPath wasn't provided (shouldn't happen for regulated items)
      if (font.family == 'Roboto') return '/system/fonts/Roboto-Regular.ttf';
      return '/system/fonts/Roboto-Regular.ttf'; 
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final filename = assetPath.split('/').last;
      // Use family-specific name to avoid collisions if multiple fonts share same filename but different subpaths (unlikely but safe)
      final targetFile = File('${tempDir.path}/font_${font.family}_$filename');
      
      if (await targetFile.exists()) return targetFile.path;

      final byteData = await rootBundle.load(assetPath);
      await targetFile.writeAsBytes(byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes), flush: true);
      return targetFile.path;
    } catch (e) {
      debugPrint('Font resolution failed for ${font.family}: $e');
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
    final allFonts = <dynamic>[]; // Mix of FontInfo and section markers
    
    // Custom fonts first (if any)
    if (customFonts.isNotEmpty) {
      allFonts.add('__custom_header__');
      for (final entry in customFonts) {
        allFonts.add(entry);
      }
      allFonts.add('__builtin_header__');
    }
    // Built-in fonts
    final fonts = FontInfo.availableFonts;
    allFonts.addAll(fonts);

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
                            trailing: isSelected
                                ? const Icon(Icons.check, color: AppColors.primary)
                                : null,
                            onTap: () {
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
  final builtIn = FontInfo.availableFonts;
  final custom = CustomFontManager().fonts.map((e) => FontInfo(
    family: e.familyName,
    displayName: e.displayName,
    isCustom: true,
    filePath: e.filePath,
  )).toList();
  return [...custom, ...builtIn];
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

class HorizontalFontSelector extends StatelessWidget {
  final FontInfo? selectedFont;
  final Function(FontInfo) onFontSelected;

  const HorizontalFontSelector({
    super.key,
    this.selectedFont,
    required this.onFontSelected,
  });

  @override
  Widget build(BuildContext context) {
    final List<FontInfo> allFonts = getAllFonts();
    final customFonts = allFonts.where((f) => f.isCustom).toList();
    final builtinFonts = allFonts.where((f) => !f.isCustom).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (customFonts.isNotEmpty) ...[
          _buildTinyHeader('YOUR FONTS'),
          _buildRow(customFonts),
          const SizedBox(height: 12),
        ],
        _buildTinyHeader('APP FONTS'),
        _buildRow(builtinFonts),
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
          final isSelected = selectedFont == font;
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
            onSelected: (val) {
              if (val) onFontSelected(font);
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

