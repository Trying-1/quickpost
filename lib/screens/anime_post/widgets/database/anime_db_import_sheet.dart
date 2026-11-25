import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../config/app_theme.dart';
import '../../services/anime_database_service.dart';
import '../../services/anime_db_llm_prompt.dart';

/// Bottom sheet to import/update the local anime database from LLM-generated JSON
/// (paste text or pick a file), plus a copyable prompt for ChatGPT/Gemini/Claude.
class AnimeDbImportSheet extends StatefulWidget {
  const AnimeDbImportSheet({super.key});

  /// Returns the import result summary if anything was imported.
  static Future<AnimeDbImportResult?> show(BuildContext context) {
    return showModalBottomSheet<AnimeDbImportResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => const AnimeDbImportSheet(),
    );
  }

  @override
  State<AnimeDbImportSheet> createState() => _AnimeDbImportSheetState();
}

class _AnimeDbImportSheetState extends State<AnimeDbImportSheet> {
  final _jsonController = TextEditingController();
  final _requestController = TextEditingController(text: 'the 50 most popular anime of all time');
  AnimeDbMergeMode _mode = AnimeDbMergeMode.updateExisting;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _jsonController.dispose();
    _requestController.dispose();
    super.dispose();
  }

  Future<void> _copyPrompt() async {
    final req = _requestController.text.trim();
    final isListRequest = req.isEmpty ||
        req.toLowerCase().startsWith('top') ||
        req.toLowerCase().startsWith('the') ||
        req.toLowerCase().contains('anime') ||
        req.toLowerCase().contains('most') ||
        req.toLowerCase().contains('best');

    final prompt = isListRequest
        ? AnimeDbLlmPrompt.build(request: req.isEmpty ? 'the 50 most popular anime of all time' : req)
        : AnimeDbLlmPrompt.buildSingle(req);

    await Clipboard.setData(ClipboardData(text: prompt));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isListRequest
            ? 'Catalog prompt copied! Paste it into ChatGPT / Claude.'
            : 'Single Anime prompt for "$req" copied with main characters instruction!'),
      ),
    );
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) setState(() => _jsonController.text = data!.text!);
  }

  Future<void> _import() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await AnimeDatabaseService.instance.importJsonText(_jsonController.text, mode: _mode);
      if (!mounted) return;
      Navigator.pop(context, r);
    } catch (e) {
      setState(() {
        _busy = false;
        _error = e is FormatException ? e.message : 'Could not read JSON: $e';
      });
    }
  }

  Future<void> _importFile() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await AnimeDatabaseService.instance.importFromFile(mode: _mode);
      if (!mounted) return;
      if (r == null) {
        setState(() => _busy = false);
        return;
      }
      Navigator.pop(context, r);
    } catch (e) {
      setState(() {
        _busy = false;
        _error = e is FormatException ? e.message : 'Could not read file: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 14, 16, 14 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.auto_awesome, color: Color(0xFF8B5CF6), size: 20),
              SizedBox(width: 8),
              Text('Import Anime Database', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 4),
            Text('Prompt requests JSON in codeblock format for quick 1-click copying. Existing anime are merged by name.',
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
            const SizedBox(height: 12),

            // Step 1
            const Text('1. Copy the prompt', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _requestController,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: 'What should the AI list?',
                    labelStyle: const TextStyle(fontSize: 12),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _copyPrompt,
                icon: const Icon(Icons.copy_rounded, size: 14),
                label: const Text('Copy', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ]),
            const SizedBox(height: 12),

            // Step 2
            Row(children: [
              const Expanded(
                child: Text('2. Paste the JSON result',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
              ),
              TextButton.icon(
                onPressed: _paste,
                icon: const Icon(Icons.content_paste_rounded, size: 14),
                label: const Text('Paste', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
            ]),
            TextField(
              controller: _jsonController,
              minLines: 5,
              maxLines: 8,
              style: const TextStyle(fontSize: 11.5, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: '[ { "name": "Series Title", ... } ]',
                errorText: _error,
                errorMaxLines: 3,
                contentPadding: const EdgeInsets.all(10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              activeThumbColor: AppColors.primary,
              title: const Text('Update existing entries', style: TextStyle(fontSize: 12.5)),
              subtitle: Text(
                _mode == AnimeDbMergeMode.updateExisting
                    ? 'Fills in new data, keeps what you already have'
                    : 'Existing anime are left untouched',
                style: const TextStyle(fontSize: 11),
              ),
              value: _mode == AnimeDbMergeMode.updateExisting,
              onChanged: (v) => setState(
                  () => _mode = v ? AnimeDbMergeMode.updateExisting : AnimeDbMergeMode.skipExisting),
            ),
            const SizedBox(height: 4),
            Row(children: [
              OutlinedButton.icon(
                onPressed: _busy ? null : _importFile,
                icon: const Icon(Icons.file_open_rounded, size: 15),
                label: const Text('From file', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : _import,
                  icon: _busy
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.download_done_rounded, size: 16),
                  label: const Text('Import', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
