import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../utils/font_selector.dart';
import '../../../../widgets/base_template_widget.dart';

/// Supported aspect ratio options for Textbox Image posts.
const List<Map<String, Object>> textboxImageAspectOptions = [
  {'label': '4:5', 'index': 0},
  {'label': '1:1', 'index': 1},
  {'label': '9:16', 'index': 2},
  {'label': '16:9', 'index': 3},
];

/// Returns numeric aspect ratio for a preset [index].
double textboxImageAspectRatio(int index) {
  switch (index) {
    case 1:
      return 1 / 1;
    case 2:
      return 9 / 16;
    case 3:
      return 16 / 9;
    case 0:
    default:
      return 4 / 5;
  }
}

/// Preview canvas + aspect ratio selector + empty-state image pick CTA.
class TextboxImagePreviewArea extends StatelessWidget {
  final int selectedAspectIndex;
  final ValueChanged<int> onAspectChanged;
  final GlobalKey previewTemplateKey;
  final TemplateViewController templateController;
  final TextEditingController textController;
  final File? singleImage;
  final List<File?> gridImages;
  final bool isGridMode;
  final bool hasImages;
  final String emptyCtaLabel;
  final VoidCallback onEmptyPickPressed;
  final FontInfo? selectedFont;
  final Color textColor;
  final Color textBoxColor;
  final bool enableTextShadow;
  final bool enableTextGlow;
  final Color shadowColor;
  final double shadowOffsetX;
  final double shadowOffsetY;
  final double shadowBlurRadius;
  final Color glowColor;
  final double glowRadius;
  final double letterSpacing;
  final double fontSize;
  final bool showPlaceholder;
  final VoidCallback onTextChanged;
  final VoidCallback onImageLoaded;

  const TextboxImagePreviewArea({
    super.key,
    required this.selectedAspectIndex,
    required this.onAspectChanged,
    required this.previewTemplateKey,
    required this.templateController,
    required this.textController,
    required this.singleImage,
    required this.gridImages,
    required this.isGridMode,
    required this.hasImages,
    required this.emptyCtaLabel,
    required this.onEmptyPickPressed,
    required this.selectedFont,
    required this.textColor,
    required this.textBoxColor,
    required this.enableTextShadow,
    required this.enableTextGlow,
    required this.shadowColor,
    required this.shadowOffsetX,
    required this.shadowOffsetY,
    required this.shadowBlurRadius,
    required this.glowColor,
    required this.glowRadius,
    required this.letterSpacing,
    required this.fontSize,
    required this.showPlaceholder,
    required this.onTextChanged,
    required this.onImageLoaded,
  });

  @override
  Widget build(BuildContext context) {
    final aspect = textboxImageAspectRatio(selectedAspectIndex);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              const Text(
                'Size',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: textboxImageAspectOptions.map((opt) {
                      final idx = opt['index']! as int;
                      final isSelected = selectedAspectIndex == idx;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: GestureDetector(
                          onTap: () => onAspectChanged(idx),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isSelected ? Colors.black87 : Colors.grey[100],
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.black87
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Text(
                              opt['label']! as String,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color:
                                    isSelected ? Colors.white : Colors.grey[800],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: LayoutBuilder(
                  builder: (_, constraints) {
                    final double previewWidth =
                        constraints.maxWidth.clamp(180.0, 600.0);
                    final double previewHeight = previewWidth / aspect;

                    return Center(
                      child: SizedBox(
                        width: previewWidth,
                        height: previewHeight,
                        child: Stack(
                          children: [
                            SocialPostTemplate(
                              key: previewTemplateKey,
                              text: textController.text,
                              image: singleImage,
                              gridImages: gridImages,
                              isGridMode: isGridMode,
                              width: previewWidth,
                              height: previewHeight,
                              isPreview: true,
                              controller: templateController,
                              selectedFont: selectedFont,
                              textColor: textColor,
                              textBoxColor: textBoxColor,
                              enableTextShadow: enableTextShadow,
                              enableTextGlow: enableTextGlow,
                              shadowColor: shadowColor,
                              shadowOffsetX: shadowOffsetX,
                              shadowOffsetY: shadowOffsetY,
                              shadowBlurRadius: shadowBlurRadius,
                              glowColor: glowColor,
                              glowRadius: glowRadius,
                              letterSpacing: letterSpacing,
                              fontSizeMultiplier: fontSize,
                              textController: textController,
                              showPlaceholder: showPlaceholder,
                              onTextChanged: (_) => onTextChanged(),
                              onImageLoaded: onImageLoaded,
                            ),
                            if (!hasImages)
                              Positioned.fill(
                                child: Center(
                                  child: ElevatedButton.icon(
                                    onPressed: onEmptyPickPressed,
                                    icon: const Icon(Icons.add_photo_alternate),
                                    label: Text(emptyCtaLabel),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.purple,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

