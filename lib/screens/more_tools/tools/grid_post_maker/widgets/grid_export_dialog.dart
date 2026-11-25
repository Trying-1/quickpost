import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';
import 'package:quickpost/config/app_theme.dart';
import '../models/grid_tile.dart';

/// Modal dialog presented after successful grid split, displaying tiles in
/// sequential Instagram posting order with 1-tap sharing and gallery confirmation.
class GridExportDialog extends StatelessWidget {
  final List<GridPostTile> tiles;

  const GridExportDialog({
    super.key,
    required this.tiles,
  });

  static Future<void> show(BuildContext context, List<GridPostTile> tiles) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GridExportDialog(tiles: tiles),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Sort tiles by Instagram upload order (Post #1 first, then Post #2, etc.)
    final sortedByPostOrder = List<GridPostTile>.from(tiles)
      ..sort((a, b) => a.postingOrder.compareTo(b.postingOrder));

    final firstSavedPath = sortedByPostOrder.firstWhere(
      (t) => t.savedPath != null,
      orElse: () => sortedByPostOrder.first,
    ).savedPath;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle & Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Saved to Gallery! 🎉',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Saved under Pictures/Quick Post Grids',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11.5,
                              color: Color(0xFF10B981),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Profile Grid Posting Sequence Banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDF2F8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFCE7F3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Color(0xFFDB2777), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Upload starting from Post #1 to Post #${tiles.length}. It will line up into a continuous panorama across your profile feed!',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            color: Color(0xFF9D174D),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Sliced Tiles List (in Instagram posting order)
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: sortedByPostOrder.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final tile = sortedByPostOrder[index];
                final isFirst = tile.postingOrder == 1;

                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isFirst ? const Color(0xFFD81B60) : const Color(0xFFE2E8F0),
                      width: isFirst ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(
                          tile.imageBytes,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Order Badge and Label
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isFirst
                                        ? const Color(0xFFD81B60)
                                        : const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Post #${tile.postingOrder}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (isFirst) ...[
                                  const SizedBox(width: 6),
                                  const Text(
                                    'POST THIS FIRST',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFFD81B60),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tile.positionLabel,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 1-Tap Share Button
                      ElevatedButton.icon(
                        onPressed: () {
                          if (tile.savedPath != null) {
                            Share.shareXFiles(
                              [XFile(tile.savedPath!)],
                              text: 'Profile Grid Post #${tile.postingOrder}',
                            );
                          }
                        },
                        icon: const Icon(Icons.share_rounded, size: 14),
                        label: const Text('Share', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF0F172A),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                if (firstSavedPath != null) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => OpenFile.open(firstSavedPath),
                      icon: const Icon(Icons.photo_library_rounded, size: 18),
                      label: const Text('View in Gallery'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0F172A),
                        side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                        minimumSize: const Size(0, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final paths = tiles
                          .where((t) => t.savedPath != null)
                          .map((t) => XFile(t.savedPath!))
                          .toList();
                      if (paths.isNotEmpty) {
                        Share.shareXFiles(paths, text: 'Quick Post Grid Panorama');
                      }
                    },
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('Share All Tiles'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD81B60),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
