import 'package:flutter/material.dart';

class AdvancedColorPicker extends StatefulWidget {
  final Color initialColor;
  final ValueChanged<Color> onColorChanged;

  const AdvancedColorPicker({
    super.key,
    required this.initialColor,
    required this.onColorChanged,
  });

  @override
  State<AdvancedColorPicker> createState() => _AdvancedColorPickerState();
}

class _AdvancedColorPickerState extends State<AdvancedColorPicker> {
  late HSVColor _hsvColor;
  late TextEditingController _hexController;
  late TextEditingController _opacityController;

  @override
  void initState() {
    super.initState();
    _hsvColor = HSVColor.fromColor(widget.initialColor);
    _hexController = TextEditingController(text: _colorToHex(widget.initialColor));
    _opacityController = TextEditingController(text: (widget.initialColor.opacity * 100).toInt().toString());
  }

  @override
  void dispose() {
    _hexController.dispose();
    _opacityController.dispose();
    super.dispose();
  }

  String _colorToHex(Color color) {
    return color.value.toRadixString(16).padLeft(8, '0').toUpperCase().substring(2);
  }

  void _updateColor(HSVColor newColor, {bool updateInputs = true}) {
    setState(() {
      _hsvColor = newColor;
      if (updateInputs) {
        _hexController.text = _colorToHex(_hsvColor.toColor());
        _opacityController.text = (_hsvColor.alpha * 100).toInt().toString();
      }
    });
    widget.onColorChanged(_hsvColor.toColor());
  }

  void _handleHexInput(String val) {
    if (val.length == 6) {
      try {
        final color = Color(int.parse("FF$val", radix: 16));
        _updateColor(HSVColor.fromColor(color.withOpacity(_hsvColor.alpha)), updateInputs: false);
      } catch (_) {}
    }
  }

  void _handleOpacityInput(String val) {
    final opacity = int.tryParse(val);
    if (opacity != null && opacity >= 0 && opacity <= 100) {
      _updateColor(_hsvColor.withAlpha(opacity / 100.0), updateInputs: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // S/V Picker Rectangle
        SizedBox(
          height: 180,
          child: GestureDetector(
            onPanUpdate: (details) {
              final RenderBox box = context.findRenderObject() as RenderBox;
              final localPos = details.localPosition;
              // We need to account for the actual widget size here
              // For simplicity, we'll use a LayoutBuilder for the SV area
            },
            child: _SVPicker(
              hsvColor: _hsvColor,
              onChanged: (v, s) => _updateColor(_hsvColor.withSaturation(s).withValue(v)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Hue Slider
        _SliderRow(
          label: 'Hue',
          child: _HueSlider(
            hue: _hsvColor.hue,
            onChanged: (h) => _updateColor(_hsvColor.withHue(h)),
          ),
        ),
        const SizedBox(height: 8),
        // Opacity Slider
        _SliderRow(
          label: 'Opacity',
          child: _OpacitySlider(
            color: _hsvColor.toColor(),
            opacity: _hsvColor.alpha,
            onChanged: (o) => _updateColor(_hsvColor.withAlpha(o)),
          ),
        ),
        const SizedBox(height: 20),
        // Inputs
        Row(
          children: [
            Expanded(
              flex: 2,
              child: _InputBox(
                label: 'HEX',
                controller: _hexController,
                onChanged: _handleHexInput,
                prefix: '#',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _InputBox(
                label: 'Opacity',
                controller: _opacityController,
                onChanged: _handleOpacityInput,
                suffix: '%',
              ),
            ),
            const SizedBox(width: 12),
            // Preview
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _hsvColor.toColor(),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey[300]!),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SVPicker extends StatelessWidget {
  final HSVColor hsvColor;
  final Function(double, double) onChanged;

  const _SVPicker({required this.hsvColor, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return GestureDetector(
        onPanUpdate: (details) {
          final x = details.localPosition.dx.clamp(0.0, constraints.maxWidth);
          final y = details.localPosition.dy.clamp(0.0, constraints.maxHeight);
          onChanged(1 - (y / constraints.maxHeight), x / constraints.maxWidth);
        },
        onPanDown: (details) {
          final x = details.localPosition.dx.clamp(0.0, constraints.maxWidth);
          final y = details.localPosition.dy.clamp(0.0, constraints.maxHeight);
          onChanged(1 - (y / constraints.maxHeight), x / constraints.maxWidth);
        },
        child: CustomPaint(
          size: Size.infinite,
          painter: _SVPainter(hsvColor: hsvColor),
        ),
      );
    });
  }
}

class _SVPainter extends CustomPainter {
  final HSVColor hsvColor;
  _SVPainter({required this.hsvColor});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    
    // Base color (Hue)
    final paintHue = Paint()
      ..shader = LinearGradient(
        colors: [Colors.white, HSVColor.fromAHSV(1.0, hsvColor.hue, 1.0, 1.0).toColor()],
      ).createShader(rect);
    canvas.drawRect(rect, paintHue);

    // Value (Black gradient)
    final paintValue = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Colors.black],
      ).createShader(rect);
    canvas.drawRect(rect, paintValue);

    // Selector circle
    final x = hsvColor.saturation * size.width;
    final y = (1 - hsvColor.value) * size.height;
    final paintSelector = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset(x, y), 8, paintSelector);
    canvas.drawCircle(Offset(x, y), 7, Paint()..color = Colors.black.withOpacity(0.3)..style = PaintingStyle.stroke..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(covariant _SVPainter oldDelegate) => oldDelegate.hsvColor != hsvColor;
}

class _HueSlider extends StatelessWidget {
  final double hue;
  final ValueChanged<double> onChanged;

  const _HueSlider({required this.hue, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 12,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFF0000), Color(0xFFFFFF00), Color(0xFF00FF00),
            Color(0xFF00FFFF), Color(0xFF0000FF), Color(0xFFFF00FF),
            Color(0xFFFF0000),
          ],
        ),
      ),
      child: SliderTheme(
        data: SliderThemeData(
          trackHeight: 12,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          overlayShape: SliderComponentShape.noOverlay,
          activeTrackColor: Colors.transparent,
          inactiveTrackColor: Colors.transparent,
          thumbColor: Colors.white,
        ),
        child: Slider(
          value: hue,
          min: 0,
          max: 360,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _OpacitySlider extends StatelessWidget {
  final Color color;
  final double opacity;
  final ValueChanged<double> onChanged;

  const _OpacitySlider({required this.color, required this.opacity, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Checkerboard placeholder (simple approach)
        Container(
          height: 12,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: Colors.grey[200],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Row(
              children: List.generate(20, (i) => Expanded(child: Container(color: i % 2 == 0 ? Colors.white : Colors.grey[300]))),
            ),
          ),
        ),
        Container(
          height: 12,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            gradient: LinearGradient(
              colors: [color.withOpacity(0), color.withOpacity(1)],
            ),
          ),
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 12,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: SliderComponentShape.noOverlay,
              activeTrackColor: Colors.transparent,
              inactiveTrackColor: Colors.transparent,
              thumbColor: Colors.white,
            ),
            child: Slider(
              value: opacity,
              min: 0,
              max: 1.0,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final Widget child;
  const _SliderRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 60, child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
        Expanded(child: child),
      ],
    );
  }
}

class _InputBox extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? prefix;
  final String? suffix;

  const _InputBox({
    required this.label,
    required this.controller,
    required this.onChanged,
    this.prefix,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          onChanged: onChanged,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            prefixText: prefix,
            suffixText: suffix,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[300]!)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[300]!)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF6C63FF))),
          ),
        ),
      ],
    );
  }
}
