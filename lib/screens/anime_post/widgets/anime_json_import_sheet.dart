import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../config/app_theme.dart';
import '../models/anime_carousel_project.dart';
import '../models/anime_carousel_slide.dart';
import '../services/anime_post_json_service.dart';

/// Interactive modal sheet to import anime carousel data from JSON or LLM prompts (Gemini, ChatGPT, Claude)
/// and populate all slides instantly without manual typing.
class AnimeJsonImportSheet extends StatefulWidget {
  final AnimeCarouselProject currentProject;
  final ValueChanged<AnimeCarouselProject> onProjectImported;
  final ValueChanged<String>? onShowToast;

  const AnimeJsonImportSheet({
    super.key,
    required this.currentProject,
    required this.onProjectImported,
    this.onShowToast,
  });

  static Future<void> show({
    required BuildContext context,
    required AnimeCarouselProject currentProject,
    required ValueChanged<AnimeCarouselProject> onProjectImported,
    ValueChanged<String>? onShowToast,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AnimeJsonImportSheet(
        currentProject: currentProject,
        onProjectImported: onProjectImported,
        onShowToast: onShowToast,
      ),
    );
  }

  @override
  State<AnimeJsonImportSheet> createState() => _AnimeJsonImportSheetState();
}

class _AnimeJsonImportSheetState extends State<AnimeJsonImportSheet> {
  final TextEditingController _jsonController = TextEditingController();
  late TextEditingController _titleController;
  int _animeCount = 5;
  bool _showPromptBuilder = false;
  bool _preserveImages = true;
  String? _validationStatus;
  bool _isValidJson = false;
  int _detectedAnimeCount = 0;

  @override
  void initState() {
    super.initState();
    final animeSlideCount = widget.currentProject.slides.where((s) => s.type == SlideType.anime).length;
    _animeCount = animeSlideCount > 0 ? animeSlideCount : 5;
    _titleController = TextEditingController(
      text: widget.currentProject.title.isNotEmpty
          ? widget.currentProject.title
          : 'Top $_animeCount Action Anime of All Time',
    );
    _jsonController.addListener(_validateInput);
  }

