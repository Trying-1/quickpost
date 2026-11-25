import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../config/app_theme.dart';
import '../../models/anime_image_asset.dart';
import '../../services/anime_asset_storage_service.dart';
import '../../services/anime_database_service.dart';

/// Dedicated tagging workspace with two methods:
/// 1. Batch: multi-select images, then tag them all with one anime.
/// 2. Two-column: untagged images (left) and anime list (right), each
///    scrollable independently. Select image(s) on the left, tap an anime on the right.
class AnimeAssetTaggingTab extends StatefulWidget {
  final List<AnimeImageAsset> assets;
  final List<String> categories;
  final List<String> suggestedAnimeNames;
  final Future<void> Function() onChanged;

  const AnimeAssetTaggingTab({
    super.key,
    required this.assets,
    required this.categories,
    required this.onChanged,
    this.suggestedAnimeNames = const [],
  });

  static bool isUntagged(AnimeImageAsset a) {
    final n = a.animeName.trim().toLowerCase();
    return n.isEmpty || n == 'general';
  }

  @override
  State<AnimeAssetTaggingTab> createState() => _AnimeAssetTaggingTabState();
}

class _AnimeAssetTaggingTabState extends State<AnimeAssetTaggingTab> {
  int _mode = 0; // 0 = batch, 1 = two-column
  final Set<String> _selected = {};
  bool _showAll = false; // batch: include already tagged images
  String? _batchTarget;
  String _animeSearch = '';
  bool _busy = false;
  List<String> _dbNames = [];

  @override
  void initState() {
    super.initState();
    _loadDbNames();
  }

  Future<void> _loadDbNames() async {
    final names = await AnimeDatabaseService.instance.getNames();
    if (mounted) setState(() => _dbNames = names);
  }

  static bool isUntagged(AnimeImageAsset a) => AnimeAssetTaggingTab.isUntagged(a);

  List<AnimeImageAsset> get _untagged => widget.assets.where(isUntagged).toList();

