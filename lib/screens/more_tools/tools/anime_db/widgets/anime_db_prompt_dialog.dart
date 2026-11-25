import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quickpost/config/app_theme.dart';
import 'package:quickpost/screens/anime_post/services/anime_db_llm_prompt.dart';

/// Interactive AI Prompt Generator Studio dialog.
/// Allows creators to generate single-anime prompts (with main/popular characters)
/// or multi-anime collection prompts for ChatGPT/Gemini/Claude.
class AnimeDbPromptDialog extends StatefulWidget {
  final String? initialAnimeTitle;
  const AnimeDbPromptDialog({super.key, this.initialAnimeTitle});

  static Future<void> show(BuildContext context, {String? initialAnimeTitle}) {
    return showDialog(
      context: context,
      builder: (_) => AnimeDbPromptDialog(initialAnimeTitle: initialAnimeTitle),
    );
  }

  @override
  State<AnimeDbPromptDialog> createState() => _AnimeDbPromptDialogState();
}

class _AnimeDbPromptDialogState extends State<AnimeDbPromptDialog> {
  int _tabIndex = 0; // 0: Single Anime, 1: Catalog Collection

  // Single Anime mode
  late final TextEditingController _singleAnimeController;

  // Catalog mode
  final List<String> _presets = [
    'the 50 most popular anime of all time',
    'the top 30 shounen and high-octane action anime',
    'the top 25 dark fantasy and psychological thriller anime',
    'the top 25 romance, drama and slice of life anime',
    'the top 20 trending hits from 2023 to 2025',
    'the top 25 nostalgic 90s and 2000s classic anime',
    'the top 20 mind-bending sci-fi and cyberpunk anime',
    'the top 20 best anime movies of all time',
  ];
  late String _selectedPreset;
  late final TextEditingController _customController;
  bool _isCustom = false;

  @override
  void initState() {
    super.initState();
    final init = widget.initialAnimeTitle?.trim() ?? '';
    _singleAnimeController = TextEditingController(text: init);
    _tabIndex = init.isNotEmpty ? 0 : 0; // default to Single Anime
    _selectedPreset = _presets.first;
    _customController = TextEditingController(text: _selectedPreset);
  }

  @override
  void dispose() {
    _singleAnimeController.dispose();
    _customController.dispose();
    super.dispose();
  }

  String _generatePrompt() {
    if (_tabIndex == 0) {
      final name = _singleAnimeController.text.trim();
      return AnimeDbLlmPrompt.buildSingle(name.isEmpty ? 'requested anime' : name);
    } else {
      final query = _isCustom ? _customController.text.trim() : _selectedPreset;
      return AnimeDbLlmPrompt.build(request: query.isEmpty ? 'popular anime' : query);
    }
  }

  Future<void> _copyPrompt() async {
    if (_tabIndex == 0 && _singleAnimeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an anime name first.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final prompt = _generatePrompt();
    await Clipboard.setData(ClipboardData(text: prompt));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_tabIndex == 0
            ? 'Copied Single Anime prompt for "${_singleAnimeController.text.trim()}"! Paste into ChatGPT/Claude.'
            : 'Copied Catalog prompt! Paste it into ChatGPT / Gemini / Claude.'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final maxHeight = (size.height * 0.85).clamp(360.0, 680.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 520, maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.psychology_rounded, color: Color(0xFF6366F1), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Prompt Generator',
                          style: TextStyle(
                            fontFamily: AppTextStyles.fontFamily,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Generate 1-click prompts for ChatGPT, Claude & Gemini',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Segmented Tab Toggle (Single Anime vs Collection)
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _tabIndex = 0),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _tabIndex == 0 ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: _tabIndex == 0
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.06),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.movie_outlined,
                                size: 16,
                                color: _tabIndex == 0 ? const Color(0xFF6366F1) : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Single Anime Details',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: _tabIndex == 0 ? FontWeight.w800 : FontWeight.w600,
                                  color: _tabIndex == 0 ? const Color(0xFF1E1B4B) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _tabIndex = 1),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _tabIndex == 1 ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: _tabIndex == 1
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.06),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.view_list_rounded,
                                size: 16,
                                color: _tabIndex == 1 ? const Color(0xFF6366F1) : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Catalog / Collection',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: _tabIndex == 1 ? FontWeight.w800 : FontWeight.w600,
                                  color: _tabIndex == 1 ? const Color(0xFF1E1B4B) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Tab Content Body
              Expanded(
                child: _tabIndex == 0 ? _buildSingleAnimeTab() : _buildCatalogTab(),
              ),

