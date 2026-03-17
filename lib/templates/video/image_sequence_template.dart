import 'package:flutter/material.dart';
import 'video_template_base.dart';

class ImageSequenceTemplate extends VideoTemplateBase {
  @override
  String get id => 'image_sequence';
  
  @override
  String get name => 'Image Sequence';
  
  @override
  IconData get icon => Icons.collections;
  
  @override
  Color get color => Colors.blue;
  
  @override
  Map<String, dynamic> getDefaultSettings() {
    return {
      'images': <String>[], // List of image paths
      'durationPerImage': 0.2, // Seconds per image
      'sequenceMode': 'sequential', // 'sequential' or 'random'
      'allowRepeat': true, // Whether to repeat the sequence
    };
  }
  
  @override
  Widget buildSettingsUI({
    required BuildContext context,
    required Map<String, dynamic> settings,
    required Function(Map<String, dynamic>) onSettingsChanged,
    required bool isProcessing,
  }) {
    final durationPerImage = settings['durationPerImage'] ?? 0.2;
    final sequenceMode = settings['sequenceMode'] ?? 'sequential';
    final allowRepeat = settings['allowRepeat'] ?? true;
    final images = settings['images'] as List<String>? ?? [];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Images count display
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.photo_library, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '${images.length} images selected',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[700],
                    ),
                  ),
                ],
              ),
              if (images.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Each image shows for ${durationPerImage.toStringAsFixed(2)}s',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  allowRepeat 
                    ? '• Images repeat to fill duration'
                    : '• Extra images skipped if too many',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue[500],
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '• Final video = min(video duration, audio duration)',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue[500],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // Duration per image input
        const Text(
          'Duration per image (seconds):',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        _DurationInputField(
          initialValue: durationPerImage,
          enabled: !isProcessing,
          onChanged: (value) {
            final newSettings = Map<String, dynamic>.from(settings);
            newSettings['durationPerImage'] = value;
            onSettingsChanged(newSettings);
          },
        ),
        const SizedBox(height: 16),
        
        // Sequence mode
        const Text(
          'Sequence Mode:',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildModeButton(
                label: 'Sequential',
                icon: Icons.view_carousel,
                isSelected: sequenceMode == 'sequential',
                onTap: isProcessing ? null : () {
                  final newSettings = Map<String, dynamic>.from(settings);
                  newSettings['sequenceMode'] = 'sequential';
                  onSettingsChanged(newSettings);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildModeButton(
                label: 'Random',
                icon: Icons.shuffle,
                isSelected: sequenceMode == 'random',
                onTap: isProcessing ? null : () {
                  final newSettings = Map<String, dynamic>.from(settings);
                  newSettings['sequenceMode'] = 'random';
                  onSettingsChanged(newSettings);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Allow repeat toggle
        InkWell(
          onTap: isProcessing ? null : () {
            final newSettings = Map<String, dynamic>.from(settings);
            newSettings['allowRepeat'] = !allowRepeat;
            onSettingsChanged(newSettings);
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                Icon(
                  allowRepeat ? Icons.repeat : Icons.repeat_one,
                  color: allowRepeat ? color : Colors.grey[600],
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Repeat sequence',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: allowRepeat ? Colors.black87 : Colors.grey[600],
                    ),
                  ),
                ),
                Switch(
                  value: allowRepeat,
                  activeColor: color,
                  onChanged: isProcessing ? null : (value) {
                    final newSettings = Map<String, dynamic>.from(settings);
                    newSettings['allowRepeat'] = value;
                    onSettingsChanged(newSettings);
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildModeButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? color : Colors.grey[600],
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? color : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  @override
  bool validateSettings(Map<String, dynamic> settings) {
    final images = settings['images'] as List<String>?;
    return images != null && images.isNotEmpty;
  }
  
  @override
  Map<String, dynamic> getNativeSettings(Map<String, dynamic> settings, {Map<String, dynamic>? automationSettings}) {
    final Map<String, dynamic> native = {
      'fadeInDuration': 1.0,
      'zoomScale': 1.2,
      'zoomDuration': 2.0,
      'durationPerImage': settings['durationPerImage'] ?? 2.0,
      'sequenceMode': settings['sequenceMode'] ?? 'sequential',
      'allowRepeat': settings['allowRepeat'] ?? true,
    };
    if (automationSettings != null) {
      native['automationSettings'] = automationSettings;
    }
    return native;
  }
}

class _DurationInputField extends StatefulWidget {
  final double initialValue;
  final bool enabled;
  final Function(double) onChanged;

  const _DurationInputField({
    required this.initialValue,
    required this.enabled,
    required this.onChanged,
  });

  @override
  State<_DurationInputField> createState() => _DurationInputFieldState();
}

class _DurationInputFieldState extends State<_DurationInputField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialValue.toStringAsFixed(2),
    );
  }

  @override
  void didUpdateWidget(_DurationInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue) {
      _controller.text = widget.initialValue.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      enabled: widget.enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        hintText: 'e.g., 2.5',
        suffixText: 'sec',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        helperText: 'Min: 0.01, Max: video duration',
        helperStyle: TextStyle(fontSize: 11, color: Colors.grey[600]),
      ),
      onChanged: (value) {
        final parsed = double.tryParse(value);
        if (parsed != null && parsed >= 0.01) {
          widget.onChanged(parsed);
        }
      },
    );
  }
}
