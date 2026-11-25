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
import 'package:quickpost/screens/anime_post/services/anime_asset_storage_service.dart';
import 'package:quickpost/screens/anime_post/services/anime_database_service.dart';
import 'package:quickpost/screens/anime_post/widgets/assets/anime_asset_library_sheet.dart';
import 'package:quickpost/screens/anime_post/widgets/database/anime_db_entry_editor_dialog.dart';

/// Professional, responsive modal detail sheet for inspecting, editing,
/// viewing local tagged artwork, and launching Post Maker for an anime.
class AnimeDbDetailSheet extends StatefulWidget {
  final AnimeDbEntry entry;
  final VoidCallback? onDatabaseChanged;

  const AnimeDbDetailSheet({
    super.key,
    required this.entry,
    this.onDatabaseChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required AnimeDbEntry entry,
    VoidCallback? onDatabaseChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AnimeDbDetailSheet(
        entry: entry,
        onDatabaseChanged: onDatabaseChanged,
      ),
    );
  }

  @override
  State<AnimeDbDetailSheet> createState() => _AnimeDbDetailSheetState();
}

class _AnimeDbDetailSheetState extends State<AnimeDbDetailSheet> {
  late AnimeDbEntry _entry;
  List<AnimeImageAsset> _taggedAssets = [];
  bool _loadingAssets = true;

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
    _loadTaggedAssets();
  }

  Future<void> _loadTaggedAssets() async {
    setState(() => _loadingAssets = true);
    final assets = await AnimeAssetStorageService.instance.findAssetsForAnime(_entry.name);
    if (mounted) {
      setState(() {
        _taggedAssets = assets;
        _loadingAssets = false;
      });
    }
  }

  Future<void> _toggleVerified() async {
    final newStatus = !_entry.verified;
    await AnimeDatabaseService.instance.setVerified(_entry.id, newStatus);
    setState(() {
      _entry = _entry.copyWith(verified: newStatus);
    });
    widget.onDatabaseChanged?.call();
  }

  Future<void> _edit() async {
    final updated = await AnimeDbEntryEditorDialog.show(context, entry: _entry);
    if (updated != null) {
      await AnimeDatabaseService.instance.upsert(updated);
      setState(() {
        _entry = updated;
      });
      widget.onDatabaseChanged?.call();
      _loadTaggedAssets();
    }
  }

  void _copyCaption() {
    final buffer = StringBuffer();
    buffer.writeln('🔥 ${_entry.name.toUpperCase()}');
    if (_entry.japaneseName.isNotEmpty) buffer.writeln('🇯🇵 ${_entry.japaneseName}');
    if (_entry.rating.isNotEmpty) buffer.writeln('⭐ Rating: ${_entry.rating}');
    if (_entry.studio.isNotEmpty) buffer.writeln('🏢 Studio: ${_entry.studio}');
    if (_entry.seasons.isNotEmpty || _entry.episodes.isNotEmpty) {
      buffer.writeln('📺 ${[_entry.seasons, _entry.episodes].where((s) => s.isNotEmpty).join(' • ')}');
    }
    if (_entry.year != null) buffer.writeln('📅 Year: ${_entry.year}');
    if (_entry.genres.isNotEmpty) buffer.writeln('🎭 Genres: ${_entry.genres}');
    if (_entry.characters.isNotEmpty) buffer.writeln('👥 Main Characters: ${_entry.characters}');
    if (_entry.synopsis.isNotEmpty) buffer.writeln('\n📖 Synopsis:\n"${_entry.synopsis}"');
    buffer.writeln('\n#anime #${_entry.name.replaceAll(RegExp(r'\s+'), '').toLowerCase()} #animerecommendation #otaku');

    Clipboard.setData(ClipboardData(text: buffer.toString().trim()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied viral caption for "${_entry.name}"'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _copyJson() {
    Clipboard.setData(ClipboardData(text: AnimeDatabaseService.exportEntriesJson([_entry])));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied JSON for "${_entry.name}"'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _launchPostMaker() {
    final artworkPath = _taggedAssets.isNotEmpty ? _taggedAssets.first.filePath : null;

    final project = AnimeCarouselProject(
      id: 'proj_${DateTime.now().millisecondsSinceEpoch}',
      title: '${_entry.name} Spotlight',
      theme: const AnimeTemplateTheme(),
      slides: [
        AnimeCarouselSlide(
          id: 'slide_cover',
          type: SlideType.cover,
          coverTag: 'ANIME SPOTLIGHT',
          coverTitle: _entry.name.toUpperCase(),
          coverSubtitle: _entry.synopsis.isNotEmpty ? _entry.synopsis : 'Must-watch series!',
          imagePath: artworkPath,
        ),
        AnimeCarouselSlide(
          id: 'slide_anime_1',
          type: SlideType.anime,
          rank: 1,
          animeName: _entry.name,
          japaneseName: _entry.japaneseName,
          rating: _entry.rating.isNotEmpty ? _entry.rating : '9.0 / 10',
          seasons: _entry.seasons.isNotEmpty ? _entry.seasons : '1 Season',
          episodes: _entry.episodes.isNotEmpty ? _entry.episodes : '24 Episodes',
          studio: _entry.studio.isNotEmpty ? _entry.studio : 'Top Studio',
          genres: _entry.genres.isNotEmpty ? _entry.genres : 'Action, Adventure',
          synopsis: _entry.synopsis,
          imagePath: artworkPath,
        ),
      ],
    );

    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AnimePostMakerScreen(initialProject: project),
      ),
    );
  }

  Future<void> _openAssetLibraryForTagging() async {
    await AnimeAssetLibrarySheet.show(context);
    _loadTaggedAssets();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final hasArtwork = _taggedAssets.isNotEmpty;

    final genreList = _entry.genres
        .split(RegExp(r'[,/•|]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final characterList = _entry.characters
        .split(RegExp(r'[,/•|]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    return Container(
      height: size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Top Navigation Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 12, 4),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _edit,
                  icon: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF475569)),
                  tooltip: 'Edit Entry',
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 22, color: Color(0xFF475569)),
                  tooltip: 'Close',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),

          // Main Scrollable Content
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 30),
              children: [
                // ── Hero Artwork / Banner ──
                if (hasArtwork)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      height: 180,
                      child: PageView.builder(
                        itemCount: _taggedAssets.length,
                        itemBuilder: (ctx, idx) {
                          return Image.file(
                            File(_taggedAssets[idx].filePath),
                            width: double.infinity,
                            height: 180,
                            fit: BoxFit.cover,
                          );
                        },
                      ),
                    ),
                  )
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      height: 90,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF1E1B4B), Color(0xFF4338CA), Color(0xFF6366F1)],
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            right: 16,
                            bottom: 6,
                            child: Opacity(
                              opacity: 0.15,
                              child: Text(
                                _entry.japaneseName.isNotEmpty ? _entry.japaneseName : 'ANIME',
                                style: const TextStyle(
                                  fontSize: 42,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const Center(
                            child: Icon(Icons.movie_filter_rounded, color: Colors.white, size: 36),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 14),

                // ── Title & Identifiers Section (Guaranteed No Overlaps) ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _entry.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: AppTextStyles.fontFamily,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          if (_entry.japaneseName.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              _entry.japaneseName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (_entry.year != null) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${_entry.year}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 12),

                // ── Verification Status Banner ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _entry.verified ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _entry.verified ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _entry.verified ? Icons.verified_rounded : Icons.info_outline_rounded,
                        size: 18,
                        color: _entry.verified ? const Color(0xFF059669) : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _entry.verified ? 'Verified Entry' : 'Unverified (Review data before export)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _entry.verified ? const Color(0xFF065F46) : const Color(0xFF475569),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _toggleVerified,
                        style: TextButton.styleFrom(
                          foregroundColor: _entry.verified ? const Color(0xFF059669) : const Color(0xFF6366F1),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: Text(
                          _entry.verified ? 'Unverify' : 'Mark Verified',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ── Quick Info Grid ──
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoTile(
                        icon: Icons.star_rounded,
                        iconColor: const Color(0xFFF59E0B),
                        label: 'Rating',
                        value: _entry.rating.isNotEmpty ? _entry.rating : 'N/A',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildInfoTile(
                        icon: Icons.business_rounded,
                        iconColor: const Color(0xFF6366F1),
                        label: 'Studio',
                        value: _entry.studio.isNotEmpty ? _entry.studio : 'Unknown',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoTile(
                        icon: Icons.tv_rounded,
                        iconColor: const Color(0xFF10B981),
                        label: 'Format',
                        value: [_entry.seasons, _entry.episodes].where((s) => s.isNotEmpty).join(' • ').isNotEmpty
                            ? [_entry.seasons, _entry.episodes].where((s) => s.isNotEmpty).join(' • ')
                            : 'N/A',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildInfoTile(
                        icon: Icons.calendar_today_rounded,
                        iconColor: const Color(0xFFEC4899),
                        label: 'Year',
                        value: _entry.year != null ? '${_entry.year}' : 'N/A',
                      ),
                    ),
                  ],
                ),

                // ── Main Characters (if present) ──
                if (characterList.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'MAIN CHARACTERS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: characterList.map((c) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFC7D2FE)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person_rounded, size: 12, color: Color(0xFF6366F1)),
                            const SizedBox(width: 4),
                            Text(
                              c,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF3730A3),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],

                // ── Genres ──
                if (genreList.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'GENRES',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: genreList.map((g) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          g,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],

                // ── Synopsis ──
                if (_entry.synopsis.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'SYNOPSIS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      _entry.synopsis,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                ],

                // ── Tagged Artwork Gallery Section ──
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'TAGGED ARTWORK',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF94A3B8),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${_taggedAssets.length}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF6366F1),
                            ),
                          ),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: _openAssetLibraryForTagging,
                      icon: const Icon(Icons.add_photo_alternate_outlined, size: 15),
                      label: const Text('Tag Artwork', style: TextStyle(fontSize: 11.5)),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF6366F1),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                if (_loadingAssets)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (_taggedAssets.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.photo_library_outlined, color: Color(0xFF94A3B8), size: 22),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'No images tagged for this anime yet. Tag images in Assets to match slides automatically.',
                            style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  SizedBox(
                    height: 85,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _taggedAssets.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (ctx, idx) {
                        final item = _taggedAssets[idx];
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(item.filePath),
                            width: 85,
                            height: 85,
                            fit: BoxFit.cover,
                          ),
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 20),

                // ── Action Buttons ──
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _copyCaption,
                        icon: const Icon(Icons.copy_rounded, size: 15),
                        label: const Text('Copy Caption', style: TextStyle(fontSize: 12.5)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _copyJson,
                        icon: const Icon(Icons.code_rounded, size: 15),
                        label: const Text('Copy JSON', style: TextStyle(fontSize: 12.5)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Primary Post Maker Launch Button
                ElevatedButton.icon(
                  onPressed: _launchPostMaker,
                  icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
                  label: const Text(
                    'Create Carousel Post with This Anime',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
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
