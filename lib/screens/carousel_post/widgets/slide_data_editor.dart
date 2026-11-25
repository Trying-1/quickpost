import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../config/app_theme.dart';
import '../models/carousel_slide.dart';
import '../models/carousel_template_theme.dart';
import 'assets/carousel_asset_library_sheet.dart';
import 'assets/carousel_asset_upload_dialog.dart';

/// Contextual data editor form for the active slide.
/// Styled according to the Quick Post light theme.
class SlideDataEditor extends StatelessWidget {
  final CarouselSlide slide;
  final int slideIndex;
  final List<CarouselSlide> allSlides;
  final CarouselTemplateTheme theme;
  final ValueChanged<CarouselSlide> onSlideChanged;
  final VoidCallback onBulkImportImages;
  final VoidCallback onRearrangeImages;
  final void Function(int targetSlideIndex) onSwapWithSlide;
  final VoidCallback? onOpenAiImportSheet;

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
  });

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
        onSlideChanged(slide.copyWith(imagePath: picked.path));
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
    final selectedPath = await CarouselAssetLibrarySheet.show(context);
    if (selectedPath != null && selectedPath.isNotEmpty) {
      onSlideChanged(slide.copyWith(imagePath: selectedPath));
    }
  }

  void _showSwapDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Swap Image With...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        children: allSlides.asMap().entries.map((entry) {
          final idx = entry.key;
          final s = entry.value;
          final isCurrent = idx == slideIndex;

          String title;
          if (s.type == SlideType.cover) {
            title = 'Slide ${idx + 1}: Cover';
          } else if (s.type == SlideType.cta) {
            title = 'Slide ${idx + 1}: CTA Outro';
          } else {
            title = 'Slide ${idx + 1}: ${s.title.isNotEmpty ? s.title : "Content"}';
          }

          final hasImg = s.imagePath != null && File(s.imagePath!).existsSync();

          return ListTile(
            enabled: !isCurrent,
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: hasImg
                  ? Image.file(File(s.imagePath!), width: 36, height: 36, fit: BoxFit.cover)
                  : Container(width: 36, height: 36, color: Colors.grey.shade200),
            ),
            title: Text(title, style: TextStyle(fontSize: 13, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
            subtitle: isCurrent ? const Text('Current slide', style: TextStyle(fontSize: 11, color: AppColors.primary)) : null,
            onTap: () {
              Navigator.pop(ctx);
              onSwapWithSlide(idx);
            },
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top quick-actions row: Image actions, bulk import, rearrange, AI import
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _pickImage(context),
                        icon: const Icon(Icons.photo_library_rounded, size: 14),
                        label: const Text('Pick Image', style: TextStyle(fontSize: 11)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton.icon(
                        onPressed: () => _openAssetLibrary(context),
                        icon: const Icon(Icons.collections_bookmark_rounded, size: 14),
                        label: const Text('Library', style: TextStyle(fontSize: 11)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton.icon(
                        onPressed: onBulkImportImages,
                        icon: const Icon(Icons.upload_file_rounded, size: 14),
                        label: const Text('Bulk Import', style: TextStyle(fontSize: 11)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton.icon(
                        onPressed: onRearrangeImages,
                        icon: const Icon(Icons.swap_vert_rounded, size: 14),
                        label: const Text('Rearrange', style: TextStyle(fontSize: 11)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton.icon(
                        onPressed: () => _showSwapDialog(context),
                        icon: const Icon(Icons.swap_horiz_rounded, size: 14),
                        label: const Text('Swap', style: TextStyle(fontSize: 11)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (onOpenAiImportSheet != null) ...[
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'AI JSON Importer',
                  icon: const Icon(Icons.auto_awesome, color: Colors.purple, size: 20),
                  onPressed: onOpenAiImportSheet,
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Contextual Slide Form
          if (slide.type == SlideType.cover)
            _buildCoverSlideEditor()
          else if (slide.type == SlideType.cta)
            _buildCtaSlideEditor()
          else
            _buildContentSlideEditor(),
        ],
      ),
    );
  }

  // 1. Cover Slide Editor
  Widget _buildCoverSlideEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          label: 'Cover Title',
          value: slide.coverTitle,
          hint: 'e.g. 5 MINDSET SHIFTS FOR SUCCESS',
          maxLines: 2,
          onChanged: (val) => onSlideChanged(slide.copyWith(coverTitle: val)),
        ),
        const SizedBox(height: 10),
        _buildTextField(
          label: 'Cover Subtitle',
          value: slide.coverSubtitle,
          hint: 'e.g. Timeless principles to master your focus & emotional strength.',
          maxLines: 2,
          onChanged: (val) => onSlideChanged(slide.copyWith(coverSubtitle: val)),
        ),
      ],
    );
  }

  // 2. CTA Slide Editor
  Widget _buildCtaSlideEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          label: 'CTA Headline',
          value: slide.ctaHeadline,
          hint: 'e.g. Which mindset shift resonated most?',
          maxLines: 2,
          onChanged: (val) => onSlideChanged(slide.copyWith(ctaHeadline: val)),
        ),
        const SizedBox(height: 10),
        _buildTextField(
          label: 'CTA Subheadline',
          value: slide.ctaSubheadline,
          hint: 'e.g. Save this post for later & share your top takeaway in the comments below!',
          maxLines: 2,
          onChanged: (val) => onSlideChanged(slide.copyWith(ctaSubheadline: val)),
        ),
        const SizedBox(height: 10),
        _buildTextField(
          label: 'CTA Tag / Button Label',
          value: slide.ctaTag,
          hint: 'e.g. SAVE & SHARE',
          onChanged: (val) => onSlideChanged(slide.copyWith(ctaTag: val)),
        ),
      ],
    );
  }

  // 3. Content Slide Editor (Quote, Guide, Tip)
  Widget _buildContentSlideEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          label: 'Headline / Core Principle',
          value: slide.title,
          hint: 'e.g. Focus on what you can control',
          onChanged: (val) => onSlideChanged(slide.copyWith(title: val)),
        ),
        const SizedBox(height: 10),
        _buildTextField(
          label: 'Body Text / Quote / Explanation',
          value: slide.bodyText,
          hint: 'e.g. You have power over your mind - not outside events. Realize this, and you will find immense strength.',
          maxLines: 5,
          onChanged: (val) => onSlideChanged(slide.copyWith(bodyText: val)),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required String value,
    required String hint,
    required ValueChanged<String> onChanged,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
        ),
        const SizedBox(height: 4),
        TextFormField(
          initialValue: value,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 12),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 11, color: Colors.grey.shade400),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

