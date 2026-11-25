import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quickpost/config/app_theme.dart';
import 'package:quickpost/services/analytics_service.dart';
import 'models/poll_quiz_model.dart';
import 'services/poll_quiz_service.dart';
import 'widgets/poll_canvas_view.dart';

/// Poll & Quiz Post Maker Studio:
/// - 4 interactive formats: 4-Option Trivia, This or That (VS), Percentage Poll, True or False
/// - Watermark-screen-style integrated control tabs (Question, Options, Timer, Theme, Format, Backdrop)
/// - Custom questions, option text, vote percentages, correct answer marking & reveal
/// - Multiple aspect ratios (9:16 Story/Reels/Shorts, 4:5 Feed, 1:1 Square)
/// - High-resolution 1080p+ canvas capture & automatic MediaStore saving to Pictures/Quick Post Polls
/// - Viral pre-configured templates
class PollQuizMakerScreen extends StatefulWidget {
  const PollQuizMakerScreen({super.key});

  @override
  State<PollQuizMakerScreen> createState() => _PollQuizMakerScreenState();
}

class _PollQuizMakerScreenState extends State<PollQuizMakerScreen> {
  final GlobalKey _boundaryKey = GlobalKey();
  PollPost _post = PollPost.initialDefault;
  bool _isSaving = false;
  String? _lastSavedPath;

  // Watermark-style control tabs state
  int _selectedTabIndex = 0;
  bool _isTabContentExpanded = true;

  // Text controllers
  late TextEditingController _categoryController;
  late TextEditingController _questionController;
  late TextEditingController _handleController;
  final List<TextEditingController> _optionControllers = [];

  @override
  void initState() {
    super.initState();
    AnalyticsService().setCurrentScreen(screenName: 'Poll Quiz Studio');
    _categoryController = TextEditingController(text: _post.category);
    _questionController = TextEditingController(text: _post.question);
    _handleController = TextEditingController(text: _post.creatorHandle);
    _syncOptionControllers();
  }

  void _syncOptionControllers() {
    for (final c in _optionControllers) {
      c.dispose();
    }
    _optionControllers.clear();
    for (final opt in _post.options) {
      _optionControllers.add(TextEditingController(text: opt.text));
    }
  }

