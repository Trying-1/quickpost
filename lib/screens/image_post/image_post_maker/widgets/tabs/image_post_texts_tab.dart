import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../config/app_theme.dart';
import '../../../../../utils/font_selector.dart';
import '../../models/image_post_overlays.dart';
import '../image_post_shared_controls.dart';

/// Text Overlays tab panel (index 8): manages adding/importing text layers,
/// Split-to-Words, Classic revert, single/multi-word selection, typography, alignment, and shadows.
class ImagePostTextsTab extends StatefulWidget {
  final List<ImagePostTextOverlay> textOverlays;
  final int? selectedTextOverlayIndex;
  final Set<int> selectedTextOverlayIndices;
  final bool multiSelectMode;
  final bool fullScreen;
  final double imageAspectRatio;
  final double videoX;
  final double videoY;
  final double videoScale;

  final ValueChanged<int?> onSelectedIndexChanged;
  final ValueChanged<Set<int>> onSelectedIndicesChanged;
  final ValueChanged<bool> onMultiSelectChanged;
  final VoidCallback onImportFromMyQuotes;
  final ValueChanged<String> onShowToast;
  final VoidCallback onStateChanged;

  const ImagePostTextsTab({
    super.key,
    required this.textOverlays,
    required this.selectedTextOverlayIndex,
    required this.selectedTextOverlayIndices,
    required this.multiSelectMode,
    required this.fullScreen,
    required this.imageAspectRatio,
    required this.videoX,
    required this.videoY,
    required this.videoScale,
    required this.onSelectedIndexChanged,
    required this.onSelectedIndicesChanged,
    required this.onMultiSelectChanged,
    required this.onImportFromMyQuotes,
    required this.onShowToast,
    required this.onStateChanged,
  });

  @override
  State<ImagePostTextsTab> createState() => _ImagePostTextsTabState();
}

class _ImagePostTextsTabState extends State<ImagePostTextsTab> {
  final TextEditingController _overlayTextController = TextEditingController();
  int? _lastSelectedOverlayIndex;

  @override
  void dispose() {
    _overlayTextController.dispose();
    super.dispose();
  }

  double _calculateFirstTextAboveVideoY() {
    final double canvasAspect =
        widget.fullScreen ? (9.0 / 16.0) : widget.imageAspectRatio;
    final double normScaledH = widget.imageAspectRatio >= canvasAspect
        ? (canvasAspect / widget.imageAspectRatio) * widget.videoScale
        : widget.videoScale;
    final double videoTopEdge = widget.videoY * (1.0 - normScaledH);
    const double gapAndHalfHeight = 0.045;
    final double targetY = videoTopEdge - gapAndHalfHeight;

    if (targetY >= 0.05) {
      return targetY;
    } else if (videoTopEdge >= 0.06) {
      return 0.05;
    } else {
      return 0.12;
    }
  }

  void _updateSelectedTextOverlays(
    void Function(ImagePostTextOverlay overlay) updater,
  ) {
    for (final idx in widget.selectedTextOverlayIndices) {
      if (idx < widget.textOverlays.length) {
        updater(widget.textOverlays[idx]);
      }
    }
    widget.onStateChanged();
  }

