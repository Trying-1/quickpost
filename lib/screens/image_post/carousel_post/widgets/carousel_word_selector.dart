import 'package:flutter/material.dart';
import '../../../../models/word_token.dart';
import '../models/carousel_slide.dart';

/// Per-word token selector bar (with single/multi select, Select All, Clear)
/// and optional per-word size/rotation/reset controls.
class CarouselWordSelector extends StatelessWidget {
  final CarouselSlide slide;
  final Set<int> selectedWordIndices;
  final bool multiSelectMode;
  final bool showPropertyControls;
  final ValueChanged<bool> onMultiSelectChanged;
  final ValueChanged<Set<int>> onSelectedWordsChanged;
  final VoidCallback onStateChanged;

  const CarouselWordSelector({
    super.key,
    required this.slide,
    required this.selectedWordIndices,
    required this.multiSelectMode,
    this.showPropertyControls = false,
    required this.onMultiSelectChanged,
    required this.onSelectedWordsChanged,
    required this.onStateChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (!slide.useWordMode || slide.wordTokens.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              const Text(
                'Select Word to Customize',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6C63FF),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => onMultiSelectChanged(!multiSelectMode),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: multiSelectMode
                        ? const Color(0xFF6C63FF)
                        : Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        multiSelectMode ? Icons.check_box : Icons.checklist,
                        size: 11,
                        color: multiSelectMode ? Colors.white : Colors.grey[700],
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'Multi',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color:
                              multiSelectMode ? Colors.white : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  onSelectedWordsChanged(
                    Set.from(
                      List.generate(slide.wordTokens.length, (i) => i),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    'All',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.blue[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              if (selectedWordIndices.isNotEmpty)
                GestureDetector(
                  onTap: () => onSelectedWordsChanged({}),
                  child: const Text(
                    'Clear',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 36,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: slide.wordTokens.length,
            itemBuilder: (context, idx) {
              final token = slide.wordTokens[idx];
              final isSelected = selectedWordIndices.contains(idx);
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(
                    token.text,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: const Color(0xFF6C63FF),
                  onSelected: (val) {
                    final next = Set<int>.from(selectedWordIndices);
                    if (multiSelectMode) {
                      if (val) {
                        next.add(idx);
                      } else {
                        next.remove(idx);
                      }
                    } else {
                      if (val) {
                        next
                          ..clear()
                          ..add(idx);
                      } else {
                        next.clear();
                      }
                    }
                    onSelectedWordsChanged(next);
                  },
                ),
              );
            },
          ),
        ),
        if (showPropertyControls && selectedWordIndices.isNotEmpty)
          _buildWordPropertyControls(
            context,
            slide.wordTokens[selectedWordIndices.first],
          ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildWordPropertyControls(BuildContext context, WordToken firstWord) {
    final bool isMulti = selectedWordIndices.length > 1;
    final String label = isMulti
        ? 'Editing ${selectedWordIndices.length} Words'
        : 'Word: "${firstWord.text}"';

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF6C63FF).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune, size: 14, color: Color(0xFF6C63FF)),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6C63FF),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  for (final idx in selectedWordIndices) {
                    final word = slide.wordTokens[idx];
                    word.position = word.originalPosition ?? Alignment.center;
                    word.rotation = 0.0;
                  }
                  onStateChanged();
                },
                child: const Text(
                  'Reset to Split',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                'Size:',
                style: TextStyle(fontSize: 10, color: Colors.black54),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                  ),
                  child: Slider(
                    value: firstWord.fontSize.clamp(10.0, 80.0),
                    min: 10,
                    max: 80,
                    activeColor: const Color(0xFF6C63FF),
                    onChanged: (v) {
                      for (final idx in selectedWordIndices) {
                        slide.wordTokens[idx].fontSize = v;
                      }
                      onStateChanged();
                    },
                  ),
                ),
              ),
              Text(
                '${firstWord.fontSize.toInt()}',
                style:
                    const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Row(
            children: [
              const Text(
                'Rotate:',
                style: TextStyle(fontSize: 10, color: Colors.black54),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                  ),
                  child: Slider(
                    value: firstWord.rotation.clamp(-180.0, 180.0),
                    min: -180,
                    max: 180,
                    activeColor: const Color(0xFF6C63FF),
                    onChanged: (v) {
                      for (final idx in selectedWordIndices) {
                        slide.wordTokens[idx].rotation = v;
                      }
                      onStateChanged();
                    },
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.refresh,
                  size: 14,
                  color: Color(0xFF6C63FF),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Reset Rotation',
                onPressed: () {
                  for (final idx in selectedWordIndices) {
                    slide.wordTokens[idx].rotation = 0.0;
                  }
                  onStateChanged();
                },
              ),
              const SizedBox(width: 8),
              Text(
                '${firstWord.rotation.toInt()}°',
                style:
                    const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
