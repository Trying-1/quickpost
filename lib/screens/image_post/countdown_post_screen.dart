import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../utils/font_selector.dart';
import '../../widgets/advanced_color_picker.dart';
import '../../utils/image_generator.dart';
import '../../services/analytics_service.dart';

class CountdownPostScreen extends StatefulWidget {
  const CountdownPostScreen({super.key});

  @override
  State<CountdownPostScreen> createState() => _CountdownPostScreenState();
}

class _CountdownPostScreenState extends State<CountdownPostScreen> {
  final TextEditingController _quoteController = TextEditingController();
  final GlobalKey _previewKey = GlobalKey();

  // Separate fonts for each element
  FontInfo? _dateFont;
  FontInfo? _quoteFont;
  FontInfo? _daysFont;

  Color _backgroundColor = const Color(0xFF141414);
  
  // Separate colors for each element
  Color _dateColor = Colors.white.withOpacity(0.6);
  Color _quoteColor = Colors.white;
  Color _daysNumberColor = Colors.white;
  Color _daysLabelColor = Colors.white.withOpacity(0.5);
  Color _progressBarColor = const Color(0xFF6C63FF);
  Color _percentageColor = const Color(0xFF6C63FF);

  File? _backgroundImage;

  // New customization states
  double _fontSize = 24.0;
  bool _showShadow = true;
  bool _showGlow = false;
  double _bgBlur = 0.0;
  double _bgBrightness = 0.5;

  // Separate offsets for each element
  Offset _progressOffset = Offset.zero;
  Offset _countdownOffset = Offset(0, 100);
  Offset _quoteOffset = Offset(0, 240);

  int _selectedTabIndex = 0; // 0 Visuals, 1 Text, 2 Effects, 3 Colors, 4 Fonts
  int _selectedColorElementIndex = 0; // 0 Date, 1 Quote, 2 Days, 3 Progress, 4 BG
  int _selectedFontElementIndex = 1; // 0 Date, 1 Quote, 2 Days
  bool _isExpanded = true;

  @override
  void initState() {
    super.initState();
    final defaultFont = FontInfo(family: 'Metrophobic', displayName: 'Metrophobic');
    _dateFont = defaultFont;
    _quoteFont = defaultFont;
    _daysFont = defaultFont;
    _quoteController.text = "The distance between who you are and who you want to be is separated only by your actions.";
    AnalyticsService().setCurrentScreen(screenName: 'Year Progress Post');
  }

  int get _daysInYear {
    final year = DateTime.now().year;
    return (DateTime(year, 12, 31).difference(DateTime(year, 1, 1)).inDays) + 1;
  }

  int get _daysPassed {
    final now = DateTime.now();
    return now.difference(DateTime(now.year, 1, 1)).inDays;
  }

  int get _daysLeftInYear {
    final now = DateTime.now();
    final lastDay = DateTime(now.year, 12, 31, 23, 59, 59);
    return lastDay.difference(now).inDays;
  }