  void _splitTextOverlayIntoWords(ImagePostTextOverlay t, int index) {
    final String textToSplit =
        t.isSplitWord ? (t.originalFullText ?? t.text) : t.text;
    if (textToSplit.trim().isEmpty) return;

    final String gid =
        t.groupId ?? 'split_grp_${DateTime.now().millisecondsSinceEpoch}';

    final double outAspect = widget.fullScreen ? 9 / 16 : widget.imageAspectRatio;
    const double refWidth = 1080.0;
    final double refHeight = 1080.0 / outAspect;

    final double maxTextWidth = refWidth * 0.92 * t.scale;

    final TextStyle style = TextStyle(
      fontSize: t.fontSize * t.scale,
      fontFamily: t.font?.family,
      height: t.lineHeight,
      letterSpacing: t.letterSpacing,
      wordSpacing: t.wordSpacing,
    );

    final fullPainter = TextPainter(
      text: TextSpan(text: textToSplit, style: style),
      textDirection: ui.TextDirection.ltr,
      textAlign: t.textAlign,
    )..layout(maxWidth: maxTextWidth.clamp(0.0, double.infinity));

    final double fullTextWidth = fullPainter.width;
    final double fullTextHeight = fullPainter.height;

    double centerX = t.x * refWidth;
    double centerY = t.y * refHeight;
    if (t.isSplitWord) {
      final groupOverlays =
          widget.textOverlays.where((x) => x.groupId == gid).toList();
      if (groupOverlays.isNotEmpty) {
        double sumX = 0;
        double sumY = 0;
        for (final x in groupOverlays) {
          sumX += x.x;
          sumY += x.y;
        }
        centerX = (sumX / groupOverlays.length) * refWidth;
        centerY = (sumY / groupOverlays.length) * refHeight;
      }
    }

    final double blockLeft = centerX - fullTextWidth / 2;
    final double blockTop = centerY - fullTextHeight / 2;

    final wordRegex = RegExp(r'\S+');
    final matches = wordRegex.allMatches(textToSplit).toList();

    final List<ImagePostTextOverlay> splitOverlays = [];

    for (int i = 0; i < matches.length; i++) {
      final match = matches[i];
      final String wordStr = match.group(0)!;
      final range =
          TextSelection(baseOffset: match.start, extentOffset: match.end);
      final boxes = fullPainter.getBoxesForSelection(range);

      if (boxes.isEmpty) continue;

      final box = boxes.first;
      final double wordLeft = blockLeft + box.left;
      final double wordTop = blockTop + box.top;
      final double wordW = box.right - box.left;
      final double wordH = box.bottom - box.top;

      final double newX = ((wordLeft + wordW / 2) / refWidth).clamp(0.0, 1.0);
      final double newY = ((wordTop + wordH / 2) / refHeight).clamp(0.0, 1.0);

      String wordColor = t.color;
      FontInfo? wordFont = t.font;
      if (t.styleSegments != null && i < t.styleSegments!.length) {
        wordColor = t.styleSegments![i].color;
        wordFont = t.styleSegments![i].font ?? t.font;
      }

      splitOverlays.add(
        ImagePostTextOverlay(
          text: wordStr,
          x: newX,
          y: newY,
          fontSize: t.fontSize,
          color: wordColor,
          font: wordFont,
          showShadow: t.showShadow,
          shadowColor: t.shadowColor,
          shadowBlur: t.shadowBlur,
          shadowOffsetX: t.shadowOffsetX,
          shadowOffsetY: t.shadowOffsetY,
          textAlign: TextAlign.center,
          scale: t.scale,
          lineHeight: t.lineHeight,
          letterSpacing: t.letterSpacing,
          wordSpacing: t.wordSpacing,
          opacity: t.opacity,
          isSplitWord: true,
          groupId: gid,
          originalFullText: textToSplit,
          isLocked: true,
        ),
      );
    }

    if (splitOverlays.isEmpty) return;

    final nextIndices = <int>{};
    int targetIdx;
    if (t.isSplitWord) {
      int insertIndex = widget.textOverlays.indexWhere((x) => x.groupId == gid);
      if (insertIndex == -1) insertIndex = index;
      widget.textOverlays.removeWhere((x) => x.groupId == gid);
      widget.textOverlays.insertAll(insertIndex, splitOverlays);
      for (int idx = 0; idx < widget.textOverlays.length; idx++) {
        if (widget.textOverlays[idx].groupId == gid) {
          nextIndices.add(idx);
        }
      }
      targetIdx = insertIndex;
    } else {
      widget.textOverlays.removeAt(index);
      widget.textOverlays.insertAll(index, splitOverlays);
      for (int idx = index; idx < index + splitOverlays.length; idx++) {
        nextIndices.add(idx);
      }
      targetIdx = index;
    }
    widget.onSelectedIndicesChanged(nextIndices);
    widget.onSelectedIndexChanged(targetIdx);
    widget.onStateChanged();
  }

