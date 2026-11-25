import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../models/anime_carousel_slide.dart';
import '../models/anime_custom_layout.dart';
import '../models/anime_template_theme.dart';
import '../services/anime_custom_layout_service.dart';

/// Bottom dock panel for Tab 2: "Layouts".
/// Allows users to view the default layout, save current element positions/styles
/// as a custom reusable layout, and apply or delete saved custom layouts.
class AnimeLayoutsPanel extends StatefulWidget {
  final AnimeCarouselSlide activeSlide;
  final AnimeTemplateTheme theme;
  final ValueChanged<AnimeTemplateTheme> onThemeChanged;
  final ValueChanged<AnimeCustomLayout> onApplyLayout;
  final VoidCallback onResetToDefault;
  final ValueChanged<bool> onToggleSync;
  final ValueChanged<SlideLayout>? onSelectSlideLayout;
  final ValueChanged<String> onShowToast;

  const AnimeLayoutsPanel({
    super.key,
    required this.activeSlide,
    required this.theme,
    required this.onThemeChanged,
    required this.onApplyLayout,
    required this.onResetToDefault,
    required this.onToggleSync,
    this.onSelectSlideLayout,
    required this.onShowToast,
  });

  @override
  State<AnimeLayoutsPanel> createState() => _AnimeLayoutsPanelState();
}

