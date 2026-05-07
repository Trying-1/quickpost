import 'package:flutter/material.dart';
import 'dart:io';
import 'package:open_file/open_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';

import '../../utils/font_selector.dart';
import '../../utils/image_generator.dart';
import '../../services/app_review_service.dart';
import '../../widgets/advanced_color_picker.dart';
import '../../services/analytics_service.dart';
import '../../services/ad_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import '../quotes/my_quotes_screen.dart';
import '../../models/quote_item.dart';

class _OverlayPatch {
  double x; // Normalized
  double y; // Normalized
  double width; // Normalized
  double height; // Normalized
  Color color;
  double opacity;
  double radius;
  bool isTop;

  _OverlayPatch({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.color = Colors.black,
    this.opacity = 0.5,
    this.radius = 8.0,
    this.isTop = false,
  });
}

class _OverlayImage {
  String path;
  double x; // Normalized
  double y; // Normalized
  double scale;
  double opacity;
  double rotation;

  _OverlayImage({
    required this.path,
    this.x = 0.5,
    this.y = 0.5,
    this.scale = 0.2,
    this.opacity = 1.0,
    this.rotation = 0.0,
  });
}

class _TextOverlay {
  String text;
  double x;
  double y;
  double fontSize;
  Color color;
  FontInfo? font;
  bool showShadow;
  Color shadowColor;
  double shadowBlur;
  double shadowOffsetX;
  double shadowOffsetY;
  TextAlign textAlign;
  double scale;

