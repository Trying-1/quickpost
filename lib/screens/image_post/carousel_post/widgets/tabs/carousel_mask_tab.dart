import 'package:flutter/material.dart';
import '../../models/carousel_slide.dart';
import '../carousel_shared_controls.dart';

/// Mask tab panel: mask gradient type, range start/end, opacity, color,
/// and apply-to-all toggle.
class CarouselMaskTab extends StatelessWidget {
  final List<CarouselSlide> slides;
  final CarouselSlide currentSlide;
  final bool applyMaskToAll;
  final ValueChanged<bool> onApplyMaskToAllChanged;
  final VoidCallback onPickMaskColor;
  final VoidCallback onStateChanged;

  const CarouselMaskTab({
    super.key,
    required this.slides,
    required this.currentSlide,
    required this.applyMaskToAll,
    required this.onApplyMaskToAllChanged,
    required this.onPickMaskColor,
    required this.onStateChanged,
  });

  void _updateMask(void Function(CarouselSlide s) updater) {
    if (applyMaskToAll) {
      for (final s in slides) {
        updater(s);
      }
    } else {
      updater(currentSlide);
    }
    onStateChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title: const Text(
            'Apply Mask to All Slides',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          value: applyMaskToAll,
          onChanged: onApplyMaskToAllChanged,
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 8),
        const CarouselSectionHeader(title: 'Mask Type'),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildMaskTypeOption(0, Icons.block, 'None'),
              const SizedBox(width: 8),
              _buildMaskTypeOption(1, Icons.gradient, 'Bottom'),
              const SizedBox(width: 8),
              _buildMaskTypeOption(2, Icons.gradient, 'Top'),
              const SizedBox(width: 8),
              _buildMaskTypeOption(4, Icons.gradient, 'Left'),
              const SizedBox(width: 8),
              _buildMaskTypeOption(5, Icons.gradient, 'Right'),
              const SizedBox(width: 8),
              _buildMaskTypeOption(3, Icons.layers, 'Full'),
            ],
          ),
        ),
        if (currentSlide.maskType != 0) ...[
          const SizedBox(height: 12),
          CarouselInlineSlider(
            label: 'Mask Range Start',
            value: currentSlide.maskStart.clamp(0.0, 1.0),
            min: 0.0,
            max: 1.0,
            onChanged: (v) => _updateMask((s) => s.maskStart = v),
          ),
          CarouselInlineSlider(
            label: 'Mask Range End',
            value: currentSlide.maskEnd.clamp(0.0, 1.0),
            min: 0.0,
            max: 1.0,
            onChanged: (v) => _updateMask((s) => s.maskEnd = v),
          ),
          CarouselInlineSlider(
            label: 'Mask Opacity',
            value: currentSlide.maskOpacity.clamp(0.0, 1.0),
            min: 0.0,
            max: 1.0,
            onChanged: (v) => _updateMask((s) => s.maskOpacity = v),
          ),
          const SizedBox(height: 8),
          const CarouselSectionHeader(title: 'Mask Color'),
          Row(
            children: [
              _buildCustomMaskColorOption(),
              _buildMaskColorOption(Colors.black),
              _buildMaskColorOption(const Color(0xFF1A1A1A)),
              _buildMaskColorOption(Colors.white),
              _buildMaskColorOption(const Color(0xFF6C63FF)),
              _buildMaskColorOption(const Color(0xFFFF4E50)),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildMaskTypeOption(int type, IconData icon, String label) {
    final isSel = currentSlide.maskType == type;
    return GestureDetector(
      onTap: () => _updateMask((s) => s.maskType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSel
              ? const Color(0xFF6C63FF).withValues(alpha: 0.1)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSel ? const Color(0xFF6C63FF) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: isSel ? const Color(0xFF6C63FF) : Colors.grey[700],
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                color: isSel ? const Color(0xFF6C63FF) : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomMaskColorOption() {
    return GestureDetector(
      onTap: onPickMaskColor,
      child: Container(
        width: 28,
        height: 28,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: const Icon(
          Icons.colorize_rounded,
          size: 14,
          color: Color(0xFF6C63FF),
        ),
      ),
    );
  }

  Widget _buildMaskColorOption(Color color) {
    final isSel = currentSlide.maskColor == color;
    return GestureDetector(
      onTap: () => _updateMask((s) => s.maskColor = color),
      child: Container(
        width: 28,
        height: 28,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSel ? const Color(0xFF6C63FF) : Colors.grey[300]!,
            width: isSel ? 2.5 : 1,
          ),
        ),
      ),
    );
  }
}

