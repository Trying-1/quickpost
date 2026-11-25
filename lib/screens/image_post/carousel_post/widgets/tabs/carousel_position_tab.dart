import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/carousel_slide.dart';
import '../carousel_shared_controls.dart';
import '../carousel_word_selector.dart';

/// Position tab panel: alignment presets, hold-to-repeat fine nudge D-pad,
/// center reset button, and per-word size/rotation/reset controls in word mode.
class CarouselPositionTab extends StatefulWidget {
  final CarouselSlide slide;
  final Set<int> selectedWordIndices;
  final bool multiSelectMode;
  final ValueChanged<bool> onMultiSelectChanged;
  final ValueChanged<Set<int>> onSelectedWordsChanged;
  final VoidCallback onStateChanged;

  const CarouselPositionTab({
    super.key,
    required this.slide,
    required this.selectedWordIndices,
    required this.multiSelectMode,
    required this.onMultiSelectChanged,
    required this.onSelectedWordsChanged,
    required this.onStateChanged,
  });

  @override
  State<CarouselPositionTab> createState() => _CarouselPositionTabState();
}

class _CarouselPositionTabState extends State<CarouselPositionTab> {
  Timer? _nudgeTimer;

  @override
  void dispose() {
    _nudgeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slide = widget.slide;

    if (!slide.useWordMode) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CarouselSectionHeader(title: 'Text Alignment'),
          _buildPositionControls(
            label: 'Presets',
            current: slide.textAlignment,
            onChanged: (val) {
              slide.textAlignment = val;
              widget.onStateChanged();
            },
          ),
          const SizedBox(height: 20),
          const Center(
            child: Text(
              'Drag text on the canvas for free positioning\nor use presets above.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ),
        ],
      );
    }

    final bool wordSelected =
        slide.useWordMode && widget.selectedWordIndices.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CarouselWordSelector(
          slide: slide,
          selectedWordIndices: widget.selectedWordIndices,
          multiSelectMode: widget.multiSelectMode,
          showPropertyControls: true,
          onMultiSelectChanged: widget.onMultiSelectChanged,
          onSelectedWordsChanged: widget.onSelectedWordsChanged,
          onStateChanged: widget.onStateChanged,
        ),
        if (wordSelected) ...[
          const Divider(height: 32),
          _buildPositionControls(
            label: 'Word Position',
            current: slide.wordTokens[widget.selectedWordIndices.first].position,
            onChanged: (val) {
              for (final idx in widget.selectedWordIndices) {
                slide.wordTokens[idx].position = val;
              }
              widget.onStateChanged();
            },
          ),
        ],
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () {
            if (wordSelected) {
              for (final idx in widget.selectedWordIndices) {
                slide.wordTokens[idx].fontSize = 28.0;
              }
            } else {
              slide.slideFontSize = 28.0;
            }
            slide.textScale = 1.0;
            widget.onStateChanged();
          },
          child: const Text('Reset Text Sizes'),
        ),
      ],
    );
  }

  Widget _buildPositionControls({
    required String label,
    required Alignment current,
    required ValueChanged<Alignment> onChanged,
  }) {
    const presets = [
      ('Center', Alignment.center),
      ('Top', Alignment.topCenter),
      ('Bottom', Alignment.bottomCenter),
      ('Left', Alignment.centerLeft),
      ('Right', Alignment.centerRight),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: presets.map((preset) {
              final target = preset.$2;
              final bool isSelected = current == target;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => onChanged(target),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF6C63FF).withValues(alpha: 0.12)
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF6C63FF)
                            : Colors.grey[300]!,
                      ),
                    ),
                    child: Text(
                      preset.$1,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? const Color(0xFF6C63FF)
                            : Colors.grey[800],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Fine Tune',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'X: ${current.x.toStringAsFixed(3)}\nY: ${current.y.toStringAsFixed(3)}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                      fontFamily: 'monospace',
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                _buildCompactNudgeButton(
                  Icons.keyboard_arrow_up,
                  () => onChanged(
                    Alignment(current.x, (current.y - 0.01).clamp(-1.0, 1.0)),
                  ),
                ),
                Row(
                  children: [
                    _buildCompactNudgeButton(
                      Icons.keyboard_arrow_left,
                      () => onChanged(
                        Alignment(
                          (current.x - 0.01).clamp(-1.0, 1.0),
                          current.y,
                        ),
                      ),
                    ),
                    _buildCompactNudgeButton(
                      Icons.adjust,
                      () => onChanged(Alignment.center),
                      isCenter: true,
                    ),
                    _buildCompactNudgeButton(
                      Icons.keyboard_arrow_right,
                      () => onChanged(
                        Alignment(
                          (current.x + 0.01).clamp(-1.0, 1.0),
                          current.y,
                        ),
                      ),
                    ),
                  ],
                ),
                _buildCompactNudgeButton(
                  Icons.keyboard_arrow_down,
                  () => onChanged(
                    Alignment(current.x, (current.y + 0.01).clamp(-1.0, 1.0)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompactNudgeButton(
    IconData icon,
    VoidCallback action, {
    bool isCenter = false,
  }) {
    return GestureDetector(
      onTapDown: (_) {
        action();
        if (!isCenter) {
          _nudgeTimer?.cancel();
          _nudgeTimer = Timer.periodic(
            const Duration(milliseconds: 80),
            (t) {
              if (t.tick > 4) action();
            },
          );
        }
      },
      onTapUp: (_) => _nudgeTimer?.cancel(),
      onTapCancel: () => _nudgeTimer?.cancel(),
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isCenter ? Colors.grey[200] : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Icon(
          icon,
          size: isCenter ? 18 : 22,
          color: isCenter ? Colors.blue : Colors.grey[700],
        ),
      ),
    );
  }
}