  _TextOverlay({
    required this.text,
    this.x = 0.5,
    this.y = 0.5,
    this.fontSize = 24.0,
    this.color = Colors.black,
    this.font,
    this.showShadow = false,
    this.shadowColor = Colors.black,
    this.shadowBlur = 4.0,
    this.shadowOffsetX = 2.0,
    this.shadowOffsetY = 2.0,
    this.textAlign = TextAlign.center,
    this.scale = 1.0,
  });
}

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
  double _textScale = 1.0; // Overall scale multiplier

  // Background Image & Adjustments
  File? _bgImage;
  double _brightness = 1.0; // 0.0 to 2.0 (multiplicative/gain)
  double _saturation = 1.0; // 0.0 to 2.0
  double _hue = 0.0;        // -3.14 to 3.14
  final TransformationController _transformationController = TransformationController();

  // Mask Settings
  Color _maskColor = Colors.black;
  double _maskOpacity = 0.5;
  int _maskType = 0; // 0: None, 1: Bottom, 2: Top, 3: Full, 4: Left, 5: Right
  double _maskStart = 0.0;
  double _maskEnd = 1.0;

  int _selectedTabIndex = 0; // 0: Text, 1: Font, 2: Colors, 3: Effects, 4: Spacing, 5: Align, 6: Position, 7: Image, 8: Adjust, 9: Mask
  bool _isTabContentExpanded = false;
  bool _isBulkMode = false;
  List<String> _bulkTexts = [];
  int _currentBulkIndex = 0;

  TextAlign _textAlign = TextAlign.center;
  Alignment _textPosition = Alignment.center;

  // Overlays
  List<_OverlayPatch> _patches = [];
  int? _selectedPatchIndex;
  List<_OverlayImage> _imageOverlays = [];
  int? _selectedImageOverlayIndex;
  List<_TextOverlay> _textOverlays = [];
  int? _selectedTextOverlayIndex;

  bool _isExporting = false;

  // 0: 1:1, 1: 4:5, 2: 9:16, 3: 16:9, 4: 4:3
  int _selectedAspectIndex = 0;

  double get _currentAspectRatio {
    switch (_selectedAspectIndex) {
      case 1:
        return 4 / 5;
      case 2:
        return 9 / 16;
      case 3:
        return 16 / 9;
      case 4:
        return 4 / 3;
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
    AnalyticsService().setCurrentScreen(screenName: 'Text Post');
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

  Widget _buildCanvasSection() {
    const options = [
      {'label': '1:1', 'index': 0},
      {'label': '4:5', 'index': 1},
      {'label': '9:16', 'index': 2},
      {'label': '16:9', 'index': 3},
      {'label': '4:3', 'index': 4},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Canvas Size / Aspect Ratio', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: options.map((opt) {
              final idx = opt['index'] as int;
              final isSelected = _selectedAspectIndex == idx;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(opt['label'] as String, style: const TextStyle(fontSize: 11)),
                  selected: isSelected,
                  onSelected: (val) {
                    if (val) setState(() => _selectedAspectIndex = idx);
                  },
                ),
              );
            }).toList(),
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

  List<double> _getColorMatrix(double brightness, double saturation, double hue) {
    final double s = saturation;
    final double bGain = brightness;
    final double h = hue;

    // Saturation matrix coefficients
    const double lumR = 0.2126;
    const double lumG = 0.7152;
    const double lumB = 0.0722;

    // Hue rotation components
    final double cosH = math.cos(h);
    final double sinH = math.sin(h);

    // Hue rotation matrix elements (standard luminance-preserving)
    final double hR1 = lumR + cosH * (1 - lumR) + sinH * (-lumR);
    final double hR2 = lumG + cosH * (-lumG) + sinH * (-lumG);
    final double hR3 = lumB + cosH * (-lumB) + sinH * (1 - lumB);

    final double hG1 = lumR + cosH * (-lumR) + sinH * (0.143);
    final double hG2 = lumG + cosH * (1 - lumG) + sinH * (0.140);
    final double hG3 = lumB + cosH * (-lumB) + sinH * (-0.283);

    final double hB1 = lumR + cosH * (-lumR) + sinH * (-(1 - lumR));
    final double hB2 = lumG + cosH * (-lumG) + sinH * (lumG);
    final double hB3 = lumB + cosH * (1 - lumB) + sinH * (lumB);

    // Saturation matrix
    final double sr1 = lumR + (1 - lumR) * s;
    final double sr2 = lumG - lumG * s;
    final double sr3 = lumB - lumB * s;

    final double sg1 = lumR - lumR * s;
    final double sg2 = lumG + (1 - lumG) * s;
    final double sg3 = lumB - lumB * s;

    final double sb1 = lumR - lumR * s;
    final double sb2 = lumG - lumG * s;
    final double sb3 = lumB + (1 - lumB) * s;

    return <double>[
      (hR1 * sr1 + hR2 * sg1 + hR3 * sb1) * bGain, (hR1 * sr2 + hR2 * sg2 + hR3 * sb2) * bGain, (hR1 * sr3 + hR2 * sg3 + hR3 * sb3) * bGain, 0, 0,
      (hG1 * sr1 + hG2 * sg1 + hG3 * sb1) * bGain, (hG1 * sr2 + hG2 * sg2 + hG3 * sb2) * bGain, (hG1 * sr3 + hG2 * sg3 + hG3 * sb3) * bGain, 0, 0,
      (hB1 * sr1 + hB2 * sg1 + hB3 * sb1) * bGain, (hB1 * sr2 + hB2 * sg2 + hB3 * sb2) * bGain, (hB1 * sr3 + hB2 * sg3 + hB3 * sb3) * bGain, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }

  Widget _buildMaskOverlay() {
    Alignment begin = Alignment.topCenter;
    Alignment end = Alignment.bottomCenter;

    switch (_maskType) {
      case 1: // Bottom
        begin = Alignment.topCenter;
        end = Alignment.bottomCenter;
        break;
      case 2: // Top
        begin = Alignment.bottomCenter;
        end = Alignment.topCenter;
        break;
      case 3: // Full (No gradient, just flat color)
        return Container(color: _maskColor.withOpacity(_maskOpacity));
      case 4: // Left
        begin = Alignment.centerRight;
        end = Alignment.centerLeft;
        break;
      case 5: // Right
        begin = Alignment.centerLeft;
        end = Alignment.centerRight;
        break;
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: begin,
          end: end,
          colors: [
            _maskColor.withOpacity(0.0),
            _maskColor.withOpacity(_maskOpacity),
          ],
          stops: [_maskStart, _maskEnd],
        ),
      ),
    );
  }

  Widget _buildPreviewSection({bool isExport = false}) {
    String previewText = '';
    if (_isBulkMode && _bulkTexts.isNotEmpty) {
      previewText = _bulkTexts[_currentBulkIndex];
    } else {
      previewText = _textController.text.isEmpty ? 'Your text here' : _textController.text;
    }

    Widget content = LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onPanUpdate: (isExport || _selectedTabIndex == 7) ? null : (details) {
            setState(() {
              final RenderBox box = context.findRenderObject() as RenderBox;
              final Offset localOffset = box.globalToLocal(details.globalPosition);
              
              // Convert local coordinates to Alignment values (-1.0 to 1.0)
              double x = (localOffset.dx / constraints.maxWidth) * 2 - 1;
              double y = (localOffset.dy / constraints.maxHeight) * 2 - 1;
              
              _textPosition = Alignment(
                x.clamp(-1.0, 1.0),
                y.clamp(-1.0, 1.0),
              );
            });
          },
          child: Container(
            color: _backgroundColor,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_bgImage != null)
                  isExport
                      ? Center(
                          child: Transform(
                            transform: _transformationController.value,
                            alignment: Alignment.center,
                            child: ColorFiltered(
                              colorFilter: ui.ColorFilter.matrix(_getColorMatrix(_brightness, _saturation, _hue)),
                              child: Image.file(_bgImage!, fit: BoxFit.cover),
                            ),
                          ),
                        )
                      : InteractiveViewer(
                          transformationController: _transformationController,
                          clipBehavior: Clip.none,
                          minScale: 0.5,
                          maxScale: 5.0,
                          child: ColorFiltered(
                            colorFilter: ui.ColorFilter.matrix(_getColorMatrix(_brightness, _saturation, _hue)),
                            child: Image.file(_bgImage!, fit: BoxFit.cover),
                          ),
                        ),
                if (_maskType != 0) _buildMaskOverlay(),

                // Patches (Bottom Layer)
                ..._patches.asMap().entries.where((e) => !e.value.isTop).map((entry) {
                  return _buildPatchPreview(entry.value, entry.key, constraints);
                }).toList(),

                Align(
                  alignment: _textPosition,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Transform.scale(
                      scale: _textScale,
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
                ),

                // Patches (Top Layer)
                ..._patches.asMap().entries.where((e) => e.value.isTop).map((entry) {
                  return _buildPatchPreview(entry.value, entry.key, constraints);
                }).toList(),

                // Text Overlays
                ..._textOverlays.asMap().entries.map((entry) {
                  return _buildTextOverlayPreview(entry.value, entry.key, constraints);
                }).toList(),

                // Image Overlays
                ..._imageOverlays.asMap().entries.map((entry) {
                  return _buildImageOverlayPreview(entry.value, entry.key, constraints);
                }).toList(),
              ],
            ),
          ),
        );
      },
    );

    return AspectRatio(
      aspectRatio: _currentAspectRatio,
      child: RepaintBoundary(
        key: _previewKey,
        child: Material(
          type: MaterialType.transparency,
          child: content,
        ),
      ),
    );
  }

  Widget _buildPreviewArea() {
    return Column(
      children: [
        if (_isBulkMode && _bulkTexts.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
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
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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
    if (_selectedTabIndex == 6) return _buildPositionSection();
    if (_selectedTabIndex == 7) return _buildImageSection();
    if (_selectedTabIndex == 8) return _buildAdjustSection();
    if (_selectedTabIndex == 9) return _buildMaskSection();
    if (_selectedTabIndex == 10) return _buildOverlaysSection();
    if (_selectedTabIndex == 11) return _buildShapesSection();
    if (_selectedTabIndex == 12) return _buildTextOverlaysSection();
    return _buildCanvasSection();
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
      {'icon': Icons.image, 'label': 'Image', 'color': Colors.blue},
      {'icon': Icons.tune, 'label': 'Adjust', 'color': Colors.orange},
      {'icon': Icons.gradient, 'label': 'Mask', 'color': Colors.cyan},
      {'icon': Icons.photo_library, 'label': 'Overlays', 'color': Colors.deepPurple},
      {'icon': Icons.layers, 'label': 'Shapes', 'color': Colors.pink},
      {'icon': Icons.add_comment, 'label': 'Extra Text', 'color': Colors.blueAccent},
      {'icon': Icons.aspect_ratio, 'label': 'Canvas', 'color': Colors.blueGrey},
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
        if (!_isBulkMode) ...[
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
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _importFromMyQuotes,
              icon: const Icon(Icons.format_quote, size: 18),
              label: const Text('Import from My Quotes', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal[50],
                foregroundColor: Colors.teal[800],
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _importCsv,
                  icon: const Icon(Icons.file_present, size: 18),
                  label: const Text('CSV', style: TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8)),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _pasteBulkText,
                  icon: const Icon(Icons.paste, size: 18),
                  label: const Text('Paste', style: TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8)),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _importFromMyQuotes,
                  icon: const Icon(Icons.format_quote, size: 18),
                  label: const Text('Quotes', style: TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal[50],
                    foregroundColor: Colors.teal[800],
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
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
          AnalyticsService().logEvent(
            name: 'bulk_import_csv',
            parameters: {'count': loadedTexts.length}
          );
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
          _buildColorPickerRow(
            label: 'Text Color',
            currentColor: _textColor,
            onColorSelected: (color) => setState(() => _textColor = color),
            onPickCustom: () => _showColorPicker('text'),
            allowTransparent: false,
          ),
          const SizedBox(height: 20),
          _buildColorPickerRow(
            label: 'Background Color',
            currentColor: _backgroundColor,
            onColorSelected: (color) => setState(() => _backgroundColor = color),
            onPickCustom: () => _showColorPicker('background'),
            allowTransparent: true,
          ),
        ],
      ),
    );
  }

  Widget _buildColorPickerRow({
    required String label,
    required Color currentColor,
    required ValueChanged<Color> onColorSelected,
    required VoidCallback onPickCustom,
    bool allowTransparent = false,
  }) {
    final List<Color> presets = [
      Colors.white,
      Colors.black,
      Colors.red,
      Colors.pink,
      Colors.purple,
      Colors.deepPurple,
      Colors.indigo,
      Colors.blue,
      Colors.lightBlue,
      Colors.cyan,
      Colors.teal,
      Colors.green,
      Colors.lightGreen,
      Colors.lime,
      Colors.yellow,
      Colors.amber,
      Colors.orange,
      Colors.deepOrange,
      Colors.brown,
      Colors.grey,
      Colors.blueGrey,
    ];

    if (allowTransparent) {
      presets.add(Colors.transparent);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                )),
            GestureDetector(
              onTap: onPickCustom,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.colorize, size: 12, color: Colors.black54),
                    const SizedBox(width: 4),
                    const Text('Custom', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 38,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: presets.length,
            padding: EdgeInsets.zero,
            itemBuilder: (context, index) {
              final color = presets[index];
              final isSelected = currentColor.value == color.value;
              final isDark = color.computeLuminance() < 0.5 && color != Colors.transparent;

              return GestureDetector(
                onTap: () => onColorSelected(color),
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.blue : Colors.grey[200]!,
                      width: isSelected ? 2.5 : 1,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 6, spreadRadius: 1)]
                        : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            )
                          ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (color == Colors.transparent)
                        const Icon(Icons.not_interested, size: 20, color: Colors.grey),
                      if (isSelected)
                        Icon(
                          Icons.check,
                          size: 20,
                          color: isDark ? Colors.white : Colors.black87,
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
          _buildSimpleSlider(
            label: 'Offset X',
            value: _shadowOffsetX,
            min: -20,
            max: 20,
            onChanged: (v) => setState(() => _shadowOffsetX = v),
            onReset: () => setState(() => _shadowOffsetX = 2.0),
            step: 1.0,
          ),
          _buildSimpleSlider(
            label: 'Offset Y',
            value: _shadowOffsetY,
            min: -20,
            max: 20,
            onChanged: (v) => setState(() => _shadowOffsetY = v),
            onReset: () => setState(() => _shadowOffsetY = 2.0),
            step: 1.0,
          ),
          _buildSimpleSlider(
            label: 'Blur',
            value: _shadowBlurRadius,
            min: 0,
            max: 20,
            onChanged: (v) => setState(() => _shadowBlurRadius = v),
            onReset: () => setState(() => _shadowBlurRadius = 5.0),
            step: 1.0,
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
          _buildSimpleSlider(
            label: 'Glow Radius',
            value: _glowRadius,
            min: 5.0,
            max: 30.0,
            onChanged: (value) {
              setState(() {
                _glowRadius = value;
              });
            },
            onReset: () => setState(() => _glowRadius = 15.0),
            step: 1.0,
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
          _buildSimpleSlider(
            label: 'Letter Spacing',
            value: _letterSpacing,
            min: -2.0,
            max: 10.0,
            onChanged: (v) => setState(() => _letterSpacing = v),
            onReset: () => setState(() => _letterSpacing = 0.0),
            step: 0.5,
          ),
          const SizedBox(height: 4),
          _buildSimpleSlider(
            label: 'Line Height',
            value: _lineHeight,
            min: 0.8,
            max: 2.0,
            onChanged: (v) => setState(() => _lineHeight = v),
            onReset: () => setState(() => _lineHeight = 1.2),
            step: 0.05,
          ),
          const SizedBox(height: 4),
          _buildSimpleSlider(
            label: 'Font Size',
            value: _fontSize,
            min: 0.5,
            max: 2.0,
            onChanged: (v) => setState(() => _fontSize = v),
            onReset: () => setState(() => _fontSize = 1.0),
            step: 0.1,
          ),
          const SizedBox(height: 4),
          _buildSimpleSlider(
            label: 'Text Scale',
            value: _textScale,
            min: 0.2,
            max: 4.0,
            onChanged: (v) => setState(() => _textScale = v),
            onReset: () => setState(() => _textScale = 1.0),
            step: 0.05,
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    final bool hasContent =
        (_isBulkMode && _bulkTexts.isNotEmpty) || (!_isBulkMode && (_textController.text.trim().isNotEmpty || _bgImage != null));
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

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Background Image', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _pickBackgroundImage,
                icon: const Icon(Icons.photo_library, size: 18),
                label: const Text('Pick Image', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[50],
                  foregroundColor: Colors.blue[800],
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            if (_bgImage != null) ...[
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => setState(() => _bgImage = null),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Clear', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[50],
                    foregroundColor: Colors.red[800],
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _transformationController.value = Matrix4.identity();
              });
            },
            icon: const Icon(Icons.center_focus_strong, size: 18),
            label: const Text('Reset Image Zoom & Position', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[100],
              foregroundColor: Colors.grey[800],
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickBackgroundImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _bgImage = File(image.path);
      });
    }
  }

  Future<void> _importFromMyQuotes() async {
    final dynamic selected = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MyQuotesScreen(selectMode: true),
      ),
    );

    if (selected != null && selected is QuoteItem) {
      setState(() {
        _textController.text = selected.text;
      });
    }
  }

  Widget _buildAdjustSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Image Adjustments', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 8),
        _buildSimpleSlider(
          label: 'Brightness',
          value: _brightness,
          min: 0.0,
          max: 2.0,
          onChanged: (v) => setState(() => _brightness = v),
          onReset: () => setState(() => _brightness = 1.0),
          step: 0.05,
        ),
        _buildSimpleSlider(
          label: 'Saturation',
          value: _saturation,
          min: 0.0,
          max: 2.0,
          onChanged: (v) => setState(() => _saturation = v),
          onReset: () => setState(() => _saturation = 1.0),
          step: 0.05,
        ),
        _buildSimpleSlider(
          label: 'Hue',
          value: _hue,
          min: -math.pi,
          max: math.pi,
          onChanged: (v) => setState(() => _hue = v),
          onReset: () => setState(() => _hue = 0.0),
          step: 0.1,
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            onPressed: () {
              setState(() {
                _brightness = 1.0;
                _saturation = 1.0;
                _hue = 0.0;
              });
            },
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Reset All Adjustments', style: TextStyle(fontSize: 11)),
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    VoidCallback? onReset,
    double step = 0.1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
            if (onReset != null) ...[
              const SizedBox(width: 4),
              InkWell(
                onTap: onReset,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: Icon(Icons.refresh, size: 12, color: Colors.indigo[400]),
                ),
              ),
            ],
            const Spacer(),
            Text(value.toStringAsFixed(2), style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
        Row(
          children: [
            _buildStepButton(Icons.chevron_left, () {
              final newValue = (value - step).clamp(min, max);
              onChanged(newValue);
            }),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                ),
                child: Slider(value: value, min: min, max: max, onChanged: onChanged),
              ),
            ),
            _buildStepButton(Icons.chevron_right, () {
              final newValue = (value + step).clamp(min, max);
              onChanged(newValue);
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildStepButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        child: Icon(icon, size: 16, color: Colors.grey[600]),
      ),
    );
  }

  Widget _buildPatchPreview(_OverlayPatch p, int idx, BoxConstraints constraints) {
    return Positioned(
      left: p.x * constraints.maxWidth,
      top: p.y * constraints.maxHeight,
      width: p.width * constraints.maxWidth,
      height: p.height * constraints.maxHeight,
      child: GestureDetector(
        onPanUpdate: (d) {
          setState(() {
            p.x = (p.x + d.delta.dx / constraints.maxWidth).clamp(0.0, 1.0 - p.width);
            p.y = (p.y + d.delta.dy / constraints.maxHeight).clamp(0.0, 1.0 - p.height);
            _selectedPatchIndex = idx;
            _selectedTabIndex = 11;
          });
        },
        onTap: () => setState(() {
          _selectedPatchIndex = idx;
          _selectedTabIndex = 11;
        }),
        child: Container(
          decoration: BoxDecoration(
            color: p.color.withOpacity(p.opacity),
            borderRadius: BorderRadius.circular(p.radius * (constraints.maxWidth / 1000)),
            border: !_isExporting && _selectedPatchIndex == idx && _selectedTabIndex == 11
                ? Border.all(color: Colors.white, width: 2)
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildImageOverlayPreview(_OverlayImage img, int idx, BoxConstraints constraints) {
    final isSelected = !_isExporting && _selectedImageOverlayIndex == idx && _selectedTabIndex == 10;
    final file = File(img.path);
    if (!file.existsSync()) return const SizedBox.shrink();

    final overlayW = constraints.maxWidth * img.scale;
    return Positioned(
      left: img.x * constraints.maxWidth,
      top: img.y * constraints.maxHeight,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: GestureDetector(
          onPanStart: (_) => setState(() {
            _selectedImageOverlayIndex = idx;
            _selectedTabIndex = 10;
          }),
          onPanUpdate: (d) => setState(() {
            img.x = (img.x + d.delta.dx / constraints.maxWidth).clamp(0.0, 1.0);
            img.y = (img.y + d.delta.dy / constraints.maxHeight).clamp(0.0, 1.0);
          }),
          onTap: () => setState(() {
            _selectedImageOverlayIndex = idx;
            _selectedTabIndex = 10;
          }),
          child: Transform.rotate(
            angle: img.rotation * (math.pi / 180),
            child: Opacity(
              opacity: img.opacity,
              child: Container(
                decoration: isSelected
                    ? BoxDecoration(
                        border: Border.all(color: Colors.deepPurple, width: 2),
                        borderRadius: BorderRadius.circular(4))
                    : null,
                child: Image.file(
                  file,
                  width: overlayW,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextOverlayPreview(_TextOverlay t, int idx, BoxConstraints constraints) {
    final isSelected = !_isExporting && _selectedTextOverlayIndex == idx && _selectedTabIndex == 12;
    return Positioned(
      left: t.x * constraints.maxWidth,
      top: t.y * constraints.maxHeight,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: GestureDetector(
          onPanStart: (_) => setState(() {
            _selectedTextOverlayIndex = idx;
            _selectedTabIndex = 12;
          }),
          onPanUpdate: (d) => setState(() {
            t.x = (t.x + d.delta.dx / constraints.maxWidth).clamp(0.0, 1.0);
            t.y = (t.y + d.delta.dy / constraints.maxHeight).clamp(0.0, 1.0);
          }),
          onTap: () => setState(() {
            _selectedTextOverlayIndex = idx;
            _selectedTabIndex = 12;
          }),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: isSelected
                ? BoxDecoration(
                    border: Border.all(color: Colors.blueAccent, width: 2),
                    borderRadius: BorderRadius.circular(4))
                : null,
            child: Text(
              t.text,
              textAlign: t.textAlign,
              style: TextStyle(
                fontFamily: t.font?.family,
                fontWeight: t.font?.weight ?? FontWeight.normal,
                fontStyle: t.font?.style ?? FontStyle.normal,
                color: t.color,
                fontSize: t.fontSize * t.scale,
                shadows: t.showShadow
                    ? [
                        Shadow(
                          color: t.shadowColor.withOpacity(0.7),
                          offset: Offset(t.shadowOffsetX, t.shadowOffsetY),
                          blurRadius: t.shadowBlur,
                        )
                      ]
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverlaysSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Image Overlays', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ElevatedButton.icon(
              onPressed: () async {
                final picker = ImagePicker();
                final picked = await picker.pickImage(source: ImageSource.gallery);
                if (picked != null) {
                  setState(() {
                    _imageOverlays.add(_OverlayImage(path: picked.path));
                    _selectedImageOverlayIndex = _imageOverlays.length - 1;
                  });
                }
              },
              icon: const Icon(Icons.add_photo_alternate, size: 16),
              label: const Text('Add Image', style: TextStyle(fontSize: 11)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_imageOverlays.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                "No image overlays added.\nPick an image or sticker to overlay.",
                style: TextStyle(color: Colors.grey, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        if (_imageOverlays.isNotEmpty) ...[
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _imageOverlays.length,
              itemBuilder: (context, i) {
                final o = _imageOverlays[i];
                final isSelected = _selectedImageOverlayIndex == i;
                return GestureDetector(
                  onTap: () => setState(() => _selectedImageOverlayIndex = i),
                  child: Container(
                    width: 56,
                    height: 56,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? Colors.deepPurple : Colors.grey.shade300,
                        width: isSelected ? 2.5 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(File(o.path), fit: BoxFit.cover),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (_selectedImageOverlayIndex != null &&
            _selectedImageOverlayIndex! < _imageOverlays.length) ...[
          _buildActiveImageOverlayControls(
              _imageOverlays[_selectedImageOverlayIndex!], _selectedImageOverlayIndex!),
        ] else if (_imageOverlays.isNotEmpty)
          const Center(
            child: Text(
              "Select an overlay on preview to edit",
              style: TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ),
      ],
    );
  }

  Widget _buildActiveImageOverlayControls(_OverlayImage o, int index) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text("Overlay #${index + 1}",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const Spacer(),
            IconButton(
              onPressed: () async {
                final picker = ImagePicker();
                final picked = await picker.pickImage(source: ImageSource.gallery);
                if (picked != null) setState(() => o.path = picked.path);
              },
              icon: const Icon(Icons.swap_horiz, color: Colors.deepPurple, size: 18),
              tooltip: 'Replace Image',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: () => setState(() {
                _imageOverlays.removeAt(index);
                _selectedImageOverlayIndex = null;
              }),
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildSimpleSlider(
          label: 'Scale',
          value: o.scale,
          min: 0.05,
          max: 1.0,
          onChanged: (v) => setState(() => o.scale = v),
          onReset: () => setState(() => o.scale = 0.2),
          step: 0.01,
        ),
        _buildSimpleSlider(
          label: 'Rotation',
          value: o.rotation,
          min: -180.0,
          max: 180.0,
          onChanged: (v) => setState(() => o.rotation = v),
          onReset: () => setState(() => o.rotation = 0.0),
          step: 1.0,
        ),
        _buildSimpleSlider(
          label: 'Opacity',
          value: o.opacity,
          min: 0.0,
          max: 1.0,
          onChanged: (v) => setState(() => o.opacity = v),
          onReset: () => setState(() => o.opacity = 1.0),
          step: 0.05,
        ),
      ],
    );
  }

  Widget _buildShapesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Background Shapes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _patches.add(_OverlayPatch(x: 0.25, y: 0.25, width: 0.5, height: 0.2));
                  _selectedPatchIndex = _patches.length - 1;
                });
              },
              icon: const Icon(Icons.add_box, size: 16),
              label: const Text('Add Shape', style: TextStyle(fontSize: 11)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_patches.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                "No shapes added. Use them to create text backdrops or accents.",
                style: TextStyle(color: Colors.grey, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        if (_selectedPatchIndex != null && _selectedPatchIndex! < _patches.length) ...[
          _buildActivePatchControls(_patches[_selectedPatchIndex!], _selectedPatchIndex!),
        ] else if (_patches.isNotEmpty)
          const Center(
            child: Text(
              "Select a shape on preview to edit",
              style: TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ),
      ],
    );
  }

  Widget _buildActivePatchControls(_OverlayPatch p, int index) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text("Shape #${index + 1}",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const Spacer(),
            ChoiceChip(
              label: const Text('Top Layer', style: TextStyle(fontSize: 10)),
              selected: p.isTop,
              onSelected: (v) => setState(() => p.isTop = v),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => setState(() {
                _patches.removeAt(index);
                _selectedPatchIndex = null;
              }),
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('Color:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                Color selectedColor = p.color;
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Shape Color'),
                    content: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AdvancedColorPicker(
                            initialColor: p.color,
                            onColorChanged: (color) => selectedColor = color,
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() => p.color = selectedColor);
                                Navigator.pop(context);
                              },
                              child: const Text('SELECT'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: p.color,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey.shade300),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildSimpleSlider(
          label: 'Width',
          value: p.width,
          min: 0.05,
          max: 1.0,
          onChanged: (v) => setState(() => p.width = v),
          onReset: () => setState(() => p.width = 0.5),
          step: 0.01,
        ),
        _buildSimpleSlider(
          label: 'Height',
          value: p.height,
          min: 0.05,
          max: 1.0,
          onChanged: (v) => setState(() => p.height = v),
          onReset: () => setState(() => p.height = 0.2),
          step: 0.01,
        ),
        _buildSimpleSlider(
          label: 'Opacity',
          value: p.opacity,
          min: 0.0,
          max: 1.0,
          onChanged: (v) => setState(() => p.opacity = v),
          onReset: () => setState(() => p.opacity = 0.5),
          step: 0.05,
        ),
        _buildSimpleSlider(
          label: 'Corner Radius',
          value: p.radius,
          min: 0.0,
          max: 100.0,
          onChanged: (v) => setState(() => p.radius = v),
          onReset: () => setState(() => p.radius = 8.0),
          step: 1.0,
        ),
      ],
    );
  }

  Widget _buildTextOverlaysSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Extra Text Layers',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _textOverlays.add(_TextOverlay(
                    text: 'New Text',
                    font: _selectedFont,
                    color: _textColor,
                  ));
                  _selectedTextOverlayIndex = _textOverlays.length - 1;
                });
              },
              icon: const Icon(Icons.add_comment, size: 16),
              label: const Text('Add Text', style: TextStyle(fontSize: 11)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_textOverlays.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                "No extra text layers added.\nUse these for subtitles, handles, or extra info.",
                style: TextStyle(color: Colors.grey, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        if (_selectedTextOverlayIndex != null &&
            _selectedTextOverlayIndex! < _textOverlays.length) ...[
          _buildActiveTextOverlayControls(
              _textOverlays[_selectedTextOverlayIndex!], _selectedTextOverlayIndex!),
        ] else if (_textOverlays.isNotEmpty)
          const Center(
            child: Text(
              "Select extra text on preview to edit",
              style: TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ),
      ],
    );
  }

  Widget _buildActiveTextOverlayControls(_TextOverlay t, int index) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text("Layer #${index + 1}",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const Spacer(),
            IconButton(
              onPressed: () => setState(() {
                _textOverlays.removeAt(index);
                _selectedTextOverlayIndex = null;
              }),
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          onChanged: (v) => setState(() => t.text = v),
          controller: TextEditingController(text: t.text)..selection = TextSelection.collapsed(offset: t.text.length),
          decoration: InputDecoration(
            hintText: 'Enter text...',
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          style: const TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text('Color:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                Color selectedColor = t.color;
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Text Color'),
                    content: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AdvancedColorPicker(
                            initialColor: t.color,
                            onColorChanged: (color) => selectedColor = color,
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() => t.color = selectedColor);
                                Navigator.pop(context);
                              },
                              child: const Text('SELECT'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: t.color,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey.shade300),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildSimpleSlider(
          label: 'Font Size',
          value: t.fontSize,
          min: 10.0,
          max: 100.0,
          onChanged: (v) => setState(() => t.fontSize = v),
          onReset: () => setState(() => t.fontSize = 24.0),
          step: 1.0,
        ),
        _buildSimpleSlider(
          label: 'Scale',
          value: t.scale,
          min: 0.5,
          max: 3.0,
          onChanged: (v) => setState(() => t.scale = v),
          onReset: () => setState(() => t.scale = 1.0),
          step: 0.1,
        ),
      ],
    );
  }

  Widget _buildMaskSection() {
    final maskTypes = [
      {'label': 'None', 'icon': Icons.block, 'type': 0},
      {'label': 'Bottom', 'icon': Icons.expand_less, 'type': 1},
      {'label': 'Top', 'icon': Icons.expand_more, 'type': 2},
      {'label': 'Full', 'icon': Icons.stop, 'type': 3},
      {'label': 'Left', 'icon': Icons.chevron_left, 'type': 4},
      {'label': 'Right', 'icon': Icons.chevron_right, 'type': 5},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Overlay Mask', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: maskTypes.map((m) {
              final isSelected = _maskType == m['type'];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(m['label'] as String, style: const TextStyle(fontSize: 11)),
                  avatar: Icon(m['icon'] as IconData, size: 14, color: isSelected ? Colors.white : Colors.black54),
                  selected: isSelected,
                  onSelected: (val) {
                    if (val) setState(() => _maskType = m['type'] as int);
                  },
                ),
              );
            }).toList(),
          ),
        ),
        if (_maskType != 0) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Color', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => _showColorPicker('mask'),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _maskColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildSimpleSlider(
            label: 'Opacity',
            value: _maskOpacity,
            min: 0.0,
            max: 1.0,
            onChanged: (v) => setState(() => _maskOpacity = v),
            onReset: () => setState(() => _maskOpacity = 0.5),
            step: 0.05,
          ),
          if (_maskType != 3) ...[
            _buildSimpleSlider(
              label: 'Start',
              value: _maskStart,
              min: 0.0,
              max: 1.0,
              onChanged: (v) => setState(() => _maskStart = v),
              onReset: () => setState(() => _maskStart = 0.0),
              step: 0.05,
            ),
            _buildSimpleSlider(
              label: 'End',
              value: _maskEnd,
              min: 0.0,
              max: 1.0,
              onChanged: (v) => setState(() => _maskEnd = v),
              onReset: () => setState(() => _maskEnd = 1.0),
              step: 0.05,
            ),
          ],
        ],
      ],
    );
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
      case 'mask':
        currentColor = _maskColor;
        title = 'Mask Color';
        break;
      default:
        currentColor = Colors.white;
        title = 'Color';
    }

    Color selectedColor = currentColor;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                initialColor: currentColor,
                onColorChanged: (color) => selectedColor = color,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      switch (type) {
                        case 'text':
                          _textColor = selectedColor;
                          break;
                        case 'background':
                          _backgroundColor = selectedColor;
                          break;
                        case 'shadow':
                          _shadowColor = selectedColor;
                          break;
                        case 'glow':
                          _glowColor = selectedColor;
                          break;
                        case 'mask':
                          _maskColor = selectedColor;
                          break;
                      }
                    });
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
        setState(() {
          _currentBulkIndex = i;
        });

        try {
          // We must wait for the frame to render the new text before capturing
          await Future.delayed(const Duration(milliseconds: 200));
          await WidgetsBinding.instance.endOfFrame;

          final String? savedPath = await ImageGenerator.savePostToGallery(
            text: '', // Text is already in the widget
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
    setState(() {
      _isExporting = true;
      _isTabContentExpanded = false;
    });

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
      const int baseWidth = 1080;
      final double aspect = _currentAspectRatio;
      final int exportWidth;
      final int exportHeight;

      if (aspect >= 1.0) {
        exportWidth = baseWidth;
        exportHeight = (baseWidth / aspect).round();
      } else {
        exportHeight = baseWidth;
        exportWidth = (baseWidth * aspect).round();
      }

      // Briefly wait for rendering
      await Future.delayed(const Duration(milliseconds: 300));
      await WidgetsBinding.instance.endOfFrame;

      final String? savedPath = await ImageGenerator.savePostToGallery(
        text: '', // Text is already in the widget
        templateKey: _previewKey,
        outputWidth: exportWidth,
        outputHeight: exportHeight,
      );

      if (!mounted) return;
      Navigator.of(context).pop();

      setState(() {
        _isExporting = false;
      });

      AppReviewService().incrementExportCount();
      AnalyticsService().logSaveAction(feature: 'text_post', type: 'image');
      AppReviewService().checkAndRequestReview();

      if (savedPath != null) {
        AdService().showInterstitialAd();
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
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
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
