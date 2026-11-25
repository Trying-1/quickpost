import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../models/user_crop_setting.dart';
import '../services/user_crop_settings_service.dart';

/// Clean, simple bottom sheet allowing users to name and save their current crop framing
/// for fast 1-tap reuse.
class UserCropPresetSheet extends StatefulWidget {
  final NormalizedCropRect? currentCropRect;
  final ValueChanged<UserCropSetting>? onPresetSelected;

  const UserCropPresetSheet({
    super.key,
    this.currentCropRect,
    this.onPresetSelected,
  });

  static Future<UserCropSetting?> show(
    BuildContext context, {
    NormalizedCropRect? currentCropRect,
    ValueChanged<UserCropSetting>? onPresetSelected,
  }) {
    return showModalBottomSheet<UserCropSetting>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => UserCropPresetSheet(
        currentCropRect: currentCropRect,
        onPresetSelected: onPresetSelected,
      ),
    );
  }

  @override
  State<UserCropPresetSheet> createState() => _UserCropPresetSheetState();
}

class _UserCropPresetSheetState extends State<UserCropPresetSheet> {
  final TextEditingController _nameController = TextEditingController();
  bool _isExactFraming = true;

  @override
  void initState() {
    super.initState();
    if (widget.currentCropRect != null) {
      final ratio = widget.currentCropRect!.aspectRatio;
      final label = UserCropSettingsService.formatRatioLabel(ratio);
      _nameController.text = 'My Crop ($label)';
    } else {
      _nameController.text = 'My Crop';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _saveCrop() async {
    if (widget.currentCropRect == null) return;
    final name = _nameController.text.trim().isEmpty
        ? 'Custom Crop'
        : _nameController.text.trim();

    final preset = UserCropSettingsService.instance.createFromCrop(
      name: name,
      rect: widget.currentCropRect!,
      isExactFraming: _isExactFraming,
    );

    await UserCropSettingsService.instance.addPreset(preset);

    if (mounted) {
      widget.onPresetSelected?.call(preset);
      Navigator.pop(context, preset);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final rect = widget.currentCropRect;
    final ratio = rect?.aspectRatio ?? 1.0;
    final ratioLabel = UserCropSettingsService.formatRatioLabel(ratio);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Save Crop Setting',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 20),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Current Frame info
              if (rect != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primarySurface,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          ratioLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Current Frame: ${(rect.width * 100).toInt()}% × ${(rect.height * 100).toInt()}%',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              // Name input
              const Text(
                'NAME',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _nameController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'e.g. Header, Subtitle Cut, My Framing',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 14),

              // Framing toggle
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Remember exact box position', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: const Text('If off, only sets ratio and centers it', style: TextStyle(fontSize: 11, color: Colors.grey)),
                value: _isExactFraming,
                activeTrackColor: AppColors.primary,
                onChanged: (val) => setState(() => _isExactFraming = val),
              ),
              const SizedBox(height: 16),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: _saveCrop,
                  icon: const Icon(Icons.bookmark_added_rounded, size: 18),
                  label: const Text('Save Setting', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ),

              // Saved presets list if any
              ValueListenableBuilder<List<UserCropSetting>>(
                valueListenable: UserCropSettingsService.instance.presetsNotifier,
                builder: (context, presets, _) {
                  if (presets.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 8),
                      const Text(
                        'YOUR SAVED PRESETS',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      ...presets.map((preset) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(preset.ratioLabel, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(preset.name, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                          onPressed: () => UserCropSettingsService.instance.deletePreset(preset.id),
                        ),
                        onTap: () {
                          widget.onPresetSelected?.call(preset);
                          Navigator.pop(context, preset);
                        },
                      )),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
