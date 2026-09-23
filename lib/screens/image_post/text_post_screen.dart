import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/app_theme.dart';
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
import '../../services/my_quotes_service.dart';
import 'package:uuid/uuid.dart';

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

  Map<String, dynamic> toMap() {
    return {
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'color': color.value,
      'opacity': opacity,
      'radius': radius,
      'isTop': isTop,
    };
  }

  factory _OverlayPatch.fromMap(Map<String, dynamic> map) {
    return _OverlayPatch(
      x: map['x']?.toDouble() ?? 0.5,
      y: map['y']?.toDouble() ?? 0.5,
      width: map['width']?.toDouble() ?? 0.2,
      height: map['height']?.toDouble() ?? 0.2,
      color: Color(map['color'] ?? Colors.black.value),
      opacity: map['opacity']?.toDouble() ?? 0.5,
      radius: map['radius']?.toDouble() ?? 8.0,
      isTop: map['isTop'] ?? false,
    );
  }
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

  Map<String, dynamic> toMap() {
    return {
      'path': path,
      'x': x,
      'y': y,
      'scale': scale,
      'opacity': opacity,
      'rotation': rotation,
    };
  }

  factory _OverlayImage.fromMap(Map<String, dynamic> map) {
    return _OverlayImage(
      path: map['path'] ?? '',
      x: map['x']?.toDouble() ?? 0.5,
      y: map['y']?.toDouble() ?? 0.5,
      scale: map['scale']?.toDouble() ?? 0.2,
      opacity: map['opacity']?.toDouble() ?? 1.0,
      rotation: map['rotation']?.toDouble() ?? 0.0,
    );
  }
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
  
  // New unified fields
  double letterSpacing;
  double lineHeight;
  bool showGlow;
  Color glowColor;
  double glowRadius;
  
  // Box properties
  bool showBox;
  Color boxColor;
  double boxOpacity;
  double boxRadius;

  _TextOverlay({
    required this.text,
    this.x = 0.5,
    this.y = 0.5,
    this.fontSize = 24.0,
    this.color = Colors.white,
    this.font,
    this.showShadow = true,
    this.shadowColor = Colors.black,
    this.shadowBlur = 0.0,
    this.shadowOffsetX = 1.0,
    this.shadowOffsetY = 1.0,
    this.textAlign = TextAlign.center,
    this.scale = 1.0,
    this.letterSpacing = 0.0,
    this.lineHeight = 1.0,
    this.showGlow = true,
    this.glowColor = Colors.white,
    this.glowRadius = 10.0,
    this.showBox = false,
    this.boxColor = Colors.white,
    this.boxOpacity = 0.8,
    this.boxRadius = 8.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'x': x,
      'y': y,
      'fontSize': fontSize,
      'color': color.value,
      'font': font?.toMap(),
      'showShadow': showShadow,
      'shadowColor': shadowColor.value,
      'shadowBlur': shadowBlur,
      'shadowOffsetX': shadowOffsetX,
      'shadowOffsetY': shadowOffsetY,
      'textAlign': textAlign.index,
      'scale': scale,
      'letterSpacing': letterSpacing,
      'lineHeight': lineHeight,
      'showGlow': showGlow,
      'glowColor': glowColor.value,
      'glowRadius': glowRadius,
      'showBox': showBox,
      'boxColor': boxColor.value,
      'boxOpacity': boxOpacity,
      'boxRadius': boxRadius,
    };
  }

  factory _TextOverlay.fromMap(Map<String, dynamic> map) {
    return _TextOverlay(
      text: map['text'] ?? '',
      x: map['x']?.toDouble() ?? 0.5,
      y: map['y']?.toDouble() ?? 0.5,
      fontSize: map['fontSize']?.toDouble() ?? 24.0,
      color: Color(map['color'] ?? Colors.white.value),
      font: map['font'] != null ? FontInfo.fromMap(Map<String, dynamic>.from(map['font'])) : null,
      showShadow: map['showShadow'] ?? true,
      shadowColor: Color(map['shadowColor'] ?? Colors.black.value),
      shadowBlur: map['shadowBlur']?.toDouble() ?? 0.0,
      shadowOffsetX: map['shadowOffsetX']?.toDouble() ?? 1.0,
      shadowOffsetY: map['shadowOffsetY']?.toDouble() ?? 1.0,
      textAlign: map['textAlign'] != null ? TextAlign.values[map['textAlign']] : TextAlign.center,
      scale: map['scale']?.toDouble() ?? 1.0,
      letterSpacing: map['letterSpacing']?.toDouble() ?? 0.0,
      lineHeight: map['lineHeight']?.toDouble() ?? 1.0,
      showGlow: map['showGlow'] ?? true,
      glowColor: Color(map['glowColor'] ?? Colors.white.value),
      glowRadius: map['glowRadius']?.toDouble() ?? 10.0,
      showBox: map['showBox'] ?? false,
      boxColor: Color(map['boxColor'] ?? Colors.white.value),
      boxOpacity: map['boxOpacity']?.toDouble() ?? 0.8,
      boxRadius: map['boxRadius']?.toDouble() ?? 8.0,
    );
  }
}

class TextPostScreen extends StatefulWidget {
  const TextPostScreen({super.key});

  @override
  State<TextPostScreen> createState() => _TextPostScreenState();
}

class _TextPostScreenState extends State<TextPostScreen> with WidgetsBindingObserver {
  final TextEditingController _textController = TextEditingController();
  final GlobalKey _previewKey = GlobalKey();

  Timer? _saveDebounce;
  bool _isRestoring = false;

  FontInfo? _selectedFont;
  Color _textColor = Colors.white;
  Color _backgroundColor = Colors.white;
  
  // State variables
  double _fontSize = 0.5; // relative multiplier
  double _lineHeight = 1.0; // Text height multiplier
  double _textScale = 1.0; // Overall scale multiplier
  bool _enableTextShadow = true;
  Color _shadowColor = Colors.black;
  double _shadowOffsetX = 1.0;
  double _shadowOffsetY = 1.0;
  double _shadowBlurRadius = 0.0;
  bool _enableTextGlow = true;
  Color _glowColor = Colors.white;
  double _glowRadius = 10.0;

  // Box styles for main text
  bool _showMainBox = false;
  Color _mainBoxColor = Colors.white;
  double _mainBoxOpacity = 0.8;
  double _mainBoxRadius = 8.0;
  double _letterSpacing = 0.0;

  // Background Image & Adjustments
  File? _bgImage;
  double _brightness = 0.5; // 0.0 to 2.0 (multiplicative/gain)
  double _saturation = 1.0; // 0.0 to 2.0
  double _hue = 0.0;        // -3.14 to 3.14
  final TransformationController _transformationController = TransformationController();

  // Mask Settings
  Color _maskColor = Colors.black;
  double _maskOpacity = 0.5;
  int _maskType = 1; // 0: None, 1: Bottom, 2: Top, 3: Full, 4: Left, 5: Right
  double _maskStart = 0.0;
  double _maskEnd = 1.0;

