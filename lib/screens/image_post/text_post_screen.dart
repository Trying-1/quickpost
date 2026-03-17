import 'package:flutter/material.dart';
import 'dart:io';
import 'package:open_file/open_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';

import '../../utils/font_selector.dart';
import '../../utils/image_generator.dart';
import '../../services/app_review_service.dart';

class TextPostScreen extends StatefulWidget {
  const TextPostScreen({super.key});

  @override
  State<TextPostScreen> createState() => _TextPostScreenState();
}

class _TextPostScreenState extends State<TextPostScreen> {
  final TextEditingController _textController = TextEditingController();
  final GlobalKey _previewKey = GlobalKey();

  FontInfo? _selectedFont;
  Color _textColor = Colors.black87;
  Color _backgroundColor = Colors.white;
  bool _enableTextShadow = false;
  bool _enableTextGlow = false;
  Color _shadowColor = Colors.black;
  Color _glowColor = Colors.white;
  double _glowRadius = 10.0;
  double _shadowOffsetX = 2.0;
  double _shadowOffsetY = 2.0;
  double _shadowBlurRadius = 4.0;
  double _letterSpacing = 0.0;
  double _fontSize = 1.0; // relative multiplier
  double _lineHeight = 1.2; // Text height multiplier

  int _selectedTabIndex = 0; // 0: Text, 1: Font, 2: Colors, 3: Effects, 4: Spacing, 5: Align, 6: Position
  bool _isTabContentExpanded = false;
  bool _isBulkMode = false;
  List<String> _bulkTexts = [];
  int _currentBulkIndex = 0;

  TextAlign _textAlign = TextAlign.center;
  Alignment _textPosition = Alignment.center;

  // 0: 1:1, 1: 4:5, 2: 9:16, 3: 16:9
  int _selectedAspectIndex = 0;

