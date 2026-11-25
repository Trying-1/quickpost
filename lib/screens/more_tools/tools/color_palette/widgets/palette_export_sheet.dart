import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quickpost/config/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/color_palette_item.dart';
import '../models/palette_export_card_style.dart';
import '../services/color_extractor_service.dart';

/// Modal sheet that renders and previews high-resolution aesthetic palette cards
/// across 3:4 Portrait & 1:1 Square aspect ratios and designer layout styles.
class PaletteExportSheet extends StatefulWidget {
  final ColorPaletteItem palette;
  final File? sourceImageFile;

  const PaletteExportSheet({
    super.key,
    required this.palette,
    this.sourceImageFile,
  });

  static Future<void> show(
    BuildContext context, {
    required ColorPaletteItem palette,
    File? sourceImageFile,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PaletteExportSheet(palette: palette, sourceImageFile: sourceImageFile),
    );
  }

  @override
  State<PaletteExportSheet> createState() => _PaletteExportSheetState();
}

class _PaletteExportSheetState extends State<PaletteExportSheet> {
  PaletteExportAspectRatio _selectedAspectRatio = PaletteExportAspectRatio.portrait3x4;
  PaletteExportCardStyle _selectedStyle = PaletteExportCardStyle.circularSwatches;
  PaletteBackgroundTheme _selectedTheme = PaletteBackgroundTheme.obsidian;
  Uint8List? _previewBytes;
  bool _isRendering = true;
  bool _isSaving = false;
  String? _savedPath;
  String? _userHandle;

  @override
  void initState() {
    super.initState();
    if (widget.sourceImageFile != null) {
      _selectedStyle = PaletteExportCardStyle.photoCompanion;
    }
    _loadUserHandle();
  }

