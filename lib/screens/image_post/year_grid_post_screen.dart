import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../utils/font_selector.dart';
import '../../utils/image_generator.dart';

class YearGridPostScreen extends StatefulWidget {
  const YearGridPostScreen({super.key});

  @override
  State<YearGridPostScreen> createState() => _YearGridPostScreenState();
}

class _YearGridPostScreenState extends State<YearGridPostScreen> {
  final TextEditingController _quoteController = TextEditingController();
  final GlobalKey _previewKey = GlobalKey();

  // Fonts
  FontInfo? _quoteFont;
  FontInfo? _headerFont;

  // Colors
  Color _backgroundColor = const Color(0xFF141414);
  Color _passedBoxColor = const Color(0xFF6C63FF);
  Color _futureBoxColor = Colors.white.withOpacity(0.1);
  Color _quoteColor = Colors.white;
  Color _headerColor = Colors.white.withOpacity(0.8);

  File? _backgroundImage;

  // Customization states
  double _fontSize = 24.0;
  bool _showShadow = true;
  double _bgBlur = 0.0;
  double _bgBrightness = 0.5;

  // Separate offsets
  Offset _gridOffset = Offset.zero;
  Offset _quoteOffset = Offset(13, 320);
  Offset _headerOffset = Offset(30, -320);

  int _selectedTabIndex = 0; // 0 Visuals, 1 Text, 2 Effects, 3 Colors, 4 Fonts
  int _selectedColorElementIndex = 0; // 0 Passed, 1 Future, 2 Quote, 3 Header, 4 BG
  int _selectedFontElementIndex = 0; // 0 Quote, 1 Header
  bool _isExpanded = true;

  @override
  void initState() {
    super.initState();
    final defaultFont = FontInfo(family: 'Metrophobic', displayName: 'Metrophobic');
    _quoteFont = defaultFont;
    _headerFont = defaultFont;
    _quoteController.text = "Each day is a new box to fulfill your dreams.";
  }

  int get _daysInYear {
    final year = DateTime.now().year;
    return (DateTime(year, 12, 31).difference(DateTime(year, 1, 1)).inDays) + 1;
  }

  int get _daysPassed {
    final now = DateTime.now();
    return now.difference(DateTime(now.year, 1, 1)).inDays;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text('Year Grid Maker', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Saved to gallery!'),
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
                backgroundColor: _passedBoxColor,
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

  Widget _buildPreview() {
    final totalDays = _daysInYear;
    final passedDays = _daysPassed;
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
              alignment: Alignment.center,
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
                if (_backgroundImage != null && _bgBlur > 0)
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: _bgBlur, sigmaY: _bgBlur),
                      child: Container(color: Colors.transparent),
                    ),
                  ),

