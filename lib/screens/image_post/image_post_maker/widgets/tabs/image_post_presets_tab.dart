import 'package:flutter/material.dart';
import '../../../../../config/app_config.dart';
import '../../../../../config/app_theme.dart';
import '../../../../../models/image_post_preset.dart';
import '../../../../../models/watermark_preset.dart';
import '../../../../../services/image_post_preset_service.dart';
import '../../../../../services/watermark_preset_service.dart';

/// Presets tab panel (index 6): switches between Watermark Styles (JSON)
/// and full Project Templates (ZIP) + backup actions.
class ImagePostPresetsTab extends StatelessWidget {
  final int selectedPresetSubTab;
  final ValueChanged<int> onSubTabChanged;

  // Watermark preset callbacks
  final VoidCallback onSaveWatermarkPreset;
  final ValueChanged<WatermarkPreset> onLoadWatermarkPreset;
  final ValueChanged<WatermarkPreset> onUpdateWatermarkPreset;
  final ValueChanged<WatermarkPreset> onRenameWatermarkPreset;
  final VoidCallback onExportWatermarkPresets;
  final VoidCallback onImportWatermarkPresets;

  // Project preset callbacks
  final VoidCallback onSaveProjectPreset;
  final Future<void> Function(ImagePostPreset) onLoadProjectPreset;
  final ValueChanged<ImagePostPreset> onUpdateProjectPreset;
  final ValueChanged<ImagePostPreset> onRenameProjectPreset;
  final VoidCallback onExportPresets;
  final VoidCallback onImportPresets;
  final VoidCallback onExportProjectZip;
  final VoidCallback onImportProjectZip;

  final void Function(String msg, {bool isError}) onShowToast;
  final VoidCallback onStateChanged;

  const ImagePostPresetsTab({
    super.key,
    required this.selectedPresetSubTab,
    required this.onSubTabChanged,
    required this.onSaveWatermarkPreset,
    required this.onLoadWatermarkPreset,
    required this.onUpdateWatermarkPreset,
    required this.onRenameWatermarkPreset,
    required this.onExportWatermarkPresets,
    required this.onImportWatermarkPresets,
    required this.onSaveProjectPreset,
    required this.onLoadProjectPreset,
    required this.onUpdateProjectPreset,
    required this.onRenameProjectPreset,
    required this.onExportPresets,
    required this.onImportPresets,
    required this.onExportProjectZip,
    required this.onImportProjectZip,
    required this.onShowToast,
    required this.onStateChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildPresetSubTabButton(
              0,
              'Watermark Presets',
              Icons.branding_watermark,
            ),
            const SizedBox(width: 12),
            _buildPresetSubTabButton(1, 'Project Presets', Icons.dashboard),
          ],
        ),
        const SizedBox(height: 16),
        if (selectedPresetSubTab == 0)
          _buildWatermarkPresetTabContent(context)
        else
          _buildProjectPresetTabContent(context),
      ],
    );
  }

  Widget _buildPresetSubTabButton(int index, String label, IconData icon) {
    final isSelected = selectedPresetSubTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => onSubTabChanged(index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : Colors.grey.shade300,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? AppColors.primary : Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? AppColors.primary : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWatermarkPresetTabContent(BuildContext context) {
    final presets = WatermarkPresetService.getAllPresets();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Watermark Styles',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            ElevatedButton.icon(
              onPressed: onSaveWatermarkPreset,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Save Current'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: presets.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return GestureDetector(
                  onTap: onSaveWatermarkPreset,
                  child: Container(
                    width: 140,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_circle_outline,
                          size: 28,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Save Style',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return _buildWatermarkPresetTabTile(context, presets[index - 1]);
            },
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Long-press a style to rename or delete.',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
        if (AppConfig.showWatermarkBackupButtons) ...[
          const Divider(height: 24),
          const Text(
            'Watermark Styles Backup (JSON)',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onExportWatermarkPresets,
                  icon: const Icon(Icons.upload_file, size: 18),
                  label: const Text('Export JSON'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onImportWatermarkPresets,
                  icon: const Icon(Icons.file_download, size: 18),
                  label: const Text('Import JSON'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Export or import your saved watermark styles database as a JSON file.',
            style: TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ],
    );
  }

  Widget _buildWatermarkPresetTabTile(
    BuildContext context,
    WatermarkPreset preset,
  ) {
    return GestureDetector(
      onTap: () {
        onLoadWatermarkPreset(preset);
        onShowToast('✨ Loaded style "${preset.name}"');
      },
      onLongPress: () {
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text('Style Preset: ${preset.name}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  onUpdateWatermarkPreset(preset);
                },
                child: const Text('Update Settings'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  onRenameWatermarkPreset(preset);
                },
                child: const Text('Rename'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  await WatermarkPresetService.deletePreset(preset.id);
                  onStateChanged();
                  onShowToast('Style preset deleted!');
                },
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                preset.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                preset.watermarkType.toUpperCase(),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectPresetTabContent(BuildContext context) {
    final presets = ImagePostPresetService.getAllPresets();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Project Templates',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            ElevatedButton.icon(
              onPressed: onSaveProjectPreset,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Save Current'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: presets.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return GestureDetector(
                  onTap: onSaveProjectPreset,
                  child: Container(
                    width: 140,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_circle_outline,
                          size: 28,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Save Preset',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return _buildPresetTabTile(context, presets[index - 1]);
            },
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Long-press a style to rename or delete.',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
        if (AppConfig.showWatermarkBackupButtons) ...[
          const Divider(height: 24),
          const Text(
            'Project Templates Backup (ZIP)',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onExportPresets,
                  icon: const Icon(Icons.upload_file, size: 18),
                  label: const Text('Export Templates (ZIP)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onImportPresets,
                  icon: const Icon(Icons.file_download, size: 18),
                  label: const Text('Import Templates (ZIP)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Export or import all your saved project templates database (including background images, overlay images, custom fonts, and profiles) as a single ZIP file.',
            style: TextStyle(fontSize: 10, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onExportProjectZip,
                  icon: const Icon(Icons.backup_outlined, size: 18),
                  label: const Text('Export ZIP'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onImportProjectZip,
                  icon: const Icon(Icons.restore_outlined, size: 18),
                  label: const Text('Import ZIP'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Export the entire project including all images, overlays, and custom fonts into a single portable zip file.',
            style: TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ],
    );
  }

  Widget _buildPresetTabTile(BuildContext context, ImagePostPreset preset) {
    return GestureDetector(
      onTap: () async {
        await onLoadProjectPreset(preset);
        onShowToast('✨ Loaded "${preset.name}"');
      },
      onLongPress: () {
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text('Preset: ${preset.name}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  onUpdateProjectPreset(preset);
                },
                child: const Text('Update Settings'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  onRenameProjectPreset(preset);
                },
                child: const Text('Rename'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  await ImagePostPresetService.deletePreset(preset.id);
                  onStateChanged();
                  onShowToast('Preset deleted!');
                },
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.stars, color: Colors.amber, size: 20),
            const SizedBox(height: 8),
            Text(
              preset.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 2),
            Text(
              preset.watermarkType.toUpperCase(),
              style: TextStyle(color: Colors.grey[500], fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
}