  double get _yearProgress => _daysPassed / _daysInYear;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text('Year Progress Maker', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
            child: ElevatedButton.icon(
              onPressed: () async {
                try {
                  final path = await ImageGenerator.savePostToGallery(
                    text: _quoteController.text,
                    templateKey: _previewKey,
                    selectedFont: _quoteFont,
                    outputWidth: 1080,
                    outputHeight: 1350,
                  );
                    if (path != null && mounted) {
                      AnalyticsService().logSaveAction(feature: 'year_progress', type: 'image');
                      ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Saved to gallery!'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error saving: $e')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Save', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _progressBarColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Center(
                child: SingleChildScrollView(
                  child: _buildPreview(),
                ),
              ),
            ),
          ),
          _buildControlsSection(),
        ],
      ),
    );
  }

  Widget _buildControlsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Active Tab Content
          if (_isExpanded)
            Container(
              height: 280,
              child: AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: _buildActiveTab(),
                ),
              ),
            ),

          const Divider(height: 1),

          // Tab Buttons (Bottom)
          Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildTabButton(0, Icons.brush_rounded, 'Visuals'),
                    _buildTabButton(1, Icons.title_rounded, 'Text'),
                    _buildTabButton(4, Icons.spellcheck_rounded, 'Fonts'),
                    _buildTabButton(3, Icons.palette_rounded, 'Colors'),
                    _buildTabButton(2, Icons.blur_on_rounded, 'Effects'),
                  ],
                ),
              ),
              // Toggle Button
              InkWell(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                child: Container(
                  width: 50,
                  height: 60,
                  child: Icon(
                    _isExpanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded,
                    color: Colors.grey[400],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    final now = DateTime.now();
    return RepaintBoundary(
      key: _previewKey,
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: Container(
          decoration: BoxDecoration(
            color: _backgroundColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                // Background Layer
                if (_backgroundImage != null)
                  Positioned.fill(
                    child: Image.file(
                      _backgroundImage!,
                      fit: BoxFit.cover,
                      color: Colors.black.withOpacity(1.0 - _bgBrightness),
                      colorBlendMode: BlendMode.darken,
                    ),
                  ),
                // Blur Effect
                if (_backgroundImage != null && _bgBlur > 0)
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: _bgBlur, sigmaY: _bgBlur),
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                
                // 1. Draggable Progress Item
                Positioned(
                  left: 40 + _progressOffset.dx,
                  top: 40 + _progressOffset.dy,
                  child: GestureDetector(
                    onPanUpdate: (details) => setState(() => _progressOffset += details.delta),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      color: Colors.transparent,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                DateFormat('EEEE, MMM dd').format(now).toUpperCase(),
                                style: TextStyle(
                                  color: _dateColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2.0,
                                  fontFamily: _dateFont?.family,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '${(_yearProgress * 100).toStringAsFixed(1)}%',
                                style: TextStyle(
                                  color: _percentageColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: _dateFont?.family,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            height: 4,
                            width: 120,
                            decoration: BoxDecoration(
                              color: _dateColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: _yearProgress.clamp(0.0, 1.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _progressBarColor,
                                    borderRadius: BorderRadius.circular(2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _progressBarColor.withOpacity(0.4),
                                        blurRadius: 4,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 2. Draggable Countdown Item
                Positioned(
                  left: 40 + _countdownOffset.dx,
                  top: 40 + _countdownOffset.dy,
                  child: GestureDetector(
                    onPanUpdate: (details) => setState(() => _countdownOffset += details.delta),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      color: Colors.transparent,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DAYS LEFT',
                            style: TextStyle(
                              color: _daysLabelColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              fontFamily: _daysFont?.family,
                            ),
                          ),
                          RichText(
                            text: TextSpan(
                              style: TextStyle(
                                color: _daysNumberColor,
                                fontSize: 72,
                                fontWeight: FontWeight.w900,
                                fontFamily: _daysFont?.family,
                                height: 1.1,
                                shadows: [
                                  if (_showShadow)
                                    const Shadow(
                                      color: Colors.black54,
                                      offset: Offset(2, 2),
                                      blurRadius: 8,
                                    ),
                                ],
                              ),
                              children: [
                                TextSpan(text: '$_daysLeftInYear'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 3. Draggable Quote Item
                if (_quoteController.text.isNotEmpty)
                  Positioned(
                    left: 40 + _quoteOffset.dx,
                    top: 40 + _quoteOffset.dy,
                    child: GestureDetector(
                      onPanUpdate: (details) => setState(() => _quoteOffset += details.delta),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        constraints: const BoxConstraints(maxWidth: 300),
                        color: Colors.transparent,
                        child: Text(
                          _quoteController.text,
                          style: TextStyle(
                            color: _quoteColor,
                            fontSize: _fontSize,
                            fontWeight: FontWeight.w600,
                            fontFamily: _quoteFont?.family,
                            height: 1.4,
                            shadows: [
                              if (_showShadow)
                                const Shadow(
                                  color: Colors.black45,
                                  offset: Offset(1, 1),
                                  blurRadius: 4,
                                ),
                              if (_showGlow)
                                Shadow(
                                  color: _progressBarColor.withOpacity(0.8),
                                  offset: Offset.zero,
                                  blurRadius: 15,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, IconData icon, String label) {
    final isSelected = _selectedTabIndex == index && _isExpanded;
    final themeColor = _progressBarColor;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() {
          if (_selectedTabIndex == index) {
            _isExpanded = !_isExpanded;
          } else {
            _selectedTabIndex = index;
            _isExpanded = true;
          }
        }),
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? themeColor : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: isSelected ? themeColor : Colors.grey[400], size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: isSelected ? themeColor : Colors.grey[500],
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveTab() {
    switch (_selectedTabIndex) {
      case 0: // Visuals
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            const Text('BACKGROUND STYLE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildModeToggle(isActive: _backgroundColor == const Color(0xFF141414), label: 'Dark Mode', icon: Icons.dark_mode_rounded, onSelect: () => setState(() { _backgroundColor = const Color(0xFF141414); _quoteColor = Colors.white; _daysNumberColor = Colors.white; _dateColor = Colors.white.withOpacity(0.6); _daysLabelColor = Colors.white.withOpacity(0.5); })),
                const SizedBox(width: 12),
                _buildModeToggle(isActive: _backgroundColor == Colors.white, label: 'Light Mode', icon: Icons.light_mode_rounded, onSelect: () => setState(() { _backgroundColor = Colors.white; _quoteColor = Colors.black; _daysNumberColor = Colors.black; _dateColor = Colors.black.withOpacity(0.6); _daysLabelColor = Colors.black.withOpacity(0.5); })),
              ],
            ),
            const SizedBox(height: 16),
            const Text('BACKGROUND IMAGE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.add_photo_alternate_rounded, size: 18),
                    label: const Text('Change Background', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
                if (_backgroundImage != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => setState(() => _backgroundImage = null),
                    icon: const Icon(Icons.close_rounded, color: Colors.redAccent),
                    style: IconButton.styleFrom(backgroundColor: Colors.red.withOpacity(0.05)),
                  ),
                ],
              ],
            ),
          ],
        );
      case 1: // Typography
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            const Text('QUOTE TEXT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 10),
            TextField(
              controller: _quoteController,
              maxLines: 2,
              onChanged: (v) => setState(() {}),
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Enter your motivational quote...',
                prefixIcon: Icon(Icons.format_quote_rounded, color: _progressBarColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _progressBarColor, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey[50],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 20),
            const Text('FONT SIZE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
            Slider(
              value: _fontSize,
              min: 12.0,
              max: 48.0,
              activeColor: _progressBarColor,
              onChanged: (v) => setState(() => _fontSize = v),
            ),
          ],
        );
      case 4: // Fonts
        return _buildFontsTab();
      case 3: // Colors
        return _buildColorsTab();
      case 2: // Effects
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            _buildToggleRow('Outer Shadow', _showShadow, (v) => setState(() => _showShadow = v)),
            _buildToggleRow('Accent Glow', _showGlow, (v) => setState(() => _showGlow = v)),
            const SizedBox(height: 16),
            const Text('IMAGE BLUR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
            Slider(value: _bgBlur, min: 0.0, max: 20.0, activeColor: _progressBarColor, onChanged: (v) => setState(() => _bgBlur = v)),
            const Text('OVERLAY INTENSITY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
            Slider(value: _bgBrightness, min: 0.1, max: 1.0, activeColor: _progressBarColor, onChanged: (v) => setState(() => _bgBrightness = v)),
          ],
        );
      default:
        return const SizedBox();
    }
  }

  Widget _buildFontsTab() {
    final elements = ['Date', 'Quote', 'Days'];
    
    FontInfo? currentFont;
    Function(FontInfo) setter;

    if (_selectedFontElementIndex == 0) {
      currentFont = _dateFont;
      setter = (f) => setState(() => _dateFont = f);
    } else if (_selectedFontElementIndex == 1) {
      currentFont = _quoteFont;
      setter = (f) => setState(() => _quoteFont = f);
    } else {
      currentFont = _daysFont;
      setter = (f) => setState(() => _daysFont = f);
    }

    return Column(
      children: [
        const SizedBox(height: 10),
        const Text('FONTS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 20),
        
        // Font selector row
        HorizontalFontSelector(
          selectedFont: currentFont,
          onFontSelected: setter,
        ),
        
        const Spacer(),
        
        // Element tabs
        _buildSegmentedControl(
          items: elements,
          selectedIndex: _selectedFontElementIndex,
          onChanged: (index) => setState(() => _selectedFontElementIndex = index),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildColorsTab() {
    final elements = ['Date', 'Quote', 'Days', 'Progress', 'Background'];
    
    Color currentColor;
    Function(Color) setter;
    List<Color>? customPalette;

    if (_selectedColorElementIndex == 0) {
      currentColor = _dateColor;
      setter = (c) => setState(() => _dateColor = c);
    } else if (_selectedColorElementIndex == 1) {
      currentColor = _quoteColor;
      setter = (c) => setState(() => _quoteColor = c);
    } else if (_selectedColorElementIndex == 2) {
      currentColor = _daysNumberColor;
      setter = (c) => setState(() => _daysNumberColor = c);
    } else if (_selectedColorElementIndex == 3) {
      currentColor = _progressBarColor;
      setter = (c) => setState(() {
        _progressBarColor = c;
        _percentageColor = c;
      });
    } else {
      currentColor = _backgroundColor;
      setter = (c) => setState(() => _backgroundColor = c);
      customPalette = [const Color(0xFF141414), Colors.white, const Color(0xFF1A1A2E), const Color(0xFF2D3436), const Color(0xFF353B48), const Color(0xFF2F3640), const Color(0xFF00B894), const Color(0xFF0984E3)];
    }

    return Column(
      children: [
        const SizedBox(height: 10),
        const Text('COLORS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 20),
        
        _buildColorPicker(
          selectedColor: currentColor,
          onColorSelected: setter,
          colors: customPalette,
          title: elements[_selectedColorElementIndex],
        ),
        
        const SizedBox(height: 12),
        
        _buildSegmentedControl(
          items: elements,
          selectedIndex: _selectedColorElementIndex,
          onChanged: (index) => setState(() => _selectedColorElementIndex = index),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildSegmentedControl({
    required List<String> items,
    required int selectedIndex,
    required Function(int) onChanged,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: List.generate(items.length, (index) {
          final isSelected = selectedIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(index),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))] : null,
                ),
                child: Text(
                  items[index],
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.black : Colors.grey[600]),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildColorPicker({
    required Color selectedColor,
    required Function(Color) onColorSelected,
    required String title,
    List<Color>? colors,
  }) {
    final List<Color> displayColors = colors ?? [
      Colors.white, Colors.black, const Color(0xFF6C63FF), const Color(0xFFFF5F6D), 
      const Color(0xFF1CB5E0), const Color(0xFF00C9FF), const Color(0xFF92FE9D), 
      const Color(0xFFFF9A8B), const Color(0xFFFDCB6E), const Color(0xFFE84393),
      const Color(0xFFEB4D4B), const Color(0xFF6AB04C), const Color(0xFFF0932B),
    ];

    return SizedBox(
      height: 32,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: displayColors.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  Color previewColor = selectedColor;
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('$title Color', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      content: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AdvancedColorPicker(
                              initialColor: selectedColor,
                              onColorChanged: (color) => previewColor = color,
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  onColorSelected(previewColor);
                                  Navigator.pop(context);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6C63FF),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('SELECT COLOR', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.red, Colors.blue, Colors.green, Colors.yellow],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.colorize, color: Colors.white, size: 16),
                ),
              ),
            );
          }
          final color = displayColors[index - 1];
          final isSelected = selectedColor.value == color.value;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onColorSelected(color),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.black87 : Colors.grey.withOpacity(0.2),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 4, spreadRadius: 1)] : null,
                ),
                child: isSelected 
                  ? Icon(Icons.check, color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white, size: 14) 
                  : null,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildToggleRow(String label, bool value, Function(bool) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        Switch(value: value, activeColor: _progressBarColor, onChanged: onChanged),
      ],
    );
  }

  Widget _buildModeToggle({
    required bool isActive,
    required String label,
    required IconData icon,
    required VoidCallback onSelect,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onSelect,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isActive ? _progressBarColor.withOpacity(0.08) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isActive ? _progressBarColor : Colors.grey.shade200, width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: isActive ? _progressBarColor : Colors.grey[600]),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isActive ? _progressBarColor : Colors.black87)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _backgroundImage = File(picked.path));
    }
  }
}
