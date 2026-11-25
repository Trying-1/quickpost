import 'package:flutter/material.dart';
import '../../../../config/app_theme.dart';

/// Horizontal scrollable ribbon for selecting categories with asset count badges.
class CarouselAssetCategoryRibbon extends StatelessWidget {
  final List<String> categories;
  final String selectedCategory;
  final Map<String, int> counts;
  final ValueChanged<String> onSelectCategory;
  final VoidCallback onAddCategory;
  final ValueChanged<String>? onDeleteCategory;

  const CarouselAssetCategoryRibbon({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.counts,
    required this.onSelectCategory,
    required this.onAddCategory,
    this.onDeleteCategory,
  });

  @override
  Widget build(BuildContext context) {
    final displayCategories = ['All', ...categories.where((c) => c != 'All')];

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: displayCategories.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == displayCategories.length) {
            return ActionChip(
              onPressed: onAddCategory,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              avatar: const Icon(Icons.add_rounded, size: 14, color: AppColors.primary),
              label: const Text(
                'New Topic',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              backgroundColor: AppColors.primarySurface,
              side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              visualDensity: VisualDensity.compact,
            );
          }

          final category = displayCategories[index];
          final isSelected = selectedCategory.toLowerCase() == category.toLowerCase();
          final count = counts[category] ?? 0;

          return ChoiceChip(
            selected: isSelected,
            showCheckmark: false,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
                if (count > 0 || category == 'All') ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white.withValues(alpha: 0.25) : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            selectedColor: AppColors.primary,
            backgroundColor: Colors.white,
            side: BorderSide(
              color: isSelected ? AppColors.primary : Colors.grey.shade300,
              width: 1,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            visualDensity: VisualDensity.compact,
            onSelected: (_) => onSelectCategory(category),
          );
        },
      ),
    );
  }
}