  void _syncAllFromPost(PollPost post) {
    _categoryController.text = post.category;
    _questionController.text = post.question;
    _handleController.text = post.creatorHandle;
    _syncOptionControllers();
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _questionController.dispose();
    _handleController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _changePollType(PollType type) {
    if (_post.type == type) return;
    List<PollOption> newOptions = [];

    switch (type) {
      case PollType.trivia4:
        newOptions = const [
          PollOption(id: 'opt1', text: 'Option A', votesPercent: 25, isCorrect: true),
          PollOption(id: 'opt2', text: 'Option B', votesPercent: 25, isCorrect: false),
          PollOption(id: 'opt3', text: 'Option C', votesPercent: 25, isCorrect: false),
          PollOption(id: 'opt4', text: 'Option D', votesPercent: 25, isCorrect: false),
        ];
        break;
      case PollType.thisOrThat:
        newOptions = const [
          PollOption(id: 'opt1', text: 'Choice A', votesPercent: 50),
          PollOption(id: 'opt2', text: 'Choice B', votesPercent: 50),
        ];
        break;
      case PollType.percentagePoll:
        newOptions = const [
          PollOption(id: 'opt1', text: 'Agree completely', votesPercent: 78),
          PollOption(id: 'opt2', text: 'Disagree completely', votesPercent: 22),
        ];
        break;
      case PollType.trueOrFalse:
        newOptions = const [
          PollOption(id: 'opt1', text: 'TRUE', votesPercent: 65, isCorrect: true),
          PollOption(id: 'opt2', text: 'FALSE', votesPercent: 35, isCorrect: false),
        ];
        break;
    }

    setState(() {
      _post = _post.copyWith(type: type, options: newOptions);
      _syncOptionControllers();
    });
  }

  void _updateOptionText(int index, String text) {
    if (index >= _post.options.length) return;
    final updatedList = List<PollOption>.from(_post.options);
    updatedList[index] = updatedList[index].copyWith(text: text);
    setState(() => _post = _post.copyWith(options: updatedList));
  }

  void _updateOptionVotes(int index, int votes) {
    if (index >= _post.options.length) return;
    final updatedList = List<PollOption>.from(_post.options);
    updatedList[index] = updatedList[index].copyWith(votesPercent: votes);
    setState(() => _post = _post.copyWith(options: updatedList));
  }

  void _setCorrectOption(int correctIndex) {
    final updatedList = List.generate(_post.options.length, (i) {
      return _post.options[i].copyWith(isCorrect: i == correctIndex);
    });
    setState(() => _post = _post.copyWith(options: updatedList));
  }

  Future<void> _pickBackdrop() async {
    final file = await PollQuizService().pickImage();
    if (file != null && mounted) {
      setState(() => _post = _post.copyWith(customBgImagePath: file.path));
    }
  }

  Future<void> _exportPoll() async {
    setState(() => _isSaving = true);

    try {
      final Uint8List? pngBytes = await PollQuizService().captureBoundary(_boundaryKey);
      if (pngBytes == null) {
        setState(() => _isSaving = false);
        return;
      }

      final String? path = await PollQuizService().savePollImageToGallery(
        pngBytes,
        _post.category.isNotEmpty ? _post.category : 'QuizPost',
      );

      if (mounted) {
        setState(() {
          _isSaving = false;
          _lastSavedPath = path;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppColors.primarySurface, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Poll post saved to Gallery! (Pictures/Quick Post Polls)',
                    style: TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.textPrimary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error exporting poll: $e');
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _sharePoll() async {
    if (_lastSavedPath == null) {
      final Uint8List? pngBytes = await PollQuizService().captureBoundary(_boundaryKey);
      if (pngBytes != null) {
        _lastSavedPath = await PollQuizService().savePollImageToGallery(
          pngBytes,
          _post.category.isNotEmpty ? _post.category : 'QuizPost',
        );
      }
    }

    if (_lastSavedPath != null) {
      await PollQuizService().sharePollImage(_lastSavedPath!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Poll & Quiz Studio',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
        ),
        actions: [
          PopupMenuButton<PollPost>(
            tooltip: 'Load Viral Poll Preset',
            icon: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFEAB308)),
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            onSelected: (template) {
              setState(() {
                _post = template;
                _syncAllFromPost(template);
              });
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                enabled: false,
                child: Text('VIRAL QUIZ PRESETS', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              ...PollPost.viralTemplates.map((preset) {
                return PopupMenuItem(
                  value: preset,
                  child: Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(color: preset.theme.accentColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          preset.category,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontFamily: 'Poppins'),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── Center Interactive Canvas ───
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 420, maxHeight: 600),
                  child: RepaintBoundary(
                    key: _boundaryKey,
                    child: PollCanvasView(
                      post: _post,
                      onEditRequested: () {
                        setState(() {
                          _selectedTabIndex = 0;
                          _isTabContentExpanded = true;
                        });
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ─── Watermark-style Active Tab Content Panel ───
          if (_isTabContentExpanded) _buildActiveTabContent(),

          // ─── Watermark-style Horizontal Control Tabs Bar ───
          _buildControlTabsBar(),

          // ─── Bottom Sticky Action Dock (Reset, Share, Export) ───
          _buildBottomActionDock(),
        ],
      ),
    );
  }

  // ─── Horizontal Control Tabs Bar ───
  Widget _buildControlTabsBar() {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        children: [
          _buildTabItem(0, Icons.help_outline_rounded, 'Question', const Color(0xFF00796B)),
          _buildTabItem(1, Icons.list_alt_rounded, 'Options', const Color(0xFF0284C7)),
          _buildTabItem(2, Icons.timer_outlined, 'Timer', const Color(0xFFF59E0B)),
          _buildTabItem(3, Icons.palette_rounded, 'Theme', const Color(0xFF8B5CF6)),
          _buildTabItem(4, Icons.aspect_ratio_rounded, 'Format', const Color(0xFF0D9488)),
          _buildTabItem(5, Icons.wallpaper_rounded, 'Backdrop', const Color(0xFFEC4899)),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, IconData icon, String label, Color color) {
    final isSelected = _selectedTabIndex == index && _isTabContentExpanded;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          if (_selectedTabIndex == index) {
            _isTabContentExpanded = !_isTabContentExpanded;
          } else {
            _selectedTabIndex = index;
            _isTabContentExpanded = true;
          }
        });
      },
      child: Container(
        width: 76,
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color.withValues(alpha: 0.5) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey.shade600, size: 20),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isSelected ? color : Colors.grey.shade700,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Active Tab Content Container ───
  Widget _buildActiveTabContent() {
    return Container(
      height: 240,
      decoration: const BoxDecoration(color: Colors.white),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: SingleChildScrollView(
        child: _buildTabSpecificContent(),
      ),
    );
  }

  Widget _buildTabSpecificContent() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildQuestionTab();
      case 1:
        return _buildOptionsTab();
      case 2:
        return _buildTimerTab();
      case 3:
        return _buildThemeTab();
      case 4:
        return _buildFormatTab();
      case 5:
        return _buildBackdropTab();
      default:
        return const SizedBox.shrink();
    }
  }

  // ─── Tab 0: Question & Type ───
  Widget _buildQuestionTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'POLL FORMAT ARCHETYPE',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: PollType.values.map((type) {
            final isSelected = _post.type == type;
            return ChoiceChip(
              avatar: Icon(type.icon, size: 14, color: isSelected ? AppColors.primary : Colors.grey.shade700),
              label: Text(type.name, style: const TextStyle(fontSize: 11, fontFamily: 'Poppins')),
              selected: isSelected,
              selectedColor: AppColors.primarySurface,
              onSelected: (_) {
                HapticFeedback.selectionClick();
                _changePollType(type);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _categoryController,
          decoration: InputDecoration(
            labelText: 'Category Ribbon Title',
            labelStyle: const TextStyle(fontSize: 11, fontFamily: 'Poppins'),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          style: const TextStyle(fontSize: 12, fontFamily: 'Poppins'),
          onChanged: (val) => setState(() => _post = _post.copyWith(category: val)),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _questionController,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: 'Central Question Headline',
            labelStyle: const TextStyle(fontSize: 11, fontFamily: 'Poppins'),
            isDense: true,
            contentPadding: const EdgeInsets.all(10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
          onChanged: (val) => setState(() => _post = _post.copyWith(question: val)),
        ),
      ],
    );
  }

  // ─── Tab 1: Options Editor ───
  Widget _buildOptionsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Reveal Correct Answer / Results', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
            Switch(
              value: _post.revealAnswer,
              activeThumbColor: AppColors.primary,
              onChanged: (val) => setState(() => _post = _post.copyWith(revealAnswer: val)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ...List.generate(_post.options.length, (i) {
          final opt = _post.options[i];
          final controller = i < _optionControllers.length ? _optionControllers[i] : TextEditingController(text: opt.text);
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: 'Option #${i + 1}',
                      labelStyle: const TextStyle(fontSize: 10, fontFamily: 'Poppins'),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    style: const TextStyle(fontSize: 11.5, fontFamily: 'Poppins'),
                    onChanged: (val) => _updateOptionText(i, val),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Row(
                    children: [
                      Text('${opt.votesPercent}%', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                      Expanded(
                        child: Slider(
                          value: opt.votesPercent.toDouble(),
                          min: 0,
                          max: 100,
                          activeColor: AppColors.primary,
                          onChanged: (val) => _updateOptionVotes(i, val.round()),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_post.type == PollType.trivia4 || _post.type == PollType.trueOrFalse)
                  IconButton(
                    icon: Icon(
                      opt.isCorrect ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      color: opt.isCorrect ? Colors.green : Colors.grey,
                      size: 20,
                    ),
                    tooltip: 'Mark as correct answer',
                    onPressed: () => _setCorrectOption(i),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ─── Tab 2: Countdown Timer & Branding ───
  Widget _buildTimerTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Show Countdown Timer Badge', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
            Switch(
              value: _post.showTimer,
              activeThumbColor: AppColors.primary,
              onChanged: (val) => setState(() => _post = _post.copyWith(showTimer: val)),
            ),
          ],
        ),
        if (_post.showTimer) ...[
          Row(
            children: [
              Text('Timer Duration: ${_post.timerSeconds}s', style: const TextStyle(fontSize: 12, fontFamily: 'Poppins')),
              Expanded(
                child: Slider(
                  value: _post.timerSeconds.toDouble(),
                  min: 3,
                  max: 30,
                  divisions: 27,
                  activeColor: AppColors.primary,
                  onChanged: (val) => setState(() => _post = _post.copyWith(timerSeconds: val.round())),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        TextField(
          controller: _handleController,
          decoration: InputDecoration(
            labelText: 'Creator Watermark / Handle',
            labelStyle: const TextStyle(fontSize: 11, fontFamily: 'Poppins'),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          style: const TextStyle(fontSize: 12, fontFamily: 'Poppins'),
          onChanged: (val) => setState(() => _post = _post.copyWith(creatorHandle: val)),
        ),
      ],
    );
  }

  // ─── Tab 3: Themes ───
  Widget _buildThemeTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'VIRAL THEME PRESETS',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: PollThemePreset.presets.length,
            itemBuilder: (ctx, index) {
              final preset = PollThemePreset.presets[index];
              final isSelected = _post.themeIndex == index;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _post = _post.copyWith(themeIndex: index));
                },
                child: Container(
                  width: 90,
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(colors: preset.gradientColors),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Colors.grey.shade400,
                      width: isSelected ? 2.5 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(color: preset.accentColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        preset.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── Tab 4: Aspect Ratio / Format ───
  Widget _buildFormatTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CANVAS ASPECT RATIO',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: PollAspectRatio.values.map((ratio) {
            final isSelected = _post.aspectRatio == ratio;
            return ChoiceChip(
              avatar: Icon(ratio.icon, size: 16, color: isSelected ? AppColors.primary : Colors.grey.shade700),
              label: Text(ratio.label, style: const TextStyle(fontSize: 11.5, fontFamily: 'Poppins')),
              selected: isSelected,
              selectedColor: AppColors.primarySurface,
              onSelected: (_) {
                HapticFeedback.selectionClick();
                setState(() => _post = _post.copyWith(aspectRatio: ratio));
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─── Tab 5: Backdrop & Image ───
  Widget _buildBackdropTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.wallpaper_rounded, size: 18),
                label: Text(
                  _post.customBgImagePath != null ? 'Change Custom Photo' : 'Custom Photo Backdrop',
                  style: const TextStyle(fontSize: 12, fontFamily: 'Poppins'),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _pickBackdrop,
              ),
            ),
            if (_post.customBgImagePath != null) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.clear_rounded, color: Colors.red),
                tooltip: 'Clear photo',
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() => _post = _post.copyWith(clearBgImage: true));
                },
              ),
            ],
          ],
        ),
      ],
    );
  }

  // ─── Bottom Sticky Action Dock ───
  Widget _buildBottomActionDock() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -3),
            blurRadius: 10,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Reset Button
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
              tooltip: 'Reset to default',
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _post = PollPost.initialDefault;
                  _syncAllFromPost(_post);
                });
              },
            ),

            // Share Button
            IconButton(
              icon: const Icon(Icons.share_rounded, color: AppColors.textPrimary),
              tooltip: 'Share poll',
              onPressed: _isSaving ? null : _sharePoll,
            ),

            const SizedBox(width: 8),

            // Export to Gallery Button
            Expanded(
              child: ElevatedButton.icon(
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.download_rounded, size: 20),
                label: Text(
                  _isSaving ? 'Exporting...' : 'Save to Gallery',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Poppins'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isSaving ? null : _exportPoll,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