  double get _currentAspectRatio {
    switch (_selectedAspectIndex) {
      case 1:
        return 4 / 5;
      case 2:
        return 9 / 16;
      case 3:
        return 16 / 9;
      case 0:
      default:
        return 1.0;
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedFont = FontInfo(family: 'Metrophobic', displayName: 'Metrophobic');
    _textController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 40,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        titleSpacing: 0,
        title: const Text(
          'Simple Text Post',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ),
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildPreviewArea()),
            _buildControlsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildAspectRatioSelector() {
    const options = [
      {'label': '1:1', 'index': 0},
      {'label': '4:5', 'index': 1},
      {'label': '9:16', 'index': 2},
      {'label': '16:9', 'index': 3},
    ];

    return Row(
      children: [
        const Text(
          'Size',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: options.map((opt) {
                final idx = opt['index'] as int;
                final isSelected = _selectedAspectIndex == idx;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedAspectIndex = idx;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.black87 : Colors.grey[100],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected ? Colors.black87 : Colors.grey[300]!,
                        ),
                      ),
                      child: Text(
                        opt['label'] as String,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isSelected ? Colors.white : Colors.grey[800],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPositionSection() {
    const presets = [
      {'label': 'Center', 'alignment': Alignment.center},
      {'label': 'Top', 'alignment': Alignment.topCenter},
      {'label': 'Bottom', 'alignment': Alignment.bottomCenter},
      {'label': 'Left', 'alignment': Alignment.centerLeft},
      {'label': 'Right', 'alignment': Alignment.centerRight},
    ];

    Widget buildPresetChips() {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: presets.map((preset) {
            final Alignment target = preset['alignment'] as Alignment;
            final bool isSelected = _textPosition == target;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _textPosition = target;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.brown.withOpacity(0.12) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? Colors.brown : Colors.grey[300]!,
                    ),
                  ),
                  child: Text(
                    preset['label'] as String,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? Colors.brown : Colors.grey[800],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      );
    }

    Widget buildArrowPad() {
      const double step = 0.1;

      void nudge(double dx, double dy) {
        setState(() {
          final double newX = (_textPosition.x + dx).clamp(-1.0, 1.0);
          final double newY = (_textPosition.y + dy).clamp(-1.0, 1.0);
          _textPosition = Alignment(newX, newY);
        });
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            onPressed: () => nudge(0, -step),
            icon: const Icon(Icons.keyboard_arrow_up),
            iconSize: 22,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () => nudge(-step, 0),
                icon: const Icon(Icons.keyboard_arrow_left),
                iconSize: 22,
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _textPosition = Alignment.center;
                  });
                },
                icon: const Icon(Icons.adjust),
                iconSize: 20,
              ),
              IconButton(
                onPressed: () => nudge(step, 0),
                icon: const Icon(Icons.keyboard_arrow_right),
                iconSize: 22,
              ),
            ],
          ),
          IconButton(
            onPressed: () => nudge(0, step),
            icon: const Icon(Icons.keyboard_arrow_down),
            iconSize: 22,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Position',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        buildPresetChips(),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Fine tune',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            buildArrowPad(),
          ],
        ),
      ],
    );
  }

  Widget _buildAlignmentSection() {
    final options = [
      {
        'icon': Icons.format_align_left,
        'align': TextAlign.left,
        'label': 'Left',
      },
      {
        'icon': Icons.format_align_center,
        'align': TextAlign.center,
        'label': 'Center',
      },
      {
        'icon': Icons.format_align_right,
        'align': TextAlign.right,
        'label': 'Right',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Alignment',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: options.map((opt) {
            final TextAlign align = opt['align'] as TextAlign;
            final bool isSelected = _textAlign == align;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _textAlign = align;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blueGrey.withOpacity(0.12) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? Colors.blueGrey : Colors.grey[300]!,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          opt['icon'] as IconData,
                          size: 16,
                          color: isSelected ? Colors.blueGrey : Colors.grey[700],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          opt['label'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isSelected ? Colors.blueGrey : Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPreviewSection() {
    String previewText = '';
    if (_isBulkMode && _bulkTexts.isNotEmpty) {
      previewText = _bulkTexts[_currentBulkIndex];
    } else {
      previewText = _textController.text.isEmpty ? 'Your text here' : _textController.text;
    }

    return Column(
      children: [
        if (_isBulkMode && _bulkTexts.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: _currentBulkIndex > 0
                      ? () => setState(() => _currentBulkIndex--)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  'Post ${_currentBulkIndex + 1} of ${_bulkTexts.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: _currentBulkIndex < _bulkTexts.length - 1
                      ? () => setState(() => _currentBulkIndex++)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
        AspectRatio(
          aspectRatio: _currentAspectRatio,
          child: RepaintBoundary(
            key: _previewKey,
            child: Container(
              decoration: BoxDecoration(
                color: _backgroundColor,
              ),
              child: Stack(
                children: [
                  Align(
                    alignment: _textPosition,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          previewText,
                          textAlign: _textAlign,
                          style: TextStyle(
                            fontFamily: _selectedFont?.family,
                            fontWeight: _selectedFont?.weight ?? FontWeight.w400,
                            fontStyle: _selectedFont?.style ?? FontStyle.normal,
                            color: _textColor,
                            fontSize: 32 * _fontSize,
                            height: _lineHeight,
                            letterSpacing: _letterSpacing,
                            shadows: [
                              if (_enableTextShadow)
                                Shadow(
                                  color: _shadowColor.withOpacity(0.7),
                                  offset: Offset(_shadowOffsetX, _shadowOffsetY),
                                  blurRadius: _shadowBlurRadius,
                                ),
                              if (_enableTextGlow)
                                Shadow(
                                  color: _glowColor.withOpacity(0.9),
                                  offset: Offset.zero,
                                  blurRadius: _glowRadius,
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
      ],
    );
  }

  Widget _buildPreviewArea() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: _buildAspectRatioSelector(),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: _buildPreviewSection(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildControlsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isTabContentExpanded)
            Container(
              height: 180,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: SingleChildScrollView(
                child: _buildActiveTabContent(),
              ),
            ),
          _buildControlTabs(),
        ],
      ),
    );
  }

  Widget _buildActiveTabContent() {
    if (_selectedTabIndex == 0) return _buildTextSection();
    if (_selectedTabIndex == 1) return _buildFontSection();
    if (_selectedTabIndex == 2) return _buildColorsSection();
    if (_selectedTabIndex == 3) return _buildEffectsSection();
    if (_selectedTabIndex == 4) return _buildSpacingSection();
    if (_selectedTabIndex == 5) return _buildAlignmentSection();
    return _buildPositionSection();
  }

  Widget _buildControlTabs() {
    final tabs = [
      {'icon': Icons.text_fields, 'label': 'Text', 'color': Colors.teal},
      {'icon': Icons.font_download_outlined, 'label': 'Font', 'color': Colors.green},
      {'icon': Icons.format_color_text, 'label': 'Colors', 'color': Colors.deepOrange},
      {'icon': Icons.auto_awesome, 'label': 'Effects', 'color': Colors.purple},
      {'icon': Icons.format_size, 'label': 'Spacing', 'color': Colors.indigo},
      {'icon': Icons.format_align_center, 'label': 'Align', 'color': Colors.blueGrey},
      {'icon': Icons.open_with, 'label': 'Position', 'color': Colors.brown},
    ];

    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 4),
            child: ElevatedButton(
              onPressed: _savePost,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black87,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: const Icon(Icons.download, size: 20),
            ),
          ),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: tabs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 4),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemBuilder: (context, index) {
                final isSelected = _selectedTabIndex == index;
                final tab = tabs[index];
                final Color baseColor = tab['color'] as Color;
                return GestureDetector(
                  onTap: () {
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
                    width: 70,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected && _isTabContentExpanded
                          ? baseColor.withOpacity(0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          tab['icon'] as IconData,
                          size: 22,
                          color: isSelected && _isTabContentExpanded ? baseColor : Colors.grey[600],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tab['label'] as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSelected && _isTabContentExpanded
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected && _isTabContentExpanded ? baseColor : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Text Content',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54),
            ),
            Row(
              children: [
                const Text('Bulk', style: TextStyle(fontSize: 12)),
                Switch(
                  value: _isBulkMode,
                  onChanged: (val) {
                    setState(() {
                      _isBulkMode = val;
                      if (!val) {
                        _bulkTexts.clear();
                        _currentBulkIndex = 0;
                      }
                    });
                  },
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (!_isBulkMode)
          TextField(
            controller: _textController,
            maxLines: 3,
            style: const TextStyle(fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'Enter your text...',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(10),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          )
        else ...[
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _importCsv,
                  icon: const Icon(Icons.file_present, size: 18),
                  label: const Text('Import CSV', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _pasteBulkText,
                  icon: const Icon(Icons.paste, size: 18),
                  label: const Text('Paste Text', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8)),
                ),
              ),
            ],
          ),
          if (_bulkTexts.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_bulkTexts.length} items loaded',
                  style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _bulkTexts.clear();
                    _currentBulkIndex = 0;
                  }),
                  child: const Text('Clear All', style: TextStyle(color: Colors.red, fontSize: 11)),
                ),
              ],
            ),
          ],
        ],
      ],
    );
  }

  Future<void> _importCsv() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
      );

      if (result != null) {
        final file = File(result.files.single.path!);
        final input = await file.readAsString();
        List<List<dynamic>> rows = const CsvToListConverter().convert(input);

        List<String> loadedTexts = [];
        for (var row in rows) {
          if (row.isNotEmpty) {
            loadedTexts.add(row.first.toString());
          }
        }

        if (loadedTexts.isNotEmpty) {
          setState(() {
            _bulkTexts = loadedTexts;
            _currentBulkIndex = 0;
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error importing file: $e')),
      );
    }
  }

  void _pasteBulkText() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Paste Multiple Lines'),
        content: TextField(
          controller: controller,
          maxLines: 10,
          decoration: const InputDecoration(
            hintText: 'Paste your lines here. Each line will become a separate post.',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final lines = controller.text.split('\n').where((l) => l.trim().isNotEmpty).toList();
              if (lines.isNotEmpty) {
                setState(() {
                  _bulkTexts = lines;
                  _currentBulkIndex = 0;
                });
              }
              Navigator.pop(context);
            },
            child: const Text('Load'),
          ),
        ],
      ),
    );
  }

  Widget _buildFontSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Font',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: getAllFonts().length,
            itemBuilder: (context, index) {
              final font = getAllFonts()[index];
              final isSelected = _selectedFont == font;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  selected: isSelected,
                  label: Text(
                    font.displayName,
                    style: TextStyle(
                      fontFamily: font.family,
                      fontWeight: font.weight ?? FontWeight.w400,
                      fontStyle: font.style ?? FontStyle.normal,
                      fontSize: 12,
                    ),
                  ),
                  selectedColor: Colors.green[100],
                  backgroundColor: Colors.grey[100],
                  onSelected: (_) {
                    setState(() {
                      _selectedFont = font;
                    });
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildColorsSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.palette_outlined, color: Colors.deepOrange[600], size: 22),
              const SizedBox(width: 8),
              const Text(
                'Colors',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('Text Color:', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => _showColorPicker('text'),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _textColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('Background:', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => _showColorPicker('background'),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _backgroundColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEffectsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title: const Text('Text Shadow', style: TextStyle(fontWeight: FontWeight.w500)),
          value: _enableTextShadow,
          onChanged: (value) {
            setState(() {
              _enableTextShadow = value;
            });
          },
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        if (_enableTextShadow) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Text('Shadow Color:', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => _showColorPicker('shadow'),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _shadowColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('X Offset', style: TextStyle(fontWeight: FontWeight.w500)),
              Expanded(
                child: Slider(
                  value: _shadowOffsetX,
                  min: -20,
                  max: 20,
                  onChanged: (v) => setState(() => _shadowOffsetX = v),
                ),
              ),
              Text(_shadowOffsetX.toStringAsFixed(1), style: const TextStyle(fontSize: 11)),
            ],
          ),
          Row(
            children: [
              const Text('Y Offset', style: TextStyle(fontWeight: FontWeight.w500)),
              Expanded(
                child: Slider(
                  value: _shadowOffsetY,
                  min: -20,
                  max: 20,
                  onChanged: (v) => setState(() => _shadowOffsetY = v),
                ),
              ),
              Text(_shadowOffsetY.toStringAsFixed(1), style: const TextStyle(fontSize: 11)),
            ],
          ),
          Row(
            children: [
              const Text('Blur', style: TextStyle(fontWeight: FontWeight.w500)),
              Expanded(
                child: Slider(
                  value: _shadowBlurRadius,
                  min: 0,
                  max: 20,
                  onChanged: (v) => setState(() => _shadowBlurRadius = v),
                ),
              ),
              Text(_shadowBlurRadius.toStringAsFixed(1), style: const TextStyle(fontSize: 11)),
            ],
          ),
          const SizedBox(height: 10),
        ],
        SwitchListTile(
          title: const Text('Text Glow', style: TextStyle(fontWeight: FontWeight.w500)),
          value: _enableTextGlow,
          onChanged: (value) {
            setState(() {
              _enableTextGlow = value;
            });
          },
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        if (_enableTextGlow) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Text('Glow Color:', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => _showColorPicker('glow'),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _glowColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Glow Radius: ${_glowRadius.toInt()}',
              style: const TextStyle(fontWeight: FontWeight.w500)),
          Slider(
            value: _glowRadius,
            min: 5.0,
            max: 30.0,
            onChanged: (value) {
              setState(() {
                _glowRadius = value;
              });
            },
          ),
        ],
      ],
    );
  }

  Widget _buildSpacingSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.format_size, color: Colors.indigo[600], size: 22),
              const SizedBox(width: 8),
              const Text(
                'Spacing & Size',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Letter Spacing: ${_letterSpacing.toStringAsFixed(1)}',
              style: const TextStyle(fontWeight: FontWeight.w500)),
          Slider(
            value: _letterSpacing,
            min: -2.0,
            max: 10.0,
            onChanged: (value) {
              setState(() {
                _letterSpacing = value;
              });
            },
          ),
          const SizedBox(height: 8),
          Text('Line Height: ${_lineHeight.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w500)),
          Slider(
            value: _lineHeight,
            min: 0.8,
            max: 2.0,
            onChanged: (value) {
              setState(() {
                _lineHeight = value;
              });
            },
          ),
          const SizedBox(height: 8),
          Text('Font Size: ${(_fontSize * 100).toInt()}%',
              style: const TextStyle(fontWeight: FontWeight.w500)),
          Slider(
            value: _fontSize,
            min: 0.5,
            max: 2.0,
            onChanged: (value) {
              setState(() {
                _fontSize = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    final bool hasContent =
        (_isBulkMode && _bulkTexts.isNotEmpty) || (!_isBulkMode && _textController.text.trim().isNotEmpty);
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: hasContent ? (_isBulkMode ? _processBulkPosts : _savePost) : null,
        icon: const Icon(Icons.save),
        label: Text(_isBulkMode ? 'Generate ${_bulkTexts.length} Posts' : 'Save Post'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Future<void> _processBulkPosts() async {
    if (_bulkTexts.isEmpty) return;

    int completed = 0;
    int failed = 0;
    List<String> savedPaths = [];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Bulk Processing'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(value: completed / _bulkTexts.length),
              const SizedBox(height: 16),
              Text('Generating post ${completed + 1} of ${_bulkTexts.length}...'),
              if (failed > 0) Text('$failed failed', style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],
          ),
        ),
      ),
    );

    try {
      final double aspect = _currentAspectRatio;
      const int baseWidth = 1080;
      final int exportWidth;
      final int exportHeight;

      if (aspect >= 1.0) {
        exportWidth = baseWidth;
        exportHeight = (baseWidth / aspect).round();
      } else {
        exportHeight = baseWidth;
        exportWidth = (baseWidth * aspect).round();
      }

      for (int i = 0; i < _bulkTexts.length; i++) {
        // Update local state for preview (optional but helps visually)
        setState(() {
          _currentBulkIndex = i;
        });

        try {
          // We must wait for the frame to render the new text before capturing
          await Future.delayed(const Duration(milliseconds: 100));

          final String? savedPath = await ImageGenerator.savePostToGallery(
            text: _bulkTexts[i],
            imageFile: null,
            transform: null,
            selectedFont: _selectedFont,
            templateKey: _previewKey,
            outputWidth: exportWidth,
            outputHeight: exportHeight,
          );

          if (savedPath != null) {
            savedPaths.add(savedPath);
            completed++;
          } else {
            failed++;
          }
        } catch (e) {
          debugPrint('Bulk item $i failed: $e');
          failed++;
        }

        // Force dialog update
        if (mounted) {
          (context as Element).markNeedsBuild();
        }
      }

      Navigator.pop(context); // Close progress dialog

      _showBulkCompletionDialog(savedPaths, failed);
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bulk error: $e')));
    }
  }

  void _showBulkCompletionDialog(List<String> paths, int failed) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bulk Processing Done'),
        content: Text('Successfully generated ${paths.length} posts.\n' + (failed > 0 ? '$failed failed.' : '')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          if (paths.isNotEmpty)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                OpenFile.open(paths.last);
              },
              child: const Text('Open Last'),
            ),
        ],
      ),
    );
  }

  Future<void> _savePost() async {
    final bool hasText = _textController.text.trim().isNotEmpty;
    if (!hasText) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Dialog(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Saving, please wait...'),
              ],
            ),
          ),
        );
      },
    );

    try {
      // Choose an export size that matches the selected aspect ratio.
      // Use 1080px as the base width and derive height from aspect.
      const int baseWidth = 1080;
      final double aspect = _currentAspectRatio;
      final int exportWidth;
      final int exportHeight;

      if (aspect >= 1.0) {
        // Wider than tall (e.g., 16:9) or square: fix width, compute height
        exportWidth = baseWidth;
        exportHeight = (baseWidth / aspect).round();
      } else {
        exportHeight = baseWidth;
        exportWidth = (baseWidth * aspect).round();
      }

      final String? savedPath = await ImageGenerator.savePostToGallery(
        text: _textController.text,
        imageFile: null,
        transform: null,
        selectedFont: _selectedFont,
        templateKey: _previewKey,
        outputWidth: exportWidth,
        outputHeight: exportHeight,
      );

      if (!mounted) return;
      Navigator.of(context).pop();

      AppReviewService().incrementExportCount();
      AppReviewService().checkAndRequestReview();

      if (savedPath != null) {
        // Compute simple export details
        int fileSizeKb = 0;
        try {
          final file = File(savedPath);
          if (await file.exists()) {
            fileSizeKb = (await file.length() / 1024).round();
          }
        } catch (_) {}

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.green[50]!, Colors.green[100]!],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green[600],
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Success!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your post has been saved successfully',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.folder, color: Colors.green[700], size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                savedPath,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black87,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow('Resolution', '${exportWidth}x${exportHeight}px'),
                        if (fileSizeKb > 0)
                          _buildDetailRow('File size', '${fileSizeKb} KB'),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text('Close'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey[700],
                              side: BorderSide(color: Colors.grey[300]!),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              Navigator.of(context).pop();
                              try {
                                final file = File(savedPath);
                                if (await file.exists()) {
                                  await OpenFile.open(savedPath);
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Could not open file')),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.photo_library, size: 18),
                            label: const Text('Open'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[600],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      } else {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: const [
                  Icon(Icons.error, color: Colors.red, size: 28),
                  SizedBox(width: 12),
                  Text('Error'),
                ],
              ),
              content: const Text('Failed to save post. Please try again.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: const [
                Icon(Icons.error, color: Colors.red, size: 28),
                SizedBox(width: 12),
                Text('Error'),
              ],
            ),
            content: Text('Error: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }

  void _showColorPicker(String type) {
    Color currentColor;
    String title;

    switch (type) {
      case 'text':
        currentColor = _textColor;
        title = 'Text Color';
        break;
      case 'background':
        currentColor = _backgroundColor;
        title = 'Background Color';
        break;
      case 'shadow':
        currentColor = _shadowColor;
        title = 'Shadow Color';
        break;
      case 'glow':
        currentColor = _glowColor;
        title = 'Glow Color';
        break;
      default:
        currentColor = Colors.white;
        title = 'Color';
    }

    showDialog(
      context: context,
      builder: (context) {
        Color tempColor = currentColor;
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Colors.black,
                Colors.white,
                Colors.red,
                Colors.green,
                Colors.blue,
                Colors.orange,
                Colors.purple,
                Colors.pink,
                Colors.teal,
                Colors.brown,
                Colors.grey,
                Colors.yellow[700]!,
              ].map((color) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      tempColor = color;
                    });
                  },
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: tempColor == color ? Colors.black : Colors.white,
                        width: 2,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  switch (type) {
                    case 'text':
                      _textColor = tempColor;
                      break;
                    case 'background':
                      _backgroundColor = tempColor;
                      break;
                    case 'shadow':
                      _shadowColor = tempColor;
                      break;
                    case 'glow':
                      _glowColor = tempColor;
                      break;
                  }
                });
                Navigator.of(context).pop();
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 2),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2E7D32),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[800],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
