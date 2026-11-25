import 'package:flutter/material.dart';
import '../../../../config/app_theme.dart';
import '../../models/anime_db_entry.dart';

/// Dialog to create or edit a single anime database entry.
class AnimeDbEntryEditorDialog extends StatefulWidget {
  final AnimeDbEntry? entry;
  const AnimeDbEntryEditorDialog({super.key, this.entry});

  static Future<AnimeDbEntry?> show(BuildContext context, {AnimeDbEntry? entry}) {
    return showDialog<AnimeDbEntry>(
      context: context,
      builder: (_) => AnimeDbEntryEditorDialog(entry: entry),
    );
  }

  @override
  State<AnimeDbEntryEditorDialog> createState() => _AnimeDbEntryEditorDialogState();
}

class _AnimeDbEntryEditorDialogState extends State<AnimeDbEntryEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _jp;
  late final TextEditingController _rating;
  late final TextEditingController _seasons;
  late final TextEditingController _episodes;
  late final TextEditingController _studio;
  late final TextEditingController _genres;
  late final TextEditingController _characters;
  late final TextEditingController _year;
  late final TextEditingController _synopsis;
  late bool _verified;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _name = TextEditingController(text: e?.name ?? '');
    _jp = TextEditingController(text: e?.japaneseName ?? '');
    _rating = TextEditingController(text: e?.rating ?? '');
    _seasons = TextEditingController(text: e?.seasons ?? '');
    _episodes = TextEditingController(text: e?.episodes ?? '');
    _studio = TextEditingController(text: e?.studio ?? '');
    _genres = TextEditingController(text: e?.genres ?? '');
    _characters = TextEditingController(text: e?.characters ?? '');
    _year = TextEditingController(text: e?.year?.toString() ?? '');
    _synopsis = TextEditingController(text: e?.synopsis ?? '');
    _verified = e?.verified ?? false;
  }

  @override
  void dispose() {
    for (final c in [_name, _jp, _rating, _seasons, _episodes, _studio, _genres, _characters, _year, _synopsis]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Anime name is required.')));
      return;
    }
    final base = widget.entry ??
        AnimeDbEntry(id: 'db_${DateTime.now().microsecondsSinceEpoch}', name: name, updatedAt: DateTime.now());
    Navigator.pop(
      context,
      base.copyWith(
        name: name,
        japaneseName: _jp.text.trim(),
        rating: _rating.text.trim(),
        seasons: _seasons.text.trim(),
        episodes: _episodes.text.trim(),
        studio: _studio.text.trim(),
        genres: _genres.text.trim(),
        characters: _characters.text.trim(),
        synopsis: _synopsis.text.trim(),
        year: int.tryParse(_year.text.trim()),
        clearYear: int.tryParse(_year.text.trim()) == null,
        verified: _verified,
      ),
    );
  }

  Widget _field(String label, TextEditingController c,
      {String? hint, int maxLines = 1, TextInputType? type}) {
    return TextField(
      controller: c,
      maxLines: maxLines,
      keyboardType: type,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        labelStyle: const TextStyle(fontSize: 12),
        hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.entry != null;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
      contentPadding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
      title: Text(isEdit ? 'Edit Anime' : 'Add Anime',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field('Name *', _name, hint: 'e.g. Series Title'),
              const SizedBox(height: 8),
              _field('Japanese / Alt name', _jp, hint: 'e.g. Romaji / Kanji Title'),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _field('Rating', _rating, hint: '8.4 / 10')),
                const SizedBox(width: 8),
                Expanded(child: _field('Year', _year, hint: '2019', type: TextInputType.number)),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _field('Seasons', _seasons, hint: '4 Seasons')),
                const SizedBox(width: 8),
                Expanded(child: _field('Episodes', _episodes, hint: '55 Episodes')),
              ]),
              const SizedBox(height: 8),
              _field('Studio', _studio, hint: 'e.g. Ufotable'),
              const SizedBox(height: 8),
              _field('Genres (comma-separated)', _genres, hint: 'Action, Dark Fantasy'),
              const SizedBox(height: 8),
              _field('Main Characters (comma-separated)', _characters, hint: 'e.g. Protagonist, Rival, Companion'),
              const SizedBox(height: 8),
              _field('Synopsis', _synopsis, maxLines: 3),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppColors.primary,
                title: const Text('Verified (I double-checked this data)', style: TextStyle(fontSize: 12)),
                value: _verified,
                onChanged: (v) => setState(() => _verified = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
          child: Text(isEdit ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}

