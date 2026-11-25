import 'package:flutter/material.dart';
import '../../../../config/app_theme.dart';
import '../../models/anime_db_entry.dart';

enum AnimeDbEntryAction { apply, addSlide, edit, toggleVerified, delete }

/// Compact list row for one anime database entry.
class AnimeDbEntryTile extends StatelessWidget {
  final AnimeDbEntry entry;
  final VoidCallback onTap;
  final ValueChanged<AnimeDbEntryAction> onAction;

  const AnimeDbEntryTile({super.key, required this.entry, required this.onTap, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (entry.year != null) '${entry.year}',
      if (entry.rating.isNotEmpty) '★ ${entry.rating}',
      if (entry.studio.isNotEmpty) entry.studio,
      if (entry.genres.isNotEmpty) entry.genres,
    ].join(' · ');
    final missing = entry.synopsis.isEmpty || entry.studio.isEmpty || entry.rating.isEmpty;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(entry.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    ),
                    if (entry.verified) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified_rounded, size: 14, color: Colors.green),
                    ] else if (missing) ...[
                      const SizedBox(width: 4),
                      Tooltip(
                        message: 'Some fields are empty',
                        child: Icon(Icons.error_outline_rounded, size: 13, color: Colors.orange.shade600),
                      ),
                    ],
                  ]),
                  if (entry.japaneseName.isNotEmpty)
                    Text(entry.japaneseName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
                  if (meta.isNotEmpty)
                    Text(meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500)),
                ],
              ),
            ),
            PopupMenuButton<AnimeDbEntryAction>(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.more_vert_rounded, size: 18, color: Colors.grey),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              onSelected: onAction,
              itemBuilder: (_) => [
                _item(AnimeDbEntryAction.apply, Icons.check_circle_outline, 'Apply to current slide', AppColors.primary),
                _item(AnimeDbEntryAction.addSlide, Icons.add_box_outlined, 'Add as new slide', Colors.teal),
                _item(AnimeDbEntryAction.edit, Icons.edit_outlined, 'Edit', Colors.indigo),
                _item(
                  AnimeDbEntryAction.toggleVerified,
                  entry.verified ? Icons.remove_done_rounded : Icons.verified_outlined,
                  entry.verified ? 'Mark unverified' : 'Mark verified',
                  Colors.green,
                ),
                _item(AnimeDbEntryAction.delete, Icons.delete_outline, 'Delete', Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<AnimeDbEntryAction> _item(AnimeDbEntryAction v, IconData icon, String label, Color color) {
    return PopupMenuItem(
      value: v,
      height: 38,
      child: Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 12, color: v == AnimeDbEntryAction.delete ? Colors.red : null)),
      ]),
    );
  }
}

