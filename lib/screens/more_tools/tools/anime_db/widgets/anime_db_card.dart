import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quickpost/config/app_theme.dart';
import 'package:quickpost/screens/anime_post/models/anime_image_asset.dart';
import 'package:quickpost/screens/anime_post/models/anime_carousel_project.dart';
import 'package:quickpost/screens/anime_post/models/anime_carousel_slide.dart';
import 'package:quickpost/screens/anime_post/models/anime_db_entry.dart';
import 'package:quickpost/screens/anime_post/models/anime_template_theme.dart';
import 'package:quickpost/screens/anime_post/anime_post_maker_screen.dart';
import 'package:quickpost/screens/anime_post/services/anime_database_service.dart';
import 'package:quickpost/screens/anime_post/widgets/database/anime_db_entry_editor_dialog.dart';

/// Professional, fully responsive card for an anime entry.
/// Uses a polished horizontal poster-details layout with strict overflow
/// protection and zero text-overlap.
class AnimeDbCard extends StatelessWidget {
  final AnimeDbEntry entry;
  final List<AnimeImageAsset> taggedAssets;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onToggleSelect;
  final VoidCallback? onRefresh;

  const AnimeDbCard({
    super.key,
    required this.entry,
    this.taggedAssets = const [],
    this.isSelected = false,
    this.isSelectionMode = false,
    this.onTap,
    this.onLongPress,
    this.onToggleSelect,
    this.onRefresh,
  });

