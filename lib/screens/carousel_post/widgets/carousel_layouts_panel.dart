import 'package:flutter/material.dart';
import '../../../../config/app_theme.dart';
import '../models/carousel_slide.dart';
import '../models/carousel_custom_layout.dart';
import '../models/carousel_template_theme.dart';
import '../services/carousel_custom_layout_service.dart';

/// Bottom dock panel for Tab 2: "Layouts".
/// Allows users to view the default layout, save current element positions/styles
/// as a custom reusable layout, and apply or delete saved custom layouts.
class CarouselLayoutsPanel extends StatefulWidget {
  final CarouselSlide activeSlide;
  final CarouselTemplateTheme theme;
  final ValueChanged<CarouselTemplateTheme> onThemeChanged;
  final ValueChanged<CarouselCustomLayout> onApplyLayout;
  final VoidCallback onResetToDefault;
  final ValueChanged<bool> onToggleSync;
  final ValueChanged<String> onShowToast;

  const CarouselLayoutsPanel({
    super.key,
    required this.activeSlide,
    required this.theme,
    required this.onThemeChanged,
    required this.onApplyLayout,
    required this.onResetToDefault,
    required this.onToggleSync,
    required this.onShowToast,
  });

  @override
  State<CarouselLayoutsPanel> createState() => _CarouselLayoutsPanelState();
}

class _CarouselLayoutsPanelState extends State<CarouselLayoutsPanel> {
  List<CarouselCustomLayout> _savedLayouts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLayouts();
  }

  Future<void> _loadLayouts() async {
    final layouts = await CarouselCustomLayoutService.loadCustomLayouts();
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
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppColors.primarySurface,
                  shape: BoxShape.circle,
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
                  hintText: 'e.g. Minimalist Quote Focus',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty) Navigator.pop(ctx, text);
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
      final newLayout = CarouselCustomLayout(
        id: 'layout_${DateTime.now().millisecondsSinceEpoch}',
        name: result,
        createdAt: DateTime.now(),
        contentOffsetX: widget.activeSlide.contentOffsetX,
        contentOffsetY: widget.activeSlide.contentOffsetY,
        headerOffsetY: widget.activeSlide.headerOffsetY,
        componentOffsets: Map<String, Offset>.from(widget.activeSlide.componentOffsets),
        showNumberBadge: widget.theme.showNumberBadge,
        showBodyText: widget.theme.showBodyText,
        showWatermark: widget.theme.showWatermark,
        showSlideCounter: widget.theme.showSlideCounter,
        cardStyle: widget.theme.cardStyle,
        showCardBackdrop: widget.theme.showCardBackdrop,
        rankBadgeStyle: widget.theme.rankBadgeStyle,
        synopsisCardStyle: widget.theme.synopsisCardStyle,
        titleCardStyle: widget.theme.titleCardStyle,
        componentFonts: Map<String, String>.from(widget.theme.componentFonts),
        componentColors: Map<String, Color>.from(widget.theme.componentColors),
      );

      await CarouselCustomLayoutService.saveCustomLayout(newLayout);
      await _loadLayouts();
      widget.onShowToast('Saved custom layout "$result"!');
    }
  }

  Future<void> _deleteLayout(CarouselCustomLayout layout) async {
    await CarouselCustomLayoutService.deleteCustomLayout(layout.id);
    await _loadLayouts();
    widget.onShowToast('Deleted layout "${layout.name}"');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(height: 180, child: Center(child: CircularProgressIndicator()));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Sync toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 24,
                    width: 38,
                    child: Switch(
                      value: widget.theme.syncSlideLayoutAndPosition,
                      onChanged: widget.onToggleSync,
                      activeColor: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Sync Layout with All Slides',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _promptSaveCurrentLayout,
                icon: const Icon(Icons.bookmark_add_rounded, size: 14),
                label: const Text('Save Layout', style: TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Default layout card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primary, width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: AppColors.primarySurface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.layers_rounded, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Standard Layout',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        'Default stacked lower third with draggable components',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: widget.onResetToDefault,
                  child: const Text('Reset', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Saved custom layouts
          const Text(
            'Saved Custom Layouts',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          if (_savedLayouts.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                'No custom layouts saved yet.\nAdjust positions on canvas and tap "Save Layout".',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _savedLayouts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final layout = _savedLayouts[index];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.bookmark_rounded, color: AppColors.primary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          layout.name,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => widget.onApplyLayout(layout),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primarySurface,
                          foregroundColor: AppColors.primary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        child: const Text('Apply', style: TextStyle(fontSize: 11)),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.grey),
                        onPressed: () => _deleteLayout(layout),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