  int _selectedTabIndex = 0; // 0: Text, 1: Font, 2: Colors, 3: Effects, 4: Spacing, 5: Align, 6: Position, 7: Image, 8: Adjust, 9: Mask
  bool _isTabContentExpanded = false;

  TextAlign _textAlign = TextAlign.center;
  Alignment _textPosition = Alignment.center;

  // Overlays
  List<_OverlayPatch> _patches = [];
  int? _selectedPatchIndex;
  List<_OverlayImage> _imageOverlays = [];
  int? _selectedImageOverlayIndex;
  List<_TextOverlay> _textOverlays = [];
  int _selectedTextIndex = -1; // -1: Main Text, 0..N: Extra layers

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
    WidgetsBinding.instance.addObserver(this);
    _selectedFont = const FontInfo(family: 'KleeOne', displayName: 'Klee One SemiBold', weight: FontWeight.w600, assetPath: 'assets/fonts/KleeOne-SemiBold.ttf');
    _textController.addListener(() {
      if (!_isRestoring) _scheduleSave();
      setState(() {});
    });
    AnalyticsService().setCurrentScreen(screenName: 'Text Post');
    _loadState();
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    if (mounted && !_isRestoring) {
      _scheduleSave();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveDebounce?.cancel();
    _saveStateSync(); // Final save attempt on exit
    _textController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _saveStateSync();
    }
  }

  void _scheduleSave() {
    if (_saveDebounce?.isActive ?? false) _saveDebounce!.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), () {
      _saveStateSync();
    });
  }

  Future<void> _saveStateSync() async {
    if (_isRestoring) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final stateMap = {
        'text': _textController.text,
        'selectedFont': _selectedFont?.toMap(),
        'textColor': _textColor.value,
        'backgroundColor': _backgroundColor.value,
        'fontSize': _fontSize,
        'lineHeight': _lineHeight,
        'textScale': _textScale,
        'enableTextShadow': _enableTextShadow,
        'shadowColor': _shadowColor.value,
        'shadowOffsetX': _shadowOffsetX,
        'shadowOffsetY': _shadowOffsetY,
        'shadowBlurRadius': _shadowBlurRadius,
        'enableTextGlow': _enableTextGlow,
        'glowColor': _glowColor.value,
        'glowRadius': _glowRadius,
        'showMainBox': _showMainBox,
        'mainBoxColor': _mainBoxColor.value,
        'mainBoxOpacity': _mainBoxOpacity,
        'mainBoxRadius': _mainBoxRadius,
        'letterSpacing': _letterSpacing,
        'bgImagePath': _bgImage?.path,
        'brightness': _brightness,
        'saturation': _saturation,
        'hue': _hue,
        'maskColor': _maskColor.value,
        'maskOpacity': _maskOpacity,
        'maskType': _maskType,
        'maskStart': _maskStart,
        'maskEnd': _maskEnd,
        'textAlign': _textAlign.index,
        'textPositionX': _textPosition.x,
        'textPositionY': _textPosition.y,
        'selectedAspectIndex': _selectedAspectIndex,
        'patches': _patches.map((p) => p.toMap()).toList(),
        'imageOverlays': _imageOverlays.map((i) => i.toMap()).toList(),
        'textOverlays': _textOverlays.map((t) => t.toMap()).toList(),
      };
      
      await prefs.setString('text_post_draft_state', jsonEncode(stateMap));
      debugPrint('[TextPostScreen] State saved successfully');
    } catch (e) {
      debugPrint('[TextPostScreen] Error saving state: $e');
    }
  }

  Future<void> _loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stateString = prefs.getString('text_post_draft_state');
      if (stateString != null && stateString.isNotEmpty) {
        final stateMap = jsonDecode(stateString) as Map<String, dynamic>;
        
        setState(() {
          _isRestoring = true;
          
          if (stateMap['text'] != null) {
            _textController.text = stateMap['text'];
          }
          if (stateMap['selectedFont'] != null) {
            _selectedFont = FontInfo.fromMap(Map<String, dynamic>.from(stateMap['selectedFont']));
          }
          if (stateMap['textColor'] != null) _textColor = Color(stateMap['textColor']);
          if (stateMap['backgroundColor'] != null) _backgroundColor = Color(stateMap['backgroundColor']);
          
          _fontSize = stateMap['fontSize']?.toDouble() ?? 0.5;
          _lineHeight = stateMap['lineHeight']?.toDouble() ?? 1.0;
          _textScale = stateMap['textScale']?.toDouble() ?? 1.0;
          _enableTextShadow = stateMap['enableTextShadow'] ?? true;
          if (stateMap['shadowColor'] != null) _shadowColor = Color(stateMap['shadowColor']);
          _shadowOffsetX = stateMap['shadowOffsetX']?.toDouble() ?? 1.0;
          _shadowOffsetY = stateMap['shadowOffsetY']?.toDouble() ?? 1.0;
          _shadowBlurRadius = stateMap['shadowBlurRadius']?.toDouble() ?? 0.0;
          _enableTextGlow = stateMap['enableTextGlow'] ?? true;
          if (stateMap['glowColor'] != null) _glowColor = Color(stateMap['glowColor']);
          _glowRadius = stateMap['glowRadius']?.toDouble() ?? 10.0;
          
          _showMainBox = stateMap['showMainBox'] ?? false;
          if (stateMap['mainBoxColor'] != null) _mainBoxColor = Color(stateMap['mainBoxColor']);
          _mainBoxOpacity = stateMap['mainBoxOpacity']?.toDouble() ?? 0.8;
          _mainBoxRadius = stateMap['mainBoxRadius']?.toDouble() ?? 8.0;
          _letterSpacing = stateMap['letterSpacing']?.toDouble() ?? 0.0;
          
          if (stateMap['bgImagePath'] != null && stateMap['bgImagePath'].toString().isNotEmpty) {
            final f = File(stateMap['bgImagePath']);
            if (f.existsSync()) _bgImage = f;
          }
          
          _brightness = stateMap['brightness']?.toDouble() ?? 0.5;
          _saturation = stateMap['saturation']?.toDouble() ?? 1.0;
          _hue = stateMap['hue']?.toDouble() ?? 0.0;
          
          if (stateMap['maskColor'] != null) _maskColor = Color(stateMap['maskColor']);
          _maskOpacity = stateMap['maskOpacity']?.toDouble() ?? 0.5;
          _maskType = stateMap['maskType'] ?? 1;
          _maskStart = stateMap['maskStart']?.toDouble() ?? 0.0;
          _maskEnd = stateMap['maskEnd']?.toDouble() ?? 1.0;
          
          if (stateMap['textAlign'] != null) _textAlign = TextAlign.values[stateMap['textAlign']];
          _textPosition = Alignment(stateMap['textPositionX']?.toDouble() ?? 0.0, stateMap['textPositionY']?.toDouble() ?? 0.0);
          _selectedAspectIndex = stateMap['selectedAspectIndex'] ?? 0;
          
          if (stateMap['patches'] != null) {
            _patches = (stateMap['patches'] as List).map((p) => _OverlayPatch.fromMap(Map<String, dynamic>.from(p))).toList();
          }
          if (stateMap['imageOverlays'] != null) {
            _imageOverlays = (stateMap['imageOverlays'] as List).map((i) => _OverlayImage.fromMap(Map<String, dynamic>.from(i))).toList();
          }
          if (stateMap['textOverlays'] != null) {
            _textOverlays = (stateMap['textOverlays'] as List).map((t) => _TextOverlay.fromMap(Map<String, dynamic>.from(t))).toList();
          }
          
          _isRestoring = false;
        });
        debugPrint('[TextPostScreen] State restored successfully');
      }
    } catch (e) {
      debugPrint('[TextPostScreen] Error loading state: $e');
      setState(() => _isRestoring = false);
    }
  }

  void _resetState() {
    setState(() {
      _textController.clear();
      _selectedFont = const FontInfo(family: 'KleeOne', displayName: 'Klee One SemiBold', weight: FontWeight.w600, assetPath: 'assets/fonts/KleeOne-SemiBold.ttf');
      _textColor = Colors.white;
      _backgroundColor = Colors.white;
      _fontSize = 0.5;
      _lineHeight = 1.0;
      _textScale = 1.0;
      _enableTextShadow = true;
      _shadowColor = Colors.black;
      _shadowOffsetX = 1.0;
      _shadowOffsetY = 1.0;
      _shadowBlurRadius = 0.0;
      _enableTextGlow = true;
      _glowColor = Colors.white;
      _glowRadius = 10.0;
      _showMainBox = false;
      _mainBoxColor = Colors.white;
      _mainBoxOpacity = 0.8;
      _mainBoxRadius = 8.0;
      _letterSpacing = 0.0;
      
      _bgImage = null;
      _brightness = 0.5;
      _saturation = 1.0;
      _hue = 0.0;
      _maskColor = Colors.black;
      _maskOpacity = 0.5;
      _maskType = 1;
      _maskStart = 0.0;
      _maskEnd = 1.0;
      
      _textAlign = TextAlign.center;
      _textPosition = Alignment.center;
      _selectedAspectIndex = 0;
      
      _patches.clear();
      _imageOverlays.clear();
      _textOverlays.clear();
      _selectedTextIndex = -1;
    });
    
    // Clear the SharedPreferences draft immediately
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('text_post_draft_state');
    });
  }

  @override
  Widget build(BuildContext context) {
    try {
      // Safety check: ensure _selectedTextIndex is valid
      if (_selectedTextIndex >= _textOverlays.length) {
        debugPrint('[TextPostScreen] build() - FIXING INVALID INDEX: $_selectedTextIndex (max: ${_textOverlays.length - 1})');
        _selectedTextIndex = -1;
      }
      
      debugPrint('[TextPostScreen] build() - _selectedTextIndex: $_selectedTextIndex, overlays: ${_textOverlays.length}, images: ${_imageOverlays.length}, patches: ${_patches.length}');
      return Scaffold(
        appBar: AppBar(
          toolbarHeight: 56,
          backgroundColor: Colors.white,
          elevation: 0.5,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87, size: 20),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          titleSpacing: 0,
          title: const Text(
            'Edit Post',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
          ),
          actions: [
            TextButton.icon(
              onPressed: _resetState,
              icon: const Icon(Icons.refresh_rounded, size: 18, color: AppColors.primary),
              label: const Text('Reset', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
            IconButton(
              icon: const Icon(Icons.help_outline_rounded, color: Colors.grey, size: 22),
              onPressed: () {},
            ),
          ],
        ),
        backgroundColor: Colors.grey[50],
        body: SafeArea(
          child: Column(
            children: [
              Expanded(child: () {
                debugPrint('[TextPostScreen] Calling _buildPreviewArea');
                return _buildPreviewArea();
              }()),
              () {
                debugPrint('[TextPostScreen] Calling _buildControlsSection');
                return _buildControlsSection();
              }(),
            ],
          ),
        ),
      );
    } catch (e, stack) {
      debugPrint('[TextPostScreen] CRITICAL ERROR IN build(): $e');
      debugPrint(stack.toString());
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                const Text('A rendering error occurred.', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(e.toString(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.red)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }
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
    final bool isMain = _selectedTextIndex == -1;
    
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
            bool isSelected;
            if (isMain) {
              isSelected = _textPosition == target;
            } else {
              final t = _textOverlays[_selectedTextIndex];
              // Approx comparison for normalized vs Alignment
              final double tx = (t.x * 2 - 1);
              final double ty = (t.y * 2 - 1);
              isSelected = (tx - target.x).abs() < 0.1 && (ty - target.y).abs() < 0.1;
            }

            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    if (isMain) {
                      _textPosition = target;
                    } else {
                      _textOverlays[_selectedTextIndex].x = (target.x + 1) / 2;
                      _textOverlays[_selectedTextIndex].y = (target.y + 1) / 2;
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



    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PRESETS',
          style: TextStyle(
            fontSize: 10, 
            fontWeight: FontWeight.w700, 
            color: Colors.grey[600],
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        buildPresetChips(),
        const SizedBox(height: 24),
        
        _buildSimpleSlider(
          label: 'Horizontal Position (X)',
          value: isMain ? _textPosition.x : _textOverlays[_selectedTextIndex].x,
          min: isMain ? -1.0 : 0.0,
          max: 1.0,
          step: 0.01,
          onChanged: (v) => setState(() {
            if (isMain) {
              _textPosition = Alignment(v, _textPosition.y);
            } else {
              _textOverlays[_selectedTextIndex].x = v;
            }
          }),
          onReset: () => setState(() {
            if (isMain) {
              _textPosition = Alignment(0.0, _textPosition.y);
            } else {
              _textOverlays[_selectedTextIndex].x = 0.5;
            }
          }),
        ),
        
        const SizedBox(height: 16),
        
        _buildSimpleSlider(
          label: 'Vertical Position (Y)',
          value: isMain ? _textPosition.y : _textOverlays[_selectedTextIndex].y,
          min: isMain ? -1.0 : 0.0,
          max: 1.0,
          step: 0.01,
          onChanged: (v) => setState(() {
            if (isMain) {
              _textPosition = Alignment(_textPosition.x, v);
            } else {
              _textOverlays[_selectedTextIndex].y = v;
            }
          }),
          onReset: () => setState(() {
            if (isMain) {
              _textPosition = Alignment(_textPosition.x, 0.0);
            } else {
              _textOverlays[_selectedTextIndex].y = 0.5;
            }
          }),
        ),
      ],
    );
  }

  Widget _buildAlignmentSection() {
    final bool isMain = _selectedTextIndex == -1;
    debugPrint('[TextPostScreen] _buildAlignmentSection() - isMain: $isMain, index: $_selectedTextIndex');
    if (!isMain && (_selectedTextIndex < 0 || _selectedTextIndex >= _textOverlays.length)) {
      return const Center(child: Text('Overlay selection error'));
    }

    final TextAlign currentAlign = isMain ? _textAlign : _textOverlays[_selectedTextIndex].textAlign;

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
            final bool isSelected = currentAlign == align;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isMain) _textAlign = align;
                      else _textOverlays[_selectedTextIndex].textAlign = align;
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
                    child: Column(
                      children: [
                        Icon(
                          opt['icon'] as IconData,
                          size: 18,
                          color: isSelected ? Colors.blueGrey[800] : Colors.grey[600],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          opt['label'] as String,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.blueGrey[800] : Colors.grey[600],
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
    String previewText = _textController.text.isEmpty ? 'Your text here' : _textController.text;

    Widget content = LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          color: _backgroundColor,
          child: Stack(
            fit: StackFit.expand,
            children: [
                // Background Deselector
                if (!isExport)
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _selectedTextIndex = -1; // Reset to main, but we can hide panel
                        _selectedPatchIndex = null;
                        _selectedImageOverlayIndex = null;
                        _isTabContentExpanded = false;
                      }),
                      child: Container(color: Colors.transparent),
                    ),
                  ),

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
                            child: _bgImage != null && _bgImage!.existsSync() 
                                ? Image.file(_bgImage!, fit: BoxFit.cover)
                                : Container(color: Colors.grey, child: const Center(child: Icon(Icons.image_not_supported))),
                          ),
                        ),
                if (_maskType != 0) _buildMaskOverlay(),

                // Patches (Bottom Layer)
                ..._patches.asMap().entries.where((e) => !e.value.isTop).map((entry) {
                  return _buildPatchPreview(entry.value, entry.key, constraints);
                }).toList(),

                Align(
                  alignment: _textPosition,
                  child: GestureDetector(
                    onPanUpdate: isExport ? null : (details) {
                      setState(() {
                        _selectedTextIndex = -1;
                        _selectedPatchIndex = null;
                        _selectedImageOverlayIndex = null;
                        // Approximate movement for Alignment
                        double dx = (details.delta.dx / constraints.maxWidth) * 2;
                        double dy = (details.delta.dy / constraints.maxHeight) * 2;
                        _textPosition = Alignment(
                          (_textPosition.x + dx).clamp(-1.0, 1.0),
                          (_textPosition.y + dy).clamp(-1.0, 1.0),
                        );
                      });
                    },
                    onTap: () => setState(() {
                      _selectedTextIndex = -1;
                      _selectedPatchIndex = null;
                      _selectedImageOverlayIndex = null;
                      _selectedTabIndex = 0;
                      _isTabContentExpanded = true;
                    }),
                    child: _buildSelectionWrapper(
                      isSelected: !isExport && _selectedTextIndex == -1 && _isTabContentExpanded,
                      color: Colors.blueAccent,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _showMainBox ? _mainBoxColor.withOpacity(_mainBoxOpacity) : null,
                            borderRadius: BorderRadius.circular(_mainBoxRadius),
                          ),
                          child: Text(
                            previewText,
                            textAlign: _textAlign,
                            style: TextStyle(
                              fontFamily: _selectedFont?.family,
                              fontWeight: _selectedFont?.weight ?? FontWeight.normal,
                              fontStyle: _selectedFont?.style ?? FontStyle.normal,
                              color: _textColor,
                              fontSize: 24 * _fontSize * _textScale,
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
                ),

                // Patches (Top Layer)
                ..._patches.asMap().entries.where((e) => e.value.isTop).map((entry) {
                  return _buildPatchPreview(entry.value, entry.key, constraints);
                }).toList(),

                // Text Overlays
                ..._textOverlays.asMap().entries.map((entry) {
                  debugPrint('[TextPostScreen] Rendering Text Overlay #${entry.key}');
                  return _buildTextOverlayPreview(entry.value, entry.key, constraints);
                }).toList(),

                // Image Overlays
                ..._imageOverlays.asMap().entries.map((entry) {
                  return _buildImageOverlayPreview(entry.value, entry.key, constraints);
                }).toList(),
            ],
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
    debugPrint('[TextPostScreen] _buildPreviewArea start');
    return Column(
      children: [
        Expanded(
          child: Center(
            child: LayoutBuilder(
              builder: (context, boxConstraints) {
                // Ensure we have a finite height for the AspectRatio
                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: boxConstraints.maxHeight,
                    maxWidth: boxConstraints.maxWidth,
                  ),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: _buildPreviewSection(),
                    ),
                  ),
                );
              }
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildControlsSection() {
    debugPrint('[TextPostScreen] _buildControlsSection start');
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
    Widget content;
    if (_selectedTabIndex == 0) content = _buildTextSection();
    else if (_selectedTabIndex == 1) content = _buildFontSection();
    else if (_selectedTabIndex == 2) content = _buildColorsSection();
    else if (_selectedTabIndex == 3) content = _buildEffectsSection();
    else if (_selectedTabIndex == 4) content = _buildSpacingSection();
    else if (_selectedTabIndex == 5) content = _buildAlignmentSection();
    else if (_selectedTabIndex == 6) content = _buildPositionSection();
    else if (_selectedTabIndex == 7) content = _buildImageSection();
    else if (_selectedTabIndex == 8) content = _buildAdjustSection();
    else if (_selectedTabIndex == 9) content = _buildMaskSection();
    else if (_selectedTabIndex == 10) content = _buildOverlaysSection();
    else if (_selectedTabIndex == 11) content = _buildShapesSection();
    else if (_selectedTabIndex == 12) content = _buildTextOverlaysSection();
    else content = _buildCanvasSection();

    // Interactive Layer Switcher for text-related tabs
    if (_selectedTabIndex <= 6) {
      final String layerName = _selectedTextIndex == -1 ? "MAIN POST" : "LAYER ${_selectedTextIndex + 1}";
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey[100]!, width: 1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: _prevLayer,
                  icon: const Icon(Icons.chevron_left_rounded, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                  color: Colors.blueAccent,
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.layers_rounded, size: 12, color: Colors.blueAccent.withOpacity(0.7)),
                    const SizedBox(width: 6),
                    Text(
                      layerName,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.blueAccent.withOpacity(0.8),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: _nextLayer,
                  icon: const Icon(Icons.chevron_right_rounded, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                  color: Colors.blueAccent,
                ),
              ],
            ),
          ),
          content,
        ],
      );
    }

    return content;
  }

  Widget _buildControlTabs() {
    final tabs = [
      {'icon': Icons.text_fields_rounded, 'label': 'Text', 'color': Colors.blue},
      {'icon': Icons.font_download_rounded, 'label': 'Font', 'color': Colors.indigo},
      {'icon': Icons.palette_rounded, 'label': 'Colors', 'color': Colors.deepOrange},
      {'icon': Icons.auto_awesome_rounded, 'label': 'Effects', 'color': Colors.purple},
      {'icon': Icons.format_size_rounded, 'label': 'Spacing', 'color': Colors.teal},
      {'icon': Icons.format_align_center_rounded, 'label': 'Align', 'color': Colors.blueGrey},
      {'icon': Icons.open_with_rounded, 'label': 'Position', 'color': Colors.brown},
      {'icon': Icons.image_rounded, 'label': 'Image', 'color': Colors.blue},
      {'icon': Icons.tune_rounded, 'label': 'Adjust', 'color': Colors.orange},
      {'icon': Icons.gradient_rounded, 'label': 'Mask', 'color': Colors.cyan},
      {'icon': Icons.photo_library_rounded, 'label': 'Overlays', 'color': Colors.deepPurple},
      {'icon': Icons.layers_rounded, 'label': 'Shapes', 'color': Colors.pink},
      {'icon': Icons.add_comment_rounded, 'label': 'Layer +', 'color': Colors.blueAccent},
      {'icon': Icons.aspect_ratio_rounded, 'label': 'Canvas', 'color': Colors.blueGrey},
    ];

    return Container(
      height: 65,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!, width: 1)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          // Circular Export Button
          Material(
            color: Colors.blueAccent,
            borderRadius: BorderRadius.circular(12),
            elevation: 0,
            child: InkWell(
              onTap: _savePost,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                child: const Icon(Icons.download_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 8),
          VerticalDivider(width: 1, indent: 14, endIndent: 14, color: Colors.grey[200]),
          const SizedBox(width: 4),
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
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 56,
                    decoration: BoxDecoration(
                      color: isSelected && _isTabContentExpanded
                          ? baseColor.withOpacity(0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          tab['icon'] as IconData,
                          size: 18,
                          color: isSelected && _isTabContentExpanded
                              ? baseColor
                              : Colors.grey[400],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tab['label'] as String,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: isSelected && _isTabContentExpanded 
                                ? FontWeight.w700 
                                : FontWeight.w500,
                            color: isSelected && _isTabContentExpanded
                                ? baseColor
                                : Colors.grey[500],
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
    debugPrint('[TextPostScreen] _buildTextSection start');
    final bool isMain = _selectedTextIndex == -1;
    
    // Safety check for index
    if (!isMain && (_selectedTextIndex < 0 || _selectedTextIndex >= _textOverlays.length)) {
      return const Center(child: Text('Please select a valid layer'));
    }

    final TextEditingController effectiveController;
    if (isMain) {
      effectiveController = _textController;
    } else {
      final overlay = _textOverlays[_selectedTextIndex];
      effectiveController = TextEditingController(text: overlay.text);
      // Only set selection if length is non-negative (it always is, but safe)
      if (overlay.text.isNotEmpty) {
        effectiveController.selection = TextSelection.fromPosition(
          TextPosition(offset: overlay.text.length),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'CONTENT',
              style: TextStyle(
                fontSize: 11, 
                fontWeight: FontWeight.w700, 
                color: Colors.grey[600],
                letterSpacing: 1.2,
              ),
            ),
            Row(
              children: [
                // My Quotes Button
                GestureDetector(
                  onTap: _importFromMyQuotes,
                  child: Row(
                    children: [
                      Icon(Icons.format_quote_rounded, size: 14, color: Colors.blueGrey[600]),
                      const SizedBox(width: 4),
                      Text(
                        'MY QUOTES',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.blueGrey[700],
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Save to My Quotes Button
                GestureDetector(
                  onTap: () => _saveToMyQuotes(effectiveController.text),
                  child: Row(
                    children: [
                      Icon(Icons.bookmark_add_outlined, size: 14, color: Colors.green[600]),
                      const SizedBox(width: 4),
                      Text(
                        'ADD QUOTE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.green[700],
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Add Layer Button
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _textOverlays.add(_TextOverlay(
                        text: 'New Text',
                        font: _selectedFont,
                        color: _textColor,
                      ));
                      _selectedTextIndex = _textOverlays.length - 1;
                    });
                  },
                  child: Row(
                    children: [
                      Icon(Icons.add_circle_outline_rounded, size: 14, color: Colors.blueAccent),
                      const SizedBox(width: 4),
                      Text(
                        'ADD LAYER',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.blueAccent,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: effectiveController,
          maxLines: 5, // Increased for better visibility
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: Colors.black87),
          decoration: InputDecoration(
            hintText: isMain ? 'Type your message here...' : 'Edit overlay text...',
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            suffixIcon: IconButton(
              icon: const Icon(Icons.cancel, size: 20, color: Colors.grey),
              onPressed: () {
                effectiveController.clear();
                setState(() {
                  if (!isMain && _selectedTextIndex >= 0 && _selectedTextIndex < _textOverlays.length) {
                    _textOverlays[_selectedTextIndex].text = '';
                  }
                });
              },
            ),
          ),
          onChanged: (v) {
            setState(() {
              if (isMain) {
                // _textController handles its own state, but we notify listeners
              } else if (_selectedTextIndex >= 0 && _selectedTextIndex < _textOverlays.length) {
                _textOverlays[_selectedTextIndex].text = v;
              }
            });
          },
        ),
        const SizedBox(height: 12),
      ],

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
        HorizontalFontSelector(
          selectedFont: _selectedTextIndex == -1 
              ? _selectedFont 
              : (_selectedTextIndex < _textOverlays.length ? _textOverlays[_selectedTextIndex].font : null),
          onFontSelected: (font) {
            setState(() {
              if (_selectedTextIndex == -1) {
                _selectedFont = font;
              } else if (_selectedTextIndex < _textOverlays.length) {
                _textOverlays[_selectedTextIndex].font = font;
              }
            });
          },
        ),
      ],
    );
  }

  Widget _buildColorsSection() {
    final bool isMain = _selectedTextIndex == -1;
    
    // Safety check for index
    if (!isMain && (_selectedTextIndex < 0 || _selectedTextIndex >= _textOverlays.length)) {
      return const Center(child: Text('Please select a valid layer'));
    }

    final Color activeTextColor = isMain ? _textColor : _textOverlays[_selectedTextIndex].color;
    final Color activeBgColor = isMain ? _backgroundColor : Colors.transparent; // Extra layers don't have bg color yet

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
            currentColor: activeTextColor,
            onColorSelected: (color) => setState(() {
              if (isMain) _textColor = color;
              else _textOverlays[_selectedTextIndex].color = color;
            }),
            onPickCustom: () => _showColorPicker('text', textIndex: _selectedTextIndex),
            allowTransparent: false,
          ),
          const SizedBox(height: 16),
          _buildColorPickerRow(
            label: isMain ? 'Canvas Background' : 'Box Color',
            currentColor: isMain ? _backgroundColor : _textOverlays[_selectedTextIndex].boxColor,
            onColorSelected: (color) => setState(() {
              if (isMain) _backgroundColor = color;
              else _textOverlays[_selectedTextIndex].boxColor = color;
            }),
            onPickCustom: () => _showColorPicker(isMain ? 'background' : 'box', textIndex: _selectedTextIndex),
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
    final bool isMain = _selectedTextIndex == -1;
    
    // Safety check for index
    if (!isMain && (_selectedTextIndex < 0 || _selectedTextIndex >= _textOverlays.length)) {
      return const Center(child: Text('Please select a valid layer'));
    }

    final bool showShadow = isMain ? _enableTextShadow : _textOverlays[_selectedTextIndex].showShadow;
    final Color shadowColor = isMain ? _shadowColor : _textOverlays[_selectedTextIndex].shadowColor;
    final double shadowX = isMain ? _shadowOffsetX : _textOverlays[_selectedTextIndex].shadowOffsetX;
    final double shadowY = isMain ? _shadowOffsetY : _textOverlays[_selectedTextIndex].shadowOffsetY;
    final double shadowBlur = isMain ? _shadowBlurRadius : _textOverlays[_selectedTextIndex].shadowBlur;

    final bool showGlow = isMain ? _enableTextGlow : _textOverlays[_selectedTextIndex].showGlow;
    final Color glowColor = isMain ? _glowColor : _textOverlays[_selectedTextIndex].glowColor;
    final double glowRadius = isMain ? _glowRadius : _textOverlays[_selectedTextIndex].glowRadius;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title: const Text('Text Shadow', style: TextStyle(fontWeight: FontWeight.w500)),
          value: showShadow,
          onChanged: (value) {
            setState(() {
              if (isMain) _enableTextShadow = value;
              else _textOverlays[_selectedTextIndex].showShadow = value;
            });
          },
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        if (showShadow) ...[
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
                    color: shadowColor,
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
            value: shadowX,
            min: -20,
            max: 20,
            onChanged: (v) => setState(() {
              if (isMain) _shadowOffsetX = v;
              else _textOverlays[_selectedTextIndex].shadowOffsetX = v;
            }),
            onReset: () => setState(() {
              if (isMain) _shadowOffsetX = 2.0;
              else _textOverlays[_selectedTextIndex].shadowOffsetX = 2.0;
            }),
            step: 1.0,
          ),
          _buildSimpleSlider(
            label: 'Offset Y',
            value: shadowY,
            min: -20,
            max: 20,
            onChanged: (v) => setState(() {
              if (isMain) _shadowOffsetY = v;
              else _textOverlays[_selectedTextIndex].shadowOffsetY = v;
            }),
            onReset: () => setState(() {
              if (isMain) _shadowOffsetY = 2.0;
              else _textOverlays[_selectedTextIndex].shadowOffsetY = 2.0;
            }),
            step: 1.0,
          ),
          _buildSimpleSlider(
            label: 'Blur',
            value: shadowBlur,
            min: 0,
            max: 20,
            onChanged: (v) => setState(() {
              if (isMain) _shadowBlurRadius = v;
              else _textOverlays[_selectedTextIndex].shadowBlur = v;
            }),
            onReset: () => setState(() {
              if (isMain) _shadowBlurRadius = 5.0;
              else _textOverlays[_selectedTextIndex].shadowBlur = 4.0;
            }),
            step: 1.0,
          ),
          const SizedBox(height: 10),
        ],
        SwitchListTile(
          title: const Text('Text Glow', style: TextStyle(fontWeight: FontWeight.w500)),
          value: showGlow,
          onChanged: (value) {
            setState(() {
              if (isMain) _enableTextGlow = value;
              else _textOverlays[_selectedTextIndex].showGlow = value;
            });
          },
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        if (showGlow) ...[
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
                    color: glowColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildSimpleSlider(
            label: 'Glow Size',
            value: glowRadius,
            min: 0,
            max: 50,
            onChanged: (v) => setState(() {
              if (isMain) _glowRadius = v;
              else _textOverlays[_selectedTextIndex].glowRadius = v;
            }),
            onReset: () => setState(() {
              if (isMain) _glowRadius = 10.0;
              else _textOverlays[_selectedTextIndex].glowRadius = 10.0;
            }),
            step: 1.0,
          ),
        ],
        const Divider(height: 32),
        _buildBoxStyleSection(),
      ],
    );
  }

  Widget _buildBoxStyleSection() {
    final bool isMain = _selectedTextIndex == -1;
    final bool showBox = isMain ? _showMainBox : _textOverlays[_selectedTextIndex].showBox;
    final double boxOpacity = isMain ? _mainBoxOpacity : _textOverlays[_selectedTextIndex].boxOpacity;
    final double boxRadius = isMain ? _mainBoxRadius : _textOverlays[_selectedTextIndex].boxRadius;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.check_box_outline_blank, size: 18, color: Colors.blueGrey),
            const SizedBox(width: 8),
            const Text('Text Box Style', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const Spacer(),
            Switch(
              value: showBox,
              onChanged: (val) => setState(() {
                if (isMain) _showMainBox = val;
                else _textOverlays[_selectedTextIndex].showBox = val;
              }),
            ),
          ],
        ),
        if (showBox) ...[
          const SizedBox(height: 8),
          _buildSimpleSlider(
            label: 'Box Opacity',
            value: boxOpacity,
            min: 0.0,
            max: 1.0,
            onChanged: (v) => setState(() {
              if (isMain) _mainBoxOpacity = v;
              else _textOverlays[_selectedTextIndex].boxOpacity = v;
            }),
            onReset: () => setState(() {
              if (isMain) _mainBoxOpacity = 0.8;
              else _textOverlays[_selectedTextIndex].boxOpacity = 0.8;
            }),
            step: 0.05,
          ),
          _buildSimpleSlider(
            label: 'Corner Radius',
            value: boxRadius,
            min: 0.0,
            max: 50.0,
            onChanged: (v) => setState(() {
              if (isMain) _mainBoxRadius = v;
              else _textOverlays[_selectedTextIndex].boxRadius = v;
            }),
            onReset: () => setState(() {
              if (isMain) _mainBoxRadius = 8.0;
              else _textOverlays[_selectedTextIndex].boxRadius = 8.0;
            }),
            step: 1.0,
          ),
        ],
      ],
    );
  }

  Widget _buildSpacingSection() {
    final bool isMain = _selectedTextIndex == -1;
    debugPrint('[TextPostScreen] _buildSpacingSection() - isMain: $isMain, index: $_selectedTextIndex');
    if (!isMain && (_selectedTextIndex < 0 || _selectedTextIndex >= _textOverlays.length)) {
      return const Center(child: Text('Overlay selection error'));
    }

    final double lSpacing = isMain ? _letterSpacing : _textOverlays[_selectedTextIndex].letterSpacing;
    final double lHeight = isMain ? _lineHeight : _textOverlays[_selectedTextIndex].lineHeight;
    final double fSize = isMain ? _fontSize : _textOverlays[_selectedTextIndex].fontSize / 32.0; // Normalize
    final double tScale = isMain ? _textScale : _textOverlays[_selectedTextIndex].scale;

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
            value: lSpacing,
            min: -2.0,
            max: 10.0,
            onChanged: (v) => setState(() {
              if (isMain) _letterSpacing = v;
              else _textOverlays[_selectedTextIndex].letterSpacing = v;
            }),
            onReset: () => setState(() {
              if (isMain) _letterSpacing = 0.0;
              else _textOverlays[_selectedTextIndex].letterSpacing = 0.0;
            }),
            step: 0.5,
          ),
          const SizedBox(height: 4),
          _buildSimpleSlider(
            label: 'Line Height',
            value: lHeight,
            min: 0.8,
            max: 2.0,
            onChanged: (v) => setState(() {
              if (isMain) _lineHeight = v;
              else _textOverlays[_selectedTextIndex].lineHeight = v;
            }),
            onReset: () => setState(() {
              if (isMain) _lineHeight = 1.2;
              else _textOverlays[_selectedTextIndex].lineHeight = 1.2;
            }),
            step: 0.05,
          ),
          const SizedBox(height: 4),
          _buildSimpleSlider(
            label: 'Font Size',
            value: isMain ? fSize : _textOverlays[_selectedTextIndex].fontSize,
            min: isMain ? 0.5 : 10.0,
            max: isMain ? 2.0 : 200.0,
            onChanged: (v) => setState(() {
              if (isMain) _fontSize = v;
              else _textOverlays[_selectedTextIndex].fontSize = v;
            }),
            onReset: () => setState(() {
              if (isMain) _fontSize = 0.5;
              else _textOverlays[_selectedTextIndex].fontSize = 24.0;
            }),
            step: isMain ? 0.1 : 1.0,
          ),
          const SizedBox(height: 4),
          _buildSimpleSlider(
            label: 'Text Scale',
            value: tScale,
            min: 0.2,
            max: 4.0,
            onChanged: (v) => setState(() {
              if (isMain) _textScale = v;
              else _textOverlays[_selectedTextIndex].scale = v;
            }),
            onReset: () => setState(() {
              if (isMain) _textScale = 1.0;
              else _textOverlays[_selectedTextIndex].scale = 1.0;
            }),
            step: 0.1,
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    final bool hasContent = _textController.text.trim().isNotEmpty || _bgImage != null;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: hasContent ? _savePost : null,
        icon: const Icon(Icons.save),
        label: const Text('Save Post'),
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

  void _nextLayer() {
    setState(() {
      if (_selectedTextIndex == -1) {
        if (_textOverlays.isNotEmpty) {
          _selectedTextIndex = 0;
        }
      } else if (_selectedTextIndex < _textOverlays.length - 1) {
        _selectedTextIndex++;
      } else {
        _selectedTextIndex = -1;
      }
      _selectedPatchIndex = null;
      _selectedImageOverlayIndex = null;
    });
  }

  void _prevLayer() {
    setState(() {
      if (_selectedTextIndex == -1) {
        if (_textOverlays.isNotEmpty) {
          _selectedTextIndex = _textOverlays.length - 1;
        }
      } else if (_selectedTextIndex > 0) {
        _selectedTextIndex--;
      } else {
        _selectedTextIndex = -1;
      }
      _selectedPatchIndex = null;
      _selectedImageOverlayIndex = null;
    });
  }

  Future<void> _importFromMyQuotes() async {
    final selected = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MyQuotesScreen(selectMode: true),
      ),
    );

    if (selected != null && selected is QuoteItem) {
      setState(() {
        if (_selectedTextIndex == -1) {
          _textController.text = selected.text;
        } else if (_selectedTextIndex >= 0 && _selectedTextIndex < _textOverlays.length) {
          _textOverlays[_selectedTextIndex].text = selected.text;
        }
      });
    }
  }

  Future<void> _saveToMyQuotes(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    await MyQuotesService.init();
    final newItem = QuoteItem(
      id: const Uuid().v4(),
      text: trimmed,
      author: '',
      category: 'Saved',
      createdAt: DateTime.now(),
    );
    await MyQuotesService.saveQuote(newItem);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved to My Quotes!', style: TextStyle(fontWeight: FontWeight.bold)),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
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
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
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
            Text(value.toStringAsFixed(max <= 2 ? 2 : 1),
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.indigo)),
          ],
        ),
        Row(
          children: [
            _buildStepButton(Icons.remove, () {
              final newValue = (value - step).clamp(min, max);
              onChanged(newValue);
            }),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                  activeTrackColor: Colors.indigo[400],
                  inactiveTrackColor: Colors.indigo[50],
                  thumbColor: Colors.indigo[600],
                  overlayColor: Colors.indigo.withOpacity(0.1),
                ),
                child: Slider(
                    value: value,
                    min: min,
                    max: max,
                    onChanged: (v) {
                      onChanged(v);
                    }),
              ),
            ),
            _buildStepButton(Icons.add, () {
              final newValue = (value + step).clamp(min, max);
              onChanged(newValue);
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildStepButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(4),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: Colors.indigo.withOpacity(0.05),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: Colors.indigo[700]),
        ),
      ),
    );
  }

  Widget _buildPatchPreview(_OverlayPatch p, int idx, BoxConstraints constraints) {
    final isSelected = !_isExporting && _selectedPatchIndex == idx;
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
            _selectedTabIndex = 11; // Shapes tab
            _isTabContentExpanded = true;
          });
        },
        onTap: () => setState(() {
          _selectedPatchIndex = idx;
          _selectedTabIndex = 11;
          _isTabContentExpanded = true;
        }),
        child: _buildSelectionWrapper(
          isSelected: isSelected,
          color: Colors.blueAccent,
          child: Container(
            decoration: BoxDecoration(
              color: p.color.withOpacity(p.opacity),
              borderRadius: BorderRadius.circular(p.radius * (constraints.maxWidth / 1000)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageOverlayPreview(_OverlayImage img, int idx, BoxConstraints constraints) {
    final isSelected = !_isExporting && _selectedImageOverlayIndex == idx;
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
            _selectedTabIndex = 7; // Image tab
            _isTabContentExpanded = true;
          }),
          onPanUpdate: (d) => setState(() {
            img.x = (img.x + d.delta.dx / constraints.maxWidth).clamp(0.0, 1.0);
            img.y = (img.y + d.delta.dy / constraints.maxHeight).clamp(0.0, 1.0);
          }),
          onTap: () => setState(() {
            _selectedImageOverlayIndex = idx;
            _selectedTabIndex = 7;
            _isTabContentExpanded = true;
          }),
          child: _buildSelectionWrapper(
            isSelected: isSelected,
            color: Colors.blueAccent,
            child: Transform.rotate(
              angle: img.rotation * (math.pi / 180),
              child: Opacity(
                opacity: img.opacity,
                child: Container(
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
      ),
    );
  }

  Widget _buildSelectionWrapper({
    required Widget child,
    required bool isSelected,
    required Color color,
  }) {
    if (!isSelected) return child;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: color.withOpacity(0.8), width: 1.5),
          ),
          child: child,
        ),
        // Corner Handles
        Positioned(top: -4, left: -4, child: _buildHandle(color)),
        Positioned(top: -4, right: -4, child: _buildHandle(color)),
        Positioned(bottom: -4, left: -4, child: _buildHandle(color)),
        Positioned(bottom: -4, right: -4, child: _buildHandle(color)),
      ],
    );
  }

  Widget _buildHandle(Color color) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.5),
      ),
    );
  }

  Widget _buildTextOverlayPreview(_TextOverlay t, int idx, BoxConstraints constraints) {
    final isSelected = !_isExporting && _selectedTextIndex == idx;
    final Color activeColor = Colors.blueAccent;

    return Positioned(
      left: t.x * constraints.maxWidth,
      top: t.y * constraints.maxHeight,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: GestureDetector(
          onPanStart: (_) => setState(() {
            _selectedTextIndex = idx;
          }),
          onPanUpdate: (d) => setState(() {
            t.x = (t.x + d.delta.dx / constraints.maxWidth).clamp(0.0, 1.0);
            t.y = (t.y + d.delta.dy / constraints.maxHeight).clamp(0.0, 1.0);
          }),
          onTap: () => setState(() {
            _selectedTextIndex = idx;
            _selectedTabIndex = 0;
            _isTabContentExpanded = true;
          }),
          child: _buildSelectionWrapper(
            isSelected: isSelected,
            color: activeColor,
            child: Container(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.92 * t.scale),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: t.showBox ? t.boxColor.withOpacity(t.boxOpacity) : null,
                borderRadius: BorderRadius.circular(t.boxRadius),
              ),
              child: Text(
                t.text,
                textAlign: t.textAlign,
                style: TextStyle(
                  fontFamily: t.font?.family,
                  fontWeight: t.font?.weight ?? FontWeight.normal,
                  fontStyle: t.font?.style ?? FontStyle.normal,
                  color: t.color,
                  fontSize: t.fontSize * t.scale,
                  letterSpacing: t.letterSpacing,
                  height: t.lineHeight,
                  shadows: [
                    if (t.showShadow)
                      Shadow(
                        color: t.shadowColor.withOpacity(0.7),
                        offset: Offset(t.shadowOffsetX, t.shadowOffsetY),
                        blurRadius: t.shadowBlur,
                      ),
                    if (t.showGlow)
                      Shadow(
                        color: t.glowColor.withOpacity(0.9),
                        offset: Offset.zero,
                        blurRadius: t.glowRadius,
                      ),
                  ],
                ),
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
            Text(
              'LAYERS',
              style: TextStyle(
                fontSize: 11, 
                fontWeight: FontWeight.w700, 
                color: Colors.grey[600],
                letterSpacing: 1.2,
              ),
            ),
            // Button moved to Text tab
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 140, // Slightly taller for better cards
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 4),
            children: [
              _buildLayerItem(
                title: 'Main Text',
                isSelected: _selectedTextIndex == -1,
                onTap: () => setState(() => _selectedTextIndex = -1),
                isMain: true,
              ),
              ..._textOverlays.asMap().entries.map((entry) {
                return _buildLayerItem(
                  title: entry.value.text.isEmpty ? 'Empty Layer' : entry.value.text,
                  index: entry.key,
                  isSelected: _selectedTextIndex == entry.key,
                  onTap: () => setState(() => _selectedTextIndex = entry.key),
                  onDelete: () => setState(() {
                    _textOverlays.removeAt(entry.key);
                    _selectedTextIndex = -1;
                  }),
                  onMoveUp: entry.key > 0 ? () => setState(() {
                    final t = _textOverlays.removeAt(entry.key);
                    _textOverlays.insert(entry.key - 1, t);
                    _selectedTextIndex = entry.key - 1;
                  }) : null,
                  onMoveDown: entry.key < _textOverlays.length - 1 ? () => setState(() {
                    final t = _textOverlays.removeAt(entry.key);
                    _textOverlays.insert(entry.key + 1, t);
                    _selectedTextIndex = entry.key + 1;
                  }) : null,
                );
              }).toList(),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          "Select a layer above or tap on preview to edit its properties.",
          style: TextStyle(color: Colors.grey, fontSize: 11),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLayerItem({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
    VoidCallback? onDelete,
    VoidCallback? onMoveUp,
    VoidCallback? onMoveDown,
    bool isMain = false,
    int? index,
  }) {
    final Color activeColor = isMain ? Colors.teal : Colors.indigo;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: isSelected ? activeColor.withOpacity(0.08) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? activeColor.withOpacity(0.5) : Colors.grey[200]!,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected ? activeColor : Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      isMain ? 'M' : '${(index ?? 0) + 1}',
                      style: TextStyle(
                        fontSize: 10, 
                        fontWeight: FontWeight.bold, 
                        color: isSelected ? Colors.white : Colors.grey[600],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isMain ? 'Main Post Text' : 'Text Layer',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? activeColor : Colors.grey[500],
                        ),
                      ),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected ? Colors.black87 : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isMain) ...[
                  if (onMoveUp != null || onMoveDown != null)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (onMoveUp != null)
                          GestureDetector(
                            onTap: onMoveUp,
                            child: Icon(Icons.keyboard_arrow_up_rounded, size: 18, color: Colors.grey[400]),
                          ),
                        if (onMoveDown != null)
                          GestureDetector(
                            onTap: onMoveDown,
                            child: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Colors.grey[400]),
                          ),
                      ],
                    ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onDelete,
                    child: Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red[300]),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
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

  void _showColorPicker(String type, {int? textIndex}) {
    Color currentColor;
    String title;

    final targetIndex = textIndex ?? _selectedTextIndex;
    final bool isMain = targetIndex == -1;

    switch (type) {
      case 'text':
        currentColor = isMain ? _textColor : _textOverlays[targetIndex].color;
        title = 'Text Color';
        break;
      case 'background':
        currentColor = _backgroundColor;
        title = 'Background Color';
        break;
      case 'shadow':
        currentColor = isMain ? _shadowColor : _textOverlays[targetIndex].shadowColor;
        title = 'Shadow Color';
        break;
      case 'glow':
        currentColor = isMain ? _glowColor : _textOverlays[targetIndex].glowColor;
        title = 'Glow Color';
        break;
      case 'mask':
        currentColor = _maskColor;
        title = 'Mask Color';
        break;
      case 'box':
        currentColor = isMain ? _mainBoxColor : _textOverlays[targetIndex].boxColor;
        title = 'Box Color';
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
                          if (isMain) _textColor = selectedColor;
                          else _textOverlays[targetIndex].color = selectedColor;
                          break;
                        case 'background':
                          _backgroundColor = selectedColor;
                          break;
                        case 'shadow':
                          if (isMain) _shadowColor = selectedColor;
                          else _textOverlays[targetIndex].shadowColor = selectedColor;
                          break;
                        case 'glow':
                          if (isMain) _glowColor = selectedColor;
                          else _textOverlays[targetIndex].glowColor = selectedColor;
                          break;
                        case 'mask':
                          _maskColor = selectedColor;
                          break;
                        case 'box':
                          if (isMain) _mainBoxColor = selectedColor;
                          else _textOverlays[targetIndex].boxColor = selectedColor;
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

  Future<void> _savePost() async {
    debugPrint('[TextPostScreen] Starting _savePost()');
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