class _AnimeLayoutsPanelState extends State<AnimeLayoutsPanel> {
  List<AnimeCustomLayout> _savedLayouts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLayouts();
  }

  Future<void> _loadLayouts() async {
    final layouts = await AnimeCustomLayoutService.loadCustomLayouts();
    if (mounted) {
      setState(() {
        _savedLayouts = layouts;
        _isLoading = false;
      });
    }
  }

  Future<void> _promptSaveCurrentLayout() async {
    final controller = TextEditingController(
      text: 'Custom Layout ${_savedLayouts.length + 1}',
    );

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.bookmark_add_rounded, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              const Text('Save Custom Layout', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Give this layout a name. All dragged element positions, visibility toggles, and card styles will be saved.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Layout Name',
                  hintText: 'e.g. Minimalist Top Title',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _buildSummaryBadge(
                    '${widget.activeSlide.componentOffsets.length} Custom Positions',
                    Icons.touch_app_rounded,
                  ),
                  _buildSummaryBadge(
                    'Card: ${widget.theme.cardStyle.name}',
                    Icons.style_rounded,
                  ),
                  _buildSummaryBadge(
                    widget.theme.showSynopsis ? 'Synopsis ON' : 'Synopsis OFF',
                    Icons.visibility_rounded,
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  Navigator.pop(ctx, text);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Save Layout'),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      final newLayout = AnimeCustomLayout(
        id: 'layout_${DateTime.now().millisecondsSinceEpoch}',
        name: result,
        createdAt: DateTime.now(),
        contentOffsetX: widget.activeSlide.contentOffsetX,
        contentOffsetY: widget.activeSlide.contentOffsetY,
        headerOffsetY: widget.activeSlide.headerOffsetY,
        componentOffsets: Map<String, Offset>.from(widget.activeSlide.componentOffsets),
        showRankBadge: widget.theme.showRankBadge,
        showRating: widget.theme.showRating,
        showSeasons: widget.theme.showSeasons,
        showEpisodes: widget.theme.showEpisodes,
        showStudio: widget.theme.showStudio,
        showGenres: widget.theme.showGenres,
        showSynopsis: widget.theme.showSynopsis,
        showWatermark: widget.theme.showWatermark,
        showSlideCounter: widget.theme.showSlideCounter,
        showHookTag: widget.theme.showHookTag,
        showJapaneseTitle: widget.theme.showJapaneseTitle,
        cardStyle: widget.theme.cardStyle,
        showCardBackdrop: widget.theme.showCardBackdrop,
        showCardBorder: widget.theme.showCardBorder,
        rankBadgeStyle: widget.theme.rankBadgeStyle,
        metadataPillStyle: widget.theme.metadataPillStyle,
        synopsisCardStyle: widget.theme.synopsisCardStyle,
        titleCardStyle: widget.theme.titleCardStyle,
        componentFonts: Map<String, String>.from(widget.theme.componentFonts),
        componentColors: Map<String, Color>.from(widget.theme.componentColors),
        componentBgColors: Map<String, Color>.from(widget.theme.componentBgColors),
        componentBgOpacities: Map<String, double>.from(widget.theme.componentBgOpacities),
        componentBorderColors: Map<String, Color>.from(widget.theme.componentBorderColors),
        componentBorderWidths: Map<String, double>.from(widget.theme.componentBorderWidths),
        componentBorderRadii: Map<String, double>.from(widget.theme.componentBorderRadii),
        componentFontSizes: Map<String, double>.from(widget.theme.componentFontSizes),
        componentFontWeights: Map<String, int>.from(widget.theme.componentFontWeights),
        componentLetterSpacings: Map<String, double>.from(widget.theme.componentLetterSpacings),
        componentPaddings: Map<String, double>.from(widget.theme.componentPaddings),
        componentShadows: Map<String, bool>.from(widget.theme.componentShadows),
        componentTextStrokeOnly: Map<String, bool>.from(widget.theme.componentTextStrokeOnly),
        componentTextStrokeWidths: Map<String, double>.from(widget.theme.componentTextStrokeWidths),
        componentTextStrokeColors: Map<String, Color>.from(widget.theme.componentTextStrokeColors),
        enableAmbientGlow: widget.theme.enableAmbientGlow,
        ambientGlowIntensity: widget.theme.ambientGlowIntensity,
        ambientGlowBlur: widget.theme.ambientGlowBlur,
        ambientGlowSpread: widget.theme.ambientGlowSpread,
        enableFilmGrain: widget.theme.enableFilmGrain,
        filmGrainIntensity: widget.theme.filmGrainIntensity,
        enableVignette: widget.theme.enableVignette,
        vignetteIntensity: widget.theme.vignetteIntensity,
      );

      await AnimeCustomLayoutService.saveCustomLayout(newLayout);
      await _loadLayouts();
      widget.onShowToast('Saved "$result" as custom layout');
    }
  }

  Future<void> _promptCreateLayoutFromScratch() async {
    final nameController = TextEditingController(
      text: 'Custom Layout ${_savedLayouts.length + 1}',
    );

    // Initial toggle states for scratch setup
    bool showRankBadge = true;
    bool showRating = true;
    bool showSeasons = false;
    bool showEpisodes = false;
    bool showStudio = false;
    bool showGenres = true;
    bool showSynopsis = false;
    bool showWatermark = true;
    bool showSlideCounter = true;
    bool showHookTag = false;
    bool showJapaneseTitle = false;
    CardStyle cardStyle = CardStyle.none;

    final createdLayout = await showDialog<AnimeCustomLayout>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void applyPreset(String preset) {
              setModalState(() {
                if (preset == 'minimal') {
                  showRankBadge = false;
                  showRating = false;
                  showSeasons = false;
                  showEpisodes = false;
                  showStudio = false;
                  showGenres = false;
                  showSynopsis = false;
                  showWatermark = true;
                  showSlideCounter = true;
                  showHookTag = false;
                  showJapaneseTitle = false;
                } else if (preset == 'standard') {
                  showRankBadge = true;
                  showRating = true;
                  showSeasons = false;
                  showEpisodes = false;
                  showStudio = false;
                  showGenres = true;
                  showSynopsis = true;
                  showWatermark = true;
                  showSlideCounter = true;
                  showHookTag = false;
                  showJapaneseTitle = false;
                } else if (preset == 'full') {
                  showRankBadge = true;
                  showRating = true;
                  showSeasons = true;
                  showEpisodes = true;
                  showStudio = true;
                  showGenres = true;
                  showSynopsis = true;
                  showWatermark = true;
                  showSlideCounter = true;
                  showHookTag = true;
                  showJapaneseTitle = true;
                }
              });
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add_box_rounded, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Create from Scratch', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text('Clean canvas with custom elements', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      TextField(
                        controller: nameController,
                        autofocus: false,
                        decoration: InputDecoration(
                          labelText: 'Layout Name',
                          hintText: 'e.g. Minimal Top Poster',
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Quick Starting Presets
                      const Text(
                        'Quick Starting Preset:',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => applyPreset('minimal'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                side: BorderSide(color: Colors.grey.shade300),
                              ),
                              child: const Text('Minimal', style: TextStyle(fontSize: 11)),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => applyPreset('standard'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                side: const BorderSide(color: AppColors.primary),
                                foregroundColor: AppColors.primary,
                              ),
                              child: const Text('Standard', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => applyPreset('full'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                side: BorderSide(color: Colors.grey.shade300),
                              ),
                              child: const Text('Full Deck', style: TextStyle(fontSize: 11)),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Elements to Include
                      const Text(
                        'Elements to Include on Canvas:',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _buildFilterChip('Anime Title', true, (val) {}, isFixed: true),
                          _buildFilterChip('Rank Badge', showRankBadge, (val) => setModalState(() => showRankBadge = val)),
                          _buildFilterChip('Rating', showRating, (val) => setModalState(() => showRating = val)),
                          _buildFilterChip('Seasons', showSeasons, (val) => setModalState(() => showSeasons = val)),
                          _buildFilterChip('Episodes', showEpisodes, (val) => setModalState(() => showEpisodes = val)),
                          _buildFilterChip('Studio', showStudio, (val) => setModalState(() => showStudio = val)),
                          _buildFilterChip('Genres', showGenres, (val) => setModalState(() => showGenres = val)),
                          _buildFilterChip('Synopsis', showSynopsis, (val) => setModalState(() => showSynopsis = val)),
                          _buildFilterChip('Watermark', showWatermark, (val) => setModalState(() => showWatermark = val)),
                          _buildFilterChip('Slide No', showSlideCounter, (val) => setModalState(() => showSlideCounter = val)),
                          _buildFilterChip('Hook Tag', showHookTag, (val) => setModalState(() => showHookTag = val)),
                          _buildFilterChip('Japanese Title', showJapaneseTitle, (val) => setModalState(() => showJapaneseTitle = val)),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Card Backdrop Style
                      const Text(
                        'Card Backdrop Style:',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: CardStyle.values.map((cs) {
                          final isSelected = cs == cardStyle;
                          return ChoiceChip(
                            label: Text(cs.label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                            selected: isSelected,
                            selectedColor: AppColors.primarySurface,
                            labelStyle: TextStyle(color: isSelected ? AppColors.primary : AppColors.textPrimary),
                            side: BorderSide(color: isSelected ? AppColors.primary : Colors.grey.shade300),
                            onSelected: (val) {
                              if (val) setModalState(() => cardStyle = cs);
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;
                    final layout = AnimeCustomLayout(
                      id: 'layout_${DateTime.now().millisecondsSinceEpoch}',
                      name: name,
                      createdAt: DateTime.now(),
                      contentOffsetX: 0.0,
                      contentOffsetY: 0.0,
                      headerOffsetY: 0.0,
                      componentOffsets: const {}, // Blank clean coordinates
                      showRankBadge: showRankBadge,
                      showRating: showRating,
                      showSeasons: showSeasons,
                      showEpisodes: showEpisodes,
                      showStudio: showStudio,
                      showGenres: showGenres,
                      showSynopsis: showSynopsis,
                      showWatermark: showWatermark,
                      showSlideCounter: showSlideCounter,
                      showHookTag: showHookTag,
                      showJapaneseTitle: showJapaneseTitle,
                      cardStyle: cardStyle,
                      showCardBackdrop: cardStyle != CardStyle.none,
                      showCardBorder: widget.theme.showCardBorder,
                      rankBadgeStyle: widget.theme.rankBadgeStyle,
                      metadataPillStyle: widget.theme.metadataPillStyle,
                      synopsisCardStyle: widget.theme.synopsisCardStyle,
                      titleCardStyle: widget.theme.titleCardStyle,
                      componentFonts: const {},
                      componentColors: const {},
                    );
                    Navigator.pop(ctx, layout);
                  },
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Create Layout'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (createdLayout != null) {
      await AnimeCustomLayoutService.saveCustomLayout(createdLayout);
      await _loadLayouts();
      widget.onApplyLayout(createdLayout);
    }
  }

  Future<void> _updateLayoutWithCurrentCanvas(AnimeCustomLayout layout) async {
    final updated = AnimeCustomLayout(
      id: layout.id,
      name: layout.name,
      createdAt: DateTime.now(),
      contentOffsetX: widget.activeSlide.contentOffsetX,
      contentOffsetY: widget.activeSlide.contentOffsetY,
      headerOffsetY: widget.activeSlide.headerOffsetY,
      componentOffsets: Map<String, Offset>.from(widget.activeSlide.componentOffsets),
      showRankBadge: widget.theme.showRankBadge,
      showRating: widget.theme.showRating,
      showSeasons: widget.theme.showSeasons,
      showEpisodes: widget.theme.showEpisodes,
      showStudio: widget.theme.showStudio,
      showGenres: widget.theme.showGenres,
      showSynopsis: widget.theme.showSynopsis,
      showWatermark: widget.theme.showWatermark,
      showSlideCounter: widget.theme.showSlideCounter,
      showHookTag: widget.theme.showHookTag,
      showJapaneseTitle: widget.theme.showJapaneseTitle,
      cardStyle: widget.theme.cardStyle,
      showCardBackdrop: widget.theme.showCardBackdrop,
      showCardBorder: widget.theme.showCardBorder,
      rankBadgeStyle: widget.theme.rankBadgeStyle,
      metadataPillStyle: widget.theme.metadataPillStyle,
      synopsisCardStyle: widget.theme.synopsisCardStyle,
      titleCardStyle: widget.theme.titleCardStyle,
      componentFonts: Map<String, String>.from(widget.theme.componentFonts),
      componentColors: Map<String, Color>.from(widget.theme.componentColors),
      componentBgColors: Map<String, Color>.from(widget.theme.componentBgColors),
      componentBgOpacities: Map<String, double>.from(widget.theme.componentBgOpacities),
      componentBorderColors: Map<String, Color>.from(widget.theme.componentBorderColors),
      componentBorderWidths: Map<String, double>.from(widget.theme.componentBorderWidths),
      componentBorderRadii: Map<String, double>.from(widget.theme.componentBorderRadii),
      componentFontSizes: Map<String, double>.from(widget.theme.componentFontSizes),
      componentFontWeights: Map<String, int>.from(widget.theme.componentFontWeights),
      componentLetterSpacings: Map<String, double>.from(widget.theme.componentLetterSpacings),
      componentPaddings: Map<String, double>.from(widget.theme.componentPaddings),
      componentShadows: Map<String, bool>.from(widget.theme.componentShadows),
      componentTextStrokeOnly: Map<String, bool>.from(widget.theme.componentTextStrokeOnly),
      componentTextStrokeWidths: Map<String, double>.from(widget.theme.componentTextStrokeWidths),
      componentTextStrokeColors: Map<String, Color>.from(widget.theme.componentTextStrokeColors),
      enableAmbientGlow: widget.theme.enableAmbientGlow,
      ambientGlowIntensity: widget.theme.ambientGlowIntensity,
      ambientGlowBlur: widget.theme.ambientGlowBlur,
      ambientGlowSpread: widget.theme.ambientGlowSpread,
      enableFilmGrain: widget.theme.enableFilmGrain,
      filmGrainIntensity: widget.theme.filmGrainIntensity,
      enableVignette: widget.theme.enableVignette,
      vignetteIntensity: widget.theme.vignetteIntensity,
    );

    await AnimeCustomLayoutService.saveCustomLayout(updated);
    await _loadLayouts();
    widget.onShowToast('Updated "${layout.name}" with current canvas positions!');
  }

  Widget _buildFilterChip(String label, bool isSelected, ValueChanged<bool> onChanged, {bool isFixed = false}) {
    return FilterChip(
      label: Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
      selected: isSelected,
      onSelected: isFixed ? null : onChanged,
      selectedColor: AppColors.primarySurface,
      labelStyle: TextStyle(color: isSelected ? AppColors.primary : Colors.grey.shade700),
      side: BorderSide(color: isSelected ? AppColors.primary : Colors.grey.shade300),
      showCheckmark: isSelected,
      checkmarkColor: AppColors.primary,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    );
  }

  Widget _buildSummaryBadge(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey.shade700),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 10.5, color: Colors.grey.shade800)),
        ],
      ),
    );
  }

  Future<void> _deleteLayout(AnimeCustomLayout layout) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Layout?'),
        content: Text('Are you sure you want to delete "${layout.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AnimeCustomLayoutService.deleteCustomLayout(layout.id);
      await _loadLayouts();
    }
  }

  Future<void> _importLayouts() async {
    final count = await AnimeCustomLayoutService.importLayoutsFromFile();
    if (count > 0) {
      await _loadLayouts();
    }
  }

  Future<void> _exportAllLayouts() async {
    if (_savedLayouts.isEmpty) {
      widget.onShowToast('No custom layouts to export');
      return;
    }
    final path = await AnimeCustomLayoutService.exportAllLayoutsToFile(share: true);
    if (path != null) {
      widget.onShowToast('Exported ${_savedLayouts.length} layout${_savedLayouts.length > 1 ? 's' : ''} to Downloads/Quick Post Backup');
    } else {
      widget.onShowToast('Failed to export layouts');
    }
  }

  Future<void> _exportSingleLayout(AnimeCustomLayout layout) async {
    final path = await AnimeCustomLayoutService.exportLayoutToFile(layout, share: true);
    if (path != null) {
      widget.onShowToast('Exported "${layout.name}" to Downloads/Quick Post Backup');
    } else {
      widget.onShowToast('Failed to export layout');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Action Buttons
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Layouts',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Design custom layouts or save current canvas',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: _promptSaveCurrentLayout,
                icon: const Icon(Icons.bookmark_add_rounded, size: 14),
                label: const Text('Save Current', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _promptCreateLayoutFromScratch,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('From Scratch', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Sync Toggle Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  widget.theme.syncAnimeSlideLayoutAndPosition
                      ? Icons.sync_rounded
                      : Icons.sync_disabled_rounded,
                  color: widget.theme.syncAnimeSlideLayoutAndPosition
                      ? AppColors.primary
                      : Colors.grey.shade500,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sync Across All Slides',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                      Text(
                        widget.theme.syncAnimeSlideLayoutAndPosition
                            ? 'Layout applies to all anime slides'
                            : 'Layout applies only to current slide',
                        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: widget.theme.syncAnimeSlideLayoutAndPosition,
                  onChanged: widget.onToggleSync,
                  activeTrackColor: AppColors.primary,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Built-in Post Layouts Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Built-in Post Layouts',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              Text(
                widget.theme.syncAnimeSlideLayoutAndPosition ? 'Applies to all slides' : 'Applies to active slide',
                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),

          ...SlideLayout.values.map((layout) {
            final effectiveCurrentLayout = (widget.theme.syncAnimeSlideLayoutAndPosition)
                ? widget.theme.slideLayout
                : widget.activeSlide.getEffectiveLayout(widget.theme);
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
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primarySurface.withValues(alpha: 0.5) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Colors.grey.shade200,
                      width: isSelected ? 1.8 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isSelected ? 0.05 : 0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          layout.icon,
                          color: isSelected ? Colors.white : AppColors.primary,
                          size: 22,
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
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primary.withValues(alpha: 0.15)
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.primary.withValues(alpha: 0.3)
                                          : Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Text(
                                    layout.badgeText,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? AppColors.primary : Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              layout.description,
                              style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isSelected)
                        const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20)
                      else
                        Icon(Icons.radio_button_off, color: Colors.grey.shade400, size: 20),
                    ],
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: 18),

          // Custom Saved Layouts Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'My Saved Layouts (${_savedLayouts.length})',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              Row(
                children: [
                  // Import Layout (.json) Button
                  InkWell(
                    onTap: _importLayouts,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.file_download_outlined, size: 13, color: AppColors.primary),
                          SizedBox(width: 4),
                          Text('Import .json', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        ],
                      ),
                    ),
                  ),
                  if (_savedLayouts.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    // Export All (.json) Button
                    InkWell(
                      onTap: _exportAllLayouts,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.share_outlined, size: 13, color: AppColors.textPrimary),
                            SizedBox(width: 4),
                            Text('Export All', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_savedLayouts.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200, style: BorderStyle.solid),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.dashboard_customize_outlined, size: 28, color: Colors.grey.shade400),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'No saved layouts yet. Start from scratch or save your current canvas setup.',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _importLayouts,
                        icon: const Icon(Icons.file_download_outlined, size: 14),
                        label: const Text('Import .json', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _promptCreateLayoutFromScratch,
                        icon: const Icon(Icons.add_rounded, size: 15),
                        label: const Text('Create from Scratch', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else
            Column(
              children: _savedLayouts.map((layout) {
                final dateStr = '${layout.createdAt.day}/${layout.createdAt.month}/${layout.createdAt.year}';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  layout.name,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  'Created $dateStr',
                                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.share_outlined, size: 17, color: AppColors.textSecondary),
                            onPressed: () => _exportSingleLayout(layout),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Export & share layout as .json',
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            icon: const Icon(Icons.sync_rounded, size: 18, color: AppColors.primary),
                            onPressed: () => _updateLayoutWithCurrentCanvas(layout),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Update with canvas positions',
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => widget.onApplyLayout(layout),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                            ),
                            child: const Text('Apply', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                            onPressed: () => _deleteLayout(layout),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Delete layout',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (layout.componentOffsets.isNotEmpty)
                            _buildSummaryBadge(
                              '${layout.componentOffsets.length} Positions',
                              Icons.touch_app_rounded,
                            ),
                          if (layout.cardStyle != CardStyle.none)
                            _buildSummaryBadge(
                              layout.cardStyle.name,
                              Icons.style_rounded,
                            ),
                          if (layout.showSynopsis)
                            _buildSummaryBadge(
                              'Synopsis',
                              Icons.article_rounded,
                            ),
                          if (layout.showRankBadge)
                            _buildSummaryBadge(
                              'Rank',
                              Icons.military_tech_rounded,
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
