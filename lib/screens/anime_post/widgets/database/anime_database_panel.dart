import 'package:flutter/material.dart';
import '../../../../config/app_theme.dart';
import '../../models/anime_db_entry.dart';
import '../../services/anime_database_service.dart';
import 'anime_db_entry_editor_dialog.dart';
import 'anime_db_entry_tile.dart';
import 'anime_db_import_sheet.dart';

/// Bottom-dock panel (tab 15) for the local anime database.
/// Fits the 230px drawer: compact toolbar + search + scrollable list.
class AnimeDatabasePanel extends StatefulWidget {
  final void Function(AnimeDbEntry entry) onApplyToSlide;
  final void Function(AnimeDbEntry entry) onAddAsSlide;
  final VoidCallback onFillAllSlides;
  final void Function(String message, {bool isError, bool isSuccess}) onShowToast;

  const AnimeDatabasePanel({
    super.key,
    required this.onApplyToSlide,
    required this.onAddAsSlide,
    required this.onFillAllSlides,
    required this.onShowToast,
  });

  @override
  State<AnimeDatabasePanel> createState() => _AnimeDatabasePanelState();
}

class _AnimeDatabasePanelState extends State<AnimeDatabasePanel> {
  final _service = AnimeDatabaseService.instance;
  final _searchController = TextEditingController();
  List<AnimeDbEntry> _entries = [];
  int _total = 0;
  bool _loading = true;
  bool _showSearch = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _service.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    _service.removeListener(_reload);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final all = await _service.getAll();
    final filtered = await _service.search(_query);
    if (!mounted) return;
    setState(() {
      _total = all.length;
      _entries = filtered;
      _loading = false;
    });
  }

  Future<void> _add() async {
    final e = await AnimeDbEntryEditorDialog.show(context);
    if (e != null) {
      await _service.upsert(e);
    }
  }

  Future<void> _import() async {
    final r = await AnimeDbImportSheet.show(context);
    if (r != null) {
      await _reload();
    }
  }

  Future<void> _handleAction(AnimeDbEntry e, AnimeDbEntryAction a) async {
    switch (a) {
      case AnimeDbEntryAction.apply:
        widget.onApplyToSlide(e);
        break;
      case AnimeDbEntryAction.addSlide:
        widget.onAddAsSlide(e);
        break;
      case AnimeDbEntryAction.edit:
        final updated = await AnimeDbEntryEditorDialog.show(context, entry: e);
        if (updated != null) await _service.upsert(updated);
        break;
      case AnimeDbEntryAction.toggleVerified:
        await _service.setVerified(e.id, !e.verified);
        break;
      case AnimeDbEntryAction.delete:
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete entry?', style: TextStyle(fontSize: 16)),
            content: Text('Remove "${e.name}" from the database?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (ok == true) await _service.delete(e.id);
        break;
    }
  }

  Future<void> _export() async {
    final path = await _service.exportAndShare();
    if (path == null) widget.onShowToast('Database is empty', isError: true);
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear database?', style: TextStyle(fontSize: 16)),
        content: Text('This removes all $_total entries. Export first if unsure.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
    if (ok == true) await _service.clearAll();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildToolbar(),
        if (_showSearch)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: SizedBox(
              height: 32,
              child: TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(fontSize: 12),
                onChanged: (v) {
                  _query = v;
                  _reload();
                },
                decoration: InputDecoration(
                  hintText: 'Search name, studio, genre...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 16),
                  contentPadding: EdgeInsets.zero,
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
            ),
          ),
        const Divider(height: 1),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _total == 0
                  ? _buildEmpty()
                  : _entries.isEmpty
                      ? Center(
                          child: Text('No anime match "$_query"',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)))
                      : ListView.separated(
                          itemCount: _entries.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final e = _entries[i];
                            return AnimeDbEntryTile(
                              entry: e,
                              onTap: () => widget.onApplyToSlide(e),
                              onAction: (a) => _handleAction(e, a),
                            );
                          },
                        ),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(6)),
            child: const Icon(Icons.storage_rounded, color: AppColors.primary, size: 16),
          ),
          const SizedBox(width: 6),
          const Text('Database', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10)),
            child: Text('$_total', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(_showSearch ? Icons.close_rounded : Icons.search_rounded, size: 18),
            tooltip: 'Search',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            padding: EdgeInsets.zero,
            onPressed: () => setState(() {
              _showSearch = !_showSearch;
              if (!_showSearch) {
                _searchController.clear();
                _query = '';
                _reload();
              }
            }),
          ),
          _pill(Icons.auto_awesome, 'Import', const Color(0xFF8B5CF6), _import),
          const SizedBox(width: 4),
          _pill(Icons.add_rounded, 'Add', AppColors.primary, _add),
          PopupMenuButton<String>(
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.more_vert_rounded, size: 18, color: Colors.grey),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            onSelected: (v) {
              if (v == 'fill') widget.onFillAllSlides();
              if (v == 'export') _export();
              if (v == 'clear') _clearAll();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'fill',
                child: Row(children: [
                  Icon(Icons.auto_fix_high_rounded, size: 16, color: Color(0xFF8B5CF6)),
                  SizedBox(width: 8),
                  Text('Fill all slides from DB', style: TextStyle(fontSize: 12)),
                ]),
              ),
              PopupMenuItem(
                value: 'export',
                child: Row(children: [
                  Icon(Icons.ios_share_rounded, size: 16, color: Colors.indigo),
                  SizedBox(width: 8),
                  Text('Export JSON', style: TextStyle(fontSize: 12)),
                ]),
              ),
              PopupMenuItem(
                value: 'clear',
                child: Row(children: [
                  Icon(Icons.delete_sweep_outlined, size: 16, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Clear database', style: TextStyle(fontSize: 12, color: Colors.red)),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 3),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.storage_rounded, size: 28, color: Colors.grey.shade400),
            const SizedBox(height: 4),
            const Text('Your anime database is empty',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text('Ask an AI for popular anime as JSON and import it in seconds.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _import,
              icon: const Icon(Icons.auto_awesome, size: 14),
              label: const Text('Import from AI', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                elevation: 0,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

