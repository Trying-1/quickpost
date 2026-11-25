import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../widgets/advanced_color_picker.dart';
import '../../../utils/font_selector.dart';
import '../models/anime_carousel_slide.dart';
import '../models/anime_template_theme.dart';

enum StylingSection {
  all,
  layouts,
  components,
  elementStyles,
  styles,
  card,
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

/// Styling and template theme customization panel.
/// Styled according to the Quick Post light theme.
class ThemeStylingPanel extends StatefulWidget {
  final AnimeTemplateTheme theme;
  final ValueChanged<AnimeTemplateTheme> onThemeChanged;
  final StylingSection section;
  final AnimeCarouselSlide? activeSlide;
  final ValueChanged<SlideLayout>? onSelectSlideLayout;
  final ValueChanged<bool>? onToggleSync;
  final String? activeComponentKey;
  final ValueChanged<String>? onSelectComponent;
  final bool showSelectionOverlay;
  final ValueChanged<bool>? onToggleSelectionOverlay;

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
    this.showSelectionOverlay = true,
    this.onToggleSelectionOverlay,
  });

  @override
  State<ThemeStylingPanel> createState() => _ThemeStylingPanelState();
}

class _ThemeStylingPanelState extends State<ThemeStylingPanel> {
  StyleSubCategory _activeSubCategory = StyleSubCategory.typography;
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
    final available = _availableComponents;
    if (!available.contains(_selectedComponentKey) && available.isNotEmpty) {
      _selectedComponentKey = available.contains(SlideComponentId.title) ? SlideComponentId.title : available.first;
    }
  }

  static const List<Color> _bgColors = [
    Colors.white,              // Pure White (Default)
    Color(0xFFF8F9FA),         // Off-White / Light Snow
    Color(0xFFF1F5F9),         // Slate White
    Color(0xFFFFFBEB),         // Light Warm Cream
    Color(0xFFF5F3FF),         // Light Violet Tint
    Color(0xFFFDF2F8),         // Soft Pink Tint
    Color(0xFF1E293B),         // Dark Slate
    Color(0xFF0F172A),         // Midnight Black
  ];

  static const List<Color> _accentColors = [
    Color(0xFFFF3366), // Crimson Neon
    Color(0xFF8B5CF6), // Royal Violet
    Color(0xFF00E5FF), // Cyber Cyan
    Color(0xFFFFB800), // Electric Gold
    Color(0xFF00E676), // Neon Mint
    Color(0xFFFF5722), // Deep Orange
    Color(0xFFE040FB), // Anime Magenta
    Color(0xFF3D5AFE), // Electric Blue
  ];

  static const List<Color> _cardBgColors = [
    Color(0xFF0D0D12), // Pure Dark Slate (Default)
    Color(0xFF000000), // Pitch Black
    Color(0xFF1E293B), // Slate Blue
    Color(0xFF111827), // Charcoal Gray
    Color(0xFF0F172A), // Midnight Navy
    Color(0xFF2E1065), // Deep Violet
    Color(0xFF1E1B4B), // Indigo Midnight
    Color(0xFF2B0A12), // Deep Crimson Wine
    Colors.white,      // Pure White
    Color(0xFFF1F5F9), // Soft Pearl Gray
  ];

  static const List<Color> _cardBorderColors = [
    Colors.white,             // Crisp White
    Color(0x66FFFFFF),        // Translucent Glass White
    Color(0xFFFF3366),        // Crimson Neon
    Color(0xFF00E5FF),        // Cyber Cyan
    Color(0xFFFFB800),        // Electric Gold
    Color(0xFF8B5CF6),        // Neon Violet
    Color(0xFF00E676),        // Mint Green
    Color(0xFFFF5722),        // Vivid Flame
    Color(0xFF64748B),        // Slate Gray
    Color(0xFF0F172A),        // Midnight Charcoal
    Colors.black,             // Solid Black
  ];

  static const List<Color> _textColorPresets = [
    Colors.white,
    Color(0xFFF8FAFC),
    Color(0xFFCBD5E1),
    Color(0xFF1E293B),
    Color(0xFF0F172A),
    Color(0xFFFF3366),
    Color(0xFF00E5FF),
    Color(0xFFFFB800),
  ];

  @override
  Widget build(BuildContext context) {
    final available = _availableComponents;
    if (!available.contains(_selectedComponentKey) && available.isNotEmpty) {
      _selectedComponentKey = available.contains(SlideComponentId.title) ? SlideComponentId.title : available.first;
    }

    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _buildSectionContent(),
        ),
      ),
    );
  }

  List<Widget> _buildSectionContent() {
    switch (widget.section) {
      case StylingSection.layouts:
        return [
          _buildSectionHeader('Slide Layout Design', Icons.dashboard_customize_rounded),
          const SizedBox(height: 10),
          _buildComponentToggleTile(
            icon: widget.theme.syncAnimeSlideLayoutAndPosition ? Icons.sync_rounded : Icons.sync_disabled_rounded,
            title: 'Same Layout & Positions for All Anime Slides',
            subtitle: widget.theme.syncAnimeSlideLayoutAndPosition
                ? 'Layout and component positioning sync across all anime slides'
                : 'Each anime slide has independent layout and positioning',
            value: widget.theme.syncAnimeSlideLayoutAndPosition,
            onChanged: (val) {
              if (widget.onToggleSync != null) {
                widget.onToggleSync!(val);
              } else {
                widget.onThemeChanged(widget.theme.copyWith(syncAnimeSlideLayoutAndPosition: val));
              }
            },
          ),
          const SizedBox(height: 12),
          _buildSlideLayoutSelector(),
          const SizedBox(height: 16),
        ];

      case StylingSection.components:
        return [
          _buildSectionHeader('Toggle Slide Components', Icons.view_quilt_rounded),
          const SizedBox(height: 4),
          const Text(
            'Turn slide elements ON or OFF to place only what you want on the canvas.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 8),
          _buildDetailComponentsToggles(),
          const SizedBox(height: 16),
        ];

      case StylingSection.elementStyles:
        return [
          _buildElementSelectorRibbon(title: 'Select Element to Style'),
          const SizedBox(height: 12),
          _buildSelectedElementOnlyStyleControls(),
          const SizedBox(height: 16),
        ];

      case StylingSection.card:
        return [
          _buildCardControlsSection(),
          const SizedBox(height: 16),
        ];

      case StylingSection.fonts:
        return [
          _buildElementSelectorRibbon(title: 'Selected Element Typography'),
          const SizedBox(height: 12),
          _buildSelectedElementFontControls(),
          const SizedBox(height: 16),
        ];

      case StylingSection.colors:
        return [
          _buildElementSelectorRibbon(title: 'Selected Element Color'),
          const SizedBox(height: 12),
          _buildSelectedElementColorControls(),
          const SizedBox(height: 16),
        ];

      case StylingSection.styles:
        return [
          _buildSubCategoryTabs(),
          const SizedBox(height: 12),
          _buildActiveSubCategoryContent(),
          const SizedBox(height: 16),
        ];

      case StylingSection.branding:
        return [
          _buildSectionHeader('Brand Watermark & Handle', Icons.verified_rounded),
          const SizedBox(height: 10),
          _buildWatermarkControls(),
          const SizedBox(height: 14),
          Divider(color: Colors.grey.shade200, height: 1),
          const SizedBox(height: 14),
          _buildSectionHeader('Page Handle Style', Icons.badge_rounded),
          const SizedBox(height: 8),
          _buildChipSelector<HandleStyle>(
            label: 'Handle Badge Design',
            values: HandleStyle.values,
            selectedValue: widget.theme.handleStyle,
            getLabel: (h) => h.label,
            onSelected: (h) => widget.onThemeChanged(widget.theme.copyWith(handleStyle: h)),
          ),
          const SizedBox(height: 14),
          Divider(color: Colors.grey.shade200, height: 1),
          const SizedBox(height: 14),
          _buildTextStrokeControls(
            SlideComponentId.pageHandle,
            label: 'Watermark Text',
            defaultStrokeColor: widget.theme.accentColor,
          ),
          const SizedBox(height: 16),
        ];

      case StylingSection.canvas:
        return [
          _buildSectionHeader('Post Aspect Ratio', Icons.aspect_ratio_rounded),
          const SizedBox(height: 8),
          _buildAspectRatioSelector(),
          const SizedBox(height: 14),
          Divider(color: Colors.grey.shade200, height: 1),
          const SizedBox(height: 14),
          _buildSectionHeader('Canvas Background Color', Icons.format_color_fill_rounded),
          const SizedBox(height: 8),
          _buildCanvasBgColorPicker(),
          const SizedBox(height: 14),
          Divider(color: Colors.grey.shade200, height: 1),
          const SizedBox(height: 14),
          _buildSectionHeader('Visual Atmosphere', Icons.tune_rounded),
          const SizedBox(height: 8),
          _buildAtmosphereSliders(),
          const SizedBox(height: 16),
        ];

      case StylingSection.all:
        return [
          _buildSectionHeader('Post Aspect Ratio', Icons.aspect_ratio_rounded),
          const SizedBox(height: 8),
          _buildAspectRatioSelector(),
          const SizedBox(height: 14),
          Divider(color: Colors.grey.shade200, height: 1),
          const SizedBox(height: 14),
          _buildSectionHeader('Slide Layout Design', Icons.dashboard_customize_rounded),
          const SizedBox(height: 8),
          _buildComponentToggleTile(
            icon: widget.theme.syncAnimeSlideLayoutAndPosition ? Icons.sync_rounded : Icons.sync_disabled_rounded,
            title: 'Same Layout & Positions for All Anime Slides',
            subtitle: widget.theme.syncAnimeSlideLayoutAndPosition
                ? 'Layout and component positioning sync across all anime slides'
                : 'Each anime slide has independent layout and positioning',
            value: widget.theme.syncAnimeSlideLayoutAndPosition,
            onChanged: (val) {
              if (widget.onToggleSync != null) {
                widget.onToggleSync!(val);
              } else {
                widget.onThemeChanged(widget.theme.copyWith(syncAnimeSlideLayoutAndPosition: val));
              }
            },
          ),
          const SizedBox(height: 8),
          _buildSlideLayoutSelector(),
          const SizedBox(height: 14),
          Divider(color: Colors.grey.shade200, height: 1),
          const SizedBox(height: 14),
          _buildSectionHeader('Slide Detail Components', Icons.view_quilt_rounded),
          const SizedBox(height: 8),
          _buildDetailComponentsToggles(),
          const SizedBox(height: 14),
          Divider(color: Colors.grey.shade200, height: 1),
          const SizedBox(height: 14),
          _buildSubCategoryTabs(),
          const SizedBox(height: 12),
          _buildActiveSubCategoryContent(),
          const SizedBox(height: 16),
        ];
    }
  }

  // ==================== SUB-CATEGORY NAVIGATION ====================

  Widget _buildSubCategoryTabs() {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          _buildSubTabItem('Typography', Icons.text_fields_rounded, StyleSubCategory.typography),
          _buildSubTabItem('Colors', Icons.palette_rounded, StyleSubCategory.colors),
          _buildSubTabItem('Card & Box', Icons.layers_outlined, StyleSubCategory.card),
          _buildSubTabItem('Elements', Icons.style_rounded, StyleSubCategory.elements),
        ],
      ),
    );
  }

  Widget _buildSubTabItem(String label, IconData icon, StyleSubCategory cat) {
    final isSelected = _activeSubCategory == cat;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeSubCategory = cat),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? AppColors.primary : Colors.grey.shade600,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? AppColors.primary : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveSubCategoryContent() {
    switch (_activeSubCategory) {
      case StyleSubCategory.typography:
        return _buildTypographySection();
      case StyleSubCategory.colors:
        return _buildColorsSection();
      case StyleSubCategory.card:
        return _buildCardControlsSection();
      case StyleSubCategory.elements:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildElementSelectorRibbon(title: 'Select Element to Style'),
            const SizedBox(height: 12),
            _buildSelectedElementOnlyStyleControls(),
          ],
        );
    }
  }

  void _selectComponent(String key) {
    setState(() => _selectedComponentKey = key);
    widget.onSelectComponent?.call(key);
  }

  List<String> get _availableComponents {
    List<String> raw;
    if (widget.activeSlide != null) {
      switch (widget.activeSlide!.type) {
        case SlideType.cover:
          raw = SlideComponentId.coverComponents;
          break;
        case SlideType.cta:
          raw = SlideComponentId.ctaComponents;
          break;
        case SlideType.anime:
          raw = SlideComponentId.animeComponents;
          break;
      }
    } else {
      raw = SlideComponentId.animeComponents;
    }

    final filtered = raw.where((key) {
      if ((widget.section == StylingSection.fonts ||
              widget.section == StylingSection.colors ||
              widget.section == StylingSection.elementStyles ||
              _activeSubCategory == StyleSubCategory.elements) &&
          key == SlideComponentId.allContent) {
        return false;
      }
      if (key == SlideComponentId.swipeIndicator) {
        return false;
      }
      return widget.theme.isComponentEnabledForSlide(key, widget.activeSlide);
    }).toList();

    if (widget.section == StylingSection.elementStyles) {
      return [SlideComponentId.cardBackdrop, ...filtered];
    }
    return filtered;
  }

  IconData _getComponentIcon(String key) {
    switch (key) {
      case SlideComponentId.cardBackdrop:
        return Icons.layers_rounded;
      case SlideComponentId.allContent:
        return Icons.dashboard_rounded;
      case SlideComponentId.title:
        return Icons.title_rounded;
      case SlideComponentId.rankBadge:
        return Icons.military_tech_rounded;
      case SlideComponentId.rating:
        return Icons.star_rounded;
      case SlideComponentId.seasons:
        return Icons.date_range_rounded;
      case SlideComponentId.episodes:
        return Icons.movie_creation_rounded;
      case SlideComponentId.studio:
        return Icons.business_rounded;
      case SlideComponentId.genres:
        return Icons.label_rounded;
      case SlideComponentId.synopsis:
        return Icons.notes_rounded;
      case SlideComponentId.japaneseTitle:
        return Icons.translate_rounded;
      case SlideComponentId.hookTag:
        return Icons.local_fire_department_rounded;
      case SlideComponentId.pageHandle:
        return Icons.branding_watermark_rounded;
      case SlideComponentId.slideCounter:
        return Icons.pin_rounded;
      case SlideComponentId.heroVisual:
        return Icons.image_rounded;
      case SlideComponentId.screenshots:
        return Icons.photo_library_rounded;
      default:
        return Icons.widgets_rounded;
    }
  }

  Widget _buildElementSelectorRibbon({required String title}) {
    final components = _availableComponents;
    if (components.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.onToggleSelectionOverlay != null) ...[
                  Tooltip(
                    message: widget.showSelectionOverlay
                        ? 'Hide selection box in preview'
                        : 'Show selection box in preview',
                    child: InkWell(
                      onTap: () => widget.onToggleSelectionOverlay?.call(!widget.showSelectionOverlay),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: widget.showSelectionOverlay ? Colors.grey.shade100 : AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: widget.showSelectionOverlay ? Colors.grey.shade300 : AppColors.primaryDark,
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.showSelectionOverlay ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                              size: 11,
                              color: widget.showSelectionOverlay ? Colors.grey.shade700 : Colors.white,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              widget.showSelectionOverlay ? 'Box' : 'Clean',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: widget.showSelectionOverlay ? Colors.grey.shade700 : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_getComponentIcon(_selectedComponentKey), size: 12, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        SlideComponentId.getLabel(_selectedComponentKey),
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: components.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final key = components[index];
              final isSelected = _selectedComponentKey == key;
              final label = SlideComponentId.getLabel(key);
              final icon = _getComponentIcon(key);

              return GestureDetector(
                onTap: () => _selectComponent(key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Colors.grey.shade300,
                      width: isSelected ? 1.5 : 0.8,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.25),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 13,
                        color: isSelected ? Colors.white : Colors.grey.shade700,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildElementFontSelector({
    required String label,
    required String currentFontFamily,
    required ValueChanged<String> onFontSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12.5,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 6),
        HorizontalFontSelector(
          selectedFont: FontInfo.getFontByFamily(currentFontFamily) ??
              FontInfo(family: currentFontFamily, displayName: currentFontFamily),
          onFontSelected: (font) => onFontSelected(font.family),
        ),
      ],
    );
  }

  Widget _buildSelectedElementFontControls() {
    final currentFont = widget.theme.getFontForComponent(_selectedComponentKey);
    final compName = SlideComponentId.getLabel(_selectedComponentKey);

    switch (_selectedComponentKey) {
      case SlideComponentId.title:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildElementFontSelector(
              label: 'Anime Title Font Style',
              currentFontFamily: currentFont,
              onFontSelected: (fam) => widget.onThemeChanged(widget.theme.copyWithComponentFont(SlideComponentId.title, fam)),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Title Font Size', style: TextStyle(color: AppColors.textPrimary, fontSize: 12)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(6)),
                  child: Text('${widget.theme.titleFontSize.toInt()}px', style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            Slider(
              value: widget.theme.titleFontSize.clamp(14.0, 36.0),
              min: 14.0,
              max: 36.0,
              activeColor: AppColors.primary,
              inactiveColor: Colors.grey.shade200,
              onChanged: (val) => widget.onThemeChanged(widget.theme.copyWith(titleFontSize: val)),
            ),
            const SizedBox(height: 6),
            const Text('Title Font Weight', style: TextStyle(color: AppColors.textPrimary, fontSize: 11.5, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            _buildFontWeightChips(),
            const SizedBox(height: 14),
            Divider(color: Colors.grey.shade200, height: 1),
            const SizedBox(height: 12),
            _buildChipSelector<TitleCardStyle>(
              label: 'Title Card Style',
              values: TitleCardStyle.values,
              selectedValue: widget.theme.titleCardStyle,
              getLabel: (t) => t.label,
              onSelected: (t) => widget.onThemeChanged(widget.theme.copyWith(titleCardStyle: t)),
            ),
            const SizedBox(height: 14),
            Divider(color: Colors.grey.shade200, height: 1),
            const SizedBox(height: 12),
            _buildTextStrokeControls(
              SlideComponentId.title,
              label: 'Title Text',
              defaultStrokeColor: widget.theme.accentColor,
            ),
          ],
        );

      case SlideComponentId.synopsis:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildElementFontSelector(
              label: 'Synopsis Font Style',
              currentFontFamily: currentFont,
              onFontSelected: (fam) => widget.onThemeChanged(widget.theme.copyWithComponentFont(SlideComponentId.synopsis, fam)),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Synopsis Font Size', style: TextStyle(color: AppColors.textPrimary, fontSize: 12)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(6)),
                  child: Text('${widget.theme.bodyFontSize.toStringAsFixed(1)}px', style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            Slider(
              value: widget.theme.bodyFontSize.clamp(9.0, 18.0),
              min: 9.0,
              max: 18.0,
              divisions: 18,
              activeColor: AppColors.primary,
              inactiveColor: Colors.grey.shade200,
              onChanged: (val) => widget.onThemeChanged(widget.theme.copyWith(bodyFontSize: val)),
            ),
            const SizedBox(height: 14),
            Divider(color: Colors.grey.shade200, height: 1),
            const SizedBox(height: 12),
            _buildChipSelector<SynopsisCardStyle>(
              label: 'Synopsis Card Style',
              values: SynopsisCardStyle.values,
              selectedValue: widget.theme.synopsisCardStyle,
              getLabel: (s) => s.label,
              onSelected: (s) => widget.onThemeChanged(widget.theme.copyWith(synopsisCardStyle: s)),
            ),
          ],
        );

      case SlideComponentId.rankBadge:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildElementFontSelector(
              label: 'Rank Badge Font Style',
              currentFontFamily: currentFont,
              onFontSelected: (fam) => widget.onThemeChanged(widget.theme.copyWithComponentFont(SlideComponentId.rankBadge, fam)),
            ),
            const SizedBox(height: 14),
            Divider(color: Colors.grey.shade200, height: 1),
            const SizedBox(height: 12),
            _buildChipSelector<RankBadgeStyle>(
              label: 'Rank Badge Card Style',
              values: RankBadgeStyle.values,
              selectedValue: widget.theme.rankBadgeStyle,
              getLabel: (r) => r.label,
              onSelected: (r) => widget.onThemeChanged(widget.theme.copyWith(rankBadgeStyle: r)),
            ),
          ],
        );

      case SlideComponentId.rating:
      case SlideComponentId.seasons:
      case SlideComponentId.episodes:
      case SlideComponentId.studio:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildElementFontSelector(
              label: '$compName Font Style',
              currentFontFamily: currentFont,
              onFontSelected: (fam) => widget.onThemeChanged(widget.theme.copyWithComponentFont(_selectedComponentKey, fam)),
            ),
            const SizedBox(height: 14),
            Divider(color: Colors.grey.shade200, height: 1),
            const SizedBox(height: 12),
            _buildChipSelector<MetadataPillStyle>(
              label: 'Metadata Cards Style ($compName)',
              values: MetadataPillStyle.values,
              selectedValue: widget.theme.metadataPillStyle,
              getLabel: (m) => m.label,
              onSelected: (m) => widget.onThemeChanged(widget.theme.copyWith(metadataPillStyle: m)),
            ),
          ],
        );

      case SlideComponentId.genres:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildElementFontSelector(
              label: 'Genres Font Style',
              currentFontFamily: currentFont,
              onFontSelected: (fam) => widget.onThemeChanged(widget.theme.copyWithComponentFont(SlideComponentId.genres, fam)),
            ),
            const SizedBox(height: 14),
            Divider(color: Colors.grey.shade200, height: 1),
            const SizedBox(height: 12),
            _buildChipSelector<GenreStyle>(
              label: 'Genres Display Style',
              values: GenreStyle.values,
              selectedValue: widget.theme.genreStyle,
              getLabel: (g) => g.label,
              onSelected: (g) => widget.onThemeChanged(widget.theme.copyWith(genreStyle: g)),
            ),
          ],
        );

      case SlideComponentId.pageHandle:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildElementFontSelector(
              label: 'Watermark Font Style',
              currentFontFamily: currentFont,
              onFontSelected: (fam) => widget.onThemeChanged(widget.theme.copyWithComponentFont(SlideComponentId.pageHandle, fam)),
            ),
            const SizedBox(height: 14),
            Divider(color: Colors.grey.shade200, height: 1),
            const SizedBox(height: 12),
            _buildChipSelector<HandleStyle>(
              label: 'Watermark Handle Style',
              values: HandleStyle.values,
              selectedValue: widget.theme.handleStyle,
              getLabel: (h) => h.label,
              onSelected: (h) => widget.onThemeChanged(widget.theme.copyWith(handleStyle: h)),
            ),
            const SizedBox(height: 14),
            Divider(color: Colors.grey.shade200, height: 1),
            const SizedBox(height: 12),
            _buildTextStrokeControls(
              SlideComponentId.pageHandle,
              label: 'Watermark Text',
              defaultStrokeColor: widget.theme.accentColor,
            ),
          ],
        );

      case SlideComponentId.slideCounter:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildElementFontSelector(
              label: 'Slide Counter Font Style',
              currentFontFamily: currentFont,
              onFontSelected: (fam) => widget.onThemeChanged(widget.theme.copyWithComponentFont(SlideComponentId.slideCounter, fam)),
            ),
            const SizedBox(height: 14),
            Divider(color: Colors.grey.shade200, height: 1),
            const SizedBox(height: 12),
            _buildChipSelector<SlideCounterStyle>(
              label: 'Slide Counter Style',
              values: SlideCounterStyle.values,
              selectedValue: widget.theme.counterStyle,
              getLabel: (c) => c.label,
              onSelected: (c) => widget.onThemeChanged(widget.theme.copyWith(counterStyle: c)),
            ),
          ],
        );

      case SlideComponentId.hookTag:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildElementFontSelector(
              label: 'Hook Tag Font Style',
              currentFontFamily: currentFont,
              onFontSelected: (fam) => widget.onThemeChanged(widget.theme.copyWithComponentFont(SlideComponentId.hookTag, fam)),
            ),
            const SizedBox(height: 14),
            Divider(color: Colors.grey.shade200, height: 1),
            const SizedBox(height: 12),
            _buildChipSelector<HookTagStyle>(
              label: 'Hook / Category Tag Style',
              values: HookTagStyle.values,
              selectedValue: widget.theme.tagStyle,
              getLabel: (t) => t.label,
              onSelected: (t) => widget.onThemeChanged(widget.theme.copyWith(tagStyle: t)),
            ),
            const SizedBox(height: 14),
            Divider(color: Colors.grey.shade200, height: 1),
            const SizedBox(height: 12),
            _buildTextStrokeControls(
              SlideComponentId.hookTag,
              label: 'Hook Tag Text',
              defaultStrokeColor: widget.theme.accentColor,
            ),
          ],
        );

      case SlideComponentId.japaneseTitle:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildElementFontSelector(
              label: 'Japanese Title Font Style',
              currentFontFamily: currentFont,
              onFontSelected: (fam) => widget.onThemeChanged(widget.theme.copyWithComponentFont(SlideComponentId.japaneseTitle, fam)),
            ),
            const SizedBox(height: 14),
            Divider(color: Colors.grey.shade200, height: 1),
            const SizedBox(height: 12),
            _buildTextStrokeControls(
              SlideComponentId.japaneseTitle,
              label: 'Japanese Title Text',
              defaultStrokeColor: widget.theme.accentColor,
            ),
          ],
        );

      default:
        return _buildTypographySection();
    }
  }

  Widget _buildSelectedElementColorControls() {
    switch (_selectedComponentKey) {
      case SlideComponentId.title:
        return _buildSingleColorItem(
          label: 'Anime Title Text Color',
          currentColor: widget.theme.getColorForComponent(SlideComponentId.title),
          allowAuto: true,
          pickerTitle: 'Select Title Text Color',
          onColorChanged: (c) {
            widget.onThemeChanged(widget.theme.copyWithComponentColor(SlideComponentId.title, c));
          },
        );

      case SlideComponentId.synopsis:
        return _buildSingleColorItem(
          label: 'Synopsis Text Color',
          currentColor: widget.theme.getColorForComponent(SlideComponentId.synopsis),
          allowAuto: true,
          pickerTitle: 'Select Synopsis Text Color',
          onColorChanged: (c) {
            widget.onThemeChanged(widget.theme.copyWithComponentColor(SlideComponentId.synopsis, c));
          },
        );

      case SlideComponentId.allContent:
        return _buildSingleColorItem(
          label: 'Card Container Color',
          currentColor: widget.theme.cardBgColor,
          allowAuto: false,
          pickerTitle: 'Select Card Background Color',
          onColorChanged: (c) {
            if (c != null) {
              widget.onThemeChanged(widget.theme.copyWith(cardBgColor: c));
            }
          },
        );

      case SlideComponentId.rankBadge:
      case SlideComponentId.rating:
      case SlideComponentId.seasons:
      case SlideComponentId.episodes:
      case SlideComponentId.studio:
      case SlideComponentId.genres:
      case SlideComponentId.pageHandle:
      case SlideComponentId.slideCounter:
      case SlideComponentId.hookTag:
      case SlideComponentId.japaneseTitle:
      default:
        final compName = SlideComponentId.getLabel(_selectedComponentKey);
        final defaultColor = _selectedComponentKey == SlideComponentId.rating
            ? const Color(0xFFFFB800)
            : widget.theme.accentColor;
        return _buildSingleColorItem(
          label: '$compName Color',
          currentColor: widget.theme.getColorForComponent(_selectedComponentKey, defaultColor: defaultColor),
          allowAuto: false,
          pickerTitle: 'Select $compName Color',
          onColorChanged: (c) {
            if (c != null) {
              widget.onThemeChanged(widget.theme.copyWithComponentColor(_selectedComponentKey, c));
            }
          },
        );
    }
  }

  Widget _buildSingleColorItem({
    required String label,
    required Color? currentColor,
    required bool allowAuto,
    required String pickerTitle,
    required ValueChanged<Color?> onColorChanged,
  }) {
    const List<Color> displayColors = [
      Colors.white,
      Colors.black,
      Color(0xFF6C63FF),
      Color(0xFFFF5F6D),
      Color(0xFF1CB5E0),
      Color(0xFF00C9FF),
      Color(0xFF92FE9D),
      Color(0xFFFF9A8B),
      Color(0xFFFDCB6E),
      Color(0xFFE84393),
      Color(0xFFEB4D4B),
      Color(0xFF6AB04C),
      Color(0xFFF0932B),
      Color(0xFFFF3366),
      Color(0xFFFFB800),
      Color(0xFF00E676),
      Color(0xFF2979FF),
      Color(0xFFAA00FF),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // Custom Color Button (identical to video_watermark_screen and other screens)
              GestureDetector(
                onTap: () async {
                  Color selectedColor = currentColor ?? Colors.white;
                  await showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(pickerTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      content: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AdvancedColorPicker(
                              initialColor: selectedColor,
                              onColorChanged: (color) => selectedColor = color,
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  onColorChanged(selectedColor);
                                  Navigator.pop(context);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6C63FF),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('SELECT COLOR', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 35,
                  height: 35,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300, width: 2),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                  ),
                  child: const Icon(Icons.colorize_rounded, size: 18, color: Colors.black54),
                ),
              ),

              // Auto Contrast pill (for text elements)
              if (allowAuto) ...[
                GestureDetector(
                  onTap: () => onColorChanged(null),
                  child: Container(
                    height: 35,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    margin: const EdgeInsets.only(right: 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: currentColor == null ? AppColors.primarySurface : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: currentColor == null ? AppColors.primary : Colors.grey.shade300,
                        width: currentColor == null ? 2.0 : 1.0,
                      ),
                    ),
                    child: Text(
                      'Auto Contrast',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: currentColor == null ? FontWeight.bold : FontWeight.w500,
                        color: currentColor == null ? AppColors.primaryDark : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],

              // Standard color circle swatches
              ...displayColors.map((c) {
                final isSelected = currentColor != null && currentColor.toARGB32() == c.toARGB32();
                final isLight = c.computeLuminance() > 0.5;
                return GestureDetector(
                  onTap: () => onColorChanged(c),
                  child: Container(
                    width: 35,
                    height: 35,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? const Color(0xFF6C63FF) : Colors.grey.shade300,
                        width: isSelected ? 2.5 : 1.0,
                      ),
                      boxShadow: isSelected
                          ? [BoxShadow(color: const Color(0xFF6C63FF).withValues(alpha: 0.35), blurRadius: 6, spreadRadius: 1)]
                          : const [BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1))],
                    ),
                    child: isSelected
                        ? Icon(Icons.check, size: 18, color: isLight ? Colors.black87 : Colors.white)
                        : null,
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== 1. TYPOGRAPHY CONTROLS ====================

  Widget _buildTypographySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildElementFontSelector(
          label: 'Title Font Style (Global Default)',
          currentFontFamily: widget.theme.titleFontFamily,
          onFontSelected: (fam) => widget.onThemeChanged(widget.theme.copyWith(titleFontFamily: fam)),
        ),
        const SizedBox(height: 14),
        _buildElementFontSelector(
          label: 'Body / Metadata Font Style (Global Default)',
          currentFontFamily: widget.theme.bodyFontFamily,
          onFontSelected: (fam) => widget.onThemeChanged(widget.theme.copyWith(bodyFontFamily: fam)),
        ),
        const SizedBox(height: 14),
        Divider(color: Colors.grey.shade200, height: 1),
        const SizedBox(height: 12),

        // Title Font Size Slider
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Title Font Size', style: TextStyle(color: AppColors.textPrimary, fontSize: 12)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(6)),
              child: Text(
                '${widget.theme.titleFontSize.toInt()}px',
                style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        Slider(
          value: widget.theme.titleFontSize.clamp(14.0, 36.0),
          min: 14.0,
          max: 36.0,
          activeColor: AppColors.primary,
          inactiveColor: Colors.grey.shade200,
          onChanged: (val) => widget.onThemeChanged(widget.theme.copyWith(titleFontSize: val)),
        ),

        // Title Font Weight
        const Text(
          'Title Font Weight',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 11.5, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        _buildFontWeightChips(),
        const SizedBox(height: 12),

        // Body Font Size Slider
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Body / Synopsis Font Size', style: TextStyle(color: AppColors.textPrimary, fontSize: 12)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(6)),
              child: Text(
                '${widget.theme.bodyFontSize.toStringAsFixed(1)}px',
                style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        Slider(
          value: widget.theme.bodyFontSize.clamp(9.0, 18.0),
          min: 9.0,
          max: 18.0,
          activeColor: AppColors.primary,
          inactiveColor: Colors.grey.shade200,
          onChanged: (val) => widget.onThemeChanged(widget.theme.copyWith(bodyFontSize: val)),
        ),
      ],
    );
  }

  Widget _buildFontWeightChips() {
    final weights = [
      {'label': 'Regular', 'weight': FontWeight.w400},
      {'label': 'SemiBold', 'weight': FontWeight.w600},
      {'label': 'Bold', 'weight': FontWeight.w700},
      {'label': 'ExtraBold', 'weight': FontWeight.w800},
      {'label': 'Black', 'weight': FontWeight.w900},
    ];

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: weights.map((w) {
        final weight = w['weight'] as FontWeight;
        final label = w['label'] as String;
        final isSelected = widget.theme.titleFontWeight == weight;
        return GestureDetector(
          onTap: () => widget.onThemeChanged(widget.theme.copyWith(titleFontWeight: weight)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primarySurface : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.grey.shade300,
                width: isSelected ? 1.5 : 0.8,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: weight,
                color: isSelected ? AppColors.primaryDark : AppColors.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ==================== 2. COLORS CONTROLS ====================

  Widget _buildColorsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title Text Color
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Title Text Color', style: TextStyle(color: AppColors.textPrimary, fontSize: 11.5, fontWeight: FontWeight.bold)),
            _buildCustomColorPickerButton(
              currentColor: widget.theme.titleTextColor ?? Colors.white,
              onColorChanged: (c) => widget.onThemeChanged(widget.theme.copyWith(titleTextColor: c)),
              pickerTitle: 'Select Title Text Color',
            ),
          ],
        ),
        const SizedBox(height: 6),
        _buildTextColorPalette(
          selectedColor: widget.theme.titleTextColor,
          allowAuto: true,
          onSelected: (c) {
            if (c == null) {
              widget.onThemeChanged(widget.theme.copyWith(clearTitleTextColor: true));
            } else {
              widget.onThemeChanged(widget.theme.copyWith(titleTextColor: c));
            }
          },
        ),
        const SizedBox(height: 14),
        Divider(color: Colors.grey.shade200, height: 1),
        const SizedBox(height: 12),

        // Body Text Color
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Body / Details Text Color', style: TextStyle(color: AppColors.textPrimary, fontSize: 11.5, fontWeight: FontWeight.bold)),
            _buildCustomColorPickerButton(
              currentColor: widget.theme.bodyTextColor ?? Colors.white70,
              onColorChanged: (c) => widget.onThemeChanged(widget.theme.copyWith(bodyTextColor: c)),
              pickerTitle: 'Select Body Text Color',
            ),
          ],
        ),
        const SizedBox(height: 6),
        _buildTextColorPalette(
          selectedColor: widget.theme.bodyTextColor,
          allowAuto: true,
          onSelected: (c) {
            if (c == null) {
              widget.onThemeChanged(widget.theme.copyWith(clearBodyTextColor: true));
            } else {
              widget.onThemeChanged(widget.theme.copyWith(bodyTextColor: c));
            }
          },
        ),
        const SizedBox(height: 14),
        Divider(color: Colors.grey.shade200, height: 1),
        const SizedBox(height: 12),

        // Accent Color
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Theme Accent Color', style: TextStyle(color: AppColors.textPrimary, fontSize: 11.5, fontWeight: FontWeight.bold)),
            _buildCustomColorPickerButton(
              currentColor: widget.theme.accentColor,
              onColorChanged: (c) => widget.onThemeChanged(widget.theme.copyWith(accentColor: c)),
              pickerTitle: 'Select Accent Color',
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildAccentColorPicker(),
        const SizedBox(height: 14),
        Divider(color: Colors.grey.shade200, height: 1),
        const SizedBox(height: 12),

        // Canvas Background Color
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Canvas Background Color', style: TextStyle(color: AppColors.textPrimary, fontSize: 11.5, fontWeight: FontWeight.bold)),
            _buildCustomColorPickerButton(
              currentColor: widget.theme.canvasBgColor,
              onColorChanged: (c) => widget.onThemeChanged(widget.theme.copyWith(canvasBgColor: c)),
              pickerTitle: 'Select Canvas Background Color',
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildCanvasBgColorPicker(),
      ],
    );
  }

  Widget _buildTextColorPalette({
    required Color? selectedColor,
    required bool allowAuto,
    required ValueChanged<Color?> onSelected,
  }) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          if (allowAuto) ...[
            GestureDetector(
              onTap: () => onSelected(null),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: selectedColor == null ? AppColors.primarySurface : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selectedColor == null ? AppColors.primary : Colors.grey.shade300,
                    width: selectedColor == null ? 1.5 : 0.8,
                  ),
                ),
                child: Center(
                  child: Text(
                    'Auto Contrast',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: selectedColor == null ? FontWeight.bold : FontWeight.normal,
                      color: selectedColor == null ? AppColors.primaryDark : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ],
          ..._textColorPresets.map((color) {
            final isSelected = selectedColor?.toARGB32() == color.toARGB32();
            final isLight = color.computeLuminance() > 0.5;
            return GestureDetector(
              onTap: () => onSelected(color),
              child: Container(
                width: 32,
                height: 32,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.grey.shade300,
                    width: isSelected ? 2.5 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 1)),
                  ],
                ),
                child: isSelected
                    ? Icon(Icons.check, size: 16, color: isLight ? Colors.black87 : Colors.white)
                    : null,
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCustomColorPickerButton({
    required Color currentColor,
    required ValueChanged<Color> onColorChanged,
    required String pickerTitle,
  }) {
    return TextButton.icon(
      onPressed: () => _openColorPickerDialog(
        context: context,
        title: pickerTitle,
        initialColor: currentColor,
        onColorChanged: onColorChanged,
      ),
      icon: const Icon(Icons.colorize_rounded, size: 14),
      label: const Text('Custom Picker', style: TextStyle(fontSize: 11)),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }

  // ==================== 3. CARD & BOX CONTROLS ====================

  Widget _buildCardControlsSection() {
    final hasCard = widget.theme.showCardBackdrop && widget.theme.cardStyle != CardStyle.none;
    final hasBorder = widget.theme.showCardBorder && widget.theme.cardBorderWidth > 0;
    final effectiveBorderColor = widget.theme.cardBorderColor ?? widget.theme.accentColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quick Card Style Presets Row
        const Text(
          'Quick Card Presets',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildQuickCardPresetPill(
                label: 'Frosted Glass',
                icon: Icons.blur_on_rounded,
                isSelected: hasCard && widget.theme.cardStyle == CardStyle.glassmorphismBottom,
                onTap: () {
                  widget.onThemeChanged(widget.theme.copyWith(
                    showCardBackdrop: true,
                    cardStyle: CardStyle.glassmorphismBottom,
                    cardBgColor: const Color(0xFF0D0D12),
                    cardOpacity: 0.85,
                    cardBlur: 14.0,
                    cardBorderRadius: 18.0,
                    showCardBorder: true,
                    cardBorderWidth: 1.0,
                    cardBorderColor: const Color(0x66FFFFFF),
                  ));
                },
              ),
              const SizedBox(width: 8),
              _buildQuickCardPresetPill(
                label: 'Cyber Neon',
                icon: Icons.electric_bolt_rounded,
                isSelected: hasCard && widget.theme.cardStyle == CardStyle.neonCyberpunk,
                onTap: () {
                  widget.onThemeChanged(widget.theme.copyWith(
                    showCardBackdrop: true,
                    cardStyle: CardStyle.neonCyberpunk,
                    cardBgColor: const Color(0xFF0D0D12),
                    cardOpacity: 0.90,
                    cardBlur: 8.0,
                    cardBorderRadius: 16.0,
                    showCardBorder: true,
                    cardBorderWidth: 2.0,
                    cardBorderColor: widget.theme.accentColor,
                  ));
                },
              ),
              const SizedBox(width: 8),
              _buildQuickCardPresetPill(
                label: 'Clean Minimal',
                icon: Icons.crop_square_rounded,
                isSelected: hasCard && widget.theme.cardStyle == CardStyle.cleanMinimalCenter,
                onTap: () {
                  widget.onThemeChanged(widget.theme.copyWith(
                    showCardBackdrop: true,
                    cardStyle: CardStyle.cleanMinimalCenter,
                    cardBgColor: const Color(0xFF1E293B),
                    cardOpacity: 0.92,
                    cardBlur: 0.0,
                    cardBorderRadius: 14.0,
                    showCardBorder: true,
                    cardBorderWidth: 1.0,
                    cardBorderColor: const Color(0x44FFFFFF),
                  ));
                },
              ),
              const SizedBox(width: 8),
              _buildQuickCardPresetPill(
                label: 'Editorial Mag',
                icon: Icons.view_sidebar_rounded,
                isSelected: hasCard && widget.theme.cardStyle == CardStyle.editorialMagazine,
                onTap: () {
                  widget.onThemeChanged(widget.theme.copyWith(
                    showCardBackdrop: true,
                    cardStyle: CardStyle.editorialMagazine,
                    cardBgColor: const Color(0xFF111827),
                    cardOpacity: 0.95,
                    cardBlur: 0.0,
                    cardBorderRadius: 8.0,
                    showCardBorder: true,
                    cardBorderWidth: 1.5,
                    cardBorderColor: widget.theme.accentColor,
                  ));
                },
              ),
              const SizedBox(width: 8),
              _buildQuickCardPresetPill(
                label: 'Pitch Black',
                icon: Icons.dark_mode_rounded,
                isSelected: hasCard && widget.theme.cardBgColor == const Color(0xFF000000),
                onTap: () {
                  widget.onThemeChanged(widget.theme.copyWith(
                    showCardBackdrop: true,
                    cardStyle: CardStyle.cleanMinimalCenter,
                    cardBgColor: const Color(0xFF000000),
                    cardOpacity: 1.0,
                    cardBlur: 0.0,
                    cardBorderRadius: 16.0,
                    showCardBorder: true,
                    cardBorderWidth: 1.5,
                    cardBorderColor: Colors.white,
                  ));
                },
              ),
              const SizedBox(width: 8),
              _buildQuickCardPresetPill(
                label: 'No Card (Clean)',
                icon: Icons.visibility_off_rounded,
                isSelected: !hasCard,
                onTap: () {
                  widget.onThemeChanged(widget.theme.copyWith(
                    showCardBackdrop: false,
                    cardStyle: CardStyle.none,
                  ));
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Divider(color: Colors.grey.shade200, height: 1),
        const SizedBox(height: 12),

        // Master Card Behind Toggle
        _buildComponentToggleTile(
          icon: Icons.layers_rounded,
          title: 'Card Behind Details (Backdrop)',
          subtitle: 'Frames anime episode & synopsis inside a stylized backdrop container',
          value: hasCard,
          onChanged: (val) {
            widget.onThemeChanged(widget.theme.copyWith(
              showCardBackdrop: val,
              cardStyle: val
                  ? (widget.theme.cardStyle == CardStyle.none ? CardStyle.glassmorphismBottom : widget.theme.cardStyle)
                  : CardStyle.none,
            ));
          },
        ),
        const SizedBox(height: 12),

        if (!hasCard)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 18, color: Colors.amber.shade800),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Clean canvas mode active: Episode text and details float directly over the artwork without a card behind. Turn on the toggle above to configure backdrop card design.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.amber.shade900,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          )
        else ...[
          // Card Style Preset Chips
          _buildChipSelector<CardStyle>(
            label: 'Card Visual Style Preset',
            values: CardStyle.values,
            selectedValue: widget.theme.cardStyle,
            getLabel: (c) => c.label,
            onSelected: (c) => widget.onThemeChanged(widget.theme.copyWith(
              cardStyle: c,
              showCardBackdrop: c != CardStyle.none,
            )),
          ),
          const SizedBox(height: 14),
          Divider(color: Colors.grey.shade200, height: 1),
          const SizedBox(height: 12),

          // Card Background Color
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    'Card Background Color',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: widget.theme.cardBgColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade300, width: 1),
                    ),
                  ),
                ],
              ),
              _buildCustomColorPickerButton(
                currentColor: widget.theme.cardBgColor,
                onColorChanged: (c) => widget.onThemeChanged(widget.theme.copyWith(cardBgColor: c)),
                pickerTitle: 'Select Card Background Color',
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _cardBgColors.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final color = _cardBgColors[index];
                final isSelected = widget.theme.cardBgColor.toARGB32() == color.toARGB32();
                final isLight = color.computeLuminance() > 0.5;
                return GestureDetector(
                  onTap: () => widget.onThemeChanged(widget.theme.copyWith(cardBgColor: color)),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? AppColors.primary : Colors.grey.shade300,
                        width: isSelected ? 2.5 : 1,
                      ),
                    ),
                    child: isSelected
                        ? Icon(Icons.check, size: 16, color: isLight ? Colors.black87 : Colors.white)
                        : null,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),

          // Card Opacity Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Card Background Opacity', style: TextStyle(color: AppColors.textPrimary, fontSize: 12)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${(widget.theme.cardOpacity * 100).toInt()}%',
                  style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          Slider(
            value: widget.theme.cardOpacity.clamp(0.0, 1.0),
            min: 0.0,
            max: 1.0,
            activeColor: AppColors.primary,
            inactiveColor: Colors.grey.shade200,
            onChanged: (val) => widget.onThemeChanged(widget.theme.copyWith(cardOpacity: val)),
          ),

          // Card Corner Radius Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Card Corner Radius', style: TextStyle(color: AppColors.textPrimary, fontSize: 12)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${widget.theme.cardBorderRadius.toInt()}px',
                  style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          Slider(
            value: widget.theme.cardBorderRadius.clamp(0.0, 32.0),
            min: 0.0,
            max: 32.0,
            activeColor: AppColors.primary,
            inactiveColor: Colors.grey.shade200,
            onChanged: (val) => widget.onThemeChanged(widget.theme.copyWith(cardBorderRadius: val)),
          ),

          // Card Blur Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Card Backdrop Blur (Frosted Glass)', style: TextStyle(color: AppColors.textPrimary, fontSize: 12)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${widget.theme.cardBlur.toInt()}px',
                  style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          Slider(
            value: widget.theme.cardBlur.clamp(0.0, 30.0),
            min: 0.0,
            max: 30.0,
            activeColor: AppColors.primary,
            inactiveColor: Colors.grey.shade200,
            onChanged: (val) => widget.onThemeChanged(widget.theme.copyWith(cardBlur: val)),
          ),

          const SizedBox(height: 10),
          Divider(color: Colors.grey.shade200, height: 1),
          const SizedBox(height: 12),

          // Card Border Toggle
          _buildComponentToggleTile(
            icon: Icons.border_outer_rounded,
            title: 'Card Border Outline',
            subtitle: 'Surround the card container with a crisp or neon border',
            value: hasBorder,
            onChanged: (val) {
              widget.onThemeChanged(widget.theme.copyWith(
                showCardBorder: val,
                cardBorderWidth: val && widget.theme.cardBorderWidth <= 0 ? 1.0 : widget.theme.cardBorderWidth,
              ));
            },
          ),

          if (hasBorder) ...[
            const SizedBox(height: 10),

            // Card Border Color Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'Card Border Color',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: effectiveBorderColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade300, width: 1),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (widget.theme.cardBorderColor != null)
                      TextButton(
                        onPressed: () => widget.onThemeChanged(widget.theme.copyWith(clearCardBorderColor: true)),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey.shade600,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                        child: const Text('Reset', style: TextStyle(fontSize: 11)),
                      ),
                    _buildCustomColorPickerButton(
                      currentColor: effectiveBorderColor,
                      onColorChanged: (c) => widget.onThemeChanged(widget.theme.copyWith(cardBorderColor: c)),
                      pickerTitle: 'Select Card Border Color',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Border color swatches (including theme accent color)
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  // Accent Color Swatch (Matches Theme Accent)
                  GestureDetector(
                    onTap: () => widget.onThemeChanged(widget.theme.copyWith(clearCardBorderColor: true)),
                    child: Tooltip(
                      message: 'Match Theme Accent',
                      child: Container(
                        width: 32,
                        height: 32,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: widget.theme.accentColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: widget.theme.cardBorderColor == null ? AppColors.primary : Colors.grey.shade300,
                            width: widget.theme.cardBorderColor == null ? 2.5 : 1,
                          ),
                        ),
                        child: widget.theme.cardBorderColor == null
                            ? const Icon(Icons.star, size: 14, color: Colors.white)
                            : null,
                      ),
                    ),
                  ),
                  ...List.generate(_cardBorderColors.length, (index) {
                    final color = _cardBorderColors[index];
                    final isSelected = widget.theme.cardBorderColor?.toARGB32() == color.toARGB32();
                    final isLight = color.computeLuminance() > 0.5;
                    return GestureDetector(
                      onTap: () => widget.onThemeChanged(widget.theme.copyWith(cardBorderColor: color)),
                      child: Container(
                        width: 32,
                        height: 32,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? AppColors.primary : Colors.grey.shade300,
                            width: isSelected ? 2.5 : 1,
                          ),
                        ),
                        child: isSelected
                            ? Icon(Icons.check, size: 16, color: isLight ? Colors.black87 : Colors.white)
                            : null,
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Card Border Width Slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Card Border Width', style: TextStyle(color: AppColors.textPrimary, fontSize: 12)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${widget.theme.cardBorderWidth.toStringAsFixed(1)}px',
                    style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            Slider(
              value: widget.theme.cardBorderWidth.clamp(0.5, 6.0),
              min: 0.5,
              max: 6.0,
              divisions: 11, // 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0, 5.5, 6.0
              activeColor: AppColors.primary,
              inactiveColor: Colors.grey.shade200,
              onChanged: (val) => widget.onThemeChanged(widget.theme.copyWith(cardBorderWidth: val)),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildQuickCardPresetPill({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primarySurface : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? AppColors.primary : Colors.grey.shade700,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 4. ELEMENT STYLES CONTROLS ====================

  Widget _buildTextStrokeControls(
    String componentKey, {
    required String label,
    Color? defaultStrokeColor,
  }) {
    final strokeOnly = widget.theme.isTextStrokeOnly(componentKey);
    final strokeWidth = widget.theme.getTextStrokeWidth(componentKey, defaultWidth: strokeOnly ? 1.5 : 0.0);
    final strokeColor = widget.theme.getTextStrokeColor(
      componentKey,
      defaultColor: defaultStrokeColor ?? widget.theme.accentColor,
    );
    final hasCustomStroke = widget.theme.componentTextStrokeOnly.containsKey(componentKey) ||
        widget.theme.componentTextStrokeWidths.containsKey(componentKey) ||
        widget.theme.componentTextStrokeColors.containsKey(componentKey);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title: Text(
            "Text Fill ${strokeOnly ? '(Outline only)' : '(Solid)'}",
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          subtitle: Text(
            strokeOnly
                ? 'Hollow text (center transparent, outline stroke only)'
                : 'Solid filled text',
            style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
          ),
          value: !strokeOnly,
          activeThumbColor: AppColors.primary,
          contentPadding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          onChanged: (fillOn) {
            final newStrokeOnly = !fillOn;
            var newTheme = widget.theme.copyWithComponentTextStrokeOnly(componentKey, newStrokeOnly);
            if (newStrokeOnly && strokeWidth <= 0) {
              newTheme = newTheme.copyWithComponentTextStrokeWidth(componentKey, 2.0);
            }
            widget.onThemeChanged(newTheme);
          },
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.line_weight_rounded, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Text('$label Outline Width', style: const TextStyle(color: AppColors.textPrimary, fontSize: 11.5)),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${strokeWidth.toStringAsFixed(1)}px',
                style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        Slider(
          value: strokeWidth.clamp(0.0, 10.0),
          min: 0.0,
          max: 10.0,
          divisions: 20,
          activeColor: AppColors.primary,
          inactiveColor: Colors.grey.shade200,
          onChanged: (val) => widget.onThemeChanged(
            widget.theme.copyWithComponentTextStrokeWidth(componentKey, val),
          ),
        ),
        if (strokeWidth > 0 || strokeOnly) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.border_color_rounded, size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    '$label Outline Color',
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 15,
                    height: 15,
                    decoration: BoxDecoration(
                      color: strokeColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade300, width: 1),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  if (hasCustomStroke)
                    TextButton(
                      onPressed: () {
                        widget.onThemeChanged(
                          widget.theme
                              .copyWithComponentTextStrokeOnly(componentKey, null)
                              .copyWithComponentTextStrokeWidth(componentKey, null)
                              .copyWithComponentTextStrokeColor(componentKey, null),
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey.shade600,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                      ),
                      child: const Text('Reset', style: TextStyle(fontSize: 10.5)),
                    ),
                  _buildCustomColorPickerButton(
                    currentColor: strokeColor,
                    onColorChanged: (c) => widget.onThemeChanged(widget.theme.copyWithComponentTextStrokeColor(componentKey, c)),
                    pickerTitle: 'Select $label Outline Color',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                GestureDetector(
                  onTap: () => widget.onThemeChanged(widget.theme.copyWithComponentTextStrokeColor(componentKey, widget.theme.accentColor)),
                  child: Tooltip(
                    message: 'Match Accent',
                    child: Container(
                      width: 30,
                      height: 30,
                      margin: const EdgeInsets.only(right: 7),
                      decoration: BoxDecoration(
                        color: widget.theme.accentColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: strokeColor.toARGB32() == widget.theme.accentColor.toARGB32() ? AppColors.primary : Colors.grey.shade300,
                          width: strokeColor.toARGB32() == widget.theme.accentColor.toARGB32() ? 2.5 : 1,
                        ),
                      ),
                      child: strokeColor.toARGB32() == widget.theme.accentColor.toARGB32()
                          ? const Icon(Icons.star, size: 13, color: Colors.white)
                          : null,
                    ),
                  ),
                ),
                ...List.generate(_cardBorderColors.length, (index) {
                  final color = _cardBorderColors[index];
                  final isSelected = strokeColor.toARGB32() == color.toARGB32();
                  final isLight = color.computeLuminance() > 0.5;
                  return GestureDetector(
                    onTap: () => widget.onThemeChanged(widget.theme.copyWithComponentTextStrokeColor(componentKey, color)),
                    child: Container(
                      width: 30,
                      height: 30,
                      margin: const EdgeInsets.only(right: 7),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? AppColors.primary : Colors.grey.shade300,
                          width: isSelected ? 2.5 : 1,
                        ),
                      ),
                      child: isSelected
                          ? Icon(Icons.check, size: 14, color: isLight ? Colors.black87 : Colors.white)
                          : null,
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ],
    );
  }

  bool _isTextComponent(String key) {
    return key != SlideComponentId.heroVisual &&
        key != SlideComponentId.screenshots &&
        key != SlideComponentId.cardBackdrop;
  }

  bool _hasPresetStyle(String key) {
    return key == SlideComponentId.title ||
        key == SlideComponentId.rankBadge ||
        key == SlideComponentId.rating ||
        key == SlideComponentId.seasons ||
        key == SlideComponentId.episodes ||
        key == SlideComponentId.studio ||
        key == SlideComponentId.synopsis ||
        key == SlideComponentId.genres ||
        key == SlideComponentId.hookTag ||
        key == SlideComponentId.slideCounter ||
        key == SlideComponentId.pageHandle ||
        key == SlideComponentId.allContent;
  }

  Widget _buildSelectedElementOnlyStyleControls() {
    final compKey = _selectedComponentKey;
    final compName = SlideComponentId.getLabel(compKey);

    if (compKey == SlideComponentId.cardBackdrop) {
      return _buildCardControlsSection();
    }

    final isText = _isTextComponent(compKey);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Element Header with Active Badges & Reset
        _buildElementHeaderCard(compKey, compName),
        const SizedBox(height: 14),

        // 2. Shape & Preset Style (if element has preset)
        if (_hasPresetStyle(compKey)) ...[
          _buildComponentPresetSelector(compKey, compName),
          const SizedBox(height: 14),
          Divider(color: Colors.grey.shade200, height: 1),
          const SizedBox(height: 14),
        ],

        // 3. Typography & Font Studio (for text elements)
        if (isText) ...[
          _buildTypographyStudio(compKey, compName),
          const SizedBox(height: 14),
          Divider(color: Colors.grey.shade200, height: 1),
          const SizedBox(height: 14),
        ],

        // 4. Colors & Background Fill Studio
        _buildColorAndFillStudio(compKey, compName, hasText: isText),
        const SizedBox(height: 14),
        Divider(color: Colors.grey.shade200, height: 1),
        const SizedBox(height: 14),

        // 5. Outlines & Borders Studio
        _buildBorderAndOutlineStudio(compKey, compName),
        const SizedBox(height: 14),
        Divider(color: Colors.grey.shade200, height: 1),
        const SizedBox(height: 14),

        // 6. Text Stroke / Outline Studio (for text elements)
        if (isText) ...[
          _buildTextStrokeControls(
            compKey,
            label: compName,
            defaultStrokeColor: widget.theme.accentColor,
          ),
          const SizedBox(height: 14),
          Divider(color: Colors.grey.shade200, height: 1),
          const SizedBox(height: 14),
        ],

        // 7. Spacing & Elevation Studio
        _buildSpacingAndShadowStudio(compKey, compName),

        // 8. Ambient Backlight Glow Studio (for hero visual)
        if (compKey == SlideComponentId.heroVisual) ...[
          const SizedBox(height: 14),
          Divider(color: Colors.grey.shade200, height: 1),
          const SizedBox(height: 14),
          _buildHeroAmbientGlowStudio(),
        ],
      ],
    );
  }

  Widget _buildHeroAmbientGlowStudio() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFFFF3366).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.flare_rounded, color: Color(0xFFFF3366), size: 15),
            ),
            const SizedBox(width: 8),
            const Text(
              'Ambient Artwork Backlight Glow',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Radiates a soft ambient halo matching the anime poster art colors',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 8),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Enable Artwork Backlight Glow', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          value: widget.theme.enableAmbientGlow,
          activeTrackColor: AppColors.primary,
          onChanged: (val) => widget.onThemeChanged(widget.theme.copyWith(enableAmbientGlow: val)),
        ),
        if (widget.theme.enableAmbientGlow) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Glow Brightness', style: TextStyle(fontSize: 11, color: AppColors.textPrimary)),
              Text('${(widget.theme.ambientGlowIntensity * 100).toInt()}%',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ],
          ),
          Slider(
            value: widget.theme.ambientGlowIntensity,
            min: 0.1,
            max: 1.0,
            activeColor: AppColors.primary,
            inactiveColor: Colors.grey.shade200,
            onChanged: (val) => widget.onThemeChanged(widget.theme.copyWith(ambientGlowIntensity: val)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Glow Blur Radius', style: TextStyle(fontSize: 11, color: AppColors.textPrimary)),
              Text('${widget.theme.ambientGlowBlur.toInt()}px',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ],
          ),
          Slider(
            value: widget.theme.ambientGlowBlur,
            min: 8.0,
            max: 60.0,
            activeColor: AppColors.primary,
            inactiveColor: Colors.grey.shade200,
            onChanged: (val) => widget.onThemeChanged(widget.theme.copyWith(ambientGlowBlur: val)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Glow Spread Distance', style: TextStyle(fontSize: 11, color: AppColors.textPrimary)),
              Text('${widget.theme.ambientGlowSpread.toInt()}px',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ],
          ),
          Slider(
            value: widget.theme.ambientGlowSpread,
            min: 0.0,
            max: 25.0,
            activeColor: AppColors.primary,
            inactiveColor: Colors.grey.shade200,
            onChanged: (val) => widget.onThemeChanged(widget.theme.copyWith(ambientGlowSpread: val)),
          ),
        ],
      ],
    );
  }

  Widget _buildElementHeaderCard(String compKey, String compName) {
    final hasFont = widget.theme.componentFonts.containsKey(compKey);
    final hasColor = widget.theme.componentColors.containsKey(compKey) || (compKey == 'title' && widget.theme.titleTextColor != null);
    final hasBg = widget.theme.componentBgColors.containsKey(compKey);
    final hasBorder = widget.theme.componentBorderWidths.containsKey(compKey) || widget.theme.componentBorderColors.containsKey(compKey);
    final hasRadius = widget.theme.componentBorderRadii.containsKey(compKey);
    final hasStroke = widget.theme.componentTextStrokeOnly.containsKey(compKey) || widget.theme.componentTextStrokeWidths.containsKey(compKey);
    final hasCustomSize = widget.theme.componentFontSizes.containsKey(compKey);
    final hasCustomWeight = widget.theme.componentFontWeights.containsKey(compKey);

    final anyCustom = hasFont || hasColor || hasBg || hasBorder || hasRadius || hasStroke || hasCustomSize || hasCustomWeight;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primarySurface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_getComponentIcon(compKey), color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      compName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Full Element UI Design & Style Controls',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (anyCustom)
                TextButton.icon(
                  onPressed: () {
                    widget.onThemeChanged(widget.theme.resetComponentAllStyles(compKey));
                  },
                  icon: const Icon(Icons.restart_alt_rounded, size: 14),
                  label: const Text('Reset', style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
            ],
          ),
          if (anyCustom) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (hasFont) _buildActiveStyleTag('Font: ${widget.theme.componentFonts[compKey]}'),
                if (hasCustomSize) _buildActiveStyleTag('${widget.theme.componentFontSizes[compKey]?.toInt()}px'),
                if (hasColor) _buildActiveStyleTag('Custom Text Color'),
                if (hasBg) _buildActiveStyleTag('Custom Fill BG'),
                if (hasBorder) _buildActiveStyleTag('Custom Outline'),
                if (hasRadius) _buildActiveStyleTag('Radius: ${widget.theme.componentBorderRadii[compKey]?.toInt()}px'),
                if (hasStroke) _buildActiveStyleTag(widget.theme.isTextStrokeOnly(compKey) ? 'Outline Only' : 'Text Stroke'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActiveStyleTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.primaryDark,
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildComponentPresetSelector(String compKey, String compName) {
    switch (compKey) {
      case SlideComponentId.title:
        return _buildChipSelector<TitleCardStyle>(
          label: 'Title Card / Backdrop Style',
          values: TitleCardStyle.values,
          selectedValue: widget.theme.titleCardStyle,
          getLabel: (t) => t.label,
          onSelected: (t) => widget.onThemeChanged(widget.theme.copyWith(titleCardStyle: t)),
        );
      case SlideComponentId.rankBadge:
        return _buildChipSelector<RankBadgeStyle>(
          label: 'Rank Badge Style',
          values: RankBadgeStyle.values,
          selectedValue: widget.theme.rankBadgeStyle,
          getLabel: (r) => r.label,
          onSelected: (r) => widget.onThemeChanged(widget.theme.copyWith(rankBadgeStyle: r)),
        );
      case SlideComponentId.rating:
      case SlideComponentId.seasons:
      case SlideComponentId.episodes:
      case SlideComponentId.studio:
        return _buildChipSelector<MetadataPillStyle>(
          label: '$compName Capsule Style',
          values: MetadataPillStyle.values,
          selectedValue: widget.theme.metadataPillStyle,
          getLabel: (m) => m.label,
          onSelected: (m) => widget.onThemeChanged(widget.theme.copyWith(metadataPillStyle: m)),
        );
      case SlideComponentId.synopsis:
        return _buildChipSelector<SynopsisCardStyle>(
          label: 'Synopsis Container Style',
          values: SynopsisCardStyle.values,
          selectedValue: widget.theme.synopsisCardStyle,
          getLabel: (s) => s.label,
          onSelected: (s) => widget.onThemeChanged(widget.theme.copyWith(synopsisCardStyle: s)),
        );
      case SlideComponentId.genres:
        return _buildChipSelector<GenreStyle>(
          label: 'Genres Display Style',
          values: GenreStyle.values,
          selectedValue: widget.theme.genreStyle,
          getLabel: (g) => g.label,
          onSelected: (g) => widget.onThemeChanged(widget.theme.copyWith(genreStyle: g)),
        );
      case SlideComponentId.hookTag:
        return _buildChipSelector<HookTagStyle>(
          label: 'Hook Tag Style',
          values: HookTagStyle.values,
          selectedValue: widget.theme.tagStyle,
          getLabel: (t) => t.label,
          onSelected: (t) => widget.onThemeChanged(widget.theme.copyWith(tagStyle: t)),
        );
      case SlideComponentId.slideCounter:
        return _buildChipSelector<SlideCounterStyle>(
          label: 'Slide Counter Style',
          values: SlideCounterStyle.values,
          selectedValue: widget.theme.counterStyle,
          getLabel: (c) => c.label,
          onSelected: (c) => widget.onThemeChanged(widget.theme.copyWith(counterStyle: c)),
        );
      case SlideComponentId.pageHandle:
        return _buildChipSelector<HandleStyle>(
          label: 'Brand Watermark Style',
          values: HandleStyle.values,
          selectedValue: widget.theme.handleStyle,
          getLabel: (h) => h.label,
          onSelected: (h) => widget.onThemeChanged(widget.theme.copyWith(handleStyle: h)),
        );
      case SlideComponentId.allContent:
        return _buildChipSelector<CardStyle>(
          label: 'Card Visual Style Preset',
          values: CardStyle.values,
          selectedValue: widget.theme.cardStyle,
          getLabel: (c) => c.label,
          onSelected: (c) => widget.onThemeChanged(widget.theme.copyWith(
            cardStyle: c,
            showCardBackdrop: c != CardStyle.none,
          )),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTypographyStudio(String compKey, String compName) {
    final currentFont = widget.theme.getFontForComponent(compKey);
    final currentSize = widget.theme.getFontSizeForComponent(
      compKey,
      defaultSize: compKey == SlideComponentId.title ? 22.0 : 12.0,
    );
    final currentWeight = widget.theme.getFontWeightForComponent(
      compKey,
      defaultWeight: compKey == SlideComponentId.title ? FontWeight.w800 : FontWeight.w600,
    );
    final currentSpacing = widget.theme.getLetterSpacingForComponent(compKey);

    final maxSize = compKey == SlideComponentId.title ? 48.0 : 28.0;
    final minSize = compKey == SlideComponentId.title ? 12.0 : 8.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Typography & Font', Icons.font_download_rounded),
        const SizedBox(height: 10),

        // Font Family Selector
        _buildElementFontSelector(
          label: '$compName Font Family',
          currentFontFamily: currentFont,
          onFontSelected: (fam) => widget.onThemeChanged(widget.theme.copyWithComponentFont(compKey, fam)),
        ),
        const SizedBox(height: 12),

        // Font Size Slider
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$compName Font Size', style: const TextStyle(color: AppColors.textPrimary, fontSize: 12)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(6)),
              child: Text('${currentSize.toInt()}px', style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        Slider(
          value: currentSize.clamp(minSize, maxSize),
          min: minSize,
          max: maxSize,
          activeColor: AppColors.primary,
          inactiveColor: Colors.grey.shade200,
          onChanged: (val) => widget.onThemeChanged(widget.theme.copyWithComponentFontSize(compKey, val)),
        ),
        const SizedBox(height: 8),

        // Font Weight Chips
        Text('$compName Font Weight', style: const TextStyle(color: AppColors.textPrimary, fontSize: 11.5, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            FontWeight.w400,
            FontWeight.w500,
            FontWeight.w600,
            FontWeight.w700,
            FontWeight.w800,
            FontWeight.w900,
          ].map((w) {
            final isSelected = currentWeight == w;
            String label;
            switch (w) {
              case FontWeight.w400:
                label = 'Regular';
                break;
              case FontWeight.w500:
                label = 'Medium';
                break;
              case FontWeight.w600:
                label = 'SemiBold';
                break;
              case FontWeight.w700:
                label = 'Bold';
                break;
              case FontWeight.w800:
                label = 'ExtraBold';
                break;
              case FontWeight.w900:
                label = 'Black';
                break;
              default:
                label = '${w.value}';
            }
            return ChoiceChip(
              label: Text(label, style: TextStyle(fontSize: 10.5, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
              selected: isSelected,
              selectedColor: AppColors.primarySurface,
              onSelected: (_) => widget.onThemeChanged(widget.theme.copyWithComponentFontWeight(compKey, w)),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),

        // Letter Spacing Slider
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$compName Letter Spacing', style: const TextStyle(color: AppColors.textPrimary, fontSize: 12)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(6)),
              child: Text('${currentSpacing.toStringAsFixed(1)}px', style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        Slider(
          value: currentSpacing.clamp(-1.0, 6.0),
          min: -1.0,
          max: 6.0,
          divisions: 14,
          activeColor: AppColors.primary,
          inactiveColor: Colors.grey.shade200,
          onChanged: (val) => widget.onThemeChanged(widget.theme.copyWithComponentLetterSpacing(compKey, val)),
        ),
      ],
    );
  }

  Widget _buildColorAndFillStudio(String compKey, String compName, {bool hasText = true}) {
    final currentColor = widget.theme.componentColors[compKey] ??
        (compKey == SlideComponentId.title ? widget.theme.titleTextColor : null);
    final currentBgColor = widget.theme.componentBgColors[compKey];
    final currentOpacity = widget.theme.getBgOpacityForComponent(compKey);

    const swatches = [
      Colors.white,
      Color(0xFF0F172A),
      Color(0xFFFF3366),
      Color(0xFFFFB800),
      Color(0xFF10B981),
      Color(0xFF06B6D4),
      Color(0xFF3B82F6),
      Color(0xFF8B5CF6),
      Color(0xFFEF4444),
      Color(0xFFFF6B6B),
    ];

    const bgSwatches = [
      Color(0x33000000), // Dark translucent
      Color(0x20FFFFFF), // Light frosted
      Color(0x26FF3366), // Accent tint
      Color(0xFF0D0D12), // Deep obsidian
      Color(0xFF1E293B), // Slate container
      Colors.white,
      Color(0xFF2E51A2), // MAL Blue
      Color(0xFF1C1917), // Charcoal
      Color(0xFFFFB800), // Gold
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Colors & Background Fill', Icons.palette_rounded),
        const SizedBox(height: 10),

        // Text & Foreground Color
        if (hasText) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$compName Text Color', style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
              _buildCustomColorPickerButton(
                currentColor: currentColor ?? Colors.white,
                pickerTitle: '$compName Text Color',
                onColorChanged: (c) => widget.onThemeChanged(widget.theme.copyWithComponentColor(compKey, c)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Auto / Adaptive button
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    avatar: Icon(Icons.brightness_auto, size: 14, color: currentColor == null ? AppColors.primary : Colors.grey),
                    label: const Text('Auto', style: TextStyle(fontSize: 10.5)),
                    backgroundColor: currentColor == null ? AppColors.primarySurface : Colors.grey.shade100,
                    onPressed: () => widget.onThemeChanged(widget.theme.copyWithComponentColor(compKey, null)),
                  ),
                ),
                ...swatches.map((color) {
                  final isSelected = currentColor?.toARGB32() == color.toARGB32();
                  return GestureDetector(
                    onTap: () => widget.onThemeChanged(widget.theme.copyWithComponentColor(compKey, color)),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? AppColors.primary : Colors.grey.shade300,
                          width: isSelected ? 2.5 : 1,
                        ),
                        boxShadow: isSelected
                            ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 6)]
                            : null,
                      ),
                      child: isSelected ? Icon(Icons.check, size: 14, color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white) : null,
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Container / Pill Background Color
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$compName Background Fill', style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
            _buildCustomColorPickerButton(
              currentColor: currentBgColor ?? Colors.black,
              pickerTitle: '$compName Background Color',
              onColorChanged: (c) => widget.onThemeChanged(widget.theme.copyWithComponentBgColor(compKey, c)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // None / Transparent button
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ActionChip(
                  avatar: Icon(Icons.block_rounded, size: 14, color: currentBgColor == null ? AppColors.primary : Colors.grey),
                  label: const Text('None', style: TextStyle(fontSize: 10.5)),
                  backgroundColor: currentBgColor == null ? AppColors.primarySurface : Colors.grey.shade100,
                  onPressed: () => widget.onThemeChanged(widget.theme.copyWithComponentBgColor(compKey, null)),
                ),
              ),
              ...bgSwatches.map((color) {
                final isSelected = currentBgColor?.toARGB32() == color.toARGB32();
                return GestureDetector(
                  onTap: () => widget.onThemeChanged(widget.theme.copyWithComponentBgColor(compKey, color)),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? AppColors.primary : Colors.grey.shade300,
                        width: isSelected ? 2.5 : 1,
                      ),
                      boxShadow: isSelected
                          ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 6)]
                          : null,
                    ),
                    child: isSelected ? Icon(Icons.check, size: 14, color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white) : null,
                  ),
                );
              }),
            ],
          ),
        ),

        // Background Opacity (if background is set)
        if (currentBgColor != null) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Background Opacity', style: TextStyle(color: AppColors.textPrimary, fontSize: 11.5)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(6)),
                child: Text('${(currentOpacity * 100).toInt()}%', style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          Slider(
            value: currentOpacity.clamp(0.0, 1.0),
            min: 0.0,
            max: 1.0,
            divisions: 20,
            activeColor: AppColors.primary,
            inactiveColor: Colors.grey.shade200,
            onChanged: (val) => widget.onThemeChanged(widget.theme.copyWithComponentBgOpacity(compKey, val)),
          ),
        ],
      ],
    );
  }

  Widget _buildBorderAndOutlineStudio(String compKey, String compName) {
    final currentBorderColor = widget.theme.componentBorderColors[compKey];
    final currentWidth = widget.theme.getBorderWidthForComponent(compKey) ?? 0.0;
    final currentRadius = widget.theme.getBorderRadiusForComponent(compKey, defaultRadius: 8.0);

    const borderSwatches = [
      Color(0xFFFF3366), // Accent pink
      Colors.white,
      Color(0xFF0F172A), // Dark slate
      Color(0xFFFFB800), // Amber Gold
      Color(0xFF06B6D4), // Cyan
      Color(0xFF94A3B8), // Silver
      Color(0xFF10B981), // Emerald
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Outlines & Borders', Icons.crop_free_rounded),
        const SizedBox(height: 10),

        // Border Color
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$compName Outline Color', style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
            _buildCustomColorPickerButton(
              currentColor: currentBorderColor ?? widget.theme.accentColor,
              pickerTitle: '$compName Border Color',
              onColorChanged: (c) => widget.onThemeChanged(widget.theme.copyWithComponentBorderColor(compKey, c)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // None / No Border button
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ActionChip(
                  avatar: Icon(Icons.block_rounded, size: 14, color: currentWidth <= 0 ? AppColors.primary : Colors.grey),
                  label: const Text('None', style: TextStyle(fontSize: 10.5)),
                  backgroundColor: currentWidth <= 0 ? AppColors.primarySurface : Colors.grey.shade100,
                  onPressed: () => widget.onThemeChanged(widget.theme.copyWithComponentBorderWidth(compKey, 0.0)),
                ),
              ),
              ...borderSwatches.map((color) {
                final isSelected = currentBorderColor?.toARGB32() == color.toARGB32() && currentWidth > 0;
                return GestureDetector(
                  onTap: () {
                    var newTheme = widget.theme.copyWithComponentBorderColor(compKey, color);
                    if (currentWidth <= 0) {
                      newTheme = newTheme.copyWithComponentBorderWidth(compKey, 1.5);
                    }
                    widget.onThemeChanged(newTheme);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? AppColors.primary : Colors.grey.shade300,
                        width: isSelected ? 2.5 : 1,
                      ),
                      boxShadow: isSelected
                          ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 6)]
                          : null,
                    ),
                    child: isSelected ? Icon(Icons.check, size: 14, color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white) : null,
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Border Width Slider
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$compName Outline Width', style: const TextStyle(color: AppColors.textPrimary, fontSize: 11.5)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(6)),
              child: Text('${currentWidth.toStringAsFixed(1)}px', style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        Slider(
          value: currentWidth.clamp(0.0, 6.0),
          min: 0.0,
          max: 6.0,
          divisions: 12,
          activeColor: AppColors.primary,
          inactiveColor: Colors.grey.shade200,
          onChanged: (val) => widget.onThemeChanged(widget.theme.copyWithComponentBorderWidth(compKey, val)),
        ),
        const SizedBox(height: 8),

        // Border Radius Slider (Corner roundness)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$compName Corner Roundness', style: const TextStyle(color: AppColors.textPrimary, fontSize: 11.5)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(6)),
              child: Text('${currentRadius.toInt()}px', style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        Slider(
          value: currentRadius.clamp(0.0, 30.0),
          min: 0.0,
          max: 30.0,
          divisions: 15,
          activeColor: AppColors.primary,
          inactiveColor: Colors.grey.shade200,
          onChanged: (val) => widget.onThemeChanged(widget.theme.copyWithComponentBorderRadius(compKey, val)),
        ),
      ],
    );
  }

  Widget _buildSpacingAndShadowStudio(String compKey, String compName) {
    final currentPadding = widget.theme.getPaddingForComponent(compKey);
    final hasShadow = widget.theme.hasShadowForComponent(compKey);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Spacing & Shadow Elevation', Icons.tune_rounded),
        const SizedBox(height: 10),

        // Padding Slider
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$compName Internal Padding', style: const TextStyle(color: AppColors.textPrimary, fontSize: 11.5)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(6)),
              child: Text('${currentPadding.toInt()}px', style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        Slider(
          value: currentPadding.clamp(2.0, 24.0),
          min: 2.0,
          max: 24.0,
          divisions: 11,
          activeColor: AppColors.primary,
          inactiveColor: Colors.grey.shade200,
          onChanged: (val) => widget.onThemeChanged(widget.theme.copyWithComponentPadding(compKey, val)),
        ),
        const SizedBox(height: 4),

        // Drop Shadow Switch
        SwitchListTile(
          title: Text(
            '$compName Drop Shadow / Glow',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          subtitle: const Text(
            'Adds ambient elevation and soft shadow beneath element',
            style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
          ),
          value: hasShadow,
          activeThumbColor: AppColors.primary,
          contentPadding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          onChanged: (val) => widget.onThemeChanged(widget.theme.copyWithComponentShadow(compKey, val)),
        ),
      ],
    );
  }

  // ==================== SHARED WIDGET HELPERS ====================

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

  Widget _buildAspectRatioSelector() {
    return Row(
      children: AspectRatioPreset.values.map((preset) {
        final isSelected = widget.theme.aspectRatioPreset == preset;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              onTap: () => widget.onThemeChanged(widget.theme.copyWith(aspectRatioPreset: preset)),
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primarySurface : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.grey.shade300,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      preset.label,
                      style: TextStyle(
                        color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${preset.exportWidth}×${preset.exportHeight}',
                      style: TextStyle(
                        color: isSelected ? AppColors.primary : AppColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSlideLayoutSelector() {
    final effectiveCurrentLayout = (widget.activeSlide != null && !widget.theme.syncAnimeSlideLayoutAndPosition)
        ? widget.activeSlide!.getEffectiveLayout(widget.theme)
        : widget.theme.slideLayout;

    return Column(
      children: SlideLayout.values.map((layout) {
        final isSelected = effectiveCurrentLayout == layout;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () {
              if (widget.onSelectSlideLayout != null) {
                widget.onSelectSlideLayout!(layout);
              } else {
                widget.onThemeChanged(widget.theme.copyWith(slideLayout: layout));
              }
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primarySurface : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.grey.shade300,
                  width: isSelected ? 1.8 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      layout.icon,
                      color: isSelected ? Colors.white : Colors.grey.shade700,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              layout.label,
                              style: TextStyle(
                                color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary.withValues(alpha: 0.15)
                                    : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                layout.badgeText,
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                  color: isSelected ? AppColors.primary : Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          layout.description,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isSelected ? Icons.check_circle_rounded : Icons.radio_button_off,
                    color: isSelected ? AppColors.primary : Colors.grey.shade400,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDetailComponentsToggles() {
    return Column(
      children: [
        _buildComponentToggleTile(
          icon: Icons.alternate_email_rounded,
          title: 'Brand Watermark (@handle)',
          subtitle: 'Display your account watermark badge',
          value: widget.theme.showWatermark,
          onChanged: (val) => widget.onThemeChanged(widget.theme.copyWith(showWatermark: val)),
        ),
        _buildComponentToggleTile(
          icon: Icons.pin_rounded,
          title: 'Slide Counter Indicator',
          subtitle: 'Display 01 / 07 page number badge',
          value: widget.theme.showSlideCounter,
          onChanged: (val) => widget.onThemeChanged(widget.theme.copyWith(showSlideCounter: val)),
        ),
        _buildComponentToggleTile(
          icon: Icons.local_fire_department_rounded,
          title: 'Hook / Category Tag Badge',
          subtitle: 'E.g. TOP RECOMMENDATION, MUST WATCH',
          value: widget.theme.showHookTag,
          onChanged: (val) => widget.onThemeChanged(widget.theme.copyWith(showHookTag: val)),
        ),
        _buildComponentToggleTile(
          icon: Icons.translate_rounded,
          title: 'Japanese Title Subtitle',
          subtitle: 'Display Kanji or Romanized subtitle under title',
          value: widget.theme.showJapaneseTitle,
          onChanged: (val) => widget.onThemeChanged(widget.theme.copyWith(showJapaneseTitle: val)),
        ),
        _buildComponentToggleTile(
          icon: Icons.star_rounded,
          title: 'Anime Rating Badge',
          subtitle: 'Display ⭐ 8.9 / 10 rating pill',
          value: widget.theme.showRating,
          onChanged: (val) => widget.onThemeChanged(widget.theme.copyWith(showRating: val)),
        ),
        _buildComponentToggleTile(
          icon: Icons.layers_rounded,
          title: 'Total Seasons Badge',
          subtitle: 'Display seasons count (e.g. 4 Seasons)',
          value: widget.theme.showSeasons,
          onChanged: (val) => widget.onThemeChanged(widget.theme.copyWith(showSeasons: val)),
        ),
        _buildComponentToggleTile(
          icon: Icons.play_circle_outline_rounded,
          title: 'Total Episodes Badge',
          subtitle: 'Display episodes count (e.g. 55 Episodes)',
          value: widget.theme.showEpisodes,
          onChanged: (val) => widget.onThemeChanged(widget.theme.copyWith(showEpisodes: val)),
        ),
        _buildComponentToggleTile(
          icon: Icons.movie_creation_outlined,
          title: 'Animation Studio Badge',
          subtitle: 'Display studio name (e.g. MAPPA, Ufotable)',
          value: widget.theme.showStudio,
          onChanged: (val) => widget.onThemeChanged(widget.theme.copyWith(showStudio: val)),
        ),
        _buildComponentToggleTile(
          icon: Icons.tag_rounded,
          title: 'Rank Number Badge',
          subtitle: 'Display #01 rank badge next to anime name',
          value: widget.theme.showRankBadge,
          onChanged: (val) => widget.onThemeChanged(widget.theme.copyWith(showRankBadge: val)),
        ),
        _buildComponentToggleTile(
          icon: Icons.category_rounded,
          title: 'Anime Genres Display',
          subtitle: 'Display genre pills or dot-separated row',
          value: widget.theme.showGenres,
          onChanged: (val) => widget.onThemeChanged(widget.theme.copyWith(showGenres: val)),
        ),
        _buildComponentToggleTile(
          icon: Icons.format_quote_rounded,
          title: 'Synopsis / Review Box',
          subtitle: 'Display quote box with anime synopsis',
          value: widget.theme.showSynopsis,
          onChanged: (val) => widget.onThemeChanged(widget.theme.copyWith(showSynopsis: val)),
        ),
        _buildComponentToggleTile(
          icon: Icons.arrow_forward_rounded,
          title: 'Swipe Teaser Indicator',
          subtitle: 'Display "Swipe to start →" teaser button',
          value: widget.theme.showSwipeIndicator,
          onChanged: (val) => widget.onThemeChanged(widget.theme.copyWith(showSwipeIndicator: val)),
        ),
      ],
    );
  }

  Widget _buildChipSelector<T>({
    required String label,
    required List<T> values,
    required T selectedValue,
    required String Function(T) getLabel,
    required ValueChanged<T> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: values.map((val) {
            final isSelected = selectedValue == val;
            return GestureDetector(
              onTap: () => onSelected(val),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primarySurface : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.grey.shade300,
                    width: isSelected ? 1.5 : 0.8,
                  ),
                ),
                child: Text(
                  getLabel(val),
                  style: TextStyle(
                    color: isSelected ? AppColors.primaryDark : AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
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
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: value ? AppColors.primary.withValues(alpha: 0.12) : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 16,
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
                          color: value ? AppColors.primaryDark : AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: value ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: value ? AppColors.primary.withValues(alpha: 0.75) : AppColors.textSecondary,
                          fontSize: 9.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                CustomModernSwitch(
                  value: value,
                  activeColor: AppColors.primary,
                  onChanged: onChanged,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCanvasBgColorPicker() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _bgColors.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final color = _bgColors[index];
          final isSelected = widget.theme.canvasBgColor.toARGB32() == color.toARGB32();
          final isLight = color.computeLuminance() > 0.5;
          return GestureDetector(
            onTap: () => widget.onThemeChanged(widget.theme.copyWith(canvasBgColor: color)),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.grey.shade300,
                  width: isSelected ? 2.5 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: isSelected
                  ? Icon(
                      Icons.check,
                      color: isLight ? AppColors.primary : Colors.white,
                      size: 20,
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildAccentColorPicker() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _accentColors.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final color = _accentColors[index];
          final isSelected = widget.theme.accentColor == color;
          return GestureDetector(
            onTap: () => widget.onThemeChanged(widget.theme.copyWith(accentColor: color)),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.black87 : Colors.grey.shade300,
                  width: isSelected ? 2.5 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                  : null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildWatermarkControls() {
    return Column(
      children: [
        _buildComponentToggleTile(
          icon: Icons.verified_rounded,
          title: 'Show Brand Watermark',
          subtitle: 'Displays @handle badge on top bar',
          value: widget.theme.showWatermark,
          onChanged: (val) => widget.onThemeChanged(widget.theme.copyWith(showWatermark: val)),
        ),
        if (widget.theme.showWatermark) ...[
          const SizedBox(height: 4),
          TextFormField(
            key: ValueKey('wm_${widget.theme.watermarkText}'),
            initialValue: widget.theme.watermarkText,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              prefixText: '@ ',
              prefixStyle: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
              labelText: 'Account Handle / Page Name',
              hintText: 'e.g. app.quickpost',
              labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            onChanged: (val) => widget.onThemeChanged(widget.theme.copyWith(watermarkText: val)),
          ),
          const SizedBox(height: 6),
        ],
        _buildComponentToggleTile(
          icon: Icons.pin_rounded,
          title: 'Show Slide Counter',
          subtitle: 'Displays "01 / 07" page indicator badge',
          value: widget.theme.showSlideCounter,
          onChanged: (val) => widget.onThemeChanged(widget.theme.copyWith(showSlideCounter: val)),
        ),
      ],
    );
  }

  Widget _buildAtmosphereSliders() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Ambient Visual Glow Card
        Container(
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF3366).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.flare_rounded, color: Color(0xFFFF3366), size: 16),
                      ),
                      const SizedBox(width: 8),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ambient Artwork Glow',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Backlight aura sampled from anime art',
                            style: TextStyle(color: Colors.grey, fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Switch.adaptive(
                    value: widget.theme.enableAmbientGlow,
                    activeTrackColor: AppColors.primary,
                    onChanged: (val) =>
                        widget.onThemeChanged(widget.theme.copyWith(enableAmbientGlow: val)),
                  ),
                ],
              ),
              if (widget.theme.enableAmbientGlow) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Glow Brightness / Opacity', style: TextStyle(color: AppColors.textPrimary, fontSize: 11.5)),
                    Text('${(widget.theme.ambientGlowIntensity * 100).toInt()}%',
                        style: const TextStyle(color: AppColors.primary, fontSize: 11.5, fontWeight: FontWeight.bold)),
                  ],
                ),
                Slider(
                  value: widget.theme.ambientGlowIntensity,
                  min: 0.1,
                  max: 1.0,
                  activeColor: AppColors.primary,
                  inactiveColor: Colors.grey.shade200,
                  onChanged: (val) =>
                      widget.onThemeChanged(widget.theme.copyWith(ambientGlowIntensity: val)),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Glow Softness / Blur', style: TextStyle(color: AppColors.textPrimary, fontSize: 11.5)),
                    Text('${widget.theme.ambientGlowBlur.toInt()}px',
                        style: const TextStyle(color: AppColors.primary, fontSize: 11.5, fontWeight: FontWeight.bold)),
                  ],
                ),
                Slider(
                  value: widget.theme.ambientGlowBlur,
                  min: 8.0,
                  max: 60.0,
                  activeColor: AppColors.primary,
                  inactiveColor: Colors.grey.shade200,
                  onChanged: (val) =>
                      widget.onThemeChanged(widget.theme.copyWith(ambientGlowBlur: val)),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Glow Spread Distance', style: TextStyle(color: AppColors.textPrimary, fontSize: 11.5)),
                    Text('${widget.theme.ambientGlowSpread.toInt()}px',
                        style: const TextStyle(color: AppColors.primary, fontSize: 11.5, fontWeight: FontWeight.bold)),
                  ],
                ),
                Slider(
                  value: widget.theme.ambientGlowSpread,
                  min: 0.0,
                  max: 25.0,
                  activeColor: AppColors.primary,
                  inactiveColor: Colors.grey.shade200,
                  onChanged: (val) =>
                      widget.onThemeChanged(widget.theme.copyWith(ambientGlowSpread: val)),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 2. 35mm Analog Film Grain Card
        Container(
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.grain_rounded, color: Colors.amber, size: 16),
                      ),
                      const SizedBox(width: 8),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '35mm Analog Film Grain',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Textured analog grain across the canvas',
                            style: TextStyle(color: Colors.grey, fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Switch.adaptive(
                    value: widget.theme.enableFilmGrain,
                    activeTrackColor: AppColors.primary,
                    onChanged: (val) =>
                        widget.onThemeChanged(widget.theme.copyWith(enableFilmGrain: val)),
                  ),
                ],
              ),
              if (widget.theme.enableFilmGrain) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Grain Density / Strength', style: TextStyle(color: AppColors.textPrimary, fontSize: 11.5)),
                    Text('${(widget.theme.filmGrainIntensity * 100).toInt()}%',
                        style: const TextStyle(color: AppColors.primary, fontSize: 11.5, fontWeight: FontWeight.bold)),
                  ],
                ),
                Slider(
                  value: widget.theme.filmGrainIntensity,
                  min: 0.01,
                  max: 0.20,
                  activeColor: AppColors.primary,
                  inactiveColor: Colors.grey.shade200,
                  onChanged: (val) =>
                      widget.onThemeChanged(widget.theme.copyWith(filmGrainIntensity: val)),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 3. Cinematic Edge Vignette Card
        Container(
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.vignette_rounded, color: Colors.blueGrey, size: 16),
                      ),
                      const SizedBox(width: 8),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cinematic Edge Vignette',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Smooth radial shadow around canvas edges',
                            style: TextStyle(color: Colors.grey, fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Switch.adaptive(
                    value: widget.theme.enableVignette,
                    activeTrackColor: AppColors.primary,
                    onChanged: (val) =>
                        widget.onThemeChanged(widget.theme.copyWith(enableVignette: val)),
                  ),
                ],
              ),
              if (widget.theme.enableVignette) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Vignette Darkness', style: TextStyle(color: AppColors.textPrimary, fontSize: 11.5)),
                    Text('${(widget.theme.vignetteIntensity * 100).toInt()}%',
                        style: const TextStyle(color: AppColors.primary, fontSize: 11.5, fontWeight: FontWeight.bold)),
                  ],
                ),
                Slider(
                  value: widget.theme.vignetteIntensity,
                  min: 0.1,
                  max: 0.8,
                  activeColor: AppColors.primary,
                  inactiveColor: Colors.grey.shade200,
                  onChanged: (val) =>
                      widget.onThemeChanged(widget.theme.copyWith(vignetteIntensity: val)),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 4. Gradient Darkness & Background Blur
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Bottom Gradient Darkness',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 12),
            ),
            Text(
              '${(widget.theme.gradientDarkness * 100).toInt()}%',
              style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Slider(
          value: widget.theme.gradientDarkness,
          min: 0.4,
          max: 1.0,
          activeColor: AppColors.primary,
          inactiveColor: Colors.grey.shade200,
          onChanged: (val) => widget.onThemeChanged(widget.theme.copyWith(gradientDarkness: val)),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Background Visual Blur',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 12),
            ),
            Text(
              '${widget.theme.backgroundBlur.toInt()}px',
              style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Slider(
          value: widget.theme.backgroundBlur,
          min: 0.0,
          max: 15.0,
          activeColor: AppColors.primary,
          inactiveColor: Colors.grey.shade200,
          onChanged: (val) => widget.onThemeChanged(widget.theme.copyWith(backgroundBlur: val)),
        ),
      ],
    );
  }

  // ==================== DIALOG & SHEET OPENERS ====================

  void _openColorPickerDialog({
    required BuildContext context,
    required String title,
    required Color initialColor,
    required ValueChanged<Color> onColorChanged,
  }) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          content: SizedBox(
            width: 320,
            child: SingleChildScrollView(
              child: AdvancedColorPicker(
                initialColor: initialColor,
                onColorChanged: onColorChanged,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}

/// Custom sleek modern iOS-style animated toggle switch.
/// Replaces the default clunky Material 3 switch with a crisp, premium design.
class CustomModernSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color activeColor;

  const CustomModernSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        width: 44,
        height: 24,
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: value ? activeColor : const Color(0xFFE2E8F0),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 19,
            height: 19,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
