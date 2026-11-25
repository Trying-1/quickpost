import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../models/anime_carousel_slide.dart';
import '../models/anime_template_theme.dart';

/// Control panel for precision slider positioning of individual slide components.
/// Supports selecting any individual component (Title, Badges, Genres, Synopsis, Watermark, etc.)
/// and adjusting its individual X and Y coordinates with live sliders and quick presets.
class SlidePositionPanel extends StatefulWidget {
  final AnimeCarouselSlide slide;
  final AnimeTemplateTheme? theme;
  final String? activeComponentKey;
  final ValueChanged<String>? onSelectComponent;
  final ValueChanged<AnimeCarouselSlide> onSlideChanged;
  final VoidCallback onApplyToAll;
  final VoidCallback onReset;
  final void Function(String componentKey)? onResetComponent;
  final bool syncAnimeSlideLayoutAndPosition;
  final ValueChanged<bool>? onToggleSync;

  const SlidePositionPanel({
    super.key,
    required this.slide,
    this.theme,
    this.activeComponentKey,
    this.onSelectComponent,
    required this.onSlideChanged,
    required this.onApplyToAll,
    required this.onReset,
    this.onResetComponent,
    this.syncAnimeSlideLayoutAndPosition = true,
    this.onToggleSync,
  });

  @override
  State<SlidePositionPanel> createState() => _SlidePositionPanelState();
}

