import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quickpost/config/app_theme.dart';
import '../models/palette_color.dart';

/// Clean, unified designer card representing a single color in the active palette.
/// Follows standard card hierarchy: clean white surface, structured color swatch,
/// crisp typography, and unified action buttons.
class PaletteSwatchCard extends StatelessWidget {
  final PaletteColor item;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onToggleLock;
  final VoidCallback? onDelete;
  final ValueChanged<PaletteColor>? onChanged;

  const PaletteSwatchCard({
    super.key,
    required this.item,
    required this.index,
    required this.onEdit,
    required this.onToggleLock,
    this.onDelete,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Color Preview Block with lock indicator
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: item.color,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.black.withOpacity(0.08),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: item.color.withOpacity(0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                    ),
                    if (item.isLocked)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.45),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),

                // Title, Role & RGB Metadata
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.name.isEmpty ? 'Shade ${index + 1}' : item.name,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                fontFamily: 'Poppins',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primarySurface,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.role.toUpperCase(),
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                fontFamily: 'Poppins',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.rgbString,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Poppins',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // 1-Tap Copy HEX Chip
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: item.hexCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: item.color,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Copied ${item.hexCode} to clipboard!',
                              style: const TextStyle(fontFamily: 'Poppins'),
                            ),
                          ],
                        ),
                        backgroundColor: AppColors.primaryDark,
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.hexCode,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.copy_rounded, size: 12, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),

                // Popup menu button
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: AppColors.textSecondary, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: Colors.white,
                  surfaceTintColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.divider),
                  ),
                  onSelected: (val) {
                    if (val == 'edit') {
                      onEdit();
                    } else if (val == 'lock') {
                      onToggleLock();
                    } else if (val == 'delete') {
                      onDelete?.call();
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.colorize_rounded, size: 16, color: AppColors.primary),
                          SizedBox(width: 10),
                          Text('Edit Color', style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontFamily: 'Poppins')),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'lock',
                      child: Row(
                        children: [
                          Icon(
                            item.isLocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                            size: 16,
                            color: AppColors.warning,
                          ),
                          SizedBox(width: 10),
                          Text(
                            item.isLocked ? 'Unlock Color' : 'Lock Color',
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontFamily: 'Poppins'),
                          ),
                        ],
                      ),
                    ),
                    if (onDelete != null)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.error),
                            SizedBox(width: 10),
                            Text('Remove', style: TextStyle(color: AppColors.error, fontSize: 13, fontFamily: 'Poppins')),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