  void _revertSplitToClassic(
    ImagePostTextOverlay t,
    int index, {
    required bool preserveStyle,
  }) {
    final String? gid = t.groupId;
    if (gid == null) return;

    final groupOverlays =
        widget.textOverlays.where((x) => x.groupId == gid).toList();
    if (groupOverlays.isEmpty) return;

    double sumX = 0;
    double sumY = 0;
    for (final x in groupOverlays) {
      sumX += x.x;
      sumY += x.y;
    }
    final double avgX = sumX / groupOverlays.length;
    final double avgY = sumY / groupOverlays.length;
    final ImagePostTextOverlay first = groupOverlays.first;

    List<TextSegment>? segments;
    if (preserveStyle) {
      segments = groupOverlays
          .map(
            (x) => TextSegment(text: x.text, color: x.color, font: x.font),
          )
          .toList();
    }

    final classicOverlay = ImagePostTextOverlay(
      text: t.originalFullText ?? groupOverlays.map((x) => x.text).join(' '),
      x: avgX,
      y: avgY,
      fontSize: first.fontSize,
      color: first.color,
      font: first.font,
      showShadow: first.showShadow,
      shadowColor: first.shadowColor,
      shadowBlur: first.shadowBlur,
      shadowOffsetX: first.shadowOffsetX,
      shadowOffsetY: first.shadowOffsetY,
      textAlign: first.textAlign,
      scale: first.scale,
      lineHeight: first.lineHeight,
      letterSpacing: first.letterSpacing,
      wordSpacing: first.wordSpacing,
      opacity: first.opacity,
      isSplitWord: false,
      styleSegments: segments,
    );

    int insertIndex = widget.textOverlays.indexWhere((x) => x.groupId == gid);
    if (insertIndex == -1) insertIndex = index;
    widget.textOverlays.removeWhere((x) => x.groupId == gid);
    widget.textOverlays.insert(insertIndex, classicOverlay);
    widget.onSelectedIndicesChanged({insertIndex});
    widget.onSelectedIndexChanged(insertIndex);
    widget.onStateChanged();
  }

