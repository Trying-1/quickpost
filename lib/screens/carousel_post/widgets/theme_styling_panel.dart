import 'package:flutter/material.dart';
import '../../../../config/app_theme.dart';
import '../../../../widgets/advanced_color_picker.dart';
import '../../../../utils/font_selector.dart';
import '../models/carousel_slide.dart';
import '../models/carousel_template_theme.dart';

enum StylingSection {
  all,
  layouts,
  components,
  styles,
  branding,
  canvas,
  fonts,
  colors,
}

enum StyleSubCategory {
  typography,
  colors,
  card,
  elements,
}

/// Styling and template theme customization panel for Carousel Posts.
class ThemeStylingPanel extends StatefulWidget {
  final CarouselTemplateTheme theme;
  final ValueChanged<CarouselTemplateTheme> onThemeChanged;
  final StylingSection section;
  final CarouselSlide? activeSlide;
  final ValueChanged<SlideLayout>? onSelectSlideLayout;
  final ValueChanged<bool>? onToggleSync;
  final String? activeComponentKey;
  final ValueChanged<String>? onSelectComponent;

  const ThemeStylingPanel({
    super.key,
    required this.theme,
    required this.onThemeChanged,
    this.section = StylingSection.all,
    this.activeSlide,
    this.onSelectSlideLayout,
    this.onToggleSync,
    this.activeComponentKey,
    this.onSelectComponent,
  });

  @override
  State<ThemeStylingPanel> createState() => _ThemeStylingPanelState();
}

class _ThemeStylingPanelState extends State<ThemeStylingPanel> {
  late String _selectedComponentKey;

  @override
  void initState() {
    super.initState();
    final available = _availableComponents;
    final initialKey = widget.activeComponentKey ?? SlideComponentId.title;
    if (available.contains(initialKey)) {
      _selectedComponentKey = initialKey;
    } else if (available.isNotEmpty) {
      _selectedComponentKey = available.contains(SlideComponentId.title) ? SlideComponentId.title : available.first;
    } else {
      _selectedComponentKey = initialKey;
    }
  }

