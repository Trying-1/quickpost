import 'dart:io';
import 'package:flutter/material.dart';
import '../models/color_fx_preset.dart';

/// Horizontal scrolling picker displaying live filtered thumbnail previews for each FX preset.
class FxPresetPicker extends StatelessWidget {
  final File imageFile;
  final ColorFxType selectedPreset;
  final ValueChanged<ColorFxType> onSelectPreset;

  const FxPresetPicker({
    super.key,
    required this.imageFile,
    required this.selectedPreset,
    required this.onSelectPreset,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 126,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: ColorFxType.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final preset = ColorFxType.values[index];
          final isSelected = preset == selectedPreset;
          final previewMatrix = preset.computeMatrix();

          return GestureDetector(
            onTap: () => onSelectPreset(preset),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 86,
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? const Color(0xFF00E5FF) : Colors.white12,
                  width: isSelected ? 2.5 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFF00E5FF).withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  // Live Thumbnail Preview
                  Expanded(
                    child: ColorFiltered(
                      colorFilter: ColorFilter.matrix(previewMatrix),
                      child: Image.file(
                        imageFile,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                    ),
                  ),

                  // Preset Label Footer
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF1E293B),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          preset.title,
                          style: TextStyle(
                            color: isSelected ? const Color(0xFF00E5FF) : Colors.white,
                            fontSize: 10.5,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            fontFamily: 'Poppins',
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
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

