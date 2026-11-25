import 'package:flutter/material.dart';
import '../../models/carousel_slide.dart';
import '../carousel_shared_controls.dart';
import '../carousel_word_selector.dart';

/// Shows the bulk-paste dialog and distributes non-empty lines across slides.
void showCarouselBulkPasteDialog({
  required BuildContext context,
  required List<CarouselSlide> slides,
  required VoidCallback onStateChanged,
}) {
  final bulkController = TextEditingController();
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text(
        'Bulk Paste Text',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Each new line will be assigned to a separate slide.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: bulkController,
            maxLines: 8,
            decoration: InputDecoration(
              hintText: 'Line 1 for Slide 1\nLine 2 for Slide 2\n...',
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final lines = bulkController.text
                .split('\n')
                .where((l) => l.trim().isNotEmpty)
                .toList();
            if (lines.isNotEmpty) {
              while (slides.length < lines.length) {
                slides.add(CarouselSlide());
              }
              for (int i = 0; i < lines.length; i++) {
                slides[i].text = lines[i].trim();
              }
              onStateChanged();
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Updated ${lines.length} slides with bulk text!',
                  ),
                ),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6C63FF),
            foregroundColor: Colors.white,
          ),
          child: const Text('Apply to Slides'),
        ),
      ],
    ),
  );
}

/// Text tab panel: slide text editor, Split to Words, Classic reset, Lock,
/// per-word selector, My Quotes import, and Bulk Paste.
class CarouselTextTab extends StatefulWidget {
  final CarouselSlide slide;
  final Set<int> selectedWordIndices;
  final bool multiSelectMode;
  final VoidCallback onSplitToWords;
  final VoidCallback onLockAllSlides;
  final VoidCallback onImportFromMyQuotes;
  final VoidCallback onBulkPaste;
  final ValueChanged<bool> onMultiSelectChanged;
  final ValueChanged<Set<int>> onSelectedWordsChanged;
  final VoidCallback onStateChanged;

  const CarouselTextTab({
    super.key,
    required this.slide,
    required this.selectedWordIndices,
    required this.multiSelectMode,
    required this.onSplitToWords,
    required this.onLockAllSlides,
    required this.onImportFromMyQuotes,
    required this.onBulkPaste,
    required this.onMultiSelectChanged,
    required this.onSelectedWordsChanged,
    required this.onStateChanged,
  });

  @override
  State<CarouselTextTab> createState() => _CarouselTextTabState();
}

class _CarouselTextTabState extends State<CarouselTextTab> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.slide.text);
  }

  @override
  void didUpdateWidget(covariant CarouselTextTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text != widget.slide.text) {
      _controller.value = TextEditingValue(
        text: widget.slide.text,
        selection: TextSelection.collapsed(offset: widget.slide.text.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slide = widget.slide;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CarouselSectionHeader(title: 'Text Content'),
        TextField(
          controller: _controller,
          onChanged: (val) {
            slide.text = val;
            widget.onStateChanged();
          },
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'Type something for this slide...',
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed:
                    slide.text.trim().isEmpty ? null : widget.onSplitToWords,
                icon: const Icon(Icons.space_bar, size: 18),
                label: Text(
                  slide.useWordMode ? 'Re-split Words' : 'Split to Words',
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
            Container(
              decoration: BoxDecoration(
                color: slide.isLocked
                    ? Colors.orange.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: Icon(
                  slide.isLocked ? Icons.lock : Icons.lock_open,
                  color: slide.isLocked ? Colors.orange : Colors.grey,
                  size: 20,
                ),
                onPressed: () {
                  slide.isLocked = !slide.isLocked;
                  widget.onStateChanged();
                },
                tooltip: slide.isLocked ? 'Unlock Position' : 'Lock Position',
              ),
            ),
          ],
        ),
        if (slide.useWordMode) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    slide.useWordMode = false;
                    slide.wordTokens.clear();
                    widget.onSelectedWordsChanged({});
                    slide.isLocked = false;
                    widget.onStateChanged();
                  },
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
              OutlinedButton.icon(
                onPressed: widget.onLockAllSlides,
                icon: const Icon(Icons.lock_person, size: 16),
                label: const Text('Lock All', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey[700],
                  side: BorderSide(color: Colors.grey[300]!),
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (slide.useWordMode && slide.wordTokens.isNotEmpty) ...[
          const SizedBox(height: 12),
          CarouselWordSelector(
            slide: slide,
            selectedWordIndices: widget.selectedWordIndices,
            multiSelectMode: widget.multiSelectMode,
            onMultiSelectChanged: widget.onMultiSelectChanged,
            onSelectedWordsChanged: widget.onSelectedWordsChanged,
            onStateChanged: widget.onStateChanged,
          ),
        ],
        if (!slide.useWordMode)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tip: Drag text on the image to position it.',
                style: TextStyle(
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  slide.textAlignment = Alignment.center;
                  widget.onStateChanged();
                },
                icon: const Icon(Icons.center_focus_weak, size: 14),
                label: const Text(
                  'Reset Position',
                  style: TextStyle(fontSize: 10),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                ),
              ),
            ],
          ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: widget.onImportFromMyQuotes,
            icon: Icon(
              Icons.collections_bookmark_outlined,
              size: 16,
              color: Colors.indigo[400],
            ),
            label: Text(
              'Import from My Quotes',
              style: TextStyle(fontSize: 11, color: Colors.indigo[700]),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.indigo,
              side: BorderSide(color: Colors.indigo[100]!),
              padding: const EdgeInsets.symmetric(vertical: 8),
              backgroundColor: Colors.indigo.withValues(alpha: 0.02),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: widget.onBulkPaste,
            icon: const Icon(Icons.content_paste_go, size: 16),
            label: const Text(
              'Bulk Paste (one line per slide)',
              style: TextStyle(fontSize: 11),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey[700],
              side: BorderSide(color: Colors.grey[300]!),
              padding: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

