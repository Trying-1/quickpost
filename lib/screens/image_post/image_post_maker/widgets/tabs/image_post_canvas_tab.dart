import 'dart:io';
import 'package:flutter/material.dart';
import '../image_post_shared_controls.dart';

/// Canvas settings tab panel (index 5): 0.85x Frame preset, 9:16 fullscreen toggle,
/// background image/color/filters, and main image placement/scale/radius/border.
class ImagePostCanvasTab extends StatelessWidget {
  final bool fullScreen;
  final File? bgImage;
  final String bgColor;
  final double bgBrightness;
  final double bgSaturation;
  final double bgBlur;
  final double videoX;
  final double videoY;
  final double videoScale;
  final double videoRadius;
  final double videoBorderWidth;
  final String videoBorderColor;
  final String watermarkType;

  final VoidCallback onToggleFramedPreset;
  final ValueChanged<bool> onFullScreenChanged;
  final VoidCallback onPickBgImage;
  final VoidCallback onClearBgImage;
  final ValueChanged<String> onBgColorChanged;
  final ValueChanged<double> onBgBrightnessChanged;
  final ValueChanged<double> onBgSaturationChanged;
  final ValueChanged<double> onBgBlurChanged;
  final ValueChanged<double> onVideoXChanged;
  final ValueChanged<double> onVideoYChanged;
  final ValueChanged<double> onVideoScaleChanged;
  final ValueChanged<double> onVideoRadiusChanged;
  final ValueChanged<double> onVideoBorderWidthChanged;
  final ValueChanged<String> onVideoBorderColorChanged;

  const ImagePostCanvasTab({
    super.key,
    required this.fullScreen,
    required this.bgImage,
    required this.bgColor,
    required this.bgBrightness,
    required this.bgSaturation,
    required this.bgBlur,
    required this.videoX,
    required this.videoY,
    required this.videoScale,
    required this.videoRadius,
    required this.videoBorderWidth,
    required this.videoBorderColor,
    required this.watermarkType,
    required this.onToggleFramedPreset,
    required this.onFullScreenChanged,
    required this.onPickBgImage,
    required this.onClearBgImage,
    required this.onBgColorChanged,
    required this.onBgBrightnessChanged,
    required this.onBgSaturationChanged,
    required this.onBgBlurChanged,
    required this.onVideoXChanged,
    required this.onVideoYChanged,
    required this.onVideoScaleChanged,
    required this.onVideoRadiusChanged,
    required this.onVideoBorderWidthChanged,
    required this.onVideoBorderColorChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isFramed = videoScale == 0.85 &&
        videoBorderWidth == 1.5 &&
        videoBorderColor.toUpperCase() == '#FFFFFF' &&
        bgColor == '#000000' &&
        bgImage == null &&
        watermarkType == 'none';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Canvas Settings',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: onToggleFramedPreset,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isFramed
                          ? Colors.deepOrange.withValues(alpha: 0.12)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color:
                            isFramed ? Colors.deepOrange : Colors.grey.shade300,
                        width: isFramed ? 1.4 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isFramed ? Icons.check : Icons.crop_free,
                          size: 13,
                          color: isFramed
                              ? Colors.deepOrange
                              : Colors.grey.shade800,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '0.85x Frame',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isFramed
                                ? Colors.deepOrange
                                : Colors.grey.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Switch(value: fullScreen, onChanged: onFullScreenChanged),
              ],
            ),
          ],
        ),
        const Text(
          'Enable 9:16 Fullscreen Padding',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        if (fullScreen) ...[
          const SizedBox(height: 16),
          const Text(
            'Background Mode',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: bgImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.file(
                      bgImage!,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    ),
                  )
                : const Icon(Icons.wallpaper, size: 40),
            title: const Text('Background Image'),
            subtitle: Text(
              bgImage == null ? 'None selected' : 'Change background image',
            ),
            trailing: bgImage != null
                ? IconButton(
                    onPressed: onClearBgImage,
                    icon: const Icon(Icons.close, color: Colors.red),
                  )
                : const Icon(Icons.chevron_right),
            onTap: onPickBgImage,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          if (bgImage == null) ...[
            const SizedBox(height: 20),
            const Text('Background Color'),
            const SizedBox(height: 8),
            ImagePostColorPicker(
              currentColor: bgColor,
              onPick: onBgColorChanged,
            ),
          ] else ...[
            const SizedBox(height: 16),
            ImagePostControlSlider(
              label: 'Brightness',
              value: bgBrightness,
              min: 0.0,
              max: 2.0,
              onChanged: onBgBrightnessChanged,
            ),
            ImagePostControlSlider(
              label: 'Saturation',
              value: bgSaturation,
              min: 0.0,
              max: 2.0,
              onChanged: onBgSaturationChanged,
            ),
            ImagePostControlSlider(
              label: 'Blur',
              value: bgBlur,
              min: 0.0,
              max: 100.0,
              onChanged: onBgBlurChanged,
            ),
          ],
        ],
        const Divider(height: 32),
        const Text(
          'Image Placement',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        ImagePostControlSlider(
          label: 'Horizontal Alignment (X)',
          value: videoX,
          min: 0.0,
          max: 1.0,
          onChanged: onVideoXChanged,
        ),
        ImagePostControlSlider(
          label: 'Vertical Alignment (Y)',
          value: videoY,
          min: 0.0,
          max: 1.0,
          onChanged: onVideoYChanged,
        ),
        const SizedBox(height: 16),
        ImagePostControlSlider(
          label: 'Image Scale',
          value: videoScale,
          min: 0.1,
          max: 3.0,
          onChanged: onVideoScaleChanged,
        ),
        const SizedBox(height: 8),
        ImagePostControlSlider(
          label: 'Corner Radius',
          value: videoRadius,
          min: 0.0,
          max: 200.0,
          onChanged: onVideoRadiusChanged,
        ),
        const SizedBox(height: 16),
        ImagePostControlSlider(
          label: 'Border Width',
          value: videoBorderWidth,
          min: 0.0,
          max: 50.0,
          onChanged: onVideoBorderWidthChanged,
        ),
        if (videoBorderWidth > 0) ...[
          const SizedBox(height: 12),
          const Text(
            'Border Color',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          ImagePostColorPicker(
            currentColor: videoBorderColor,
            onPick: onVideoBorderColorChanged,
          ),
        ],
        const Divider(height: 32),
      ],
    );
  }
}