  Future<void> _loadUserHandle() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _userHandle = prefs.getString('watermark_handle') ?? '@quickpost';
    } catch (_) {
      _userHandle = '@quickpost';
    }
    _renderPreview();
  }

  Future<void> _renderPreview() async {
    setState(() {
      _isRendering = true;
      _savedPath = null;
    });

    try {
      Uint8List? sourceBytes;
      if (widget.sourceImageFile != null) {
        sourceBytes = await widget.sourceImageFile!.readAsBytes();
      }

      final bytes = await ColorExtractorService().renderPaletteCardImage(
        palette: widget.palette,
        style: _selectedStyle,
        aspectRatio: _selectedAspectRatio,
        theme: _selectedTheme,
        sourceImageBytes: sourceBytes,
        userHandle: _userHandle,
      );

      if (mounted) {
        setState(() {
          _previewBytes = bytes;
          _isRendering = false;
        });
      }
    } catch (e) {
      debugPrint('Error rendering palette preview: $e');
      if (mounted) setState(() => _isRendering = false);
    }
  }

  Future<void> _saveToGallery() async {
    if (_previewBytes == null) return;
    setState(() => _isSaving = true);

    try {
      final path = await ColorExtractorService().savePaletteImageToGallery(
        _previewBytes!,
        widget.palette.title,
      );

      if (mounted) {
        setState(() {
          _isSaving = false;
          _savedPath = path;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Color(0xFF00E5FF), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Palette card saved to Gallery! (Pictures/Quick Post Palettes)',
                    style: TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.primaryDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving to gallery: $e');
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _shareImage() async {
    if (_previewBytes == null) return;

    if (_savedPath == null) {
      final path = await ColorExtractorService().savePaletteImageToGallery(
        _previewBytes!,
        widget.palette.title,
      );
      _savedPath = path;
    }

    if (_savedPath != null) {
      await ColorExtractorService().sharePaletteImage(_savedPath!, widget.palette.title);
    }
  }

  void _showCopyFormats() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Copy Palette Codes', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
              const SizedBox(height: 14),
              _buildCopyItem(
                title: 'HEX Values',
                subtitle: widget.palette.toHexListString(),
                contentToCopy: widget.palette.toHexListString(),
              ),
              _buildCopyItem(
                title: 'CSS Root Variables',
                subtitle: ':root { --color-1: #...; }',
                contentToCopy: widget.palette.toCssVariables(),
              ),
              _buildCopyItem(
                title: 'Flutter Color Array',
                subtitle: 'const [Color(0xFF...), ...]',
                contentToCopy: widget.palette.toFlutterCode(),
              ),
              _buildCopyItem(
                title: 'JSON Data',
                subtitle: '{"title": "...", "colors": [...]}',
                contentToCopy: widget.palette.toJsonExport(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCopyItem({required String title, required String subtitle, required String contentToCopy}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Poppins')),
      subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontFamily: 'Poppins'), maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.copy_rounded, color: AppColors.primary, size: 18),
      onTap: () {
        Clipboard.setData(ClipboardData(text: contentToCopy));
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Copied $title to clipboard!'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  Widget _buildRatioChip(PaletteExportAspectRatio ratio) {
    final isSelected = ratio == _selectedAspectRatio;
    return GestureDetector(
      onTap: () {
        if (ratio != _selectedAspectRatio) {
          setState(() => _selectedAspectRatio = ratio);
          _renderPreview();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              ratio.icon,
              size: 14,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              ratio.label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 10),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Export Palette Swatch Card',
                      style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Poppins'),
                    ),
                    Text(
                      widget.palette.title,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontFamily: 'Poppins'),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // 1:1 and 3:4 Aspect Ratio Selector Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text(
                  'RATIO:',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
                ),
                const SizedBox(width: 10),
                _buildRatioChip(PaletteExportAspectRatio.portrait3x4),
                const SizedBox(width: 8),
                _buildRatioChip(PaletteExportAspectRatio.square1x1),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Style Selector Horizontal Chips (Circular, Square Pantone, Columns, Rows, Photo Companion)
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: PaletteExportCardStyle.values.map((style) {
                // Skip photoCompanion if no image picked
                if (style == PaletteExportCardStyle.photoCompanion && widget.sourceImageFile == null) {
                  return const SizedBox.shrink();
                }

                final isSelected = style == _selectedStyle;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(style.icon, size: 14, color: isSelected ? Colors.white : AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Text(style.label),
                      ],
                    ),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val && style != _selectedStyle) {
                        setState(() => _selectedStyle = style);
                        _renderPreview();
                      }
                    },
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.background,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      fontFamily: 'Poppins',
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: isSelected ? AppColors.primary : AppColors.divider),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),

          // Background Theme Selector (Obsidian, White, Slate, Sand)
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: PaletteBackgroundTheme.values.map((theme) {
                final isSelected = theme == _selectedTheme;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      if (theme != _selectedTheme) {
                        setState(() => _selectedTheme = theme);
                        _renderPreview();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.backgroundColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : Colors.black12,
                          width: isSelected ? 2.5 : 1,
                        ),
                        boxShadow: isSelected
                            ? [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 4)]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: theme.primaryTextColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            theme.label,
                            style: TextStyle(
                              color: theme.primaryTextColor,
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),

          // Center Live Preview Canvas
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.divider),
              ),
              alignment: Alignment.center,
              child: _isRendering
                  ? const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary),
                        SizedBox(height: 14),
                        Text('Rendering Swatch Card...', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontFamily: 'Poppins')),
                      ],
                    )
                  : _previewBytes != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: AspectRatio(
                            aspectRatio: _selectedAspectRatio.ratio,
                            child: Image.memory(
                              _previewBytes!,
                              fit: BoxFit.contain,
                            ),
                          ),
                        )
                      : const Text('Failed to render preview', style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Poppins')),
            ),
          ),
          const SizedBox(height: 12),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    // Copy Codes Button
                    OutlinedButton.icon(
                      onPressed: _showCopyFormats,
                      icon: const Icon(Icons.code_rounded, size: 16),
                      label: const Text('Copy Codes', style: TextStyle(fontFamily: 'Poppins')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primaryLight),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Share Image Button
                    OutlinedButton.icon(
                      onPressed: _isRendering || _previewBytes == null ? null : _shareImage,
                      icon: const Icon(Icons.share_rounded, size: 16),
                      label: const Text('Share', style: TextStyle(fontFamily: 'Poppins')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.divider),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Primary Save to Gallery Button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isRendering || _isSaving || _previewBytes == null ? null : _saveToGallery,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.download_rounded, size: 18),
                        label: Text(
                          _savedPath != null ? 'Saved to Gallery' : 'Save to Gallery',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Poppins'),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