class _SlidePositionPanelState extends State<SlidePositionPanel> {
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
  void didUpdateWidget(covariant SlidePositionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeComponentKey != null && widget.activeComponentKey != _selectedComponentKey) {
      _selectedComponentKey = widget.activeComponentKey!;
    }
    final available = _availableComponents;
    if (!available.contains(_selectedComponentKey) && available.isNotEmpty) {
      _selectedComponentKey = available.contains(SlideComponentId.title) ? SlideComponentId.title : available.first;
    }
  }

  List<String> get _availableComponents {
    List<String> raw;
    switch (widget.slide.type) {
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
    if (widget.theme != null) {
      return raw.where((key) => widget.theme!.isComponentEnabledForSlide(key, widget.slide)).toList();
    }
    return raw;
  }

  IconData _getComponentIcon(String key) {
    switch (key) {
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
      case SlideComponentId.swipeIndicator:
        return Icons.swipe_rounded;
      default:
        return Icons.crop_free_rounded;
    }
  }

  void _selectComponent(String key) {
    setState(() => _selectedComponentKey = key);
    widget.onSelectComponent?.call(key);
  }

  @override
  Widget build(BuildContext context) {
    final available = _availableComponents;
    if (!available.contains(_selectedComponentKey) && available.isNotEmpty) {
      _selectedComponentKey = available.contains(SlideComponentId.title) ? SlideComponentId.title : available.first;
    }
    final currentOffset = widget.slide.getComponentOffset(_selectedComponentKey);
    final activeLabel = SlideComponentId.getLabel(_selectedComponentKey);
    final (double refW, double refH) = _getCanvasRefSize();
    final Offset restNorm = _getRestingNormPos(_selectedComponentKey, refW, refH);
    final double normX = (restNorm.dx + (currentOffset.dx / refW)).clamp(0.0, 1.0);
    final double normY = (restNorm.dy + (currentOffset.dy / refH)).clamp(0.0, 1.0);

    void updateNormPosition(double nextNormX, double nextNormY) {
      final double clampedX = nextNormX.clamp(0.0, 1.0);
      final double clampedY = nextNormY.clamp(0.0, 1.0);
      final double dx = ((clampedX - restNorm.dx) * refW).clamp(-360.0, 360.0);
      final double dy = ((clampedY - restNorm.dy) * refH).clamp(-640.0, 640.0);
      widget.onSlideChanged(
        widget.slide.copyWithComponentOffset(
          _selectedComponentKey,
          Offset(dx, dy),
        ),
      );
    }

    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar: Title & Global Reset
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.open_with_rounded, color: AppColors.primary, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Individual Component Positioning',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: widget.onReset,
                  icon: const Icon(Icons.restart_alt_rounded, size: 15),
                  label: const Text('Reset All', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            const Text(
              'Select any component below or tap on canvas to position it individually.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
            const SizedBox(height: 10),

            // Tip Banner: Touch & Drag
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.touch_app_rounded, color: AppColors.primary, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tip: Tap or drag any component directly on the canvas preview to select and move it!',
                      style: TextStyle(color: AppColors.primaryDark, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Synchronize Layout & Position for all Anime Slides Toggle
            if (widget.slide.type == SlideType.anime) ...[
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onToggleSync != null
                      ? () => widget.onToggleSync!(!widget.syncAnimeSlideLayoutAndPosition)
                      : null,
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: widget.syncAnimeSlideLayoutAndPosition ? AppColors.primarySurface : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: widget.syncAnimeSlideLayoutAndPosition
                            ? AppColors.primary.withValues(alpha: 0.5)
                            : Colors.grey.shade300,
                        width: widget.syncAnimeSlideLayoutAndPosition ? 1.2 : 0.8,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          widget.syncAnimeSlideLayoutAndPosition ? Icons.sync_rounded : Icons.sync_disabled_rounded,
                          color: widget.syncAnimeSlideLayoutAndPosition ? AppColors.primary : Colors.grey.shade600,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Same layout & positioning for all anime slides',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                widget.syncAnimeSlideLayoutAndPosition
                                    ? 'Moving or styling components updates all anime slides automatically'
                                    : 'Each anime slide has independent layout & component positioning',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: widget.syncAnimeSlideLayoutAndPosition,
                          activeThumbColor: AppColors.primary,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          onChanged: widget.onToggleSync,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ] else
              const SizedBox(height: 12),

            // Component Selector Strip (Chips)
            const Text(
              'Select Component to Position:',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _availableComponents.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, idx) {
                  final key = _availableComponents[idx];
                  final isSelected = key == _selectedComponentKey;
                  final icon = _getComponentIcon(key);
                  final label = SlideComponentId.getLabel(key);
                  final hasOffset = widget.slide.getComponentOffset(key) != Offset.zero;

                  return InkWell(
                    onTap: () => _selectComponent(key),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : (hasOffset ? AppColors.primarySurface : Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : (hasOffset ? AppColors.primary.withValues(alpha: 0.5) : Colors.grey.shade300),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            icon,
                            size: 14,
                            color: isSelected ? Colors.white : (hasOffset ? AppColors.primaryDark : Colors.grey.shade700),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              color: isSelected ? Colors.white : (hasOffset ? AppColors.primaryDark : Colors.grey.shade800),
                            ),
                          ),
                          if (hasOffset && !isSelected) ...[
                            const SizedBox(width: 4),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 14),
            Divider(color: Colors.grey.shade200, height: 1),
            const SizedBox(height: 10),

            // Active Component Header & Reset Single Component
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(_getComponentIcon(_selectedComponentKey), color: AppColors.primary, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activeLabel,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'X: ${normX.toStringAsFixed(2)}   |   Y: ${normY.toStringAsFixed(2)}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5),
                        ),
                      ],
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    if (widget.onResetComponent != null) {
                      widget.onResetComponent!(_selectedComponentKey);
                    } else {
                      widget.onSlideChanged(widget.slide.copyWithResetOffsets(specificKey: _selectedComponentKey));
                    }
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.orange.shade800,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  child: const Text('Reset Component', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ─── Watermark-Style Quick Alignment Grid (Left/Center/Right & Top/Middle/Bottom) ───
            const Text('Quick Alignment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAlignXButton(
                  Icons.align_horizontal_left,
                  'Left',
                  0.12,
                  normX,
                  (x) => updateNormPosition(x, normY),
                ),
                _buildAlignXButton(
                  Icons.align_horizontal_center,
                  'Center',
                  0.50,
                  normX,
                  (x) => updateNormPosition(x, normY),
                ),
                _buildAlignXButton(
                  Icons.align_horizontal_right,
                  'Right',
                  0.88,
                  normX,
                  (x) => updateNormPosition(x, normY),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAlignYButton(
                  Icons.vertical_align_top,
                  'Top',
                  0.12,
                  normY,
                  (y) => updateNormPosition(normX, y),
                ),
                _buildAlignYButton(
                  Icons.vertical_align_center,
                  'Middle',
                  0.50,
                  normY,
                  (y) => updateNormPosition(normX, y),
                ),
                _buildAlignYButton(
                  Icons.vertical_align_bottom,
                  'Bottom',
                  0.88,
                  normY,
                  (y) => updateNormPosition(normX, y),
                ),
              ],
            ),

            const Divider(height: 28),

            // ─── Watermark-Style Fine-Tune Coordinate Sliders with - / + Buttons ───
            const Text(
              'Manual Coordinates (Fine-tune)',
              style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildWatermarkControlSlider(
              label: 'Horizontal Position (X)',
              value: normX,
              min: 0.0,
              max: 1.0,
              step: 0.02,
              onChanged: (val) => updateNormPosition(val, normY),
            ),
            const SizedBox(height: 10),
            _buildWatermarkControlSlider(
              label: 'Vertical Position (Y)',
              value: normY,
              min: 0.0,
              max: 1.0,
              step: 0.02,
              onChanged: (val) => updateNormPosition(normX, val),
            ),

            const SizedBox(height: 14),

            // Apply to All Slides Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: widget.onApplyToAll,
                icon: const Icon(Icons.copy_all_rounded, size: 16),
                label: const Text('Apply All Positions to All Slides', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary, width: 1.2),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  (double, double) _getCanvasRefSize() {
    const double refW = 340.0;
    final double aspect = widget.theme?.aspectValue ?? 0.8;
    return (refW, refW / aspect);
  }

  /// Resting normalized `(0..1, 0..1)` position of [componentKey] before manual offset.
  Offset _getRestingNormPos(String componentKey, double refW, double refH) {
    double bottomY(double baseBottom) => ((refH - baseBottom) / refH).clamp(0.05, 0.95);
    switch (componentKey) {
      case SlideComponentId.pageHandle:
        return Offset((70.0 / refW).clamp(0.05, 0.95), (26.0 / refH).clamp(0.05, 0.95));
      case SlideComponentId.slideCounter:
        return Offset(((refW - 44.0) / refW).clamp(0.05, 0.95), (26.0 / refH).clamp(0.05, 0.95));
      case SlideComponentId.rankBadge:
        return Offset((42.0 / refW).clamp(0.05, 0.95), (68.0 / refH).clamp(0.05, 0.95));
      case SlideComponentId.title:
        if (widget.slide.type == SlideType.cover) {
          return Offset(0.50, bottomY(120.0));
        } else if (widget.slide.type == SlideType.cta) {
          return Offset(0.50, bottomY(190.0));
        }
        return Offset(0.50, bottomY(158.0));
      case SlideComponentId.rating:
        return Offset((58.0 / refW).clamp(0.05, 0.95), bottomY(110.0));
      case SlideComponentId.seasons:
        return Offset(((refW - 58.0) / refW).clamp(0.05, 0.95), bottomY(110.0));
      case SlideComponentId.episodes:
        return Offset(0.50, bottomY(110.0));
      case SlideComponentId.studio:
        return Offset(0.50, bottomY(72.0));
      case SlideComponentId.genres:
        return Offset(0.50, bottomY(36.0));
      case SlideComponentId.synopsis:
        if (widget.slide.type == SlideType.cover) {
          return Offset(0.50, bottomY(68.0));
        } else if (widget.slide.type == SlideType.cta) {
          return Offset(0.50, bottomY(145.0));
        }
        return Offset(0.50, bottomY(236.0));
      case SlideComponentId.hookTag:
        return Offset(0.50, bottomY(190.0));
      case SlideComponentId.swipeIndicator:
        if (widget.slide.type == SlideType.cta) {
          return Offset(0.50, bottomY(68.0));
        }
        return Offset(0.50, bottomY(28.0));
      case SlideComponentId.allContent:
      default:
        return Offset(0.50, bottomY(120.0));
    }
  }

  Widget _buildAlignXButton(
    IconData icon,
    String label,
    double xValue,
    double currentX,
    ValueChanged<double> onTap,
  ) {
    final isSelected = (currentX - xValue).abs() < 0.05;
    return InkWell(
      onTap: () => onTap(xValue),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: isSelected ? Colors.white : Colors.black87),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlignYButton(
    IconData icon,
    String label,
    double yValue,
    double currentY,
    ValueChanged<double> onTap,
  ) {
    final isSelected = (currentY - yValue).abs() < 0.05;
    return InkWell(
      onTap: () => onTap(yValue),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: isSelected ? Colors.white : Colors.black87),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWatermarkControlSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    double? step,
  }) {
    final double range = max - min;
    final double increment = step ?? (range <= 2 ? 0.02 : 5.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12.5)),
            Text(
              value.toStringAsFixed(2),
              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12.5),
            ),
          ],
        ),
        Row(
          children: [
            _buildPreciseBtn(
              icon: Icons.remove,
              onTap: () => onChanged((value - increment).clamp(min, max)),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                  activeTrackColor: AppColors.primary,
                  inactiveTrackColor: AppColors.primary.withValues(alpha: 0.12),
                  thumbColor: AppColors.primary,
                  overlayColor: AppColors.primary.withValues(alpha: 0.12),
                ),
                child: Slider(
                  value: value.clamp(min, max),
                  min: min,
                  max: max,
                  onChanged: onChanged,
                ),
              ),
            ),
            _buildPreciseBtn(
              icon: Icons.add,
              onTap: () => onChanged((value + increment).clamp(min, max)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPreciseBtn({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppColors.primary),
        ),
      ),
    );
  }
}
