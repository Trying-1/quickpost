import 'package:flutter/material.dart';
import 'package:quickpost/config/app_theme.dart';
import '../models/palette_color.dart';

/// Interactive modal sheet to customize color via HEX, HSV, or RGB sliders.
class ColorPickerDialog extends StatefulWidget {
  final PaletteColor initial;
  final ValueChanged<PaletteColor> onSaved;

  const ColorPickerDialog({
    super.key,
    required this.initial,
    required this.onSaved,
  });

  static Future<void> show(
    BuildContext context, {
    required PaletteColor initial,
    required ValueChanged<PaletteColor> onSaved,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ColorPickerDialog(initial: initial, onSaved: onSaved),
    );
  }

  @override
  State<ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<ColorPickerDialog> {
  late Color _currentColor;
  late String _role;
  late TextEditingController _hexController;
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _currentColor = widget.initial.color;
    _role = widget.initial.role;
    _hexController = TextEditingController(text: widget.initial.hexCode.replaceAll('#', ''));
    _nameController = TextEditingController(
      text: widget.initial.name.isEmpty ? PaletteColor.findNearestName(_currentColor) : widget.initial.name,
    );
  }

  @override
  void dispose() {
    _hexController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _updateFromHsv(HSVColor hsv) {
    setState(() {
      _currentColor = hsv.toColor();
      _hexController.text = _currentColor.value.toRadixString(16).substring(2).toUpperCase();
      _nameController.text = PaletteColor.findNearestName(_currentColor);
    });
  }

  void _onHexSubmitted(String val) {
    final clean = val.replaceAll('#', '').trim();
    if (clean.length == 6) {
      final intVal = int.tryParse(clean, radix: 16);
      if (intVal != null) {
        setState(() {
          _currentColor = Color(0xFF000000 | intVal);
          _nameController.text = PaletteColor.findNearestName(_currentColor);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hsv = HSVColor.fromColor(_currentColor);
    final isDark = _currentColor.computeLuminance() < 0.45;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Top Header & Color Preview Block
            Container(
              height: 90,
              decoration: BoxDecoration(
                color: _currentColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black12, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: _currentColor.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _nameController.text.isEmpty ? 'Custom Color' : _nameController.text,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'RGB(${_currentColor.red}, ${_currentColor.green}, ${_currentColor.blue})',
                          style: TextStyle(
                            color: textColor.withOpacity(0.8),
                            fontSize: 12,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: textColor.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '#${_currentColor.value.toRadixString(16).substring(2).toUpperCase()}',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'monospace',
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // HEX & Name Input Fields
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _hexController,
                    onChanged: _onHexSubmitted,
                    style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: 'HEX CODE',
                      prefixText: '# ',
                      prefixStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontFamily: 'Poppins'),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 4,
                  child: TextField(
                    controller: _nameController,
                    style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Poppins'),
                    decoration: InputDecoration(
                      labelText: 'COLOR NAME',
                      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontFamily: 'Poppins'),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Role Selector
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _role,
                  dropdownColor: Colors.white,
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
                  items: const [
                    DropdownMenuItem(value: 'Dominant', child: Text('Dominant Color')),
                    DropdownMenuItem(value: 'Vibrant Accent', child: Text('Vibrant Accent')),
                    DropdownMenuItem(value: 'Secondary Accent', child: Text('Secondary Accent')),
                    DropdownMenuItem(value: 'Dark Shade', child: Text('Dark Shade')),
                    DropdownMenuItem(value: 'Light Highlight', child: Text('Light Highlight')),
                    DropdownMenuItem(value: 'Muted Neutral', child: Text('Muted Neutral')),
                    DropdownMenuItem(value: 'Custom', child: Text('Custom Tone')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _role = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Hue Slider
            _buildSliderRow(
              label: 'HUE',
              value: hsv.hue,
              min: 0,
              max: 360,
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFF0000),
                  Color(0xFFFFFF00),
                  Color(0xFF00FF00),
                  Color(0xFF00FFFF),
                  Color(0xFF0000FF),
                  Color(0xFFFF00FF),
                  Color(0xFFFF0000),
                ],
              ),
              onChanged: (v) => _updateFromHsv(hsv.withHue(v)),
            ),
            const SizedBox(height: 12),

            // Saturation Slider
            _buildSliderRow(
              label: 'SATURATION',
              value: hsv.saturation,
              min: 0,
              max: 1.0,
              gradient: LinearGradient(
                colors: [
                  HSVColor.fromAHSV(1.0, hsv.hue, 0.0, hsv.value).toColor(),
                  HSVColor.fromAHSV(1.0, hsv.hue, 1.0, hsv.value).toColor(),
                ],
              ),
              onChanged: (v) => _updateFromHsv(hsv.withSaturation(v)),
            ),
            const SizedBox(height: 12),

            // Value / Brightness Slider
            _buildSliderRow(
              label: 'BRIGHTNESS',
              value: hsv.value,
              min: 0,
              max: 1.0,
              gradient: LinearGradient(
                colors: [
                  Colors.black,
                  HSVColor.fromAHSV(1.0, hsv.hue, hsv.saturation, 1.0).toColor(),
                ],
              ),
              onChanged: (v) => _updateFromHsv(hsv.withValue(v)),
            ),
            const SizedBox(height: 20),

            // Quick Tint / Shade Variations Row
            const Text(
              'TINTS & SHADES',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(6, (i) {
                final factor = 0.2 + (i * 0.16);
                final shade = HSVColor.fromAHSV(1.0, hsv.hue, hsv.saturation, factor.clamp(0.05, 1.0)).toColor();
                return Expanded(
                  child: GestureDetector(
                    onTap: () => _updateFromHsv(HSVColor.fromColor(shade)),
                    child: Container(
                      height: 36,
                      margin: EdgeInsets.only(right: i < 5 ? 6 : 0),
                      decoration: BoxDecoration(
                        color: shade,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _currentColor == shade ? Colors.white : Colors.white12,
                          width: _currentColor == shade ? 2 : 1,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),

            // Save Action Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  widget.onSaved(PaletteColor(
                    color: _currentColor,
                    name: _nameController.text.trim(),
                    role: _role,
                    isLocked: widget.initial.isLocked,
                  ));
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text(
                  'Apply Color to Palette',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Poppins'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required Gradient gradient,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
            Text(
              max == 1.0 ? '${(value * 100).toInt()}%' : '${value.toInt()}°',
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 14,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(7),
          ),
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 14,
              overlayShape: SliderComponentShape.noOverlay,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10, elevation: 3),
              thumbColor: Colors.white,
              activeTrackColor: Colors.transparent,
              inactiveTrackColor: Colors.transparent,
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

