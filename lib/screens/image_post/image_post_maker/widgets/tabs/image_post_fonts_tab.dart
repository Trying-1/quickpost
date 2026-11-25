import 'package:flutter/material.dart';
import '../../../../../config/app_theme.dart';
import '../../../../../utils/font_selector.dart';
import '../image_post_shared_controls.dart';

/// Fonts tab panel (index 4): switches between Username and Handle font families.
class ImagePostFontsTab extends StatelessWidget {
  final int selectedStyleSubTab;
  final FontInfo? selectedUsernameFont;
  final FontInfo? selectedHandleFont;
  final ValueChanged<int> onSubTabChanged;
  final ValueChanged<FontInfo> onFontSelected;

  const ImagePostFontsTab({
    super.key,
    required this.selectedStyleSubTab,
    required this.selectedUsernameFont,
    required this.selectedHandleFont,
    required this.onSubTabChanged,
    required this.onFontSelected,
  });

  @override
  Widget build(BuildContext context) {
    final fonts = getAllFonts();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ImagePostSubTabButtonSmall(
              index: 0,
              selectedIndex: selectedStyleSubTab,
              label: 'Username',
              icon: Icons.person_outline,
              onTap: onSubTabChanged,
            ),
            ImagePostSubTabButtonSmall(
              index: 1,
              selectedIndex: selectedStyleSubTab,
              label: 'Handle',
              icon: Icons.alternate_email,
              onTap: onSubTabChanged,
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Font Family',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: fonts.length,
            itemBuilder: (context, index) {
              final font = fonts[index];
              final bool isSelected = selectedStyleSubTab == 0
                  ? selectedUsernameFont == font
                  : selectedHandleFont == font;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(
                    font.displayName,
                    style: TextStyle(
                      fontFamily: font.family,
                      fontWeight: font.weight,
                      fontStyle: font.style,
                      color: isSelected ? Colors.white : Colors.black87,
                      fontSize: 12,
                    ),
                  ),
                  selected: isSelected,
                  showCheckmark: false,
                  onSelected: (_) => onFontSelected(font),
                  selectedColor: AppColors.primary,
                  backgroundColor: Colors.grey.shade100,
                  checkmarkColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