  void _showRevertToClassicDialog(ImagePostTextOverlay t, int index) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Revert to Classic'),
        content: const Text(
          'Do you want to preserve the separate colors and fonts of each word as a styled block, or reset them to use a single style?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _revertSplitToClassic(t, index, preserveStyle: false);
            },
            child: const Text('Reset Style'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _revertSplitToClassic(t, index, preserveStyle: true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Preserve Style'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Text Overlays',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    final double defaultY;
                    if (widget.textOverlays.isEmpty) {
                      defaultY = _calculateFirstTextAboveVideoY();
                    } else if (widget.textOverlays.last.y >= 0.12) {
                      defaultY =
                          (widget.textOverlays.last.y - 0.06).clamp(0.05, 0.94);
                    } else {
                      defaultY =
                          (widget.textOverlays.last.y + 0.06).clamp(0.05, 0.94);
                    }
                    widget.textOverlays.add(
                      ImagePostTextOverlay(
                        text: 'New Text',
                        x: widget.videoX,
                        y: defaultY,
                        fontSize: 30.0,
                        font: const FontInfo(
                          family: 'KleeOne',
                          displayName: 'Klee One SemiBold',
                          weight: FontWeight.w600,
                          assetPath: 'assets/fonts/KleeOne-SemiBold.ttf',
                        ),
                      ),
                    );
                    widget.onSelectedIndexChanged(widget.textOverlays.length - 1);
                    widget.onStateChanged();
                  },
                  icon: const Icon(Icons.add_comment, size: 16),
                  label: const Text('Add Text', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    elevation: 0,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: widget.onImportFromMyQuotes,
                  icon: const Icon(Icons.format_quote, size: 16),
                  label:
                      const Text('Import Quote', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (widget.textOverlays.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'No text overlays added. Use them to place generic text anywhere.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        if (widget.textOverlays.isNotEmpty) ...[
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: widget.textOverlays.length,
              itemBuilder: (context, idx) {
                final isSelected = widget.selectedTextOverlayIndex == idx;
                return GestureDetector(
                  onTap: () => widget.onSelectedIndexChanged(idx),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Text #${idx + 1}',
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (widget.selectedTextOverlayIndex != null &&
            widget.selectedTextOverlayIndex! >= 0 &&
            widget.selectedTextOverlayIndex! < widget.textOverlays.length)
          _buildActiveTextOverlayControls(
            widget.textOverlays[widget.selectedTextOverlayIndex!],
            widget.selectedTextOverlayIndex!,
          )
        else if (widget.textOverlays.isNotEmpty)
          const Text(
            'Select a text overlay on preview to edit',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
      ],
    );
  }

  Widget _buildActiveTextOverlayControls(ImagePostTextOverlay t, int index) {
    if (_lastSelectedOverlayIndex != index ||
        _overlayTextController.text != t.text) {
      _lastSelectedOverlayIndex = index;
      _overlayTextController.text = t.text;
    }
    final allFonts = getAllFonts();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Text #${index + 1}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(
                      Icons.format_quote,
                      size: 20,
                      color: Colors.teal,
                    ),
                    tooltip: 'Import Quote',
                    onPressed: widget.onImportFromMyQuotes,
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(
                      Icons.copy,
                      size: 20,
                      color: Colors.blueGrey,
                    ),
                    tooltip: 'Copy Text',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: t.text));
                      widget.onShowToast('Text copied to clipboard');
                    },
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(
                      Icons.clear,
                      size: 20,
                      color: Colors.orange,
                    ),
                    tooltip: 'Clear Text',
                    onPressed: () {
                      t.text = '';
                      widget.onStateChanged();
                    },
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      widget.textOverlays.removeAt(index);
                      widget.onSelectedIndicesChanged({});
                      widget.onSelectedIndexChanged(null);
                      widget.onStateChanged();
                    },
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                      size: 20,
                    ),
                    tooltip: 'Delete',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            key: ValueKey('text_field_$index'),
            controller: _overlayTextController,
            maxLines: null,
            onChanged: (v) {
              t.text = v;
              widget.onStateChanged();
            },
            decoration: InputDecoration(
              labelText: t.isSplitWord ? 'Word Text' : 'Text Content',
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          if (t.isSplitWord && t.originalFullText != null) ...[
            const SizedBox(height: 8),
            TextFormField(
              key: ValueKey('orig_text_field_$index'),
              initialValue: t.originalFullText,
              maxLines: null,
              onChanged: (v) {
                final gid = t.groupId;
                if (gid != null) {
                  for (final x in widget.textOverlays) {
                    if (x.groupId == gid) {
                      x.originalFullText = v;
                    }
                  }
                  widget.onStateChanged();
                }
              },
              decoration: const InputDecoration(
                labelText: 'Original Full Text',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: t.text.trim().isEmpty &&
                          (t.originalFullText?.trim().isEmpty ?? true)
                      ? null
                      : () => _splitTextOverlayIntoWords(t, index),
                  icon: const Icon(Icons.space_bar, size: 18),
                  label: Text(
                    t.isSplitWord ? 'Re-split Words' : 'Split to Words',
                    style: const TextStyle(fontSize: 11),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF6C63FF).withValues(alpha: 0.1),
                    foregroundColor: const Color(0xFF6C63FF),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (t.isSplitWord) ...[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showRevertToClassicDialog(t, index),
                    icon: const Icon(Icons.undo, size: 16),
                    label: const Text('Classic', style: TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.withValues(alpha: 0.1),
                      foregroundColor: Colors.orange,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Container(
                decoration: BoxDecoration(
                  color: t.isLocked
                      ? Colors.orange.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: Icon(
                    t.isLocked ? Icons.lock : Icons.lock_open,
                    color: t.isLocked ? Colors.orange : Colors.grey,
                    size: 20,
                  ),
                  onPressed: () => _updateSelectedTextOverlays(
                    (o) => o.isLocked = !o.isLocked,
                  ),
                  tooltip: t.isLocked ? 'Unlock Position' : 'Lock Position',
                ),
              ),
            ],
          ),
          if (t.isSplitWord) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Multi-Select',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: widget.multiSelectMode,
                      onChanged: widget.onMultiSelectChanged,
                      activeThumbColor: const Color(0xFF6C63FF),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () {
                        final gid = t.groupId;
                        if (gid != null) {
                          final next = <int>{};
                          for (int idx = 0;
                              idx < widget.textOverlays.length;
                              idx++) {
                            if (widget.textOverlays[idx].groupId == gid) {
                              next.add(idx);
                            }
                          }
                          widget.onSelectedIndicesChanged(next);
                        }
                      },
                      child: const Text('All', style: TextStyle(fontSize: 11)),
                    ),
                    TextButton(
                      onPressed: () {
                        final next = <int>{};
                        if (widget.selectedTextOverlayIndex != null) {
                          next.add(widget.selectedTextOverlayIndex!);
                        }
                        widget.onSelectedIndicesChanged(next);
                      },
                      child: const Text(
                        'Clear',
                        style: TextStyle(fontSize: 11, color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 38,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: widget.textOverlays.length,
                itemBuilder: (context, idx) {
                  final item = widget.textOverlays[idx];
                  if (item.groupId != t.groupId) return const SizedBox.shrink();
                  final bool isSel =
                      widget.selectedTextOverlayIndices.contains(idx);
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(
                        item.text,
                        style: TextStyle(
                          color: isSel ? Colors.white : Colors.black87,
                        ),
                      ),
                      selected: isSel,
                      selectedColor: const Color(0xFF6C63FF),
                      backgroundColor: Colors.grey[100],
                      onSelected: (selected) {
                        final next =
                            Set<int>.from(widget.selectedTextOverlayIndices);
                        int? nextMain = widget.selectedTextOverlayIndex;
                        if (widget.multiSelectMode) {
                          if (selected) {
                            next.add(idx);
                            nextMain = idx;
                          } else if (next.length > 1) {
                            next.remove(idx);
                            if (nextMain == idx) {
                              nextMain = next.first;
                            }
                          }
                        } else {
                          next
                            ..clear()
                            ..add(idx);
                          nextMain = idx;
                        }
                        widget.onSelectedIndicesChanged(next);
                        widget.onSelectedIndexChanged(nextMain);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 16),
          ImagePostControlSlider(
            label: 'Font Size',
            value: t.fontSize,
            min: 10,
            max: 200,
            onChanged: (v) =>
                _updateSelectedTextOverlays((o) => o.fontSize = v),
          ),
          ImagePostControlSlider(
            label: 'Scale',
            value: t.scale,
            min: 0.1,
            max: 5.0,
            onChanged: (v) => _updateSelectedTextOverlays((o) => o.scale = v),
          ),
          ImagePostControlSlider(
            label: 'Line Spacing',
            value: t.lineHeight,
            min: 0.5,
            max: 3.0,
            onChanged: (v) =>
                _updateSelectedTextOverlays((o) => o.lineHeight = v),
          ),
          ImagePostControlSlider(
            label: 'Letter Spacing',
            value: t.letterSpacing,
            min: -5.0,
            max: 20.0,
            onChanged: (v) =>
                _updateSelectedTextOverlays((o) => o.letterSpacing = v),
          ),
          ImagePostControlSlider(
            label: 'Word Spacing',
            value: t.wordSpacing,
            min: -10.0,
            max: 50.0,
            onChanged: (v) =>
                _updateSelectedTextOverlays((o) => o.wordSpacing = v),
          ),
          const SizedBox(height: 8),
          const Text(
            'Text Color',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 8),
          ImagePostColorPicker(
            currentColor: t.color,
            onPick: (c) => _updateSelectedTextOverlays((o) => o.color = c),
          ),
          const SizedBox(height: 16),
          ImagePostControlSlider(
            label: 'Opacity',
            value: t.opacity,
            min: 0.0,
            max: 1.0,
            onChanged: (v) => _updateSelectedTextOverlays((o) => o.opacity = v),
          ),
          const SizedBox(height: 16),
          const Text(
            'Font Style',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: allFonts.length,
              itemBuilder: (context, idx) {
                final f = allFonts[idx];
                final bool isSelected = t.font == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      f.displayName,
                      style: TextStyle(
                        fontFamily: f.family,
                        fontWeight: f.weight,
                        fontStyle: f.style,
                        fontSize: 12,
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                    selected: isSelected,
                    showCheckmark: false,
                    selectedColor: AppColors.primary,
                    backgroundColor: Colors.grey.shade100,
                    onSelected: (_) =>
                        _updateSelectedTextOverlays((o) => o.font = f),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Alignment',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 8),
          ToggleButtons(
            isSelected: [
              t.textAlign == TextAlign.left,
              t.textAlign == TextAlign.center,
              t.textAlign == TextAlign.right,
            ],
            onPressed: (btnIdx) {
              _updateSelectedTextOverlays((o) {
                if (btnIdx == 0) o.textAlign = TextAlign.left;
                if (btnIdx == 1) o.textAlign = TextAlign.center;
                if (btnIdx == 2) o.textAlign = TextAlign.right;
              });
            },
            borderRadius: BorderRadius.circular(8),
            constraints: const BoxConstraints(minHeight: 36, minWidth: 48),
            children: const [
              Icon(Icons.format_align_left, size: 20),
              Icon(Icons.format_align_center, size: 20),
              Icon(Icons.format_align_right, size: 20),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 32),
          const Text(
            'Positioning',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 12),
          const Text(
            'Quick Horizontal',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _alignBtn(Icons.align_horizontal_left, 'Left', 0.1, true, t),
              _alignBtn(Icons.align_horizontal_center, 'Center', 0.5, true, t),
              _alignBtn(Icons.align_horizontal_right, 'Right', 0.9, true, t),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Quick Vertical',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _alignBtn(Icons.align_vertical_top, 'Top', 0.1, false, t),
              _alignBtn(Icons.align_vertical_center, 'Middle', 0.5, false, t),
              _alignBtn(Icons.align_vertical_bottom, 'Bottom', 0.9, false, t),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Fine-tune Positioning',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ImagePostControlSlider(
            label: 'Horizontal Position (X)',
            value: t.x,
            min: 0,
            max: 1,
            onChanged: (v) => _updateSelectedTextOverlays((o) => o.x = v),
          ),
          ImagePostControlSlider(
            label: 'Vertical Position (Y)',
            value: t.y,
            min: 0,
            max: 1,
            onChanged: (v) => _updateSelectedTextOverlays((o) => o.y = v),
          ),
          const SizedBox(height: 8),
          const Divider(height: 32),
          const Text(
            'Shadow Settings',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          SwitchListTile(
            title: const Text(
              'Show Drop Shadow',
              style: TextStyle(fontSize: 13),
            ),
            value: t.showShadow,
            onChanged: (v) =>
                _updateSelectedTextOverlays((o) => o.showShadow = v),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
          if (t.showShadow) ...[
            ImagePostControlSlider(
              label: 'Shadow Blur',
              value: t.shadowBlur,
              min: 0.1,
              max: 20.0,
              onChanged: (v) =>
                  _updateSelectedTextOverlays((o) => o.shadowBlur = v),
            ),
            ImagePostControlSlider(
              label: 'Offset X',
              value: t.shadowOffsetX,
              min: -20.0,
              max: 20.0,
              onChanged: (v) =>
                  _updateSelectedTextOverlays((o) => o.shadowOffsetX = v),
            ),
            ImagePostControlSlider(
              label: 'Offset Y',
              value: t.shadowOffsetY,
              min: -20.0,
              max: 20.0,
              onChanged: (v) =>
                  _updateSelectedTextOverlays((o) => o.shadowOffsetY = v),
            ),
            const SizedBox(height: 8),
            const Text('Shadow Color', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            ImagePostColorPicker(
              currentColor: t.shadowColor,
              onPick: (c) =>
                  _updateSelectedTextOverlays((o) => o.shadowColor = c),
            ),
          ],
        ],
      ),
    );
  }

  Widget _alignBtn(
    IconData icon,
    String label,
    double target,
    bool isX,
    ImagePostTextOverlay t,
  ) {
    final bool isSelected = ((isX ? t.x : t.y) - target).abs() < 0.02;
    return InkWell(
      onTap: () => _updateSelectedTextOverlays((o) {
        if (isX) {
          o.x = target;
        } else {
          o.y = target;
        }
      }),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.black),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

