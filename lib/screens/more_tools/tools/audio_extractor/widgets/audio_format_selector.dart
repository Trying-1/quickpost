import 'package:flutter/material.dart';
import '../models/audio_export_format.dart';

class AudioFormatSelector extends StatelessWidget {
  final AudioExportFormat selectedFormat;
  final ValueChanged<AudioExportFormat> onFormatChanged;
  final int selectedBitrate;
  final ValueChanged<int> onBitrateChanged;

  const AudioFormatSelector({
    super.key,
    required this.selectedFormat,
    required this.onFormatChanged,
    required this.selectedBitrate,
    required this.onBitrateChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.tune_rounded, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Audio Format & Encoding',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Format Cards
        ...AudioExportFormat.values.map((format) {
          final isSelected = format == selectedFormat;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => onFormatChanged(format),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? format.color.withOpacity(isDark ? 0.16 : 0.08)
                      : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03)),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? format.color : (isDark ? Colors.white12 : Colors.black12),
                    width: isSelected ? 1.8 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: format.color.withOpacity(0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(format.icon, color: format.color, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                format.title,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? format.color : null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: format.color.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '.${format.extensionName}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: format.color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            format.description,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark ? Colors.white70 : Colors.black54,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? format.color : Colors.transparent,
                        border: Border.all(
                          color: isSelected ? format.color : (isDark ? Colors.white30 : Colors.black26),
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),

        // Bitrate row (if format supports bitrate adjustment)
        if (selectedFormat.availableBitrates.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                'Bitrate Quality:',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const Spacer(),
              Text(
                '$selectedBitrate kbps',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: selectedFormat.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: selectedFormat.availableBitrates.map((bitrate) {
                final isSelectedBitrate = bitrate == selectedBitrate;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text('$bitrate kbps'),
                    selected: isSelectedBitrate,
                    selectedColor: selectedFormat.color.withOpacity(0.2),
                    backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
                    side: BorderSide(
                      color: isSelectedBitrate ? selectedFormat.color : Colors.transparent,
                    ),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelectedBitrate ? FontWeight.bold : FontWeight.normal,
                      color: isSelectedBitrate
                          ? selectedFormat.color
                          : (isDark ? Colors.white70 : Colors.black87),
                    ),
                    onSelected: (_) => onBitrateChanged(bitrate),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }
}
