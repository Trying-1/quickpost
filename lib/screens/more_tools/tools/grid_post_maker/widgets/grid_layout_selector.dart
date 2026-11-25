import 'package:flutter/material.dart';
import 'package:quickpost/config/app_theme.dart';
import '../models/grid_layout_type.dart';

/// Horizontal ribbon of selectable Instagram grid layout presets.
class GridLayoutSelector extends StatelessWidget {
  final GridLayoutType selectedLayout;
  final ValueChanged<GridLayoutType> onLayoutSelected;

  const GridLayoutSelector({
    super.key,
    required this.selectedLayout,
    required this.onLayoutSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 94,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: GridLayoutType.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final layout = GridLayoutType.values[index];
          final isSelected = layout == selectedLayout;

          return GestureDetector(
            onTap: () => onLayoutSelected(layout),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 120,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFD81B60) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? const Color(0xFFAD1457) : const Color(0xFFE2E8F0),
                  width: isSelected ? 1.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? const Color(0xFFD81B60).withOpacity(0.25)
                        : Colors.black.withOpacity(0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(
                        Icons.grid_on_rounded,
                        size: 18,
                        color: isSelected ? Colors.white : const Color(0xFFD81B60),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withOpacity(0.2)
                              : const Color(0xFFFCE4EC),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          layout.badge,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : const Color(0xFFC2185B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        layout.label,
                        style: TextStyle(
                          fontFamily: AppTextStyles.fontFamily,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: isSelected ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        layout.subtitle,
                        style: TextStyle(
                          fontFamily: AppTextStyles.fontFamily,
                          fontSize: 9.5,
                          color: isSelected ? Colors.white.withOpacity(0.85) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

