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
import 'package:quickpost/screens/anime_post/widgets/database/anime_db_entry_editor_dialog.dart';
import 'package:quickpost/screens/anime_post/widgets/database/anime_db_import_sheet.dart';
import 'widgets/anime_db_card.dart';
import 'widgets/anime_db_detail_sheet.dart';
import 'widgets/anime_db_prompt_dialog.dart';
import 'widgets/anime_db_stats_dialog.dart';

enum AnimeDbSortBy {
  nameAsc('Name (A - Z)'),
  nameDesc('Name (Z - A)'),
  ratingDesc('Highest Rating'),
  yearDesc('Newest First'),
  artworkDesc('Most Artwork');

  final String label;
  const AnimeDbSortBy(this.label);
}

enum AnimeDbFilter {
  all('All'),
  verified('Verified'),
  unverified('Needs Review'),
  hasArtwork('Has Artwork'),
  missingInfo('Missing Info');

  final String label;
  const AnimeDbFilter(this.label);
}

/// Anime Database Studio Screen in More Tools.
/// 100% Offline, Zero-API Anime Database Manager connected seamlessly
/// with Anime Post Maker and local Tagged Artwork Assets.
class AnimeDbStudioScreen extends StatefulWidget {
  const AnimeDbStudioScreen({super.key});

  @override
  State<AnimeDbStudioScreen> createState() => _AnimeDbStudioScreenState();
}