              const SizedBox(height: 14),

              // Footer Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _copyPrompt,
                      icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 18),
                      label: Text(
                        _tabIndex == 0 ? 'Copy Single Anime Prompt' : 'Copy Catalog Prompt',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSingleAnimeTab() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        const Text(
          'ENTER ANIME NAME',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF94A3B8),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _singleAnimeController,
          autofocus: false,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'e.g. Vinland Saga, Frieren, Chainsaw Man...',
            hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400, fontWeight: FontWeight.normal),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF6366F1)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
            ),
          ),
        ),

        const SizedBox(height: 14),

        // Features included card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFC7D2FE)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 16, color: Color(0xFF4F46E5)),
                  SizedBox(width: 8),
                  Text(
                    'What this prompt requests:',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF3730A3),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildFeatureItem(Icons.star_rounded, 'Score & Rating', 'Accurate global/MAL rating'),
              _buildFeatureItem(Icons.tv_rounded, 'Episodes & Format', 'Season count, total episodes, studio'),
              _buildFeatureItem(Icons.people_rounded, 'Main & Popular Characters', '4-6 key character names (cast)'),
              _buildFeatureItem(Icons.format_quote_rounded, 'Hook Synopsis', 'Engaging, spoiler-free 1-2 sentence hook'),
              _buildFeatureItem(Icons.code_rounded, 'Strict JSON Codeblock', '1-click copy without chit-chat'),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Workflow Steps
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'HOW IT WORKS',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8)),
              ),
              SizedBox(height: 4),
              Text(
                '1. Type the title & tap "Copy Single Anime Prompt".\n'
                '2. Paste into ChatGPT, Claude or Gemini.\n'
                '3. Click the LLM\'s "Copy code" button on the JSON block.\n'
                '4. In the app, tap "Import JSON" and hit Save to add directly to your database!',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF475569), height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFF6366F1)),
          const SizedBox(width: 8),
          Text(
            '$title: ',
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF1E1B4B)),
          ),
          Expanded(
            child: Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF4338CA)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogTab() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        const Text(
          'CHOOSE PRESET OR TOPIC',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF94A3B8),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        ..._presets.map((p) {
          final isSelected = !_isCustom && _selectedPreset == p;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                setState(() {
                  _selectedPreset = p;
                  _isCustom = false;
                  _customController.text = p;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFEEF2FF) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                      size: 16,
                      color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        p,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? const Color(0xFF3730A3) : const Color(0xFF334155),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),

        // Custom Topic Option
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 6),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => _isCustom = true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _isCustom ? const Color(0xFFEEF2FF) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _isCustom ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isCustom ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    size: 16,
                    color: _isCustom ? const Color(0xFF6366F1) : const Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Custom topic or niche collection...',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),

        if (_isCustom) ...[
          const SizedBox(height: 6),
          TextField(
            controller: _customController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'e.g. top 15 sports anime, or 90s cyberpunk movies',
              filled: true,
              fillColor: const Color(0xFFF1F5F9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
            style: const TextStyle(fontSize: 13),
          ),
        ],

        const SizedBox(height: 12),

        // Characters Note
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF16A34A)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Includes instructions to fetch 3-5 main/popular character names for each anime entry along with clean markdown codeblock formatting.',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF15803D), height: 1.3),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
