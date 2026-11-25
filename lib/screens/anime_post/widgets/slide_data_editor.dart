import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../config/app_theme.dart';
import '../models/anime_carousel_slide.dart';
import '../models/anime_db_entry.dart';
import '../models/anime_image_asset.dart';
import '../models/anime_template_theme.dart';
import '../services/anime_asset_storage_service.dart';
import '../services/anime_database_service.dart';
import 'assets/anime_asset_library_sheet.dart';
import 'assets/anime_asset_upload_dialog.dart';

/// Contextual data editor form for the active slide.
/// Styled according to the Quick Post light theme.
/// Supports single image picking, bulk import, smart anime tag auto-matching,
/// and quick image swapping.
class SlideDataEditor extends StatefulWidget {
  final AnimeCarouselSlide slide;
  final int slideIndex;
  final List<AnimeCarouselSlide> allSlides;
  final AnimeTemplateTheme theme;
  final ValueChanged<AnimeCarouselSlide> onSlideChanged;
  final VoidCallback onBulkImportImages;
  final VoidCallback onRearrangeImages;
  final void Function(int targetSlideIndex) onSwapWithSlide;
  final VoidCallback? onOpenAiImportSheet;
  final VoidCallback? onAutoMatchAllSlides;

  const SlideDataEditor({
    super.key,
    required this.slide,
    required this.slideIndex,
    required this.allSlides,
    required this.theme,
    required this.onSlideChanged,
    required this.onBulkImportImages,
    required this.onRearrangeImages,
    required this.onSwapWithSlide,
    this.onOpenAiImportSheet,
    this.onAutoMatchAllSlides,
  });

  @override
  State<SlideDataEditor> createState() => _SlideDataEditorState();
}

class _SlideDataEditorState extends State<SlideDataEditor> {
  List<AnimeImageAsset> _matchingAssets = [];
  AnimeDbEntry? _dbMatch;

  @override
  void initState() {
    super.initState();
    _loadMatchingAssets();
  }

