import 'package:flutter/material.dart';

/// Fine-tuning slider panel for adjusting brightness and contrast.
class FxAdjustmentsPanel extends StatelessWidget {
  final double brightness;
  final double contrast;
  final ValueChanged<double> onBrightnessChanged;
  final ValueChanged<double> onContrastChanged;
  final VoidCallback onReset;

  const FxAdjustmentsPanel({
    super.key,
    required this.brightness,
    required this.contrast,
    required this.onBrightnessChanged,
    required this.onContrastChanged,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'FINE-TUNE ADJUSTMENTS',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  fontFamily: 'Poppins',
                ),
              ),
              if (brightness != 0.0 || contrast != 0.0)
                TextButton.icon(
                  onPressed: onReset,
                  icon: const Icon(Icons.refresh_rounded, size: 14, color: Color(0xFF00E5FF)),
                  label: const Text('Reset', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 12, fontFamily: 'Poppins')),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Brightness Slider
          _buildSlider(
            context: context,
            icon: Icons.brightness_6_rounded,
            label: 'Brightness',
            value: brightness,
            min: -1.0,
            max: 1.0,
            onChanged: onBrightnessChanged,
          ),
          const SizedBox(height: 14),

          // Contrast Slider
          _buildSlider(
            context: context,
            icon: Icons.contrast_rounded,
            label: 'Contrast',
            value: contrast,
            min: -1.0,
            max: 1.0,
            onChanged: onContrastChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSlider({
    required BuildContext context,
    required IconData icon,
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    final int percent = (value * 100).round();
    final String sign = percent > 0 ? '+' : '';

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF00E5FF), size: 16),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Poppins',
                ),
              ),
              const Spacer(),
              Text(
                '$sign$percent%',
                style: const TextStyle(
                  color: Color(0xFF00E5FF),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8, elevation: 3),
              thumbColor: const Color(0xFF00E5FF),
              activeTrackColor: const Color(0xFF00E5FF),
              inactiveTrackColor: Colors.white12,
              overlayColor: const Color(0xFF00E5FF).withOpacity(0.2),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

