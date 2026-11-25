import 'package:flutter/material.dart';
import '../../../../config/app_theme.dart';
import '../models/carousel_slide.dart';
import '../models/carousel_template_theme.dart';

/// Control panel for precision slider positioning of individual slide components.
class SlidePositionPanel extends StatefulWidget {
  final CarouselSlide slide;
  final CarouselTemplateTheme? theme;
  final String? activeComponentKey;
  final ValueChanged<String>? onSelectComponent;
  final ValueChanged<CarouselSlide> onSlideChanged;
  final VoidCallback onApplyToAll;
  final VoidCallback onReset;
  final void Function(String componentKey)? onResetComponent;
  final bool syncSlideLayoutAndPosition;
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
    this.syncSlideLayoutAndPosition = true,
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
    switch (widget.slide.type) {
      case SlideType.cover:
        return SlideComponentId.coverComponents;
      case SlideType.cta:
        return SlideComponentId.ctaComponents;
      case SlideType.content:
        return SlideComponentId.contentComponents;
    }
  }

  IconData _getComponentIcon(String key) {
    switch (key) {
      case SlideComponentId.allContent:
        return Icons.dashboard_rounded;
      case SlideComponentId.title:
        return Icons.title_rounded;
      case SlideComponentId.bodyText:
        return Icons.format_quote_rounded;
      case SlideComponentId.pageHandle:
        return Icons.alternate_email_rounded;
      case SlideComponentId.slideCounter:
        return Icons.numbers_rounded;
      case SlideComponentId.swipeIndicator:
        return Icons.swipe_rounded;
      default:
        return Icons.widgets_rounded;
    }
  }

  Offset get _currentOffset {
    return widget.slide.getComponentOffset(_selectedComponentKey);
  }

  void _updateOffset({double? dx, double? dy}) {
    final current = _currentOffset;
    final newX = (dx ?? current.dx).clamp(-180.0, 180.0);
    final newY = (dy ?? current.dy).clamp(-350.0, 350.0);

    final updated = widget.slide.copyWithComponentOffset(
      _selectedComponentKey,
      Offset(newX, newY),
    );
    widget.onSlideChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final components = _availableComponents;
    final offset = _currentOffset;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Sync toggle & Reset
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (widget.slide.type == SlideType.content && widget.onToggleSync != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 24,
                      width: 38,
                      child: Switch(
                        value: widget.syncSlideLayoutAndPosition,
                        onChanged: widget.onToggleSync,
                        activeColor: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Sync with All Slides',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                )
              else
                const Text(
                  'Component Positioning',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      widget.onResetComponent?.call(_selectedComponentKey);
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 14),
                    label: const Text('Reset Component', style: TextStyle(fontSize: 11)),
                  ),
                  TextButton.icon(
                    onPressed: widget.onReset,
                    icon: const Icon(Icons.restart_alt_rounded, size: 14),
                    label: const Text('Reset All', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Horizontal selector of components
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: components.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final key = components[index];
                final isSelected = key == _selectedComponentKey;
                final label = SlideComponentId.getLabel(key);

                return ChoiceChip(
                  selected: isSelected,
                  showCheckmark: false,
                  avatar: Icon(
                    _getComponentIcon(key),
                    size: 14,
                    color: isSelected ? Colors.white : AppColors.primary,
                  ),
                  label: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  selectedColor: AppColors.primary,
                  backgroundColor: Colors.grey.shade100,
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : Colors.grey.shade300,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  onSelected: (_) {
                    setState(() => _selectedComponentKey = key);
                    widget.onSelectComponent?.call(key);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Sliders card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // X Position Slider
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Horizontal (X): ${offset.dx.toStringAsFixed(0)}px',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.restore_rounded, size: 16),
                      tooltip: 'Center X',
                      onPressed: () => _updateOffset(dx: 0.0),
                    ),
                  ],
                ),
                Slider(
                  value: offset.dx.clamp(-180.0, 180.0),
                  min: -180.0,
                  max: 180.0,
                  activeColor: AppColors.primary,
                  onChanged: (val) => _updateOffset(dx: val),
                ),
                const SizedBox(height: 8),

                // Y Position Slider
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Vertical (Y): ${offset.dy.toStringAsFixed(0)}px',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.restore_rounded, size: 16),
                      tooltip: 'Center Y',
                      onPressed: () => _updateOffset(dy: 0.0),
                    ),
                  ],
                ),
                Slider(
                  value: offset.dy.clamp(-350.0, 350.0),
                  min: -350.0,
                  max: 350.0,
                  activeColor: AppColors.primary,
                  onChanged: (val) => _updateOffset(dy: val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Apply to all button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: widget.onApplyToAll,
              icon: const Icon(Icons.copy_all_rounded, size: 16),
              label: const Text('Apply Positions to All Slides'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primarySurface,
                foregroundColor: AppColors.primary,
                elevation: 0,
                side: const BorderSide(color: AppColors.primary, width: 0.8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