  @override
  void didUpdateWidget(covariant SlideDataEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.slide.id != oldWidget.slide.id ||
        widget.slide.animeName != oldWidget.slide.animeName ||
        widget.slide.imagePath != oldWidget.slide.imagePath) {
      _loadMatchingAssets();
    }
  }

  Future<void> _loadMatchingAssets() async {
    final title = widget.slide.type == SlideType.anime
        ? widget.slide.animeName.trim()
        : (widget.slide.type == SlideType.cover ? widget.slide.coverTitle.trim() : '');

    if (title.isEmpty) {
      if (mounted) {
        setState(() {
          _matchingAssets = [];
          _dbMatch = null;
        });
      }
      return;
    }

    try {
      final matches = await AnimeAssetStorageService.instance.findAssetsForAnime(title);
      final dbMatch = await AnimeDatabaseService.instance.findByName(title);
      if (mounted) {
        setState(() {
          _matchingAssets = matches;
          _dbMatch = dbMatch;
        });
      }
    } catch (_) {}
  }

  Future<void> _pickImage(BuildContext context) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 95,
      );
      if (picked != null) {
        widget.onSlideChanged(widget.slide.copyWith(imagePath: picked.path));
        _loadMatchingAssets();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  Future<void> _openAssetLibrary(BuildContext context) async {
    final suggestions = widget.allSlides
        .where((s) => s.type == SlideType.anime)
        .map((s) => s.animeName)
        .toList();

    final selectedPath = await AnimeAssetLibrarySheet.show(
      context,
      initialCategory: widget.slide.type == SlideType.anime ? widget.slide.animeName : null,
      suggestedAnimeNames: suggestions,
    );
    if (selectedPath != null && selectedPath.isNotEmpty) {
      widget.onSlideChanged(widget.slide.copyWith(imagePath: selectedPath));
      _loadMatchingAssets();
    }
  }

  Future<void> _saveToAssetStorage(BuildContext context) async {
    if (widget.slide.imagePath == null) return;
    final suggestions = widget.allSlides
        .where((s) => s.type == SlideType.anime)
        .map((s) => s.animeName)
        .toList();

    final imported = await AnimeAssetUploadDialog.show(
      context,
      initialCategory: widget.slide.type == SlideType.anime ? widget.slide.animeName : null,
      initialSourceFilePaths: [widget.slide.imagePath!],
      suggestedAnimeNames: suggestions,
    );
    if (imported != null && imported.isNotEmpty && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tagged & saved to "${imported.first.animeName}" in Asset Storage!'),
          backgroundColor: Colors.green.shade700,
        ),
      );
      _loadMatchingAssets();
    }
  }

  void _showSwapDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Swap Image With...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        children: widget.allSlides.asMap().entries.map((entry) {
          final idx = entry.key;
          final s = entry.value;
          final isCurrent = idx == widget.slideIndex;

          String title;
          if (s.type == SlideType.cover) {
            title = 'Slide ${idx + 1}: Cover';
          } else if (s.type == SlideType.cta) {
            title = 'Slide ${idx + 1}: CTA Outro';
          } else {
            title = 'Slide ${idx + 1}: #${s.rank} ${s.animeName}';
          }

          final hasImg = s.imagePath != null && File(s.imagePath!).existsSync();

          return SimpleDialogOption(
            onPressed: isCurrent
                ? null
                : () {
                    Navigator.pop(ctx);
                    widget.onSwapWithSlide(idx);
                  },
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: hasImg
                      ? Image.file(File(s.imagePath!), fit: BoxFit.cover)
                      : Icon(Icons.image_outlined, color: Colors.grey.shade400, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isCurrent ? Colors.grey : AppColors.textPrimary,
                      fontWeight: isCurrent ? FontWeight.normal : FontWeight.w600,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isCurrent)
                  const Text('(Current)', style: TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AI JSON Auto-Fill Banner
            if (widget.onOpenAiImportSheet != null) ...[
              InkWell(
                onTap: widget.onOpenAiImportSheet,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                        const Color(0xFF6366F1).withValues(alpha: 0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                          ),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: const Icon(Icons.auto_awesome, color: Colors.white, size: 14),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Auto-Fill Slides with AI / JSON',
                              style: TextStyle(
                                color: Color(0xFF4338CA),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Paste from ChatGPT / Gemini or load .json to populate all slides',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 10.5),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF6366F1)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Background Image Row & Quick Tools
            _buildImagePickerRow(context),

            // Smart Tag Matches Preview Strip
            if (_matchingAssets.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildMatchingAssetsStrip(),
            ],

            const SizedBox(height: 14),
            Divider(color: Colors.grey.shade200, height: 1),
            const SizedBox(height: 14),

            // Form Fields based on Slide Type
            if (widget.slide.type == SlideType.cover) ...[
              _buildCoverEditor(),
            ] else if (widget.slide.type == SlideType.anime) ...[
              _buildAnimeEditor(),
            ] else if (widget.slide.type == SlideType.cta) ...[
              _buildCtaEditor(),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchingAssetsStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 13, color: Color(0xFF8B5CF6)),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  '${_matchingAssets.length} tagged image${_matchingAssets.length == 1 ? '' : 's'} for "${widget.slide.animeName}"',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5B21B6),
                  ),
                ),
              ),
              InkWell(
                onTap: () {
                  widget.onSlideChanged(widget.slide.copyWith(imagePath: _matchingAssets.first.filePath));
                },
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Auto-Set',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _matchingAssets.map((asset) {
                final isApplied = widget.slide.imagePath == asset.filePath;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () {
                      widget.onSlideChanged(widget.slide.copyWith(imagePath: asset.filePath));
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isApplied ? const Color(0xFF8B5CF6) : Colors.grey.shade300,
                          width: isApplied ? 2.5 : 1.0,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(File(asset.filePath), fit: BoxFit.cover),
                          if (isApplied)
                            Positioned(
                              top: 2,
                              left: 2,
                              child: Container(
                                padding: const EdgeInsets.all(1.5),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF8B5CF6),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check, size: 10, color: Colors.white),
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
        ],
      ),
    );
  }

  Widget _buildImagePickerRow(BuildContext context) {
    final hasImage = widget.slide.imagePath != null && File(widget.slide.imagePath!).existsSync();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () => _openAssetLibrary(context),
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                clipBehavior: Clip.antiAlias,
                child: hasImage
                    ? Image.file(
                        File(widget.slide.imagePath!),
                        fit: BoxFit.cover,
                      )
                    : const Icon(
                        Icons.add_photo_alternate_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Slide Background Image',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasImage ? 'Custom image loaded' : 'Library or gallery',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
            if (hasImage) ...[
              IconButton(
                icon: const Icon(Icons.bookmark_add_outlined, color: AppColors.primary, size: 18),
                tooltip: 'Tag & Save to Asset Storage',
                onPressed: () => _saveToAssetStorage(context),
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                padding: EdgeInsets.zero,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                tooltip: 'Remove image',
                onPressed: () {
                  widget.onSlideChanged(widget.slide.copyWith(clearImagePath: true));
                  _loadMatchingAssets();
                },
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                padding: EdgeInsets.zero,
              ),
            ],
            const SizedBox(width: 2),
            ElevatedButton.icon(
              onPressed: () => _openAssetLibrary(context),
              icon: const Icon(Icons.collections_bookmark_rounded, size: 12),
              label: const Text('Assets', style: TextStyle(fontSize: 11)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Bulk Import, Rearrange, and Auto-Match Buttons
        Row(
          children: [
            // Gallery Pick Button
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(context),
                icon: const Icon(Icons.photo_library_outlined, size: 13),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    hasImage ? 'Change' : 'Gallery',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey.shade800,
                  side: BorderSide(color: Colors.grey.shade300),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(width: 6),

            // Bulk Import Button
            Expanded(
              child: OutlinedButton.icon(
                onPressed: widget.onBulkImportImages,
                icon: const Icon(Icons.collections_rounded, size: 13),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Bulk Import',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(width: 6),

            // Auto-Match from Tags Button
            if (widget.onAutoMatchAllSlides != null) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.onAutoMatchAllSlides,
                  icon: const Icon(Icons.auto_awesome, size: 13, color: Color(0xFF8B5CF6)),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Auto-Match',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6)),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF8B5CF6)),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],

            // Rearrange / Swap button
            IconButton.outlined(
              onPressed: widget.onRearrangeImages,
              icon: const Icon(Icons.swap_vert_rounded, size: 15, color: Colors.indigo),
              tooltip: 'Rearrange images',
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              style: IconButton.styleFrom(
                side: BorderSide(color: Colors.indigo.shade300),
                padding: const EdgeInsets.all(6),
                visualDensity: VisualDensity.compact,
              ),
            ),

            if (hasImage) ...[
              const SizedBox(width: 6),
              IconButton.outlined(
                onPressed: () => _showSwapDialog(context),
                icon: const Icon(Icons.sync_alt_rounded, size: 15, color: Colors.deepOrange),
                tooltip: 'Swap with another slide',
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                style: IconButton.styleFrom(
                  side: BorderSide(color: Colors.deepOrange.shade300),
                  padding: const EdgeInsets.all(6),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  // ==================== COVER EDITOR ====================
  Widget _buildCoverEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Cover Slide Content', Icons.movie_filter_rounded),
        const SizedBox(height: 10),
        _buildTextField(
          label: 'Hook / Badge Tag',
          hint: 'e.g. TOP PICKS, RECOMMENDATIONS',
          initialValue: widget.slide.coverTag,
          onChanged: (val) => widget.onSlideChanged(widget.slide.copyWith(coverTag: val)),
        ),
        const SizedBox(height: 10),
        _buildTextField(
          label: 'Cover Title',
          hint: 'e.g. TOP 5 ACTION ANIME OF ALL TIME',
          initialValue: widget.slide.coverTitle,
          maxLines: 2,
          onChanged: (val) {
            widget.onSlideChanged(widget.slide.copyWith(coverTitle: val));
            _loadMatchingAssets();
          },
        ),
        const SizedBox(height: 10),
        _buildTextField(
          label: 'Subtitle / Description',
          hint: 'e.g. Masterpiece series you must watch',
          initialValue: widget.slide.coverSubtitle,
          maxLines: 2,
          onChanged: (val) => widget.onSlideChanged(widget.slide.copyWith(coverSubtitle: val)),
        ),
      ],
    );
  }

  // ==================== ANIME VARIABLE EDITOR ====================
  Widget _buildAnimeEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader('Anime Slide Variables', Icons.tv_rounded),
            if (widget.slide.animeName.trim().isNotEmpty)
              TextButton.icon(
                onPressed: () async {
                  final e = AnimeDbEntry(
                    id: 'db_${DateTime.now().microsecondsSinceEpoch}',
                    name: widget.slide.animeName.trim(),
                    japaneseName: widget.slide.japaneseName,
                    rating: widget.slide.rating,
                    seasons: widget.slide.seasons,
                    episodes: widget.slide.episodes,
                    studio: widget.slide.studio,
                    genres: widget.slide.genres,
                    synopsis: widget.slide.synopsis,
                    verified: true,
                    updatedAt: DateTime.now(),
                  );
                  await AnimeDatabaseService.instance.upsert(e);
                  _loadMatchingAssets();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Saved "${widget.slide.animeName}" to Anime Database!'),
                        backgroundColor: Colors.green.shade700,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.bookmark_add_outlined, size: 13, color: Colors.indigo),
                label: const Text('Save to DB', style: TextStyle(fontSize: 11, color: Colors.indigo)),
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 4)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            SizedBox(
              width: 70,
              child: _buildTextField(
                label: 'Rank',
                hint: '1',
                initialValue: widget.slide.rank.toString(),
                keyboardType: TextInputType.number,
                onChanged: (val) {
                  final parsed = int.tryParse(val) ?? widget.slide.rank;
                  widget.onSlideChanged(widget.slide.copyWith(rank: parsed));
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildTextField(
                label: 'Anime Name',
                hint: 'e.g. Series Title',
                initialValue: widget.slide.animeName,
                onChanged: (val) {
                  widget.onSlideChanged(widget.slide.copyWith(animeName: val));
                  _loadMatchingAssets();
                },
              ),
            ),
          ],
        ),
        if (_dbMatch != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.indigo.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.storage_rounded, size: 14, color: Colors.indigo),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'DB: ${_dbMatch!.name}${_dbMatch!.rating.isNotEmpty ? ' · ★ ${_dbMatch!.rating}' : ''}${_dbMatch!.characters.isNotEmpty ? ' · 👥 ${_dbMatch!.characters}' : (_dbMatch!.studio.isNotEmpty ? ' · ${_dbMatch!.studio}' : '')}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.indigo),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () {
                    widget.onSlideChanged(widget.slide.copyWith(
                      animeName: _dbMatch!.name,
                      japaneseName: _dbMatch!.japaneseName.isNotEmpty ? _dbMatch!.japaneseName : widget.slide.japaneseName,
                      rating: _dbMatch!.rating.isNotEmpty ? _dbMatch!.rating : widget.slide.rating,
                      seasons: _dbMatch!.seasons.isNotEmpty ? _dbMatch!.seasons : widget.slide.seasons,
                      episodes: _dbMatch!.episodes.isNotEmpty ? _dbMatch!.episodes : widget.slide.episodes,
                      studio: _dbMatch!.studio.isNotEmpty ? _dbMatch!.studio : widget.slide.studio,
                      genres: _dbMatch!.genres.isNotEmpty ? _dbMatch!.genres : widget.slide.genres,
                      synopsis: _dbMatch!.synopsis.isNotEmpty ? _dbMatch!.synopsis : widget.slide.synopsis,
                    ));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Auto-filled details for "${_dbMatch!.name}" from Database!'),
                        duration: const Duration(seconds: 2),
                        backgroundColor: Colors.indigo,
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.indigo,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('Fill Data', style: TextStyle(fontSize: 10.5, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        _buildTextField(
          label: 'Japanese / Alt Name',
          hint: 'e.g. Kimetsu no Yaiba',
          initialValue: widget.slide.japaneseName,
          onChanged: (val) => widget.onSlideChanged(widget.slide.copyWith(japaneseName: val)),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                label: 'Rating',
                hint: 'e.g. 8.9 / 10',
                initialValue: widget.slide.rating,
                onChanged: (val) => widget.onSlideChanged(widget.slide.copyWith(rating: val)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildTextField(
                label: 'Seasons',
                hint: 'e.g. 4 Seasons',
                initialValue: widget.slide.seasons,
                onChanged: (val) => widget.onSlideChanged(widget.slide.copyWith(seasons: val)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                label: 'Episodes',
                hint: 'e.g. 55 Episodes',
                initialValue: widget.slide.episodes,
                onChanged: (val) => widget.onSlideChanged(widget.slide.copyWith(episodes: val)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildTextField(
                label: 'Studio',
                hint: 'e.g. ufotable, MAPPA',
                initialValue: widget.slide.studio,
                onChanged: (val) => widget.onSlideChanged(widget.slide.copyWith(studio: val)),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),
        _buildTextField(
          label: 'Genres (comma-separated)',
          hint: 'e.g. Action, Dark Fantasy, Shounen',
          initialValue: widget.slide.genres,
          onChanged: (val) {
            widget.onSlideChanged(widget.slide.copyWith(genres: val));
          },
        ),
        const SizedBox(height: 10),
        _buildTextField(
          label: 'Synopsis / Review Hook',
          hint: 'Short synopsis or recommendation commentary...',
          initialValue: widget.slide.synopsis,
          maxLines: 2,
          onChanged: (val) => widget.onSlideChanged(widget.slide.copyWith(synopsis: val)),
        ),
      ],
    );
  }

  // ==================== CTA EDITOR ====================
  Widget _buildCtaEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Outro / CTA Content', Icons.chat_bubble_outline_rounded),
        const SizedBox(height: 10),
        _buildTextField(
          label: 'Call to Action Headline',
          hint: 'e.g. Which one is your favorite?',
          initialValue: widget.slide.ctaHeadline,
          maxLines: 2,
          onChanged: (val) => widget.onSlideChanged(widget.slide.copyWith(ctaHeadline: val)),
        ),
        const SizedBox(height: 10),
        _buildTextField(
          label: 'Subheadline / Question',
          hint: 'e.g. Drop your top pick in comments!',
          initialValue: widget.slide.ctaSubheadline,
          maxLines: 2,
          onChanged: (val) => widget.onSlideChanged(widget.slide.copyWith(ctaSubheadline: val)),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 16),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required String initialValue,
    required ValueChanged<String> onChanged,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      key: ValueKey('${widget.slide.id}_$label'),
      initialValue: initialValue,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}