  @override
  void didUpdateWidget(covariant ThemeStylingPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeComponentKey != null && widget.activeComponentKey != _selectedComponentKey) {
      _selectedComponentKey = widget.activeComponentKey!;
    }
  }

  List<String> get _availableComponents {
    final slide = widget.activeSlide;
    if (slide == null) return SlideComponentId.contentComponents;
    switch (slide.type) {
      case SlideType.cover:
        return SlideComponentId.coverComponents;
      case SlideType.cta:
        return SlideComponentId.ctaComponents;
      case SlideType.content:
        return SlideComponentId.contentComponents;
    }
  }

  static const List<Map<String, dynamic>> _curatedBackgrounds = [
    {'name': 'Obsidian Dark', 'color': Color(0xFF0A0A0C), 'accent': Color(0xFF0D9488)},
    {'name': 'Porcelain Light', 'color': Color(0xFFFAF8F5), 'accent': Color(0xFF059669)},
    {'name': 'Pure White', 'color': Color(0xFFFFFFFF), 'accent': Color(0xFF2563EB)},
    {'name': 'Nordic Slate', 'color': Color(0xFF1E293B), 'accent': Color(0xFF06B6D4)},
    {'name': 'Midnight Navy', 'color': Color(0xFF0F172A), 'accent': Color(0xFF6366F1)},
    {'name': 'Warm Sand', 'color': Color(0xFFF5F2EB), 'accent': Color(0xFFD97706)},
    {'name': 'Matte Charcoal', 'color': Color(0xFF18181B), 'accent': Color(0xFF10B981)},
    {'name': 'Espresso Dark', 'color': Color(0xFF1C1917), 'accent': Color(0xFFF59E0B)},
    {'name': 'Botanical Dark', 'color': Color(0xFF0A140F), 'accent': Color(0xFF22C55E)},
  ];

  static const List<Map<String, String>> _popularFonts = [
    {'name': 'Poppins Bold', 'family': 'Poppins-Bold'},
    {'name': 'Poppins', 'family': 'Poppins'},
    {'name': 'Poppins SemiBold', 'family': 'Poppins-SemiBold'},
    {'name': 'Klee One', 'family': 'KleeOne'},
    {'name': 'Michroma', 'family': 'Michroma'},
    {'name': 'Luckiest Guy', 'family': 'LuckiestGuy'},
    {'name': 'Metrophobic', 'family': 'Metrophobic'},
    {'name': 'Protest Revolution', 'family': 'ProtestRevolution'},
  ];

  static const List<Color> _accentColors = [
    Color(0xFF0D9488), // Sleek Teal
    Color(0xFF6366F1), // Royal Indigo
    Color(0xFF3B82F6), // Clean Blue
    Color(0xFF10B981), // Emerald
    Color(0xFFF59E0B), // Warm Amber
    Color(0xFFEC4899), // Pink
    Color(0xFF8B5CF6), // Purple
    Color(0xFFEF4444), // Coral Red
  ];

  @override
  Widget build(BuildContext context) {
    switch (widget.section) {
      case StylingSection.styles:
        return _buildStylesSection();
      case StylingSection.components:
        return _buildComponentsSection();
      case StylingSection.fonts:
        return _buildFontsSection();
      case StylingSection.colors:
        return _buildColorsSection();
      case StylingSection.branding:
        return _buildBrandingSection();
      case StylingSection.canvas:
        return _buildCanvasSection();
      default:
        return _buildStylesSection();
    }
  }

  // 1. STYLES (Cards, Accents, Backgrounds)
  Widget _buildStylesSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Card Container Style', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: CardStyle.values.map((style) {
              final isSel = widget.theme.cardStyle == style;
              return ChoiceChip(
                label: Text(style.label),
                selected: isSel,
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: isSel ? Colors.white : Colors.black87,
                  fontSize: 11,
                  fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                ),
                onSelected: (_) => widget.onThemeChanged(widget.theme.copyWith(cardStyle: style)),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          const Text('Theme Accent Color', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _accentColors.map((col) {
              final isSel = widget.theme.accentColor.value == col.value;
              return GestureDetector(
                onTap: () => widget.onThemeChanged(widget.theme.copyWith(accentColor: col)),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: col,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSel ? Colors.black : Colors.white,
                      width: isSel ? 2.5 : 1,
                    ),
                    boxShadow: [
                      if (isSel) BoxShadow(color: col.withValues(alpha: 0.4), blurRadius: 6),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Custom color picker trigger
          Row(
            children: [
              const Text('Custom Accent:', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Pick Accent Color'),
                      content: AdvancedColorPicker(
                        initialColor: widget.theme.accentColor,
                        onColorChanged: (c) => widget.onThemeChanged(widget.theme.copyWith(accentColor: c)),
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
                      ],
                    ),
                  );
                },
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: widget.theme.accentColor,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 2. COMPONENTS (Visibility Toggles & Element Styles)
  Widget _buildComponentsSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section A: Element Visibility Toggles
          const Text('Element Visibility', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          _buildComponentToggleTile(
            icon: Icons.format_quote_rounded,
            title: 'Body Text / Quote / Content',
            subtitle: 'Display explanation text, quote, or principle body',
            value: widget.theme.showBodyText,
            onChanged: (val) => widget.onThemeChanged(widget.theme.copyWith(showBodyText: val)),
          ),
          _buildComponentToggleTile(
            icon: Icons.alternate_email_rounded,
            title: 'Brand Watermark (@handle)',
            subtitle: 'Display account handle badge on the top-left',
            value: widget.theme.showWatermark,
            onChanged: (val) => widget.onThemeChanged(widget.theme.copyWith(showWatermark: val)),
          ),
          _buildComponentToggleTile(
            icon: Icons.numbers_rounded,
            title: 'Slide Counter (01 / 07)',
            subtitle: 'Display page fraction badge on the top-right',
            value: widget.theme.showSlideCounter,
            onChanged: (val) => widget.onThemeChanged(widget.theme.copyWith(showSlideCounter: val)),
          ),
          _buildComponentToggleTile(
            icon: Icons.swipe_rounded,
            title: 'Swipe Cue (Swipe to read ->)',
            subtitle: 'Display swipe cue indicator on the cover slide',
            value: widget.theme.showSwipeIndicator,
            onChanged: (val) => widget.onThemeChanged(widget.theme.copyWith(showSwipeIndicator: val)),
          ),
          _buildComponentToggleTile(
            icon: Icons.layers_rounded,
            title: 'Card Backdrop Container',
            subtitle: 'Wrap slide text inside a modern elevated card',
            value: widget.theme.showCardBackdrop || widget.theme.cardStyle != CardStyle.none,
            onChanged: (val) => widget.onThemeChanged(
              widget.theme.copyWith(
                showCardBackdrop: val,
                cardStyle: val ? (widget.theme.cardStyle == CardStyle.none ? CardStyle.cleanMinimalCenter : widget.theme.cardStyle) : CardStyle.none,
              ),
            ),
          ),
          _buildComponentToggleTile(
            icon: Icons.verified_rounded,
            title: 'Verified Checkmark on Handle',
            subtitle: 'Show blue verified checkmark next to your handle',
            value: widget.theme.showVerifiedBadge,
            onChanged: (val) => widget.onThemeChanged(widget.theme.copyWith(showVerifiedBadge: val)),
          ),

          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // Section B: Element Card & Badge Styles
          const Text('Element Card & Badge Designs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 12),

          // 1. Headline Title Style
          const Text('Headline / Title Style', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: TitleCardStyle.values.map((s) {
              final isSel = widget.theme.titleCardStyle == s;
              return ChoiceChip(
                label: Text(s.label),
                selected: isSel,
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: isSel ? Colors.white : Colors.black87,
                  fontSize: 11,
                  fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                ),
                onSelected: (_) => widget.onThemeChanged(widget.theme.copyWith(titleCardStyle: s)),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // 3. Body / Quote Style
          const Text('Body / Quote Box Style', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: SynopsisCardStyle.values.map((s) {
              final isSel = widget.theme.synopsisCardStyle == s;
              return ChoiceChip(
                label: Text(s.label),
                selected: isSel,
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: isSel ? Colors.white : Colors.black87,
                  fontSize: 11,
                  fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                ),
                onSelected: (_) => widget.onThemeChanged(widget.theme.copyWith(synopsisCardStyle: s)),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // 4. Slide Counter Style
          const Text('Slide Counter Style', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: SlideCounterStyle.values.map((s) {
              final isSel = widget.theme.slideCounterStyle == s;
              return ChoiceChip(
                label: Text(s.label),
                selected: isSel,
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: isSel ? Colors.white : Colors.black87,
                  fontSize: 11,
                  fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                ),
                onSelected: (_) => widget.onThemeChanged(widget.theme.copyWith(slideCounterStyle: s)),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // 5. Watermark Style
          const Text('Watermark / Handle Style', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: HandleStyle.values.map((s) {
              final isSel = widget.theme.handleStyle == s;
              return ChoiceChip(
                label: Text(s.label),
                selected: isSel,
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: isSel ? Colors.white : Colors.black87,
                  fontSize: 11,
                  fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                ),
                onSelected: (_) => widget.onThemeChanged(widget.theme.copyWith(handleStyle: s)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildComponentToggleTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onChanged(!value),
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: value ? AppColors.primarySurface : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: value ? AppColors.primary.withValues(alpha: 0.5) : Colors.grey.shade200,
                width: value ? 1.2 : 0.8,
              ),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: value ? AppColors.primary.withValues(alpha: 0.12) : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 17,
                    color: value ? AppColors.primary : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: value ? FontWeight.bold : FontWeight.w500,
                          color: value ? AppColors.primary : Colors.black87,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: value,
                  onChanged: onChanged,
                  activeColor: AppColors.primary,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 3. FONTS (Global & Granular per Component)
  Widget _buildFontsSection() {
    final currentFontFamily = widget.theme.getFontForComponent(_selectedComponentKey);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select Component to Style Font', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _availableComponents.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final key = _availableComponents[i];
                final isSel = key == _selectedComponentKey;
                return ChoiceChip(
                  label: Text(SlideComponentId.getLabel(key)),
                  selected: isSel,
                  selectedColor: Colors.deepPurple,
                  labelStyle: TextStyle(
                    color: isSel ? Colors.white : Colors.black87,
                    fontSize: 11,
                  ),
                  onSelected: (_) => setState(() => _selectedComponentKey = key),
                );
              },
            ),
          ),
          const SizedBox(height: 14),

          Text(
            'Popular Carousel Fonts for ${SlideComponentId.getLabel(_selectedComponentKey)}:',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _popularFonts.map((pf) {
              final isSel = currentFontFamily == pf['family'];
              return ChoiceChip(
                label: Text(
                  pf['name']!,
                  style: TextStyle(
                    fontFamily: pf['family'],
                    fontSize: 11,
                    color: isSel ? Colors.white : Colors.black87,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                selected: isSel,
                selectedColor: AppColors.primary,
                onSelected: (_) {
                  final updated = Map<String, String>.from(widget.theme.componentFonts);
                  updated[_selectedComponentKey] = pf['family']!;
                  widget.onThemeChanged(widget.theme.copyWith(componentFonts: updated));
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          Text(
            'All Fonts (Google & Local):',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 8),
          HorizontalFontSelector(
            selectedFont: FontInfo.getFontByFamily(currentFontFamily) ??
                FontInfo(
                  family: currentFontFamily,
                  displayName: currentFontFamily,
                ),
            onFontSelected: (font) {
              final updated = Map<String, String>.from(widget.theme.componentFonts);
              updated[_selectedComponentKey] = font.family;
              widget.onThemeChanged(widget.theme.copyWith(componentFonts: updated));
            },
          ),
        ],
      ),
    );
  }

  // 4. COLORS (Global & Granular per Component)
  Widget _buildColorsSection() {
    final colorComponents = SlideComponentId.colorComponents;
    final selectedKey = colorComponents.contains(_selectedComponentKey)
        ? _selectedComponentKey
        : colorComponents.first;
    final isCanvasBg = selectedKey == SlideComponentId.canvasBackground;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select Component to Style Color', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: colorComponents.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final key = colorComponents[i];
                final isSel = key == selectedKey;
                return ChoiceChip(
                  label: Text(SlideComponentId.getLabel(key)),
                  selected: isSel,
                  selectedColor: Colors.pinkAccent,
                  labelStyle: TextStyle(
                    color: isSel ? Colors.white : Colors.black87,
                    fontSize: 11,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (_) => setState(() => _selectedComponentKey = key),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          if (isCanvasBg) ...[
            const Text(
              'Aesthetic Slide Backgrounds:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _curatedBackgrounds.map((bg) {
                final color = bg['color'] as Color;
                final name = bg['name'] as String;
                final accent = bg['accent'] as Color;
                final isSel = widget.theme.canvasBackgroundColor.value == color.value;
                return GestureDetector(
                  onTap: () => widget.onThemeChanged(widget.theme.copyWith(canvasBackgroundColor: color)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSel ? AppColors.primary : (color.computeLuminance() > 0.5 ? Colors.grey.shade300 : Colors.white24),
                        width: isSel ? 2.5 : 1.0,
                      ),
                      boxShadow: [
                        if (isSel) BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 6),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          name,
                          style: TextStyle(
                            color: color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
                            fontSize: 11,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Custom Slide Background Color'),
                    content: AdvancedColorPicker(
                      initialColor: widget.theme.canvasBackgroundColor,
                      onColorChanged: (c) => widget.onThemeChanged(widget.theme.copyWith(canvasBackgroundColor: c)),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.palette_rounded, size: 16),
              label: const Text('Pick Custom Background Color'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ] else ...[
            Text(
              'Color for ${SlideComponentId.getLabel(selectedKey)}:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                Colors.white,
                const Color(0xFF0A0A0C),
                const Color(0xFF0F172A),
                const Color(0xFF334155),
                ..._accentColors,
              ].map((col) {
                return GestureDetector(
                  onTap: () {
                    final updated = Map<String, Color>.from(widget.theme.componentColors);
                    updated[selectedKey] = col;
                    widget.onThemeChanged(widget.theme.copyWith(componentColors: updated));
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: col,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text('Pick Color for ${SlideComponentId.getLabel(selectedKey)}'),
                    content: AdvancedColorPicker(
                      initialColor: widget.theme.getColorForComponent(selectedKey),
                      onColorChanged: (c) {
                        final updated = Map<String, Color>.from(widget.theme.componentColors);
                        updated[selectedKey] = c;
                        widget.onThemeChanged(widget.theme.copyWith(componentColors: updated));
                      },
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.palette_rounded, size: 16),
              label: const Text('Custom Color Picker'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pinkAccent,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 5. BRANDING (Watermark & Handle)
  Widget _buildBrandingSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Show Watermark / Handle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            value: widget.theme.showWatermark,
            activeColor: AppColors.primary,
            onChanged: (val) => widget.onThemeChanged(widget.theme.copyWith(showWatermark: val)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: TextEditingController(text: widget.theme.watermarkHandle)
              ..selection = TextSelection.collapsed(offset: widget.theme.watermarkHandle.length),
            decoration: InputDecoration(
              labelText: 'Watermark Handle',
              hintText: 'e.g. @app.quickpost',
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: (val) => widget.onThemeChanged(widget.theme.copyWith(watermarkHandle: val)),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Show Verified Badge', style: TextStyle(fontSize: 12)),
            value: widget.theme.showVerifiedBadge,
            activeColor: AppColors.primary,
            onChanged: (val) => widget.onThemeChanged(widget.theme.copyWith(showVerifiedBadge: val)),
          ),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Show Slide Counter (01 / 07)', style: TextStyle(fontSize: 12)),
            value: widget.theme.showSlideCounter,
            activeColor: AppColors.primary,
            onChanged: (val) => widget.onThemeChanged(widget.theme.copyWith(showSlideCounter: val)),
          ),
        ],
      ),
    );
  }

  // 6. CANVAS (Aspect Ratio & Background)
  Widget _buildCanvasSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Aspect Ratio Preset', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: AspectRatioPreset.values.map((preset) {
              final isSel = widget.theme.aspectRatioPreset == preset;
              return ChoiceChip(
                label: Text(preset.label),
                selected: isSel,
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: isSel ? Colors.white : Colors.black87,
                  fontSize: 11,
                  fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                ),
                onSelected: (_) => widget.onThemeChanged(widget.theme.copyWith(aspectRatioPreset: preset)),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          const Text('Slide Background Color', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _curatedBackgrounds.map((bg) {
              final color = bg['color'] as Color;
              final name = bg['name'] as String;
              final accent = bg['accent'] as Color;
              final isSel = widget.theme.canvasBackgroundColor.value == color.value;
              return GestureDetector(
                onTap: () => widget.onThemeChanged(widget.theme.copyWith(canvasBackgroundColor: color)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSel ? AppColors.primary : (color.computeLuminance() > 0.5 ? Colors.grey.shade300 : Colors.white24),
                      width: isSel ? 2.5 : 1.0,
                    ),
                    boxShadow: [
                      if (isSel) BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 6),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        name,
                        style: TextStyle(
                          color: color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
                          fontSize: 11,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Custom Slide Background Color'),
                  content: AdvancedColorPicker(
                    initialColor: widget.theme.canvasBackgroundColor,
                    onColorChanged: (c) => widget.onThemeChanged(widget.theme.copyWith(canvasBackgroundColor: c)),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.palette_rounded, size: 16),
            label: const Text('Pick Custom Background Color'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'Default Background Brightness: ${(widget.theme.backgroundBrightness * 100).toStringAsFixed(0)}%',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          Slider(
            value: widget.theme.backgroundBrightness.clamp(0.0, 1.0),
            min: 0.0,
            max: 1.0,
            activeColor: AppColors.primary,
            onChanged: (val) => widget.onThemeChanged(widget.theme.copyWith(backgroundBrightness: val)),
          ),
          const SizedBox(height: 12),

          Text(
            'Default Background Blur: ${widget.theme.backgroundBlur.toStringAsFixed(1)}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          Slider(
            value: widget.theme.backgroundBlur.clamp(0.0, 10.0),
            min: 0.0,
            max: 10.0,
            activeColor: AppColors.primary,
            onChanged: (val) => widget.onThemeChanged(widget.theme.copyWith(backgroundBlur: val)),
          ),
        ],
      ),
    );
  }
}
