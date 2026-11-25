import 'package:flutter/material.dart';
import '../../../../config/app_theme.dart';

/// Horizontal scrollable ribbon for selecting anime categories with asset count badges.
class AnimeAssetCategoryRibbon extends StatelessWidget {
  final List<String> categories;
  final String selectedCategory;
  final Map<String, int> counts;
  final ValueChanged<String> onSelectCategory;
  final VoidCallback onAddCategory;
  final ValueChanged<String>? onDeleteCategory;

  const AnimeAssetCategoryRibbon({
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
    // Ensure 'All' is at the very beginning
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
            // "+ Add Anime" Action Chip
            return ActionChip(
              onPressed: onAddCategory,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              avatar: const Icon(Icons.add_rounded, size: 14, color: AppColors.primary),
              label: const Text(
                'New Anime',
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

          return GestureDetector(
            onLongPress: (category != 'All' && category != 'General' && onDeleteCategory != null)
                ? () => _showCategoryOptions(context, category)
                : null,
            child: ChoiceChip(
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
              backgroundColor: Colors.grey.shade100,
              side: BorderSide(
                color: isSelected ? AppColors.primary : Colors.grey.shade300,
                width: 1,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              visualDensity: VisualDensity.compact,
              onSelected: (_) => onSelectCategory(category),
            ),
          );
        },
      ),
    );
  }

  void _showCategoryOptions(BuildContext context, String category) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('Anime: $category', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Manage this category'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete Category', style: TextStyle(color: Colors.red)),
              subtitle: const Text('Existing images will be moved to General'),
              onTap: () {
                Navigator.pop(ctx);
                onDeleteCategory?.call(category);
              },
            ),
          ],
        ),
      ),
    );
  }
}