  @override
  void dispose() {
    _jsonController.removeListener(_validateInput);
    _jsonController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _validateInput() {
    final text = _jsonController.text.trim();
    if (text.isEmpty) {
      if (mounted) {
        setState(() {
          _validationStatus = null;
          _isValidJson = false;
          _detectedAnimeCount = 0;
        });
      }
      return;
    }

    try {
      final parsed = AnimePostJsonService.parseLlmJson(text);
      int count = 0;
      if (parsed is Map) {
        final list = parsed['anime'] ?? parsed['items'] ?? parsed['list'] ?? parsed['slides'];
        if (list is List) {
          count = list.length;
        }
      } else if (parsed is List) {
        count = parsed.length;
      }

      if (mounted) {
        setState(() {
          _isValidJson = true;
          _detectedAnimeCount = count;
          _validationStatus = 'Valid JSON • $count Anime Recommendations detected';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isValidJson = false;
          _detectedAnimeCount = 0;
          _validationStatus = 'Invalid JSON: Check brackets or commas';
        });
      }
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null && data.text!.isNotEmpty) {
      _jsonController.text = data.text!;
    }
  }

  Future<void> _pickJsonFile() async {
    try {
      final content = await AnimePostJsonService.pickJsonFile();
      if (content != null && content.isNotEmpty) {
        _jsonController.text = content;
      }
    } catch (e) {
      // Pick file error silently handled
    }
  }

  void _copyAiPrompt() {
    final title = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : 'Top $_animeCount Action Anime of All Time';
    final prompt = AnimePostJsonService.getAiPromptTemplate(
      title: title,
      count: _animeCount,
    );
    Clipboard.setData(ClipboardData(text: prompt));
  }

  void _loadSample(String key) {
    final sample = AnimePostJsonService.samplePresets[key];
    if (sample != null) {
      _jsonController.text = sample.trim();
    }
  }

  Future<void> _exportCurrentToJson() async {
    try {
      final path = await AnimePostJsonService.exportProjectToJsonFile(widget.currentProject);
      _showToast('Exported to $path');
    } catch (e) {
      _showToast('Export failed: $e');
    }
  }

  void _applyImport() {
    final text = _jsonController.text.trim();
    if (text.isEmpty) {
      return;
    }

    try {
      final parsed = AnimePostJsonService.parseLlmJson(text);
      final newProject = AnimePostJsonService.createProjectFromJson(
        jsonData: parsed,
        existingTheme: widget.currentProject.theme,
        existingSlides: widget.currentProject.slides,
        preserveImages: _preserveImages,
      );

      widget.onProjectImported(newProject);
      Navigator.pop(context);
    } catch (e) {
      // Parse JSON error silently handled
    }
  }

  void _showToast(String msg) {
    widget.onShowToast?.call(msg);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle pill
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Auto-Fill with JSON',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Import from ChatGPT, Gemini, or .json file',
                        style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.grey),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Scrollable Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. AI Prompt Customizer & Generator Card
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F3FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        initiallyExpanded: _showPromptBuilder,
                        onExpansionChanged: (val) => setState(() => _showPromptBuilder = val),
                        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        leading: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)]),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 16),
                        ),
                        title: const Text(
                          'Configure AI Prompt (ChatGPT / Gemini)',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4338CA),
                          ),
                        ),
                        subtitle: Text(
                          '"${_titleController.text.isNotEmpty ? _titleController.text : "Top $_animeCount Anime"}" • $_animeCount Anime • ```json codeblock',
                          style: TextStyle(fontSize: 10.5, color: Colors.indigo.shade700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Title / Topic Variable:',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                                const SizedBox(height: 5),
                                TextField(
                                  controller: _titleController,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    filled: true,
                                    fillColor: Colors.white,
                                    hintText: 'e.g. Top 5 Mind-Bending Anime, Top 10 Shonen Fights',
                                    hintStyle: const TextStyle(fontSize: 11.5, color: Colors.grey),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: Colors.indigo.shade200),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
                                    ),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                                const SizedBox(height: 10),

                                const Text(
                                  'Anime Count Variable (Items in Carousel):',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  children: [3, 5, 7, 10].map((countVal) {
                                    final isSelected = _animeCount == countVal;
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: ChoiceChip(
                                        label: Text('$countVal Anime', style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                          color: isSelected ? Colors.white : Colors.indigo.shade900,
                                        )),
                                        selected: isSelected,
                                        selectedColor: const Color(0xFF6366F1),
                                        backgroundColor: Colors.white,
                                        side: BorderSide(
                                          color: isSelected ? const Color(0xFF6366F1) : Colors.indigo.shade100,
                                        ),
                                        onSelected: (selected) {
                                          if (selected) {
                                            setState(() {
                                              _animeCount = countVal;
                                              if (_titleController.text.startsWith('Top ') && _titleController.text.contains('Anime')) {
                                                _titleController.text = _titleController.text.replaceFirst(RegExp(r'Top \d+'), 'Top $countVal');
                                              }
                                            });
                                          }
                                        },
                                      ),
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 10),

                                // Copy Prompt Button inside builder
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _copyAiPrompt,
                                    icon: const Icon(Icons.copy_rounded, size: 14),
                                    label: Text(
                                      'Copy Prompt ($_animeCount Anime in ```json Codeblock)',
                                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF6366F1),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 2. Action Ribbon
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _copyAiPrompt,
                          icon: const Icon(Icons.smart_toy_rounded, size: 15, color: Colors.indigo),
                          label: const Text('Copy AI Prompt', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.indigo,
                            side: BorderSide(color: Colors.indigo.shade200),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pasteFromClipboard,
                          icon: const Icon(Icons.paste_rounded, size: 15, color: AppColors.primary),
                          label: const Text('Paste Clipboard', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Secondary Action Ribbon
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickJsonFile,
                          icon: const Icon(Icons.folder_open_rounded, size: 15, color: Colors.teal),
                          label: const Text('Pick .json File', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.teal,
                            side: BorderSide(color: Colors.teal.shade200),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _exportCurrentToJson,
                          icon: const Icon(Icons.file_upload_outlined, size: 15, color: Colors.blueGrey),
                          label: const Text('Backup to JSON', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blueGrey,
                            side: BorderSide(color: Colors.blueGrey.shade200),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Quick Sample Chips
                  Row(
                    children: [
                      const Icon(Icons.flash_on_rounded, size: 14, color: Colors.amber),
                      const SizedBox(width: 4),
                      const Text(
                        '1-Click Sample Demos:',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const Spacer(),
                      if (_jsonController.text.isNotEmpty)
                        InkWell(
                          onTap: () => _jsonController.clear(),
                          child: const Text('Clear', style: TextStyle(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: AnimePostJsonService.samplePresets.keys.map((title) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            label: Text(title, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600)),
                            backgroundColor: Colors.grey.shade50,
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            onPressed: () => _loadSample(title),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // JSON Editor Textarea
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _isValidJson
                            ? Colors.green.shade400
                            : (_validationStatus != null ? Colors.red.shade300 : Colors.grey.shade300),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _jsonController,
                          maxLines: 9,
                          minLines: 6,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11.5,
                            color: Color(0xFF1E293B),
                            height: 1.35,
                          ),
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.all(12),
                            border: InputBorder.none,
                            hintText: 'Paste raw JSON or markdown from Gemini / ChatGPT here...\n\nExample:\n{\n  "title": "TOP 5 ACTION ANIME",\n  "anime": [...]\n}',
                            hintStyle: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        if (_validationStatus != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _isValidJson ? Colors.green.shade50 : Colors.red.shade50,
                              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(9)),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _isValidJson ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                                  size: 14,
                                  color: _isValidJson ? Colors.green.shade700 : Colors.red.shade700,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _validationStatus!,
                                    style: TextStyle(
                                      color: _isValidJson ? Colors.green.shade800 : Colors.red.shade800,
                                      fontSize: 11,
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

                  const SizedBox(height: 10),

                  // Option: Preserve Existing Images
                  CheckboxListTile(
                    value: _preserveImages,
                    onChanged: (val) => setState(() => _preserveImages = val ?? true),
                    activeColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text(
                      'Keep existing slide images',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                    subtitle: const Text(
                      'Preserve images already assigned to slides 1..N and map them to new titles',
                      style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
            ),
          ),

          // Footer Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: _isValidJson ? _applyImport : null,
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: Text(
                  _detectedAnimeCount > 0
                      ? 'Import & Generate $_detectedAnimeCount Anime Slides'
                      : 'Import & Generate Carousel Slides',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade200,
                  disabledForegroundColor: Colors.grey.shade500,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