class _AnimeDbStudioScreenState extends State<AnimeDbStudioScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<AnimeDbEntry> _allEntries = [];
  Map<String, List<AnimeImageAsset>> _artworkMap = {};
  bool _loading = true;

  // Filters & Sorting
  String _searchQuery = '';
  AnimeDbFilter _activeFilter = AnimeDbFilter.all;
  String _selectedGenre = 'All';
  AnimeDbSortBy _sortBy = AnimeDbSortBy.nameAsc;

  // Selection Mode
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadData();
    AnimeDatabaseService.instance.addListener(_handleDatabaseUpdate);
  }

  @override
  void dispose() {
    _searchController.dispose();
    AnimeDatabaseService.instance.removeListener(_handleDatabaseUpdate);
    super.dispose();
  }

  void _handleDatabaseUpdate() {
    if (mounted) _loadData(silent: true);
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    final entries = await AnimeDatabaseService.instance.getAll();

    // Pre-cache tagged artworks for each anime
    final map = <String, List<AnimeImageAsset>>{};
    for (final e in entries) {
      final assets = await AnimeAssetStorageService.instance.findAssetsForAnime(e.name);
      if (assets.isNotEmpty) {
        map[e.id] = assets;
      }
    }

    if (mounted) {
      setState(() {
        _allEntries = entries;
        _artworkMap = map;
        _loading = false;
      });
    }
  }

  List<AnimeDbEntry> get _filteredEntries {
    final q = _searchQuery.trim().toLowerCase();
    return _allEntries.where((e) {
      // Search query
      if (q.isNotEmpty) {
        final matches = e.name.toLowerCase().contains(q) ||
            e.japaneseName.toLowerCase().contains(q) ||
            e.studio.toLowerCase().contains(q) ||
            e.genres.toLowerCase().contains(q) ||
            e.characters.toLowerCase().contains(q) ||
            e.synopsis.toLowerCase().contains(q);
        if (!matches) return false;
      }

      // Filter chips
      switch (_activeFilter) {
        case AnimeDbFilter.all:
          break;
        case AnimeDbFilter.verified:
          if (!e.verified) return false;
          break;
        case AnimeDbFilter.unverified:
          if (e.verified) return false;
          break;
        case AnimeDbFilter.hasArtwork:
          if (!_artworkMap.containsKey(e.id)) return false;
          break;
        case AnimeDbFilter.missingInfo:
          if (e.synopsis.isNotEmpty && e.rating.isNotEmpty && e.studio.isNotEmpty) {
            return false;
          }
          break;
      }

      // Genre filter
      if (_selectedGenre != 'All') {
        final parts = e.genres.split(RegExp(r'[,/•|]')).map((s) => s.trim().toLowerCase());
        if (!parts.contains(_selectedGenre.toLowerCase())) {
          return false;
        }
      }

      return true;
    }).toList()
      ..sort((a, b) {
        switch (_sortBy) {
          case AnimeDbSortBy.nameAsc:
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          case AnimeDbSortBy.nameDesc:
            return b.name.toLowerCase().compareTo(a.name.toLowerCase());
          case AnimeDbSortBy.ratingDesc:
            final rA = _extractNumericRating(a.rating);
            final rB = _extractNumericRating(b.rating);
            return rB.compareTo(rA);
          case AnimeDbSortBy.yearDesc:
            final yA = a.year ?? 0;
            final yB = b.year ?? 0;
            return yB.compareTo(yA);
          case AnimeDbSortBy.artworkDesc:
            final cA = _artworkMap[a.id]?.length ?? 0;
            final cB = _artworkMap[b.id]?.length ?? 0;
            return cB.compareTo(cA);
        }
      });
  }

  double _extractNumericRating(String rating) {
    final m = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(rating);
    return m != null ? (double.tryParse(m.group(1)!) ?? 0.0) : 0.0;
  }

  List<String> get _dynamicGenres {
    final set = <String>{};
    for (final e in _allEntries) {
      if (e.genres.trim().isEmpty) continue;
      final parts = e.genres.split(RegExp(r'[,/•|]')).map((s) => s.trim()).where((s) => s.isNotEmpty);
      set.addAll(parts);
    }
    final list = set.toList()..sort();
    return ['All', ...list];
  }

  // ===================== ACTIONS =====================

  Future<void> _addNewEntry() async {
    final entry = await AnimeDbEntryEditorDialog.show(context);
    if (entry != null) {
      await AnimeDatabaseService.instance.upsert(entry);
      _loadData();
    }
  }

  Future<void> _openImportSheet() async {
    final result = await AnimeDbImportSheet.show(context);
    if (result != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Import complete: ${result.summary}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadData();
    }
  }

  Future<void> _exportEntireDatabase() async {
    final count = _allEntries.length;
    if (count == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Database is empty.')),
      );
      return;
    }
    await AnimeDatabaseService.instance.exportAndShare();
  }

  Future<void> _clearEntireDatabase() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Entire Database?'),
        content: const Text(
          'This will permanently delete all local anime records. Make sure you export a backup first if needed.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await AnimeDatabaseService.instance.clearAll();
      _selectedIds.clear();
      _isSelectionMode = false;
      _loadData();
    }
  }

  // ===================== BATCH ACTIONS =====================

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedIds.addAll(_filteredEntries.map((e) => e.id));
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedIds.clear();
      _isSelectionMode = false;
    });
  }

  Future<void> _batchSetVerified(bool verified) async {
    await AnimeDatabaseService.instance.setVerifiedBatch(_selectedIds.toList(), verified);
    _clearSelection();
    _loadData();
  }

  Future<void> _batchDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${_selectedIds.length} Anime?'),
        content: const Text('Are you sure you want to delete these selected entries from your local database?'),
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
      await AnimeDatabaseService.instance.deleteBatch(_selectedIds.toList());
      _clearSelection();
      _loadData();
    }
  }

  void _batchExportJson() {
    final selectedEntries = _allEntries.where((e) => _selectedIds.contains(e.id)).toList();
    final jsonText = AnimeDatabaseService.exportEntriesJson(selectedEntries);
    Clipboard.setData(ClipboardData(text: jsonText));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied JSON for ${selectedEntries.length} anime to clipboard!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _batchCreatePost() {
    final selectedEntries = _allEntries.where((e) => _selectedIds.contains(e.id)).toList();
    if (selectedEntries.isEmpty) return;

    final slides = <AnimeCarouselSlide>[
      // Cover Slide
      AnimeCarouselSlide(
        id: 'slide_cover',
        type: SlideType.cover,
        coverTag: 'TOP PICKS',
        coverTitle: 'TOP ${selectedEntries.length} ANIME PICKS',
        coverSubtitle: 'Curated masterpiece series you must watch!',
        imagePath: _artworkMap[selectedEntries.first.id]?.firstOrNull?.filePath,
      ),
    ];

    // Anime Slides
    for (int i = 0; i < selectedEntries.length; i++) {
      final e = selectedEntries[i];
      final artworkPath = _artworkMap[e.id]?.firstOrNull?.filePath;
      slides.add(
        AnimeCarouselSlide(
          id: 'slide_anime_${i + 1}',
          type: SlideType.anime,
          rank: i + 1,
          animeName: e.name,
          japaneseName: e.japaneseName,
          rating: e.rating.isNotEmpty ? e.rating : '9.0 / 10',
          seasons: e.seasons.isNotEmpty ? e.seasons : '1 Season',
          episodes: e.episodes.isNotEmpty ? e.episodes : '24 Episodes',
          studio: e.studio.isNotEmpty ? e.studio : 'Top Studio',
          genres: e.genres.isNotEmpty ? e.genres : 'Action, Adventure',
          synopsis: e.synopsis,
          imagePath: artworkPath,
        ),
      );
    }

    final project = AnimeCarouselProject(
      id: 'proj_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Top ${selectedEntries.length} Anime Picks',
      theme: const AnimeTemplateTheme(),
      slides: slides,
    );

    _clearSelection();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AnimePostMakerScreen(initialProject: project),
      ),
    );
  }

  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  'Add Anime to Vault',
                  style: TextStyle(
                    fontFamily: AppTextStyles.fontFamily,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.psychology_rounded, color: Color(0xFF6366F1), size: 22),
                ),
                title: const Text('AI Prompt: Single Anime Details', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                subtitle: const Text('Generates 1-click prompt with main characters & ratings', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  AnimeDbPromptDialog.show(context);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.download_rounded, color: Color(0xFF10B981), size: 22),
                ),
                title: const Text('Paste / Import JSON', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                subtitle: const Text('Paste codeblock from ChatGPT/Claude or pick file', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _openImportSheet();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.edit_note_rounded, color: Color(0xFF475569), size: 22),
                ),
                title: const Text('Manual Entry', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                subtitle: const Text('Enter title, studio, characters and synopsis by hand', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _addNewEntry();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===================== UI BUILD =====================

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredEntries;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Sticky Filter & Search Control Header
          _buildFilterHeader(),

          // Batch Action Toolbar if in Selection Mode
          if (_isSelectionMode) _buildBatchToolbar(),

          // Main Content List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : filtered.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: () => _loadData(silent: true),
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                          padding: const EdgeInsets.only(top: 8, bottom: 80),
                          itemCount: filtered.length,
                          itemBuilder: (ctx, idx) {
                            final entry = filtered[idx];
                            final assets = _artworkMap[entry.id] ?? const [];
                            return AnimeDbCard(
                              entry: entry,
                              taggedAssets: assets,
                              isSelected: _selectedIds.contains(entry.id),
                              isSelectionMode: _isSelectionMode,
                              onTap: () {
                                AnimeDbDetailSheet.show(
                                  context,
                                  entry: entry,
                                  onDatabaseChanged: () => _loadData(silent: true),
                                );
                              },
                              onLongPress: () {
                                setState(() {
                                  _isSelectionMode = true;
                                  _selectedIds.add(entry.id);
                                });
                              },
                              onToggleSelect: () => _toggleSelect(entry.id),
                              onRefresh: () => _loadData(silent: true),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddOptions,
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.add_rounded, size: 22),
        label: const Text(
          'Add Anime',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    if (_isSelectionMode) {
      return AppBar(
        backgroundColor: const Color(0xFF1E1B4B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: _clearSelection,
        ),
        title: Text(
          '${_selectedIds.length} Selected',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.select_all_rounded, color: Colors.white),
            tooltip: 'Select All',
            onPressed: _selectAll,
          ),
          IconButton(
            icon: const Icon(Icons.code_rounded, color: Colors.white),
            tooltip: 'Copy JSON',
            onPressed: _batchExportJson,
          ),
        ],
      );
    }

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 1,
      titleSpacing: 16,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Flexible(
            child: Text(
              'Anime Vault',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTextStyles.fontFamily,
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${_allEntries.length}',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF6366F1),
              ),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.analytics_outlined, color: Color(0xFF475569), size: 22),
          tooltip: 'Analytics',
          visualDensity: VisualDensity.compact,
          onPressed: () => AnimeDbStatsDialog.show(context, entries: _allEntries),
        ),
        IconButton(
          icon: const Icon(Icons.psychology_outlined, color: Color(0xFF6366F1), size: 22),
          tooltip: 'AI Prompt Generator',
          visualDensity: VisualDensity.compact,
          onPressed: () => AnimeDbPromptDialog.show(context),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF475569), size: 22),
          tooltip: 'More actions',
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: (val) {
            switch (val) {
              case 'import':
                _openImportSheet();
                break;
              case 'prompt':
                AnimeDbPromptDialog.show(context);
                break;
              case 'export':
                _exportEntireDatabase();
                break;
              case 'select':
                setState(() => _isSelectionMode = true);
                break;
              case 'clear':
                _clearEntireDatabase();
                break;
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'prompt',
              child: Row(
                children: [
                  Icon(Icons.psychology_rounded, size: 18, color: Color(0xFF6366F1)),
                  SizedBox(width: 10),
                  Text('AI Prompt Studio'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'import',
              child: Row(
                children: [
                  Icon(Icons.download_rounded, size: 18, color: Color(0xFF10B981)),
                  SizedBox(width: 10),
                  Text('Import JSON / Paste LLM'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'export',
              child: Row(
                children: [
                  Icon(Icons.upload_rounded, size: 18, color: Color(0xFF6366F1)),
                  SizedBox(width: 10),
                  Text('Export Entire Database'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'select',
              child: Row(
                children: [
                  Icon(Icons.checklist_rounded, size: 18, color: Color(0xFF334155)),
                  SizedBox(width: 10),
                  Text('Select Multiple'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'clear',
              child: Row(
                children: [
                  Icon(Icons.delete_sweep_rounded, size: 18, color: Colors.red),
                  SizedBox(width: 10),
                  Text('Clear All Records', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterHeader() {
    final genres = _dynamicGenres;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        children: [
          // Search & Sort row
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFF94A3B8)),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      hintText: 'Search anime, studio, genre...',
                      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Sort Menu
              PopupMenuButton<AnimeDbSortBy>(
                initialValue: _sortBy,
                tooltip: 'Sort by',
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (val) => setState(() => _sortBy = val),
                itemBuilder: (_) => AnimeDbSortBy.values.map((s) {
                  return PopupMenuItem(
                    value: s,
                    child: Row(
                      children: [
                        Icon(
                          _sortBy == s ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                          size: 15,
                          color: _sortBy == s ? const Color(0xFF6366F1) : const Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 8),
                        Text(s.label, style: const TextStyle(fontSize: 12.5)),
                      ],
                    ),
                  );
                }).toList(),
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sort_rounded, size: 18, color: Color(0xFF475569)),
                      const SizedBox(width: 4),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 72),
                        child: Text(
                          _sortBy.label.split(' ').first,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Primary Filter Pills Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: AnimeDbFilter.values.map((f) {
                final isSelected = _activeFilter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => setState(() => _activeFilter = f),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF6366F1) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Text(
                        f.label,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: isSelected ? Colors.white : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Genre Scroll Bar if genres exist
          if (genres.length > 2) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 28,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: genres.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (ctx, idx) {
                  final g = genres[idx];
                  final isSelected = _selectedGenre == g;
                  return InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => setState(() => _selectedGenre = g),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFEEF2FF) : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        g,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? const Color(0xFF4338CA) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBatchToolbar() {
    return Container(
      color: const Color(0xFF1E1B4B),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${_selectedIds.length} selected',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11.5),
            ),
          ),
          const Spacer(),

          // Batch Verify
          TextButton.icon(
            onPressed: () => _batchSetVerified(true),
            icon: const Icon(Icons.verified_rounded, size: 15, color: Color(0xFF34D399)),
            label: const Text('Verify', style: TextStyle(color: Colors.white, fontSize: 11.5)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              visualDensity: VisualDensity.compact,
            ),
          ),

          const SizedBox(width: 4),

          // Batch Create Carousel
          ElevatedButton.icon(
            onPressed: _batchCreatePost,
            icon: const Icon(Icons.auto_awesome_rounded, size: 13, color: Colors.white),
            label: const Text('Post', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              elevation: 0,
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),

          const SizedBox(width: 4),

          // Batch Delete
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFF87171), size: 18),
            onPressed: _batchDelete,
            tooltip: 'Delete Selected',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasNoEntriesAtAll = _allEntries.isEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.video_library_rounded, size: 48, color: Color(0xFF6366F1)),
            ),
            const SizedBox(height: 18),
            Text(
              hasNoEntriesAtAll ? 'Your Anime Vault is Empty' : 'No Anime Match Your Filters',
              style: const TextStyle(
                fontFamily: AppTextStyles.fontFamily,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasNoEntriesAtAll
                  ? 'Easily build your anime database using AI prompts (ChatGPT, Gemini, Claude), importing JSON, or adding your favorite series manually.'
                  : 'Try adjusting your search keywords, genre filters, or verification status.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 24),
            if (hasNoEntriesAtAll) ...[
              ElevatedButton.icon(
                onPressed: () => AnimeDbPromptDialog.show(context),
                icon: const Icon(Icons.psychology_rounded, size: 20, color: Colors.white),
                label: const Text(
                  'AI Prompt Generator (1-Click Copy)',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _openImportSheet,
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Import from JSON or File'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: _addNewEntry,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Single Anime Manually'),
              ),
            ] else ...[
              OutlinedButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _activeFilter = AnimeDbFilter.all;
                    _selectedGenre = 'All';
                  });
                },
                child: const Text('Reset All Filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

