import 'package:flutter/material.dart';

class DurationSelectorWidget extends StatefulWidget {
  final int duration;
  final Function(int) onDurationChanged;
  final bool isProcessing;
  
  const DurationSelectorWidget({
    Key? key,
    required this.duration,
    required this.onDurationChanged,
    required this.isProcessing,
  }) : super(key: key);

  @override
  State<DurationSelectorWidget> createState() => _DurationSelectorWidgetState();
}

class _DurationSelectorWidgetState extends State<DurationSelectorWidget> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.duration.toString());
  }

  @override
  void didUpdateWidget(DurationSelectorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _controller.text = widget.duration.toString();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Video Duration (seconds):',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          enabled: !widget.isProcessing,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'e.g., 7',
            suffixText: 'sec',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            helperText: 'Min: 1, Max: 60 seconds',
            helperStyle: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
          onChanged: (value) {
            final parsed = int.tryParse(value);
            if (parsed != null && parsed >= 1 && parsed <= 60) {
              widget.onDurationChanged(parsed);
            }
          },
        ),
      ],
    );
  }
}