  void _copyCaption(BuildContext context) {
    final buffer = StringBuffer();
    buffer.writeln('🔥 ${entry.name.toUpperCase()}');
    if (entry.japaneseName.isNotEmpty) {
      buffer.writeln('🇯🇵 ${entry.japaneseName}');
    }
    if (entry.rating.isNotEmpty) {
      buffer.writeln('⭐ Rating: ${entry.rating}');
    }
    if (entry.studio.isNotEmpty) {
      buffer.writeln('🏢 Studio: ${entry.studio}');
    }
    if (entry.seasons.isNotEmpty || entry.episodes.isNotEmpty) {
      buffer.writeln('📺 ${[entry.seasons, entry.episodes].where((s) => s.isNotEmpty).join(' • ')}');
    }
    if (entry.year != null) {
      buffer.writeln('📅 Year: ${entry.year}');
    }
    if (entry.genres.isNotEmpty) {
      buffer.writeln('🎭 Genres: ${entry.genres}');
    }
    if (entry.characters.isNotEmpty) {
      buffer.writeln('👥 Characters: ${entry.characters}');
    }
    if (entry.synopsis.isNotEmpty) {
      buffer.writeln('\n📖 Synopsis:\n"${entry.synopsis}"');
    }
    buffer.writeln('\n#anime #${entry.name.replaceAll(RegExp(r'\s+'), '').toLowerCase()} #animerecommendation #otaku #animepost');

    Clipboard.setData(ClipboardData(text: buffer.toString().trim()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied caption for "${entry.name}"'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _copyJson(BuildContext context) {
    Clipboard.setData(ClipboardData(text: AnimeDatabaseService.exportEntriesJson([entry])));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied JSON for "${entry.name}"'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _launchInPostMaker(BuildContext context) {
    final artworkPath = taggedAssets.isNotEmpty ? taggedAssets.first.filePath : null;

    final project = AnimeCarouselProject(
      id: 'proj_${DateTime.now().millisecondsSinceEpoch}',
      title: '${entry.name} Spotlight',
      theme: const AnimeTemplateTheme(),
      slides: [
        AnimeCarouselSlide(
          id: 'slide_cover',
          type: SlideType.cover,
          coverTag: 'ANIME SPOTLIGHT',
          coverTitle: entry.name.toUpperCase(),
          coverSubtitle: entry.synopsis.isNotEmpty ? entry.synopsis : 'Must-watch series!',
          imagePath: artworkPath,
        ),
        AnimeCarouselSlide(
          id: 'slide_anime_1',
          type: SlideType.anime,
          rank: 1,
          animeName: entry.name,
          japaneseName: entry.japaneseName,
          rating: entry.rating.isNotEmpty ? entry.rating : '9.0 / 10',
          seasons: entry.seasons.isNotEmpty ? entry.seasons : '1 Season',
          episodes: entry.episodes.isNotEmpty ? entry.episodes : '24 Episodes',
          studio: entry.studio.isNotEmpty ? entry.studio : 'Top Studio',
          genres: entry.genres.isNotEmpty ? entry.genres : 'Action, Adventure',
          synopsis: entry.synopsis,
          imagePath: artworkPath,
        ),
      ],
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AnimePostMakerScreen(initialProject: project),
      ),
    );
  }

  Future<void> _edit(BuildContext context) async {
    final updated = await AnimeDbEntryEditorDialog.show(context, entry: entry);
    if (updated != null) {
      await AnimeDatabaseService.instance.upsert(updated);
      onRefresh?.call();
    }
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Anime?'),
        content: Text('Are you sure you want to delete "${entry.name}" from your local database?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await AnimeDatabaseService.instance.delete(entry.id);
      onRefresh?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasArtwork = taggedAssets.isNotEmpty;
    final primaryArtwork = hasArtwork ? taggedAssets.first : null;

    final genreList = entry.genres
        .split(RegExp(r'[,/•|]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .take(2)
        .toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF6366F1)
              : (entry.verified ? const Color(0xFFE2E8F0) : const Color(0xFFF1F5F9)),
          width: isSelected ? 2.0 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? const Color(0xFF6366F1).withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: isSelectionMode ? onToggleSelect : onTap,
          onLongPress: onLongPress ?? onToggleSelect,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Left: Anime Poster / Artwork Thumbnail ──
                _buildPosterThumbnail(hasArtwork, primaryArtwork),

                const SizedBox(width: 12),

                // ── Right: Comprehensive Details Column ──
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title & Year Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              entry.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: AppTextStyles.fontFamily,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          if (entry.year != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${entry.year}',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),

                      // Japanese / Romaji Name
                      if (entry.japaneseName.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          entry.japaneseName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppTextStyles.fontFamily,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],

                      const SizedBox(height: 6),

                      // Badges Wrap: Rating, Studio, Format
                      Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (entry.rating.isNotEmpty)
                            _buildCompactChip(
                              icon: Icons.star_rounded,
                              iconColor: const Color(0xFFD97706),
                              text: entry.rating,
                              bg: const Color(0xFFFEF3C7),
                              textColor: const Color(0xFF92400E),
                            ),
                          if (entry.studio.isNotEmpty)
                            _buildCompactChip(
                              icon: Icons.business_rounded,
                              iconColor: const Color(0xFF4F46E5),
                              text: entry.studio,
                              bg: const Color(0xFFEEF2FF),
                              textColor: const Color(0xFF3730A3),
                              maxWidth: 110,
                            ),
                          if (entry.seasons.isNotEmpty || entry.episodes.isNotEmpty)
                            _buildCompactChip(
                              icon: Icons.tv_rounded,
                              iconColor: const Color(0xFF059669),
                              text: [entry.seasons, entry.episodes].where((s) => s.isNotEmpty).join(' • '),
                              bg: const Color(0xFFECFDF5),
                              textColor: const Color(0xFF065F46),
                              maxWidth: 120,
                            ),
                        ],
                      ),

                      // Genre Pills
                      if (genreList.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 4,
                          runSpacing: 3,
                          children: genreList.map((g) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Text(
                                g,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],

                      // Characters line
                      if (entry.characters.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            const Icon(Icons.people_alt_rounded, size: 12, color: Color(0xFF6366F1)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                entry.characters,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF4F46E5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      // Synopsis (Clamped to 2 lines)
                      if (entry.synopsis.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          entry.synopsis,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            height: 1.3,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ],

                      const SizedBox(height: 8),

                      // Bottom Toolbar: Verified Status + Post Maker + Actions
                      Row(
                        children: [
                          // Verified Status Badge
                          InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: () async {
                              await AnimeDatabaseService.instance.setVerified(entry.id, !entry.verified);
                              onRefresh?.call();
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    entry.verified ? Icons.verified_rounded : Icons.radio_button_unchecked_rounded,
                                    size: 14,
                                    color: entry.verified ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    entry.verified ? 'Verified' : 'Unverified',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: entry.verified ? const Color(0xFF059669) : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const Spacer(),

                          // Quick Post Maker Button
                          InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: () => _launchInPostMaker(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.auto_awesome_rounded, size: 11, color: Colors.white),
                                  SizedBox(width: 3),
                                  Text(
                                    'Post',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(width: 2),

                          // Popup Menu
                          SizedBox(
                            width: 28,
                            height: 28,
                            child: PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert_rounded, size: 18, color: Color(0xFF64748B)),
                              padding: EdgeInsets.zero,
                              tooltip: 'Actions',
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              onSelected: (val) {
                                switch (val) {
                                  case 'caption':
                                    _copyCaption(context);
                                    break;
                                  case 'json':
                                    _copyJson(context);
                                    break;
                                  case 'edit':
                                    _edit(context);
                                    break;
                                  case 'delete':
                                    _delete(context);
                                    break;
                                }
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'caption',
                                  child: Row(
                                    children: [
                                      Icon(Icons.copy_rounded, size: 15, color: Color(0xFF6366F1)),
                                      SizedBox(width: 8),
                                      Text('Copy Viral Caption', style: TextStyle(fontSize: 12.5)),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'json',
                                  child: Row(
                                    children: [
                                      Icon(Icons.code_rounded, size: 15, color: Color(0xFF10B981)),
                                      SizedBox(width: 8),
                                      Text('Copy JSON', style: TextStyle(fontSize: 12.5)),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_outlined, size: 15, color: Color(0xFFF59E0B)),
                                      SizedBox(width: 8),
                                      Text('Edit Entry', style: TextStyle(fontSize: 12.5)),
                                    ],
                                  ),
                                ),
                                const PopupMenuDivider(),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline_rounded, size: 15, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Delete Anime', style: TextStyle(fontSize: 12.5, color: Colors.red)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPosterThumbnail(bool hasArtwork, AnimeImageAsset? primaryArtwork) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 82,
        height: 118,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1B4B),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasArtwork && primaryArtwork != null)
              Image.file(
                File(primaryArtwork.filePath),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildAestheticGradient(),
              )
            else
              _buildAestheticGradient(),

            // Top selection check if in multi-select mode
            if (isSelectionMode)
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? const Color(0xFF6366F1) : Colors.black.withValues(alpha: 0.5),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 13, color: Colors.white)
                      : null,
                ),
              ),

            // Bottom Artwork Badge if has local assets
            if (hasArtwork)
              Positioned(
                bottom: 4,
                left: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.photo_library_rounded, size: 10, color: Colors.white),
                      const SizedBox(width: 3),
                      Text(
                        '${taggedAssets.length} art',
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAestheticGradient() {
    final hash = entry.name.hashCode.abs();
    final palettes = [
      [const Color(0xFF1E1B4B), const Color(0xFF4338CA)],
      [const Color(0xFF311042), const Color(0xFF701A75)],
      [const Color(0xFF0F172A), const Color(0xFF334155)],
      [const Color(0xFF064E3B), const Color(0xFF047857)],
      [const Color(0xFF7C2D12), const Color(0xFFC2410C)],
      [const Color(0xFF1E293B), const Color(0xFF2563EB)],
    ];
    final pair = palettes[hash % palettes.length];

    // Take first letter or kanji symbol
    final char = entry.japaneseName.isNotEmpty
        ? entry.japaneseName.characters.first
        : (entry.name.isNotEmpty ? entry.name.characters.first.toUpperCase() : 'A');

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: pair,
        ),
      ),
      child: Center(
        child: Opacity(
          opacity: 0.35,
          child: Text(
            char,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactChip({
    required IconData icon,
    required Color iconColor,
    required String text,
    required Color bg,
    required Color textColor,
    double? maxWidth,
  }) {
    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10.5, color: iconColor),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ),
      ],
    );

    if (maxWidth != null) {
      content = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: content,
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: content,
    );
  }
}
