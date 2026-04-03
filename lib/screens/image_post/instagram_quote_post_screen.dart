import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';

import '../../utils/font_selector.dart';
import '../../widgets/advanced_color_picker.dart';
import '../../utils/image_generator.dart';
import 'package:quickpost/utils/watermark_settings.dart';
import '../../services/app_review_service.dart';
import '../../models/instagram_quote_template.dart';
import '../../services/instagram_quote_template_service.dart';
import '../quotes/my_quotes_screen.dart';
import '../../models/quote_item.dart';
import '../../services/instagram_quote_template_service.dart';

class InstagramQuotePostScreen extends StatefulWidget {
  const InstagramQuotePostScreen({super.key});

  @override
  State<InstagramQuotePostScreen> createState() => _InstagramQuotePostScreenState();
}

class _InstagramQuotePostScreenState extends State<InstagramQuotePostScreen> {
  final TextEditingController _quoteController = TextEditingController();
  final TextEditingController _authorController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  final GlobalKey _previewKey = GlobalKey();

  FontInfo? _quoteFont;
  FontInfo? _authorFont;
  FontInfo? _displayNameFont;
  FontInfo? _handleFont;
  Color _textColor = Colors.black;
  Color _backgroundColor = Colors.white;
  Color _authorColor = Colors.black87;
  Color _displayNameColor = Colors.black87;
  Color _usernameColor = Colors.black54;

  bool _enableQuoteShadow = true;
  bool _enableAuthorShadow = false;
  bool _enableQuoteGlow = false;
  bool _enableAuthorGlow = false;
  Color _quoteShadowColor = Colors.black87;
  Color _authorShadowColor = Colors.black54;
  Color _quoteGlowColor = Colors.white70;
  Color _authorGlowColor = Colors.white70;
  double _quoteGlowRadius = 12.0;
  double _authorGlowRadius = 10.0;
  double _quoteShadowOffsetX = 1.0;
  double _quoteShadowOffsetY = 1.0;
  double _quoteShadowBlur = 3.0;
  double _authorShadowOffsetX = 1.0;
  double _authorShadowOffsetY = 1.0;
  double _authorShadowBlur = 3.0;
  double _letterSpacing = 0.0;
  double _fontSize = 0.5;
  double _lineHeight = 1.3;

  int _selectedTabIndex = 0; // 0 Text, 1 Font, 2 Colors, 3 Effects, 4 Spacing, 5 Align, 6 Quote Pos, 7 Identity Pos
  bool _isTabContentExpanded = false;
  bool _isBulkMode = false;
  List<Map<String, String>> _bulkQuotes = [];
  int _currentBulkIndex = 0;

  TextAlign _textAlign = TextAlign.center;
  Alignment _textPosition = Alignment(0.0, 0.2);
  Alignment _identityPosition = Alignment(0.0, -0.4);
  bool _isDraggingQuote = false;
  bool _isDraggingIdentity = false;

  File? _profileImage;
  File? _backgroundImage;
  BoxFit _backgroundFit = BoxFit.cover;
  Offset _backgroundOffset = Offset.zero;
  double _backgroundScale = 1.0;
  double _backgroundBlur = 0.0;
  double _backgroundBrightness = 1.0;
  double _backgroundSaturation = 1.0;

  // 0: 4:5, 1: 1:1, 2: 9:16, 3: 16:9
  int _selectedAspectIndex = 1;

  double get _currentAspectRatio {
    switch (_selectedAspectIndex) {
      case 1:
        return 1 / 1;
      case 2:
        return 9 / 16;
      case 3:
        return 16 / 9;
      case 0:
      default:
        return 4 / 5; // IG-style default
    }
  }

  Color get _watermarkColor {
    // Use background luminance to pick contrasting watermark color
    final double luminance = _backgroundColor.computeLuminance();
    // Dark text on light backgrounds, light text on dark backgrounds
    return luminance > 0.5
        ? Colors.black.withOpacity(0.35)
        : Colors.white.withOpacity(0.35);
  }

