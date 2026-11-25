import 'package:flutter/material.dart';
import 'package:quickpost/config/app_theme.dart';
import '../models/color_palette_item.dart';
import '../models/palette_color.dart';

/// Interactive contrast tester that benchmarks palette colors against WCAG 2.1 guidelines
/// and renders a live social post preview card.
class PaletteContrastView extends StatefulWidget {
  final ColorPaletteItem palette;

  const PaletteContrastView({super.key, required this.palette});

  @override
  State<PaletteContrastView> createState() => _PaletteContrastViewState();
}

class _PaletteContrastViewState extends State<PaletteContrastView> {
  int _bgIndex = 0;
  int _textIndex = 1;
  int _accentIndex = 2;

  @override
  void initState() {
    super.initState();
    _initIndexes();
  }

  @override
  void didUpdateWidget(covariant PaletteContrastView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _initIndexes();
  }

  void _initIndexes() {
    final len = widget.palette.colors.length;
    if (len == 0) return;
    _bgIndex = 0;
    _textIndex = (1 < len) ? 1 : 0;
    _accentIndex = (2 < len) ? 2 : (len - 1);
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.palette.colors;
    if (colors.isEmpty) {
      return const Center(child: Text('No colors in active palette.', style: TextStyle(color: Colors.white70)));
    }

    final bgColor = colors[_bgIndex.clamp(0, colors.length - 1)];
    final textColor = colors[_textIndex.clamp(0, colors.length - 1)];
    final accentColor = colors[_accentIndex.clamp(0, colors.length - 1)];

    final ratio = textColor.contrastRatioWith(bgColor.color);
    final rating = textColor.getWcagRating(bgColor.color);
    final isPassAA = ratio >= 4.5;
    final isPassAAA = ratio >= 7.0;
    final isPassLarge = ratio >= 3.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          const Row(
            children: [
              Icon(Icons.remove_red_eye_rounded, color: AppColors.primary, size: 18),
              SizedBox(width: 8),
              Text(
                'Live Post Preview & Contrast Test',
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Poppins'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Live Post Mockup Card styled with active palette colors
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: bgColor.color,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: accentColor.color.withOpacity(0.5),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: accentColor.color,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'FEATURED STORY',
                        style: TextStyle(
                          color: accentColor.onColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    Text(
                      'Just now',
                      style: TextStyle(
                        color: textColor.color.withOpacity(0.6),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'High Contrast Design for Creators',
                  style: TextStyle(
                    color: textColor.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Great content starts with legibility. Clean typography and tested contrast ensure your message stands out across Reels, Carousels, and Stories.',
                  style: TextStyle(
                    color: textColor.color.withOpacity(0.85),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor.color,
                        foregroundColor: accentColor.onColor,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: const Text('Read Story', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${ratio.toStringAsFixed(1)}:1 Contrast',
                      style: TextStyle(
                        color: textColor.color.withOpacity(0.7),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Contrast Score Matrix Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'WCAG 2.1 Compliance',
                      style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Poppins'),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isPassAAA
                            ? const Color(0xFF10B981)
                            : isPassAA
                                ? AppColors.primary
                                : const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$rating (${ratio.toStringAsFixed(2)}:1)',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 3 Standard Badges (Normal Text, Large Text, UI Components)
                Row(
                  children: [
                    _buildWcagBadge('Normal Text', isPassAA ? 'Pass (4.5+)' : 'Fail', isPassAA),
                    const SizedBox(width: 8),
                    _buildWcagBadge('Large Text', isPassLarge ? 'Pass (3.0+)' : 'Fail', isPassLarge),
                    const SizedBox(width: 8),
                    _buildWcagBadge('Enhanced AAA', isPassAAA ? 'Pass (7.0+)' : 'Fail', isPassAAA),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Interactive Role Switcher
          const Text(
            'ASSIGN PALETTE COLORS TO PREVIEW',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1, fontFamily: 'Poppins'),
          ),
          const SizedBox(height: 10),

          // Background Picker Row
          _buildColorSelectionRow(
            label: 'Background',
            selectedIndex: _bgIndex,
            colors: colors,
            onSelected: (i) => setState(() => _bgIndex = i),
          ),
          const SizedBox(height: 10),

          // Text Color Picker Row
          _buildColorSelectionRow(
            label: 'Headline & Body',
            selectedIndex: _textIndex,
            colors: colors,
            onSelected: (i) => setState(() => _textIndex = i),
          ),
          const SizedBox(height: 10),

          // Accent Picker Row
          _buildColorSelectionRow(
            label: 'Button Accent',
            selectedIndex: _accentIndex,
            colors: colors,
            onSelected: (i) => setState(() => _accentIndex = i),
          ),
        ],
      ),
    );
  }

  Widget _buildWcagBadge(String title, String status, bool pass) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: pass ? const Color(0xFF10B981).withOpacity(0.15) : const Color(0xFFEF4444).withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: pass ? const Color(0xFF10B981).withOpacity(0.4) : const Color(0xFFEF4444).withOpacity(0.4),
          ),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 3),
            Text(
              status,
              style: TextStyle(
                color: pass ? const Color(0xFF34D399) : const Color(0xFFF87171),
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorSelectionRow({
    required String label,
    required int selectedIndex,
    required List<PaletteColor> colors,
    required ValueChanged<int> onSelected,
  }) {
    final selectedColor = (selectedIndex >= 0 && selectedIndex < colors.length) ? colors[selectedIndex] : colors.first;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
              ),
              Text(
                '${selectedColor.name} (${selectedColor.hexCode})',
                style: const TextStyle(color: AppColors.primary, fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: colors.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final isSelected = i == selectedIndex;
                final c = colors[i];
                return GestureDetector(
                  onTap: () => onSelected(i),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: c.color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? AppColors.primary : Colors.black12,
                        width: isSelected ? 3 : 1,
                      ),
                      boxShadow: isSelected
                          ? [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 8)]
                          : null,
                    ),
                    child: isSelected
                        ? Icon(Icons.check, size: 18, color: c.onColor)
                        : null,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