  List<String> get _animeList {
    final set = <String>{};
    for (final s in widget.suggestedAnimeNames) {
      final t = s.trim();
      if (t.isNotEmpty && t != 'New Anime Recommendation') set.add(t);
    }
    for (final d in _dbNames) {
      if (d.trim().isNotEmpty && d.toLowerCase() != 'general') set.add(d.trim());
    }
    for (final c in widget.categories) {
      if (c.trim().isNotEmpty && c.toLowerCase() != 'general') set.add(c);
    }
    final list = set.toList();
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  int _countFor(String anime) =>
      widget.assets.where((a) => a.animeName.toLowerCase() == anime.toLowerCase()).length;

  Set<String> get _validSelected {
    final ids = widget.assets.map((a) => a.id).toSet();
    return _selected.where(ids.contains).toSet();
  }

  Future<void> _applyTag(String anime) async {
    final ids = _validSelected;
    if (ids.isEmpty || _busy) return;
    setState(() => _busy = true);
    final n = await AnimeAssetStorageService.instance.tagAssets(ids, anime);
    _selected.clear();
    await widget.onChanged();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Tagged $n image${n == 1 ? '' : 's'} as "$anime"'),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.green.shade700,
      ));
  }

  Future<String?> _promptNewAnime() async {
    final c = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('New Anime', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: c,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'e.g. Chainsaw Man',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return null;
    await AnimeAssetStorageService.instance.addCategory(name);
    await widget.onChanged();
    return name;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildModeToggle(),
        Expanded(child: _mode == 0 ? _buildBatch() : _buildTwoColumn()),
      ],
    );
  }

  Widget _buildModeToggle() {
    Widget seg(int idx, IconData icon, String label) {
      final sel = _mode == idx;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _mode = idx),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(
              color: sel ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 14, color: sel ? Colors.white : Colors.grey.shade700),
                const SizedBox(width: 5),
                Text(label,
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: sel ? Colors.white : Colors.grey.shade700)),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        seg(0, Icons.checklist_rounded, 'Batch Tag'),
        seg(1, Icons.view_column_rounded, 'Two-Column'),
      ]),
    );
  }

  Widget _thumb(AnimeImageAsset a, {required bool selected, required VoidCallback onTap, bool showTag = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: selected ? AppColors.primary : Colors.grey.shade300, width: selected ? 3 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(File(a.filePath),
                fit: BoxFit.cover,
                cacheWidth: 300,
                errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey.shade200, child: const Icon(Icons.broken_image, color: Colors.grey))),
            if (selected)
              Container(color: AppColors.primary.withValues(alpha: 0.18)),
            Positioned(
              top: 4,
              left: 4,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : Colors.black38,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: selected ? const Icon(Icons.check, size: 13, color: Colors.white) : null,
              ),
            ),
            if (showTag)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 2),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black87, Colors.transparent]),
                  ),
                  child: Text(a.animeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _allDone() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.task_alt_rounded, size: 40, color: Colors.green.shade400),
            const SizedBox(height: 8),
            const Text('All images are tagged',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text('New uploads under "General" will show up here.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  // ===================== BATCH =====================
  Widget _buildBatch() {
    final pool = _showAll ? widget.assets : _untagged;
    final sel = _validSelected;
    final anime = _animeList;
    final target = anime.contains(_batchTarget) ? _batchTarget : null;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 10, 2),
          child: Row(
            children: [
              ChoiceChip(
                visualDensity: VisualDensity.compact,
                label: Text('Untagged (${_untagged.length})', style: const TextStyle(fontSize: 11)),
                selected: !_showAll,
                onSelected: (_) => setState(() => _showAll = false),
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                visualDensity: VisualDensity.compact,
                label: Text('All (${widget.assets.length})', style: const TextStyle(fontSize: 11)),
                selected: _showAll,
                onSelected: (_) => setState(() => _showAll = true),
              ),
              const Spacer(),
              TextButton(
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8)),
                onPressed: pool.isEmpty
                    ? null
                    : () => setState(() {
                          if (sel.length == pool.length) {
                            _selected.clear();
                          } else {
                            _selected
                              ..clear()
                              ..addAll(pool.map((a) => a.id));
                          }
                        }),
                child: Text(sel.length == pool.length && pool.isNotEmpty ? 'Clear' : 'Select all',
                    style: const TextStyle(fontSize: 11.5)),
              ),
            ],
          ),
        ),
        Expanded(
          child: pool.isEmpty
              ? _allDone()
              : GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4, crossAxisSpacing: 6, mainAxisSpacing: 6),
                  itemCount: pool.length,
                  itemBuilder: (_, i) {
                    final a = pool[i];
                    return _thumb(a,
                        selected: sel.contains(a.id),
                        showTag: !isUntagged(a),
                        onTap: () => setState(() {
                              if (!_selected.remove(a.id)) _selected.add(a.id);
                            }));
                  },
                ),
        ),
        // Bottom tag bar
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
          ),
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        visualDensity: VisualDensity.compact,
                        avatar: const Icon(Icons.add, size: 14),
                        label: const Text('New', style: TextStyle(fontSize: 11)),
                        onPressed: () async {
                          final n = await _promptNewAnime();
                          if (n != null && mounted) setState(() => _batchTarget = n);
                        },
                      ),
                    ),
                    ...anime.map((n) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            visualDensity: VisualDensity.compact,
                            label: Text(n, style: const TextStyle(fontSize: 11)),
                            selected: target == n,
                            onSelected: (_) => setState(() => _batchTarget = n),
                          ),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: sel.isEmpty || target == null || _busy ? null : () => _applyTag(target),
                  icon: _busy
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.label_rounded, size: 16),
                  label: Text(
                    sel.isEmpty
                        ? 'Select images to tag'
                        : target == null
                            ? 'Choose an anime for ${sel.length} image${sel.length == 1 ? '' : 's'}'
                            : 'Tag ${sel.length} as "$target"',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===================== TWO COLUMN =====================
  Widget _buildTwoColumn() {
    final untagged = _untagged;
    final sel = _validSelected;
    final q = _animeSearch.trim().toLowerCase();
    final anime = _animeList.where((n) => q.isEmpty || n.toLowerCase().contains(q)).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 10, 2),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  sel.isEmpty
                      ? 'Tap images on the left, then tap an anime on the right'
                      : '${sel.length} selected → tap an anime',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: sel.isEmpty ? FontWeight.normal : FontWeight.bold,
                      color: sel.isEmpty ? Colors.grey.shade600 : AppColors.primary),
                ),
              ),
              if (sel.isNotEmpty)
                TextButton(
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8)),
                  onPressed: () => setState(_selected.clear),
                  child: const Text('Clear', style: TextStyle(fontSize: 11.5)),
                ),
            ],
          ),
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // LEFT: untagged images
              Expanded(
                flex: 5,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(12, 2, 4, 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: Row(children: [
                          const Icon(Icons.image_not_supported_outlined, size: 14, color: Colors.orange),
                          const SizedBox(width: 5),
                          Text('Untagged (${untagged.length})',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ]),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: untagged.isEmpty
                            ? _allDone()
                            : GridView.builder(
                                padding: const EdgeInsets.all(6),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2, crossAxisSpacing: 6, mainAxisSpacing: 6),
                                itemCount: untagged.length,
                                itemBuilder: (_, i) {
                                  final a = untagged[i];
                                  return _thumb(a,
                                      selected: sel.contains(a.id),
                                      onTap: () => setState(() {
                                            if (!_selected.remove(a.id)) _selected.add(a.id);
                                          }));
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              // RIGHT: anime list
              Expanded(
                flex: 4,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(4, 2, 12, 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
                        child: Row(children: [
                          Expanded(
                            child: SizedBox(
                              height: 30,
                              child: TextField(
                                onChanged: (v) => setState(() => _animeSearch = v),
                                style: const TextStyle(fontSize: 12),
                                decoration: InputDecoration(
                                  hintText: 'Search anime',
                                  prefixIcon: const Icon(Icons.search_rounded, size: 15),
                                  contentPadding: EdgeInsets.zero,
                                  filled: true,
                                  fillColor: Colors.grey.shade100,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'New anime',
                            icon: const Icon(Icons.add_circle_outline_rounded, size: 20, color: AppColors.primary),
                            visualDensity: VisualDensity.compact,
                            onPressed: () async {
                              final n = await _promptNewAnime();
                              if (n != null && sel.isNotEmpty) _applyTag(n);
                            },
                          ),
                        ]),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: anime.isEmpty
                            ? Center(
                                child: Text('No anime yet.\nTap + to add one.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)))
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                itemCount: anime.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (_, i) {
                                  final n = anime[i];
                                  final enabled = sel.isNotEmpty && !_busy;
                                  return InkWell(
                                    onTap: enabled ? () => _applyTag(n) : null,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                                      child: Row(children: [
                                        Expanded(
                                          child: Text(n,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: enabled ? AppColors.textPrimary : Colors.grey.shade500)),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                              color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10)),
                                          child: Text('${_countFor(n)}',
                                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                        ),
                                      ]),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