  Future<void> _pickBackgroundImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      setState(() {
        _backgroundImage = File(picked.path);
      });
    } catch (_) {}
  }

  void _removeBackgroundImage() {
    setState(() {
      _backgroundImage = null;
      _backgroundOffset = Offset.zero;
      _backgroundScale = 1.0;
      _backgroundBlur = 0.0;
      _backgroundBrightness = 1.0;
      _backgroundSaturation = 1.0;
    });
  }

  @override
  void initState() {
    super.initState();
    _quoteFont = FontInfo(family: 'Metrophobic', displayName: 'Metrophobic');
    _authorFont = FontInfo(family: 'Metrophobic', displayName: 'Metrophobic');
    _displayNameFont = FontInfo(family: 'Metrophobic', displayName: 'Metrophobic');
    _handleFont = FontInfo(family: 'Metrophobic', displayName: 'Metrophobic');

    // Default quote and author
    _quoteController.text =
        'Its not about if I can, I am doing thing because I wanted to';
    _authorController.text = 'Monkey D. Luffy';
  }

  @override
  void dispose() {
    _quoteController.dispose();
    _authorController.dispose();
    _displayNameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final shouldLeave = await showDialog<bool>(
              context: context,
              builder: (context) {
                return AlertDialog(
                  title: const Text('Discard current design?'),
                  content: const Text(
                    'If you go back now, your current IG quote design will be lost.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Stay'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Leave'),
                    ),
                  ],
                );
              },
            ) ??
            false;

        return shouldLeave;
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 40,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          titleSpacing: 0,
          title: const Text(
            'IG Quote Post',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          actions: [
            IconButton(
              tooltip: 'Load template',
              icon: const Icon(Icons.bookmarks_outlined),
              onPressed: _showTemplatePicker,
            ),
            IconButton(
              tooltip: 'Save as template',
              icon: const Icon(Icons.bookmark_add_outlined),
              onPressed: _saveCurrentAsTemplate,
            ),
          ],
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
      ),
    );
  }

  Widget _buildPreviewArea() {
    return Column(
      children: [
        _buildAspectRatioSelector(),
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

  Widget _buildAspectRatioSelector() {
    const options = [
      {'label': '4:5', 'index': 0},
      {'label': '1:1', 'index': 1},
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
              Icon(Icons.format_align_center, color: Colors.blueGrey[600], size: 22),
              const SizedBox(width: 8),
              const Text(
                'Text Align',
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
      ),
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

    Widget buildPresetChips({required bool forIdentity}) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: presets.map((preset) {
            final Alignment target = preset['alignment'] as Alignment;
            final Alignment current = forIdentity ? _identityPosition : _textPosition;
            final bool isSelected = current == target;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    if (forIdentity) {
                      _identityPosition = target;
                    } else {
                      _textPosition = target;
                    }
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

    Widget buildArrowPad({required bool forIdentity}) {
      const double step = 0.1;

      void nudge(double dx, double dy) {
        setState(() {
          if (forIdentity) {
            final double newX = (_identityPosition.x + dx).clamp(-1.0, 1.0);
            final double newY = (_identityPosition.y + dy).clamp(-1.0, 1.0);
            _identityPosition = Alignment(newX, newY);
          } else {
            final double newX = (_textPosition.x + dx).clamp(-1.0, 1.0);
            final double newY = (_textPosition.y + dy).clamp(-1.0, 1.0);
            _textPosition = Alignment(newX, newY);
          }
        });
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            forIdentity
                ? 'x: ${_identityPosition.x.toStringAsFixed(2)}, y: ${_identityPosition.y.toStringAsFixed(2)}'
                : 'x: ${_textPosition.x.toStringAsFixed(2)}, y: ${_textPosition.y.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 10, color: Colors.black54),
          ),
          const SizedBox(height: 2),
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
                    if (forIdentity) {
                      _identityPosition = Alignment.bottomCenter;
                    } else {
                      _textPosition = Alignment.center;
                    }
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
              Icon(Icons.open_with, color: Colors.brown[600], size: 22),
              const SizedBox(width: 8),
              const Text(
                'Quote Position',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Presets',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          buildPresetChips(forIdentity: false),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Fine tune',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              buildArrowPad(forIdentity: false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityPositionSection() {
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
            final bool isSelected = _identityPosition == target;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _identityPosition = target;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.pink.withOpacity(0.12) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? Colors.pink : Colors.grey[300]!,
                    ),
                  ),
                  child: Text(
                    preset['label'] as String,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? Colors.pink : Colors.grey[800],
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
          final double newX = (_identityPosition.x + dx).clamp(-1.0, 1.0);
          final double newY = (_identityPosition.y + dy).clamp(-1.0, 1.0);
          _identityPosition = Alignment(newX, newY);
        });
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'x: ${_identityPosition.x.toStringAsFixed(2)}, y: ${_identityPosition.y.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 10, color: Colors.black54),
          ),
          const SizedBox(height: 2),
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
                    _identityPosition = Alignment.bottomCenter;
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
              Icon(Icons.account_circle, color: Colors.pink[600], size: 22),
              const SizedBox(width: 8),
              const Text(
                'Identity Bar Position',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Presets',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          buildPresetChips(),
          const SizedBox(height: 8),
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
      ),
    );
  }

  Widget _buildPreviewSection() {
    String previewQuote = '';
    String previewAuthor = '';

    if (_isBulkMode && _bulkQuotes.isNotEmpty) {
      previewQuote = _bulkQuotes[_currentBulkIndex]['quote'] ?? '';
      previewAuthor = _bulkQuotes[_currentBulkIndex]['author'] ?? '';
    } else {
      previewQuote = _quoteController.text.isEmpty ? 'Write your quote here' : _quoteController.text;
      previewAuthor = _authorController.text;
    }

    return Column(
      children: [
        if (_isBulkMode && _bulkQuotes.isNotEmpty)
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
                  'Post ${_currentBulkIndex + 1} of ${_bulkQuotes.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: _currentBulkIndex < _bulkQuotes.length - 1
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Container(
                  color: _backgroundColor,
                  child: Stack(
                    children: [
                      if (_backgroundImage != null)
                        Positioned.fill(
                          child: GestureDetector(
                            onPanUpdate: (details) {
                              setState(() {
                                _backgroundOffset += details.delta;
                              });
                            },
                            child: ClipRect(
                              child: Transform.translate(
                                offset: _backgroundOffset,
                                child: Transform.scale(
                                  scale: _backgroundScale,
                                  child: ColorFiltered(
                                    colorFilter: ColorFilter.matrix([
                                      0.2126 + 0.7874 * _backgroundSaturation, 0.7152 - 0.7152 * _backgroundSaturation, 0.0722 - 0.0722 * _backgroundSaturation, 0, 0,
                                      0.2126 - 0.2126 * _backgroundSaturation, 0.7152 + 0.2848 * _backgroundSaturation, 0.0722 - 0.0722 * _backgroundSaturation, 0, 0,
                                      0.2126 - 0.2126 * _backgroundSaturation, 0.7152 - 0.7152 * _backgroundSaturation, 0.0722 + 0.9278 * _backgroundSaturation, 0, 0,
                                      0, 0, 0, 1, 0,
                                    ]),
                                    child: ColorFiltered(
                                      colorFilter: ColorFilter.matrix([
                                        _backgroundBrightness, 0, 0, 0, 0,
                                        0, _backgroundBrightness, 0, 0, 0,
                                        0, 0, _backgroundBrightness, 0, 0,
                                        0, 0, 0, 1, 0,
                                      ]),
                                      child: ImageFiltered(
                                        imageFilter: ImageFilter.blur(
                                          sigmaX: _backgroundBlur,
                                          sigmaY: _backgroundBlur,
                                        ),
                                        child: Image.file(
                                          _backgroundImage!,
                                          fit: _backgroundFit,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                      // Draggable Quote Section
                      Positioned(
                        left: (constraints.maxWidth / 2) + (_textPosition.x * constraints.maxWidth / 2),
                        top: (constraints.maxHeight / 2) + (_textPosition.y * constraints.maxHeight / 2),
                        child: FractionalTranslation(
                          translation: const Offset(-0.5, -0.5),
                          child: GestureDetector(
                            onPanUpdate: (details) {
                              setState(() {
                                double newX = _textPosition.x + (details.delta.dx / (constraints.maxWidth / 2));
                                double newY = _textPosition.y + (details.delta.dy / (constraints.maxHeight / 2));
                                _textPosition = Alignment(newX.clamp(-1.0, 1.0), newY.clamp(-1.0, 1.0));
                                _isDraggingQuote = true;
                              });
                            },
                            onPanEnd: (_) => setState(() => _isDraggingQuote = false),
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth: constraints.maxWidth * 0.85,
                              ),
                              padding: const EdgeInsets.all(8),
                              color: Colors.transparent, // Ensure hit testing
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    previewQuote,
                                    textAlign: _textAlign,
                                    style: TextStyle(
                                      fontFamily: _quoteFont?.family,
                                      fontWeight: _quoteFont?.weight ?? FontWeight.w600,
                                      fontStyle: _quoteFont?.style ?? FontStyle.normal,
                                      color: _textColor,
                                      fontSize: 30 * _fontSize,
                                      height: _lineHeight,
                                      letterSpacing: _letterSpacing,
                                      shadows: [
                                        if (_enableQuoteShadow)
                                          Shadow(
                                            color: _quoteShadowColor,
                                            offset: Offset(_quoteShadowOffsetX, _quoteShadowOffsetY),
                                            blurRadius: _quoteShadowBlur,
                                          ),
                                        if (_enableQuoteGlow)
                                          Shadow(
                                            color: _quoteGlowColor,
                                            offset: const Offset(0, 0),
                                            blurRadius: _quoteGlowRadius,
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (previewAuthor.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      '- $previewAuthor',
                                      textAlign: _textAlign,
                                      style: TextStyle(
                                        fontFamily: _authorFont?.family,
                                        fontWeight: _authorFont?.weight ?? FontWeight.w400,
                                        fontStyle: FontStyle.italic,
                                        color: _authorColor,
                                        fontSize: 16 * _fontSize,
                                        shadows: [
                                          if (_enableAuthorShadow)
                                            Shadow(
                                              color: _authorShadowColor,
                                              offset: Offset(_authorShadowOffsetX, _authorShadowOffsetY),
                                              blurRadius: _authorShadowBlur,
                                            ),
                                          if (_enableAuthorGlow)
                                            Shadow(
                                              color: _authorGlowColor,
                                              offset: const Offset(0, 0),
                                              blurRadius: _authorGlowRadius,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      // Draggable Identity Bar
                      Positioned(
                        left: (constraints.maxWidth / 2) + (_identityPosition.x * constraints.maxWidth / 2),
                        top: (constraints.maxHeight / 2) + (_identityPosition.y * constraints.maxHeight / 2),
                        child: FractionalTranslation(
                          translation: const Offset(-0.5, -0.5),
                          child: GestureDetector(
                            onPanUpdate: (details) {
                              setState(() {
                                double newX = _identityPosition.x + (details.delta.dx / (constraints.maxWidth / 2));
                                double newY = _identityPosition.y + (details.delta.dy / (constraints.maxHeight / 2));
                                _identityPosition = Alignment(newX.clamp(-1.0, 1.0), newY.clamp(-1.0, 1.0));
                                _isDraggingIdentity = true;
                              });
                            },
                            onPanEnd: (_) => setState(() => _isDraggingIdentity = false),
                            child: _buildBottomIdentityBar(),
                          ),
                        ),
                      ),

                      if (WatermarkSettings.showWatermark)
                        Align(
                          alignment: const Alignment(0, 0.95),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Text(
                              'made in Quick Post Maker',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.5,
                                color: _watermarkColor,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomIdentityBar() {
    final hasProfile = _profileImage != null;
    final displayName = _displayNameController.text.isEmpty
        ? 'Username'
        : _displayNameController.text;
    final username = _usernameController.text.isEmpty
        ? '@yourhandle'
        : _usernameController.text;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.black.withOpacity(0.06),
            backgroundImage: hasProfile ? FileImage(_profileImage!) : null,
            child: hasProfile
                ? null
                : const Icon(Icons.person, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                displayName,
                style: TextStyle(
                  fontFamily: _displayNameFont?.family,
                  fontWeight: _displayNameFont?.weight ?? FontWeight.w600,
                  fontStyle: _displayNameFont?.style ?? FontStyle.normal,
                  fontSize: 12,
                  color: _displayNameColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                username,
                style: TextStyle(
                  fontFamily: _handleFont?.family,
                  fontWeight: _handleFont?.weight ?? FontWeight.w400,
                  fontStyle: _handleFont?.style ?? FontStyle.normal,
                  fontSize: 10,
                  color: _usernameColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
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
              height: 240,
              padding: const EdgeInsets.all(12),
              child: SingleChildScrollView(
                child: _buildActiveTabContent(),
              ),
            ),
          _buildControlTabs(),
        ],
      ),
    );
  }

  Future<void> _saveAsImage() async {
    try {
      if (_isBulkMode && _bulkQuotes.isNotEmpty) {
        // Bulk saving logic
        final int total = _bulkQuotes.length;
        int savedCount = 0;

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: const Text('Generating Posts'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(value: savedCount / total),
                  const SizedBox(height: 16),
                  Text('Generated $savedCount of $total posts...'),
                ],
              ),
            ),
          ),
        );

        for (int i = 0; i < total; i++) {
          setState(() {
            _currentBulkIndex = i;
          });
          // Small delay to ensure UI updates before capture
          await Future.delayed(const Duration(milliseconds: 150));
          await ImageGenerator.savePostToGallery(
            text: '',
            templateKey: _previewKey,
            outputWidth: _selectedAspectIndex == 2 ? 1080 : (_selectedAspectIndex == 3 ? 1920 : 1080),
            outputHeight: _selectedAspectIndex == 2 ? 1920 : (_selectedAspectIndex == 3 ? 1080 : (_selectedAspectIndex == 0 ? 1350 : 1080)),
          );
          savedCount++;
        }

        Navigator.pop(context); // Close progress dialog
        _showSuccessSnackBar('$total posts saved to gallery!');
        AppReviewService().requestReview();
      } else {
        final result = await ImageGenerator.savePostToGallery(
          text: '',
          templateKey: _previewKey,
          outputWidth: _selectedAspectIndex == 2 ? 1080 : (_selectedAspectIndex == 3 ? 1920 : 1080),
          outputHeight: _selectedAspectIndex == 2 ? 1920 : (_selectedAspectIndex == 3 ? 1080 : (_selectedAspectIndex == 0 ? 1350 : 1080)),
        );
        if (result != null) {
          _showSuccessSnackBar('Saved to gallery!');
          AppReviewService().requestReview();
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving: $e')),
      );
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
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
    if (_selectedTabIndex == 7) return _buildIdentityPositionSection();
    return _buildBackgroundOptionsSection();
  }

  Widget _buildBackgroundOptionsSection() {
    if (_backgroundImage == null) {
      return const Center(
        child: Text('Add a background image first to see options'),
      );
    }

    final fits = [
      {'label': 'Cover', 'fit': BoxFit.cover},
      {'label': 'Contain', 'fit': BoxFit.contain},
      {'label': 'Fill', 'fit': BoxFit.fill},
      {'label': 'Fit Width', 'fit': BoxFit.fitWidth},
      {'label': 'Fit Height', 'fit': BoxFit.fitHeight},
      {'label': 'None', 'fit': BoxFit.none},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Image Fit', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: fits.map((f) {
            final isSelected = _backgroundFit == f['fit'];
            return ChoiceChip(
              label: Text(f['label'] as String),
              selected: isSelected,
              onSelected: (val) {
                if (val) {
                  setState(() {
                    _backgroundFit = f['fit'] as BoxFit;
                  });
                }
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        _buildFilterSlider('Scale', _backgroundScale, 0.5, 3.0, (val) => _backgroundScale = val),
        _buildFilterSlider('Blur', _backgroundBlur, 0.0, 15.0, (val) => _backgroundBlur = val),
        _buildFilterSlider('Brightness', _backgroundBrightness, 0.0, 2.0, (val) => _backgroundBrightness = val),
        _buildFilterSlider('Saturation', _backgroundSaturation, 0.0, 2.0, (val) => _backgroundSaturation = val),
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            onPressed: () {
              setState(() {
                _backgroundOffset = Offset.zero;
                _backgroundScale = 1.0;
                _backgroundBlur = 0.0;
                _backgroundBrightness = 1.0;
                _backgroundSaturation = 1.0;
              });
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Reset All Filters'),
          ),
        ),
        const Text(
          'Tip: Drag the background image in the preview to adjust its position.',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildFilterSlider(String label, double value, double min, double max, Function(double) onChanged) {
    return Row(
      children: [
        SizedBox(width: 80, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: (val) {
              setState(() {
                onChanged(val);
              });
            },
          ),
        ),
        SizedBox(width: 35, child: Text(value.toStringAsFixed(1))),
      ],
    );
  }

  Widget _buildControlTabs() {
    final tabs = [
      {'icon': Icons.format_quote, 'label': 'Text', 'color': Colors.teal},
      {'icon': Icons.font_download_outlined, 'label': 'Font', 'color': Colors.green},
      {'icon': Icons.format_color_text, 'label': 'Colors', 'color': Colors.deepOrange},
      {'icon': Icons.auto_awesome, 'label': 'Effects', 'color': Colors.purple},
      {'icon': Icons.format_size, 'label': 'Spacing', 'color': Colors.indigo},
      {'icon': Icons.format_align_center, 'label': 'Align', 'color': Colors.blueGrey},
      {'icon': Icons.open_with, 'label': 'Quote Pos', 'color': Colors.brown},
      {'icon': Icons.account_circle, 'label': 'Identity Pos', 'color': Colors.pink},
      {'icon': Icons.wallpaper, 'label': 'BG Options', 'color': Colors.blue},
    ];

    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 4),
            child: ElevatedButton(
              onPressed: _saveAsImage,
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
                      color: isSelected && _isTabContentExpanded ? baseColor.withOpacity(0.12) : Colors.transparent,
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
                            fontWeight: isSelected && _isTabContentExpanded ? FontWeight.bold : FontWeight.normal,
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.format_quote, color: Colors.teal[600], size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    'Text Input',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () {
                      if (_isBulkMode) {
                        _importBulkFromMyQuotes();
                      } else {
                        _importFromMyQuotes();
                      }
                    },
                    icon: const Icon(Icons.bookmark, size: 16),
                    label: const Text('My Quotes', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
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
                          _bulkQuotes.clear();
                          _currentBulkIndex = 0;
                        }
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (!_isBulkMode) ...[
            TextField(
              controller: _quoteController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Enter your quote...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(10),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _authorController,
              decoration: const InputDecoration(
                hintText: 'Author (optional)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            const Text('Identity'),
            const SizedBox(height: 4),
            TextField(
              controller: _displayNameController,
              decoration: const InputDecoration(
                hintText: 'Your theme page',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                hintText: '@yourhandle',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                GestureDetector(
                  onTap: _pickProfileImage,
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                    child: _profileImage == null
                        ? const Icon(Icons.camera_alt, size: 18, color: Colors.grey)
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Tap to add/change profile picture',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _importCsv,
                    icon: const Icon(Icons.file_present),
                    label: const Text('Import CSV'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pasteBulkText,
                    icon: const Icon(Icons.paste),
                    label: const Text('Paste Text'),
                  ),
                ),
              ],
            ),
            if (_bulkQuotes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '${_bulkQuotes.length} quotes loaded',
                style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'First 3 lines:',
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
              ..._bulkQuotes.take(3).map((q) => Text(
                    '${q['quote']} - ${q['author']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11),
                  )),
              TextButton(
                onPressed: () => setState(() {
                  _bulkQuotes.clear();
                  _currentBulkIndex = 0;
                }),
                child: const Text('Clear All', style: TextStyle(color: Colors.red, fontSize: 12)),
              ),
            ],
          ],
        ],
      ),
    );
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
        _quoteController.text = selected.text;
        _authorController.text = selected.author;
      });
    }
  }

  Future<void> _importBulkFromMyQuotes() async {
    final dynamic selected = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MyQuotesScreen(multiSelectMode: true),
      ),
    );
    if (selected != null && selected is List<QuoteItem> && selected.isNotEmpty) {
      final List<Map<String, String>> loaded = selected.map((q) => {
        'quote': q.text,
        'author': q.author,
      }).toList();
      setState(() {
        _bulkQuotes.addAll(loaded);
        _currentBulkIndex = 0;
      });
    }
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
        List<List<dynamic>> rows = const CsvToListConverter().convert(input, fieldDelimiter: ',');

        List<Map<String, String>> loadedQuotes = [];
        for (var row in rows) {
          if (row.isNotEmpty) {
            loadedQuotes.add({
              'quote': row[0].toString(),
              'author': row.length > 1 ? row[1].toString() : '',
            });
          }
        }

        if (loadedQuotes.isNotEmpty) {
          setState(() {
            _bulkQuotes = loadedQuotes;
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
        title: const Text('Paste Quotes'),
        content: TextField(
          controller: controller,
          maxLines: 10,
          decoration: const InputDecoration(
            hintText: 'Format: Quote | Author (one per line)\nOr just Quote per line.',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final lines = controller.text.split('\n').where((l) => l.trim().isNotEmpty).toList();
              if (lines.isNotEmpty) {
                final List<Map<String, String>> loaded = [];
                for (var line in lines) {
                  if (line.contains('|')) {
                    final parts = line.split('|');
                    loaded.add({
                      'quote': parts[0].trim(),
                      'author': parts.length > 1 ? parts[1].trim() : '',
                    });
                  } else {
                    loaded.add({
                      'quote': line.trim(),
                      'author': '',
                    });
                  }
                }
                setState(() {
                  _bulkQuotes = loaded;
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
    final fonts = getAllFonts();

    Widget buildFontRow({required String label, required bool isAuthor}) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: fonts.length,
              itemBuilder: (context, index) {
                final font = fonts[index];
                final isSelected = isAuthor ? _authorFont == font : _quoteFont == font;
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
                        fontSize: 13,
                      ),
                    ),
                    selectedColor: Colors.green[100],
                    backgroundColor: Colors.grey[100],
                    onSelected: (_) {
                      setState(() {
                        if (isAuthor) {
                          _authorFont = font;
                        } else {
                          _quoteFont = font;
                        }
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

    Widget buildIdentityFontRow({required String label, required bool isHandle}) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: fonts.length,
              itemBuilder: (context, index) {
                final font = fonts[index];
                final isSelected = isHandle ? _handleFont == font : _displayNameFont == font;
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
                        fontSize: 13,
                      ),
                    ),
                    selectedColor: Colors.green[100],
                    backgroundColor: Colors.grey[100],
                    onSelected: (_) {
                      setState(() {
                        if (isHandle) {
                          _handleFont = font;
                        } else {
                          _displayNameFont = font;
                        }
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildFontRow(label: 'Quote font', isAuthor: false),
        const SizedBox(height: 12),
        buildFontRow(label: 'Author font', isAuthor: true),
        const SizedBox(height: 12),
        buildIdentityFontRow(label: 'Username font', isHandle: false),
        const SizedBox(height: 12),
        buildIdentityFontRow(label: 'Handle font', isHandle: true),
      ],
    );
  }

  Widget _buildColorsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Text color'),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _showColorPicker('text'),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _textColor,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey[300]!),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('Background'),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _showColorPicker('background'),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _backgroundColor,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey[300]!),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickBackgroundImage,
                icon: const Icon(Icons.image, size: 18),
                label: Text(_backgroundImage == null ? 'Add bg image' : 'Change bg'),
              ),
            ),
            if (_backgroundImage != null) ...[
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Remove background image',
                onPressed: _removeBackgroundImage,
                icon: const Icon(Icons.close),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('Author color'),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _showColorPicker('author'),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _authorColor,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey[300]!),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('Username color'),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _showColorPicker('display'),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _displayNameColor,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey[300]!),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('Handle color'),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _showColorPicker('handle'),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _usernameColor,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey[300]!),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEffectsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title: const Text('Quote shadow', style: TextStyle(fontWeight: FontWeight.w500)),
          value: _enableQuoteShadow,
          onChanged: (value) {
            setState(() {
              _enableQuoteShadow = value;
            });
          },
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        if (_enableQuoteShadow)
          Padding(
            padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Shadow color', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _showColorPicker('quoteShadow'),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: _quoteShadowColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('X Offset', style: TextStyle(fontSize: 12)),
                    Expanded(
                      child: Slider(
                        value: _quoteShadowOffsetX,
                        min: -20,
                        max: 20,
                        onChanged: (v) => setState(() => _quoteShadowOffsetX = v),
                      ),
                    ),
                    Text(_quoteShadowOffsetX.toStringAsFixed(1), style: const TextStyle(fontSize: 11)),
                  ],
                ),
                Row(
                  children: [
                    const Text('Y Offset', style: TextStyle(fontSize: 12)),
                    Expanded(
                      child: Slider(
                        value: _quoteShadowOffsetY,
                        min: -20,
                        max: 20,
                        onChanged: (v) => setState(() => _quoteShadowOffsetY = v),
                      ),
                    ),
                    Text(_quoteShadowOffsetY.toStringAsFixed(1), style: const TextStyle(fontSize: 11)),
                  ],
                ),
                Row(
                  children: [
                    const Text('Blur Radius', style: TextStyle(fontSize: 12)),
                    Expanded(
                      child: Slider(
                        value: _quoteShadowBlur,
                        min: 0,
                        max: 20,
                        onChanged: (v) => setState(() => _quoteShadowBlur = v),
                      ),
                    ),
                    Text(_quoteShadowBlur.toStringAsFixed(1), style: const TextStyle(fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        const Divider(),
        SwitchListTile(
          title: const Text('Author shadow', style: TextStyle(fontWeight: FontWeight.w500)),
          value: _enableAuthorShadow,
          onChanged: (value) {
            setState(() {
              _enableAuthorShadow = value;
            });
          },
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        if (_enableAuthorShadow)
          Padding(
            padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Shadow color', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _showColorPicker('authorShadow'),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: _authorShadowColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('X Offset', style: TextStyle(fontSize: 12)),
                    Expanded(
                      child: Slider(
                        value: _authorShadowOffsetX,
                        min: -20,
                        max: 20,
                        onChanged: (v) => setState(() => _authorShadowOffsetX = v),
                      ),
                    ),
                    Text(_authorShadowOffsetX.toStringAsFixed(1), style: const TextStyle(fontSize: 11)),
                  ],
                ),
                Row(
                  children: [
                    const Text('Y Offset', style: TextStyle(fontSize: 12)),
                    Expanded(
                      child: Slider(
                        value: _authorShadowOffsetY,
                        min: -20,
                        max: 20,
                        onChanged: (v) => setState(() => _authorShadowOffsetY = v),
                      ),
                    ),
                    Text(_authorShadowOffsetY.toStringAsFixed(1), style: const TextStyle(fontSize: 11)),
                  ],
                ),
                Row(
                  children: [
                    const Text('Blur Radius', style: TextStyle(fontSize: 12)),
                    Expanded(
                      child: Slider(
                        value: _authorShadowBlur,
                        min: 0,
                        max: 20,
                        onChanged: (v) => setState(() => _authorShadowBlur = v),
                      ),
                    ),
                    Text(_authorShadowBlur.toStringAsFixed(1), style: const TextStyle(fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        const Divider(),
        SwitchListTile(
          title: const Text('Quote glow', style: TextStyle(fontWeight: FontWeight.w500)),
          value: _enableQuoteGlow,
          onChanged: (value) {
            setState(() {
              _enableQuoteGlow = value;
            });
          },
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        if (_enableQuoteGlow)
          Padding(
            padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Glow color', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _showColorPicker('quoteGlow'),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: _quoteGlowColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Glow radius', style: TextStyle(fontSize: 12)),
                    Expanded(
                      child: Slider(
                        value: _quoteGlowRadius,
                        min: 0,
                        max: 30,
                        onChanged: (v) => setState(() => _quoteGlowRadius = v),
                      ),
                    ),
                    Text(_quoteGlowRadius.toStringAsFixed(1), style: const TextStyle(fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        const Divider(),
        SwitchListTile(
          title: const Text('Author glow', style: TextStyle(fontWeight: FontWeight.w500)),
          value: _enableAuthorGlow,
          onChanged: (value) {
            setState(() {
              _enableAuthorGlow = value;
            });
          },
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        if (_enableAuthorGlow)
          Padding(
            padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Glow color', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _showColorPicker('authorGlow'),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: _authorGlowColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Glow radius', style: TextStyle(fontSize: 12)),
                    Expanded(
                      child: Slider(
                        value: _authorGlowRadius,
                        min: 0,
                        max: 30,
                        onChanged: (v) => setState(() => _authorGlowRadius = v),
                      ),
                    ),
                    Text(_authorGlowRadius.toStringAsFixed(1), style: const TextStyle(fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSpacingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Letter Spacing: ${_letterSpacing.toStringAsFixed(1)}'),
        Slider(
          value: _letterSpacing,
          min: -2.0,
          max: 10.0,
          onChanged: (v) => setState(() => _letterSpacing = v),
        ),
        const SizedBox(height: 4),
        Text('Line Height: ${_lineHeight.toStringAsFixed(2)}'),
        Slider(
          value: _lineHeight,
          min: 0.8,
          max: 2.0,
          onChanged: (v) => setState(() => _lineHeight = v),
        ),
        const SizedBox(height: 4),
        Text('Font Size: ${(_fontSize * 100).toInt()}%'),
        Slider(
          value: _fontSize,
          min: 0.5,
          max: 2.0,
          onChanged: (v) => setState(() => _fontSize = v),
        ),
      ],
    );
  }

  Future<void> _pickProfileImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? file = await picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      setState(() {
        _profileImage = File(file.path);
      });
    }
  }

  Future<void> _showColorPicker(String type) async {
    final Color current;
    String title;

    if (type == 'text') {
      current = _textColor;
      title = 'Text Color';
    } else if (type == 'background') {
      current = _backgroundColor;
      title = 'Background Color';
    } else if (type == 'author') {
      current = _authorColor;
      title = 'Author Color';
    } else if (type == 'display') {
      current = _displayNameColor;
      title = 'Username Color';
    } else if (type == 'handle') {
      current = _usernameColor;
      title = 'Handle Color';
    } else if (type == 'quoteShadow') {
      current = _quoteShadowColor;
      title = 'Quote Shadow Color';
    } else if (type == 'quoteGlow') {
      current = _quoteGlowColor;
      title = 'Quote Glow Color';
    } else if (type == 'authorShadow') {
      current = _authorShadowColor;
      title = 'Author Shadow Color';
    } else {
      current = _authorGlowColor;
      title = 'Author Glow Color';
    }

    Color selectedColor = current;

    await showDialog(
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
                initialColor: current,
                onColorChanged: (color) => selectedColor = color,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      if (type == 'text') {
                        _textColor = selectedColor;
                      } else if (type == 'background') {
                        _backgroundColor = selectedColor;
                      } else if (type == 'author') {
                        _authorColor = selectedColor;
                      } else if (type == 'display') {
                        _displayNameColor = selectedColor;
                      } else if (type == 'handle') {
                        _usernameColor = selectedColor;
                      } else if (type == 'quoteShadow') {
                        _quoteShadowColor = selectedColor;
                      } else if (type == 'quoteGlow') {
                        _quoteGlowColor = selectedColor;
                      } else if (type == 'authorShadow') {
                        _authorShadowColor = selectedColor;
                      } else {
                        _authorGlowColor = selectedColor;
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

  Future<void> _savePost() async {
    final bool hasQuote = _quoteController.text.trim().isNotEmpty;
    if (!hasQuote) return;

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

      final String? savedPath = await ImageGenerator.savePostToGallery(
        text: _quoteController.text,
        imageFile: null,
        transform: null,
        selectedFont: _quoteFont,
        templateKey: _previewKey,
        outputWidth: exportWidth,
        outputHeight: exportHeight,
      );

      if (!mounted) return;
      Navigator.of(context).pop();

      AppReviewService().incrementExportCount();
      AppReviewService().checkAndRequestReview();

      if (savedPath != null) {
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
            return AlertDialog(
              title: const Text('Post saved'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(savedPath, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Text('Resolution: ${exportWidth}x${exportHeight}px'),
                  if (fileSizeKb > 0)
                    Text('File size: ${fileSizeKb} KB'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.of(context).pop();

                    if (savedPath != null) {
                      try {
                        final file = File(savedPath);
                        if (await file.exists()) {
                          await OpenFile.open(savedPath);
                        }
                      } catch (_) {}
                    }
                  },
                  child: const Text('Open'),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving post: $e')),
      );
    }
  }

  int _textAlignToIndex(TextAlign align) {
    switch (align) {
      case TextAlign.left:
        return 0;
      case TextAlign.center:
        return 1;
      case TextAlign.right:
        return 2;
      default:
        return 1;
    }
  }

  TextAlign _indexToTextAlign(int index) {
    switch (index) {
      case 0:
        return TextAlign.left;
      case 2:
        return TextAlign.right;
      case 1:
      default:
        return TextAlign.center;
    }
  }

  FontInfo? _fontFromFamily(String? family) {
    if (family == null) return null;
    final fonts = getAllFonts();
    for (final f in fonts) {
      if (f.family == family) {
        return f;
      }
    }
    return null;
  }

  Future<void> _saveCurrentAsTemplate() async {
    final nameController = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Save as template'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Template name',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(nameController.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    final name = result;
    if (name == null || name.isEmpty) return;
    
    // If a template with this name already exists, overwrite it
    final existingTemplates = await InstagramQuoteTemplateService.getTemplates(handleOnly: false);
    InstagramQuoteTemplate? existing;
    for (final t in existingTemplates) {
      if (t.name == name) {
        existing = t;
        break;
      }
    }

    final template = InstagramQuoteTemplate(
      id: existing?.id ?? '',
      name: name,
      displayName: _displayNameController.text,
      username: _usernameController.text,
      quoteFontFamily: _quoteFont?.family,
      authorFontFamily: _authorFont?.family,
      displayNameFontFamily: _displayNameFont?.family,
      handleFontFamily: _handleFont?.family,
      backgroundColorValue: _backgroundColor.value,
      quoteColorValue: _textColor.value,
      authorColorValue: _authorColor.value,
      displayNameColorValue: _displayNameColor.value,
      usernameColorValue: _usernameColor.value,
      enableQuoteShadow: _enableQuoteShadow,
      enableAuthorShadow: _enableAuthorShadow,
      enableQuoteGlow: _enableQuoteGlow,
      enableAuthorGlow: _enableAuthorGlow,
      quoteShadowColorValue: _quoteShadowColor.value,
      authorShadowColorValue: _authorShadowColor.value,
      quoteGlowColorValue: _quoteGlowColor.value,
      authorGlowColorValue: _authorGlowColor.value,
      quoteGlowRadius: _quoteGlowRadius,
      authorGlowRadius: _authorGlowRadius,
      textAlignIndex: _textAlignToIndex(_textAlign),
      textPosX: _textPosition.x,
      textPosY: _textPosition.y,
      identityPosX: _identityPosition.x,
      identityPosY: _identityPosition.y,
      letterSpacing: _letterSpacing,
      fontSizeMultiplier: _fontSize,
      aspectIndex: _selectedAspectIndex,
    );

    await InstagramQuoteTemplateService.saveTemplate(template, handleOnly: false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Template "$name" saved')),
    );
  }

  Future<void> _showTemplatePicker() async {
    final templates = await InstagramQuoteTemplateService.getTemplates(handleOnly: false);
    if (!mounted) return;

    final selected = await showModalBottomSheet<InstagramQuoteTemplate?>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        if (templates.isEmpty) {
          return const SafeArea(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: Text('No templates yet. Save your current style as a template.'),
              ),
            ),
          );
        }
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 8, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Saved templates',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(null),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: templates.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final t = templates[index];
                    return ListTile(
                      title: Text(t.name),
                      subtitle: t.username.isNotEmpty
                          ? Text(t.username, style: const TextStyle(fontSize: 12))
                          : null,
                      onTap: () => Navigator.of(context).pop(t),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Edit',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => Navigator.of(context).pop(t),
                          ),
                          IconButton(
                            tooltip: 'Rename',
                            icon: const Icon(Icons.drive_file_rename_outline),
                            onPressed: () async {
                              final controller = TextEditingController(text: t.name);
                              final newName = await showDialog<String?>(
                                context: context,
                                builder: (context) {
                                  return AlertDialog(
                                    title: const Text('Rename template'),
                                    content: TextField(
                                      controller: controller,
                                      decoration: const InputDecoration(
                                        labelText: 'Template name',
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(null),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(controller.text.trim()),
                                        child: const Text('Save'),
                                      ),
                                    ],
                                  );
                                },
                              );

                              if (newName != null && newName.isNotEmpty && newName != t.name) {
                                t.name = newName;
                                await InstagramQuoteTemplateService.saveTemplate(t, handleOnly: false);
                              }
                            },
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              await InstagramQuoteTemplateService.deleteTemplate(t.id, handleOnly: false);
                              if (Navigator.of(context).canPop()) {
                                Navigator.of(context).pop(null);
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selected == null) return;

    setState(() {
      _displayNameController.text = selected.displayName;
      _usernameController.text = selected.username;

      _quoteFont = _fontFromFamily(selected.quoteFontFamily);
      _authorFont = _fontFromFamily(selected.authorFontFamily);
      _displayNameFont = _fontFromFamily(selected.displayNameFontFamily);
      _handleFont = _fontFromFamily(selected.handleFontFamily);

      _backgroundColor = Color(selected.backgroundColorValue);
      _textColor = Color(selected.quoteColorValue);
      _authorColor = Color(selected.authorColorValue);
      _displayNameColor = Color(selected.displayNameColorValue);
      _usernameColor = Color(selected.usernameColorValue);

      _enableQuoteShadow = selected.enableQuoteShadow;
      _enableAuthorShadow = selected.enableAuthorShadow;
      _enableQuoteGlow = selected.enableQuoteGlow;
      _enableAuthorGlow = selected.enableAuthorGlow;

      _quoteShadowColor = Color(selected.quoteShadowColorValue);
      _authorShadowColor = Color(selected.authorShadowColorValue);
      _quoteGlowColor = Color(selected.quoteGlowColorValue);
      _authorGlowColor = Color(selected.authorGlowColorValue);

      _quoteGlowRadius = selected.quoteGlowRadius;
      _authorGlowRadius = selected.authorGlowRadius;

      _textAlign = _indexToTextAlign(selected.textAlignIndex);
      _textPosition = Alignment(selected.textPosX, selected.textPosY);
      _identityPosition = Alignment(selected.identityPosX, selected.identityPosY);

      _letterSpacing = selected.letterSpacing;
      _fontSize = selected.fontSizeMultiplier;
      _selectedAspectIndex = selected.aspectIndex;
    });
  }
}
