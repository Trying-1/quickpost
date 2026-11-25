import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../config/app_theme.dart';
import '../models/carousel_project.dart';
import '../models/carousel_slide.dart';
import '../services/carousel_json_service.dart';

/// Interactive modal sheet to import carousel data from JSON or LLM prompts (Gemini, ChatGPT, Claude)
/// and populate all slides instantly without manual typing.
class CarouselJsonImportSheet extends StatefulWidget {
  final CarouselProject currentProject;
  final ValueChanged<CarouselProject> onProjectImported;
  final ValueChanged<String>? onShowToast;

  const CarouselJsonImportSheet({
    super.key,
    required this.currentProject,
    required this.onProjectImported,
    this.onShowToast,
  });

  static Future<void> show({
    required BuildContext context,
    required CarouselProject currentProject,
    required ValueChanged<CarouselProject> onProjectImported,
    ValueChanged<String>? onShowToast,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CarouselJsonImportSheet(
        currentProject: currentProject,
        onProjectImported: onProjectImported,
        onShowToast: onShowToast,
      ),
    );
  }

  @override
  State<CarouselJsonImportSheet> createState() => _CarouselJsonImportSheetState();
}

class _CarouselJsonImportSheetState extends State<CarouselJsonImportSheet> {
  final TextEditingController _jsonController = TextEditingController();
  late TextEditingController _titleController;
  int _slideCount = 5;
  bool _showPromptBuilder = false;
  bool _preserveImages = true;
  String? _validationStatus;
  bool _isValidJson = false;
  int _detectedSlideCount = 0;

  @override
  void initState() {
    super.initState();
    final count = widget.currentProject.slides.where((s) => s.type == SlideType.content).length;
    _slideCount = count > 0 ? count : 5;
    _titleController = TextEditingController(
      text: widget.currentProject.title.isNotEmpty
          ? widget.currentProject.title
          : '5 Mindset Shifts for Success',
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
          _detectedSlideCount = 0;
        });
      }
      return;
    }

    try {
      final parsed = CarouselJsonService.parseLlmJson(text);
      int count = 0;
      if (parsed is Map) {
        final list = parsed['slides'] ??
            parsed['items'] ??
            parsed['list'] ??
            parsed['quotes'] ??
            parsed['steps'] ??
            parsed['tips'] ??
            parsed['points'] ??
            parsed['content'];
        if (list is List) {
          count = list.length;
        }
      } else if (parsed is List) {
        count = parsed.length;
      }

      if (mounted) {
        setState(() {
          _isValidJson = true;
          _detectedSlideCount = count;
          _validationStatus = 'Valid JSON detected ($count slide item${count == 1 ? '' : 's'})';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isValidJson = false;
          _detectedSlideCount = 0;
          _validationStatus = 'Invalid or incomplete JSON: $e';
        });
      }
    }
  }

  void _copyAiPrompt() {
    final title = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : '5 Mindset Shifts for Success';
    final prompt = CarouselJsonService.generateLlmPrompt(
      title: title,
      count: _slideCount,
    );
    Clipboard.setData(ClipboardData(text: prompt));
    widget.onShowToast?.call('Copied AI prompt to clipboard!');
  }

  void _applyJson() {
    final text = _jsonController.text.trim();
    if (text.isEmpty) return;

    try {
      final parsed = CarouselJsonService.parseLlmJson(text);
      final project = CarouselJsonService.createProjectFromJson(
        jsonData: parsed,
        existingTheme: widget.currentProject.theme,
        existingSlides: _preserveImages ? widget.currentProject.slides : null,
        preserveImages: _preserveImages,
      );

      widget.onProjectImported(project);
      Navigator.pop(context);
      widget.onShowToast?.call('Imported ${project.slides.length} slides successfully!');
    } catch (e) {
      widget.onShowToast?.call('Import error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.purple, size: 22),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'AI JSON Importer',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Prompt builder expander
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.purple.shade200),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.lightbulb_rounded, color: Colors.purple),
                          title: const Text(
                            'Generate with AI (ChatGPT / Gemini / Claude)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          subtitle: const Text(
                            'Copy prompt -> Paste into AI -> Paste response below',
                            style: TextStyle(fontSize: 11),
                          ),
                          trailing: IconButton(
                            icon: Icon(_showPromptBuilder ? Icons.expand_less : Icons.expand_more),
                            onPressed: () => setState(() => _showPromptBuilder = !_showPromptBuilder),
                          ),
                        ),
                        if (_showPromptBuilder) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextField(
                                  controller: _titleController,
                                  decoration: InputDecoration(
                                    labelText: 'Topic / Title',
                                    hintText: 'e.g. 7 Stoic Rules for Peace',
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    const Text('Slide count:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                    const SizedBox(width: 8),
                                    ...[3, 5, 7, 10].map((c) {
                                      final isSel = _slideCount == c;
                                      return Padding(
                                        padding: const EdgeInsets.only(right: 6),
                                        child: ChoiceChip(
                                          label: Text('$c'),
                                          selected: isSel,
                                          selectedColor: Colors.purple,
                                          labelStyle: TextStyle(
                                            color: isSel ? Colors.white : Colors.black87,
                                            fontSize: 11,
                                          ),
                                          onSelected: (_) => setState(() => _slideCount = c),
                                        ),
                                      );
                                    }).toList(),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _copyAiPrompt,
                                    icon: const Icon(Icons.copy_rounded, size: 14),
                                    label: const Text('Copy AI Prompt to Clipboard'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.purple,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Paste area
                  const Text(
                    'Paste JSON / Markdown from AI:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _jsonController,
                    maxLines: 8,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                    decoration: InputDecoration(
                      hintText: 'Paste raw JSON or ```json block from ChatGPT or Gemini here...',
                      hintStyle: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.all(12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Validation status
                  if (_validationStatus != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _isValidJson ? Colors.green.shade50 : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _isValidJson ? Colors.green.shade200 : Colors.red.shade200,
                        ),
                      ),
                      child: Text(
                        _validationStatus!,
                        style: TextStyle(
                          fontSize: 11,
                          color: _isValidJson ? Colors.green.shade800 : Colors.red.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),
                  // Preserve images checkbox
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Preserve existing slide background images',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: _preserveImages,
                    onChanged: (val) => setState(() => _preserveImages = val ?? true),
                  ),

                  const SizedBox(height: 16),
                  // Apply button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isValidJson ? _applyJson : null,
                      icon: const Icon(Icons.download_done_rounded, size: 18),
                      label: Text('Apply to Carousel (${_detectedSlideCount > 0 ? "$_detectedSlideCount items" : "Ready"})'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