                // 1. Draggable Header
                Positioned(
                  top: 60 + _headerOffset.dy,
                  left: 40 + _headerOffset.dx,
                  child: GestureDetector(
                    onPanUpdate: (d) => setState(() => _headerOffset += d.delta),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      color: Colors.transparent,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'WEEK ${((passedDays/7)+1).toInt()} OF 52  •  $passedDays / $totalDays',
                            style: TextStyle(
                              color: _headerColor.withOpacity(0.6),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2.0,
                              fontFamily: _headerFont?.family,
                            ),
                          ),
                          Text(
                            DateFormat('MMMM dd, yyyy').format(now).toUpperCase(),
                            style: TextStyle(
                              color: _headerColor,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              fontFamily: _headerFont?.family,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 2. Static Year Grid (365/366 boxes)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    width: 320,
                    color: Colors.transparent,
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      alignment: WrapAlignment.center,
                      children: List.generate(totalDays, (index) {
                        final isPassed = index < passedDays;
                        return Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: isPassed ? _passedBoxColor : _futureBoxColor,
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: isPassed ? [
                              BoxShadow(
                                color: _passedBoxColor.withOpacity(0.3),
                                blurRadius: 2,
                                spreadRadius: 1,
                              )
                            ] : null,
                          ),
                        );
                      }),
                    ),
                  ),
                ),

                // 3. Draggable Quote
                Positioned(
                  bottom: 60 + _quoteOffset.dy,
                  left: 40 + _quoteOffset.dx,
                  child: GestureDetector(
                    onPanUpdate: (d) => setState(() => _quoteOffset += d.delta),
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

  Widget _buildTabButton(int index, IconData icon, String label) {
    final isSelected = _selectedTabIndex == index && _isExpanded;
    final themeColor = _passedBoxColor;
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
                _buildModeToggle(isActive: _backgroundColor == const Color(0xFF141414), label: 'Dark Mode', icon: Icons.dark_mode_rounded, onSelect: () => setState(() { _backgroundColor = const Color(0xFF141414); _quoteColor = Colors.white; _headerColor = Colors.white.withOpacity(0.8); _futureBoxColor = Colors.white.withOpacity(0.1); })),
                const SizedBox(width: 12),
                _buildModeToggle(isActive: _backgroundColor == Colors.white, label: 'Light Mode', icon: Icons.light_mode_rounded, onSelect: () => setState(() { _backgroundColor = Colors.white; _quoteColor = Colors.black; _headerColor = Colors.black.withOpacity(0.8); _futureBoxColor = Colors.black.withOpacity(0.1); })),
              ],
            ),
            const SizedBox(height: 16),
            const Text('BACKGROUND IMAGE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 10),
            _buildBgImageAction(),
          ],
        );
      case 1: // Text
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
                hintText: 'Enter your quote...',
                prefixIcon: Icon(Icons.format_quote_rounded, color: _passedBoxColor),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: _passedBoxColor, width: 2), borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            const Text('FONT SIZE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
            Slider(value: _fontSize, min: 12, max: 48, activeColor: _passedBoxColor, onChanged: (v) => setState(() => _fontSize = v)),
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
            const SizedBox(height: 16),
            const Text('IMAGE BLUR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
            Slider(value: _bgBlur, min: 0, max: 20, activeColor: _passedBoxColor, onChanged: (v) => setState(() => _bgBlur = v)),
            const Text('OVERLAY INTENSITY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
            Slider(value: _bgBrightness, min: 0.1, max: 1, activeColor: _passedBoxColor, onChanged: (v) => setState(() => _bgBrightness = v)),
          ],
        );
      default:
        return const SizedBox();
    }
  }

  Widget _buildFontsTab() {
    final elements = ['Quote', 'Header'];
    FontInfo? currentFont = _selectedFontElementIndex == 0 ? _quoteFont : _headerFont;
    Function(FontInfo) setter = (f) => setState(() {
      if (_selectedFontElementIndex == 0) _quoteFont = f;
      else _headerFont = f;
    });

    return Column(
      children: [
        const SizedBox(height: 10),
        const Text('FONTS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 20),
        HorizontalFontSelector(selectedFont: currentFont, onFontSelected: setter),
        const Spacer(),
        _buildSegmentedControl(items: elements, selectedIndex: _selectedFontElementIndex, onChanged: (i) => setState(() => _selectedFontElementIndex = i)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildColorsTab() {
    final elements = ['Passed', 'Future', 'Quote', 'Header', 'BG'];
    Color currentColor;
    Function(Color) setter;
    switch (_selectedColorElementIndex) {
      case 0: currentColor = _passedBoxColor; setter = (c) => setState(() => _passedBoxColor = c); break;
      case 1: currentColor = _futureBoxColor; setter = (c) => setState(() => _futureBoxColor = c); break;
      case 2: currentColor = _quoteColor; setter = (c) => setState(() => _quoteColor = c); break;
      case 3: currentColor = _headerColor; setter = (c) => setState(() => _headerColor = c); break;
      case 4: currentColor = _backgroundColor; setter = (c) => setState(() => _backgroundColor = c); break;
      default: currentColor = Colors.white; setter = (c) {};
    }

    return Column(
      children: [
        const SizedBox(height: 10),
        const Text('COLORS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 20),
        _buildColorPicker(selectedColor: currentColor, onColorSelected: setter),
        const Spacer(),
        _buildSegmentedControl(items: elements, selectedIndex: _selectedColorElementIndex, onChanged: (i) => setState(() => _selectedColorElementIndex = i)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildSegmentedControl({required List<String> items, required int selectedIndex, required Function(int) onChanged}) {
    return Container(
      height: 48,
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
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
                child: Text(items[index], style: TextStyle(fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isSelected ? Colors.black : Colors.grey[600])),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildColorPicker({required Color selectedColor, required Function(Color) onColorSelected}) {
    final List<Color> displayColors = [
      Colors.white, Colors.black, const Color(0xFF6C63FF), const Color(0xFFFF5F6D), 
      const Color(0xFF1CB5E0), const Color(0xFF00C9FF), const Color(0xFF92FE9D), 
      const Color(0xFFFF9A8B), const Color(0xFFFDCB6E), const Color(0xFFE84393),
      const Color(0xFFEB4D4B), const Color(0xFF6AB04C), const Color(0xFFF0932B),
    ];
    return SizedBox(
      height: 30,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: displayColors.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final color = displayColors[index];
          final isSelected = selectedColor.value == color.value;
          return GestureDetector(
            onTap: () => onColorSelected(color),
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: isSelected ? Colors.black87 : Colors.grey.withOpacity(0.2), width: isSelected ? 2 : 1),
              ),
              child: isSelected ? Icon(Icons.check, color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white, size: 14) : null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildBgImageAction() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.add_photo_alternate_rounded, size: 18),
            label: const Text('Change Background', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.black87, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ),
        if (_backgroundImage != null) ...[
          const SizedBox(width: 8),
          IconButton(onPressed: () => setState(() => _backgroundImage = null), icon: const Icon(Icons.close_rounded, color: Colors.redAccent)),
        ],
      ],
    );
  }

  Widget _buildToggleRow(String label, bool value, Function(bool) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        Switch(value: value, activeColor: _passedBoxColor, onChanged: onChanged),
      ],
    );
  }

  Widget _buildModeToggle({required bool isActive, required String label, required IconData icon, required VoidCallback onSelect}) {
    return Expanded(
      child: GestureDetector(
        onTap: onSelect,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isActive ? _passedBoxColor.withOpacity(0.08) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isActive ? _passedBoxColor : Colors.grey.shade200, width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: isActive ? _passedBoxColor : Colors.grey[600]),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isActive ? _passedBoxColor : Colors.black87)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _backgroundImage = File(picked.path));
  }
}
