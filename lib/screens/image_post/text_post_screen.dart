import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../config/app_theme.dart';
import '../../models/quote_item.dart';
import '../../services/analytics_service.dart';
import '../../services/my_quotes_service.dart';
import '../../utils/font_selector.dart';
import '../quotes/my_quotes_screen.dart';
import 'text_post/models/text_post_overlays.dart';
import 'text_post/models/text_post_presets.dart';
import 'text_post/services/text_post_export_service.dart';
import 'text_post/widgets/tabs/text_post_background_tabs.dart';
import 'text_post/widgets/tabs/text_post_effects_tab.dart';
import 'text_post/widgets/tabs/text_post_layers_tabs.dart';
import 'text_post/widgets/tabs/text_post_layout_tabs.dart';
import 'text_post/widgets/tabs/text_post_typography_tabs.dart';
import 'text_post/widgets/text_post_preview_canvas.dart';
import 'text_post/widgets/text_post_shared_controls.dart';

/// Full-featured editor screen for Simple Text Post with multi-layer text,
/// background photos/masks, sticker overlays, shapes, and draft persistence.
class TextPostScreen extends StatefulWidget {
  const TextPostScreen({super.key});

  @override
  State<TextPostScreen> createState() => _TextPostScreenState();
}

class _TextPostScreenState extends State<TextPostScreen>
    with WidgetsBindingObserver {
  final TextEditingController _textController = TextEditingController();
  final GlobalKey _previewKey = GlobalKey();
  final TransformationController _transformationController =
      TransformationController();

  Timer? _saveDebounce;
  Timer? _undoBatchTimer;
  bool _isRestoring = false;
  bool _isUndoingOrRedoing = false;
  final List<Map<String, dynamic>> _undoStack = [];
  final List<Map<String, dynamic>> _redoStack = [];
  Map<String, dynamic>? _lastCommittedSnapshot;

  FontInfo? _selectedFont;
  Color _textColor = Colors.white;
  Color _backgroundColor = Colors.white;
  bool _bgUseGradient = false;
  Color _bgColor2 = const Color(0xFF2C5364);
  double _bgGradientAngle = 135.0;
  double _canvasPadding = 16.0;

  // Typography & effects for main text layer
  double _fontSize = 0.5;
  double _lineHeight = 1.0;
  double _textScale = 1.0;
  double _textOpacity = 1.0;
  double _textRotation = 0.0;
  bool _enableTextShadow = true;
  Color _shadowColor = Colors.black;
  double _shadowOffsetX = 1.0;
  double _shadowOffsetY = 1.0;
  double _shadowBlurRadius = 0.0;
  bool _enableTextGlow = true;
  Color _glowColor = Colors.white;
  double _glowRadius = 10.0;
  bool _textFill = true;
  bool _showStroke = false;
  Color _strokeColor = Colors.black;
  double _strokeWidth = 2.0;

  bool _showMainBox = false;
  Color _mainBoxColor = Colors.white;
  double _mainBoxOpacity = 0.8;
  double _mainBoxRadius = 8.0;
  double _letterSpacing = 0.0;
  String _warpType = 'none';
  double _warpIntensity = 0.0;

  // Background image & adjustments
  File? _bgImage;
  double _brightness = 0.5;
  double _saturation = 1.0;
  double _hue = 0.0;

  // Mask settings
  Color _maskColor = Colors.black;
  double _maskOpacity = 0.5;
  int _maskType = 1; // 0: None, 1: Bottom, 2: Top, 3: Full, 4: Left, 5: Right
  double _maskStart = 0.0;
  double _maskEnd = 1.0;

  // Panel state: 0 Text, 1 Type, 2 Colors, 3 Effects, 4 Position,
  // 5 BG Photo, 6 Mask, 7 Overlays, 8 Shapes, 9 Layers
  int _selectedTabIndex = 0;
  bool _isTabContentExpanded = true;
  bool _isTallSheet = false;

  TextAlign _textAlign = TextAlign.center;
  Alignment _textPosition = Alignment.center;

  // Overlays & layers
  List<TextPostOverlayPatch> _patches = [];
  int? _selectedPatchIndex;
  List<TextPostOverlayImage> _imageOverlays = [];
  int? _selectedImageOverlayIndex;
  List<TextPostTextOverlay> _textOverlays = [];
  int _selectedTextIndex = -1; // -1: Main Text, 0..N: Extra layers

  bool _snapGuideX = false;
  bool _snapGuideY = false;
  bool _isExporting = false;

  // 0: 1:1, 1: 4:5, 2: 9:16, 3: 16:9, 4: 4:3
  int _selectedAspectIndex = 0;

  static const _aspectOptions = [
    ('1:1', 0, 1.0),
    ('4:5', 1, 4 / 5),
    ('9:16', 2, 9 / 16),
    ('16:9', 3, 16 / 9),
    ('4:3', 4, 4 / 3),
  ];

  static const _tabs = [
    (Icons.text_fields_rounded, 'Text', Colors.blue),
    (Icons.font_download_rounded, 'Type', Colors.indigo),
    (Icons.palette_rounded, 'Colors', Colors.deepOrange),
    (Icons.auto_awesome_rounded, 'Effects', Colors.purple),
    (Icons.open_with_rounded, 'Position', Colors.brown),
    (Icons.image_rounded, 'BG Photo', Colors.teal),
    (Icons.gradient_rounded, 'Mask', Colors.cyan),
    (Icons.photo_library_rounded, 'Overlays', Colors.deepPurple),
    (Icons.layers_rounded, 'Shapes', Colors.pink),
    (Icons.format_list_bulleted_rounded, 'Layers', Colors.blueAccent),
  ];

  double get _currentAspectRatio {
    for (final opt in _aspectOptions) {
      if (opt.$2 == _selectedAspectIndex) return opt.$3;
    }
    return 1.0;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedFont = const FontInfo(
      family: 'KleeOne',
      displayName: 'Klee One SemiBold',
      weight: FontWeight.w600,
      assetPath: 'assets/fonts/KleeOne-SemiBold.ttf',
    );
    _textController.addListener(() {
      if (!_isRestoring) _scheduleSave();
      setState(() {});
    });
    AnalyticsService().setCurrentScreen(screenName: 'Text Post');
    _loadState();
  }

  @override
  void setState(VoidCallback fn) {
    final shouldRecordUndo = mounted && !_isRestoring && !_isUndoingOrRedoing;
    if (shouldRecordUndo && !(_undoBatchTimer?.isActive ?? false)) {
      _lastCommittedSnapshot ??= _serializeStateMap();
      _undoStack.add(_lastCommittedSnapshot!);
      if (_undoStack.length > 25) _undoStack.removeAt(0);
      _redoStack.clear();
    }
    super.setState(fn);
    if (shouldRecordUndo) {
      _undoBatchTimer?.cancel();
      _undoBatchTimer = Timer(const Duration(milliseconds: 450), () {
        if (mounted) _lastCommittedSnapshot = _serializeStateMap();
      });
      _scheduleSave();
    }
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    _undoBatchTimer?.cancel();
    _redoStack.add(_serializeStateMap());
    final prev = _undoStack.removeLast();
    _isUndoingOrRedoing = true;
    super.setState(() => _applyStateMap(prev));
    _isUndoingOrRedoing = false;
    _lastCommittedSnapshot = _serializeStateMap();
    _scheduleSave();
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    _undoBatchTimer?.cancel();
    _undoStack.add(_serializeStateMap());
    final next = _redoStack.removeLast();
    _isUndoingOrRedoing = true;
    super.setState(() => _applyStateMap(next));
    _isUndoingOrRedoing = false;
    _lastCommittedSnapshot = _serializeStateMap();
    _scheduleSave();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveDebounce?.cancel();
    _undoBatchTimer?.cancel();
    _saveStateSync();
    _textController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _saveStateSync();
    }
  }

  void _scheduleSave() {
    if (_saveDebounce?.isActive ?? false) _saveDebounce!.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), _saveStateSync);
  }

  Map<String, dynamic> _serializeStateMap() {
    return {
      'text': _textController.text,
      'selectedFont': _selectedFont?.toMap(),
      'textColor': _textColor.toARGB32(),
      'backgroundColor': _backgroundColor.toARGB32(),
      'bgUseGradient': _bgUseGradient,
      'bgColor2': _bgColor2.toARGB32(),
      'bgGradientAngle': _bgGradientAngle,
      'canvasPadding': _canvasPadding,
      'fontSize': _fontSize,
      'lineHeight': _lineHeight,
      'textScale': _textScale,
      'textOpacity': _textOpacity,
      'textRotation': _textRotation,
      'enableTextShadow': _enableTextShadow,
      'shadowColor': _shadowColor.toARGB32(),
      'shadowOffsetX': _shadowOffsetX,
      'shadowOffsetY': _shadowOffsetY,
      'shadowBlurRadius': _shadowBlurRadius,
      'enableTextGlow': _enableTextGlow,
      'glowColor': _glowColor.toARGB32(),
      'glowRadius': _glowRadius,
      'textFill': _textFill,
      'showStroke': _showStroke,
      'strokeColor': _strokeColor.toARGB32(),
      'strokeWidth': _strokeWidth,
      'showMainBox': _showMainBox,
      'mainBoxColor': _mainBoxColor.toARGB32(),
      'mainBoxOpacity': _mainBoxOpacity,
      'mainBoxRadius': _mainBoxRadius,
      'letterSpacing': _letterSpacing,
      'warpType': _warpType,
      'warpIntensity': _warpIntensity,
      'bgImagePath': _bgImage?.path,
      'brightness': _brightness,
      'saturation': _saturation,
      'hue': _hue,
      'maskColor': _maskColor.toARGB32(),
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
  }

  void _applyStateMap(Map<String, dynamic> stateMap) {
    if (stateMap['text'] != null) _textController.text = stateMap['text'];
    if (stateMap['selectedFont'] != null) {
      _selectedFont = FontInfo.fromMap(
        Map<String, dynamic>.from(stateMap['selectedFont']),
      );
    }
    if (stateMap['textColor'] != null) {
      _textColor = Color(stateMap['textColor']);
    }
    if (stateMap['backgroundColor'] != null) {
      _backgroundColor = Color(stateMap['backgroundColor']);
    }
    _bgUseGradient = stateMap['bgUseGradient'] ?? false;
    if (stateMap['bgColor2'] != null) {
      _bgColor2 = Color(stateMap['bgColor2']);
    }
    _bgGradientAngle = stateMap['bgGradientAngle']?.toDouble() ?? 135.0;
    _canvasPadding = stateMap['canvasPadding']?.toDouble() ?? 16.0;

    _fontSize = stateMap['fontSize']?.toDouble() ?? 0.5;
    _lineHeight = stateMap['lineHeight']?.toDouble() ?? 1.0;
    _textScale = stateMap['textScale']?.toDouble() ?? 1.0;
    _textOpacity = stateMap['textOpacity']?.toDouble() ?? 1.0;
    _textRotation = stateMap['textRotation']?.toDouble() ?? 0.0;
    _enableTextShadow = stateMap['enableTextShadow'] ?? true;
    if (stateMap['shadowColor'] != null) {
      _shadowColor = Color(stateMap['shadowColor']);
    }
    _shadowOffsetX = stateMap['shadowOffsetX']?.toDouble() ?? 1.0;
    _shadowOffsetY = stateMap['shadowOffsetY']?.toDouble() ?? 1.0;
    _shadowBlurRadius = stateMap['shadowBlurRadius']?.toDouble() ?? 0.0;
    _enableTextGlow = stateMap['enableTextGlow'] ?? true;
    if (stateMap['glowColor'] != null) {
      _glowColor = Color(stateMap['glowColor']);
    }
    _glowRadius = stateMap['glowRadius']?.toDouble() ?? 10.0;
    _textFill = stateMap['textFill'] ?? true;
    _showStroke = stateMap['showStroke'] ?? false;
    if (stateMap['strokeColor'] != null) {
      _strokeColor = Color(stateMap['strokeColor']);
    }
    _strokeWidth = stateMap['strokeWidth']?.toDouble() ?? 2.0;

    _showMainBox = stateMap['showMainBox'] ?? false;
    if (stateMap['mainBoxColor'] != null) {
      _mainBoxColor = Color(stateMap['mainBoxColor']);
    }
    _mainBoxOpacity = stateMap['mainBoxOpacity']?.toDouble() ?? 0.8;
    _mainBoxRadius = stateMap['mainBoxRadius']?.toDouble() ?? 8.0;
    _letterSpacing = stateMap['letterSpacing']?.toDouble() ?? 0.0;
    _warpType = stateMap['warpType'] ?? 'none';
    _warpIntensity = stateMap['warpIntensity']?.toDouble() ?? 0.0;

    if (stateMap['bgImagePath'] != null &&
        stateMap['bgImagePath'].toString().isNotEmpty) {
      final f = File(stateMap['bgImagePath']);
      _bgImage = f.existsSync() ? f : null;
    } else {
      _bgImage = null;
    }
    _brightness = stateMap['brightness']?.toDouble() ?? 0.5;
    _saturation = stateMap['saturation']?.toDouble() ?? 1.0;
    _hue = stateMap['hue']?.toDouble() ?? 0.0;

    if (stateMap['maskColor'] != null) {
      _maskColor = Color(stateMap['maskColor']);
    }
    _maskOpacity = stateMap['maskOpacity']?.toDouble() ?? 0.5;
    _maskType = stateMap['maskType'] ?? 1;
    _maskStart = stateMap['maskStart']?.toDouble() ?? 0.0;
    _maskEnd = stateMap['maskEnd']?.toDouble() ?? 1.0;

    if (stateMap['textAlign'] != null) {
      _textAlign = TextAlign.values[stateMap['textAlign']];
    }
    _textPosition = Alignment(
      stateMap['textPositionX']?.toDouble() ?? 0.0,
      stateMap['textPositionY']?.toDouble() ?? 0.0,
    );
    _selectedAspectIndex = stateMap['selectedAspectIndex'] ?? 0;

    _patches = stateMap['patches'] != null
        ? (stateMap['patches'] as List)
            .map((p) => TextPostOverlayPatch.fromMap(Map<String, dynamic>.from(p)))
            .toList()
        : [];
    _imageOverlays = stateMap['imageOverlays'] != null
        ? (stateMap['imageOverlays'] as List)
            .map((i) => TextPostOverlayImage.fromMap(Map<String, dynamic>.from(i)))
            .toList()
        : [];
    _textOverlays = stateMap['textOverlays'] != null
        ? (stateMap['textOverlays'] as List)
            .map((t) => TextPostTextOverlay.fromMap(Map<String, dynamic>.from(t)))
            .toList()
        : [];
  }

  Future<void> _saveStateSync() async {
    if (_isRestoring) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'text_post_draft_state',
        jsonEncode(_serializeStateMap()),
      );
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
          _applyStateMap(stateMap);
          _isRestoring = false;
        });
        _lastCommittedSnapshot = _serializeStateMap();
      }
    } catch (e) {
      debugPrint('[TextPostScreen] Error loading state: $e');
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  Future<void> _confirmResetState() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Reset Post?'),
            content: const Text(
              'Clear your current text, background, overlays, and styling?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Reset'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    setState(() {
      _textController.clear();
      _selectedFont = const FontInfo(
        family: 'KleeOne',
        displayName: 'Klee One SemiBold',
        weight: FontWeight.w600,
        assetPath: 'assets/fonts/KleeOne-SemiBold.ttf',
      );
      _textColor = Colors.white;
      _backgroundColor = Colors.white;
      _bgUseGradient = false;
      _bgColor2 = const Color(0xFF2C5364);
      _bgGradientAngle = 135.0;
      _canvasPadding = 16.0;
      _fontSize = 0.5;
      _lineHeight = 1.0;
      _textScale = 1.0;
      _textOpacity = 1.0;
      _textRotation = 0.0;
      _enableTextShadow = true;
      _shadowColor = Colors.black;
      _shadowOffsetX = 1.0;
      _shadowOffsetY = 1.0;
      _shadowBlurRadius = 0.0;
      _enableTextGlow = true;
      _glowColor = Colors.white;
      _glowRadius = 10.0;
      _textFill = true;
      _showStroke = false;
      _strokeColor = Colors.black;
      _strokeWidth = 2.0;
      _showMainBox = false;
      _mainBoxColor = Colors.white;
      _mainBoxOpacity = 0.8;
      _mainBoxRadius = 8.0;
      _letterSpacing = 0.0;
      _warpType = 'none';
      _warpIntensity = 0.0;

      _bgImage = null;
      _transformationController.value = Matrix4.identity();
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
      _selectedPatchIndex = null;
      _imageOverlays.clear();
      _selectedImageOverlayIndex = null;
      _textOverlays.clear();
      _selectedTextIndex = -1;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('text_post_draft_state');
  }

  void _showTipsDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Quick Editing Tips'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• Drag any text, sticker, or shape directly on the canvas.'),
            SizedBox(height: 6),
            Text('• Pinch & drag the background photo to pan or zoom it.'),
            SizedBox(height: 6),
            Text('• Tap empty canvas to collapse controls for a clean preview.'),
            SizedBox(height: 6),
            Text('• Switch between Main and extra layers inside Text or Layers.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedTextIndex >= _textOverlays.length) {
      _selectedTextIndex = -1;
    }

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 44,
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.black87,
            size: 18,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        titleSpacing: 0,
        title: const Text(
          'Simple Text Post',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.undo_rounded,
              color: _undoStack.isNotEmpty ? Colors.black87 : Colors.grey[400],
              size: 20,
            ),
            tooltip: 'Undo',
            onPressed: _undoStack.isNotEmpty ? _undo : null,
          ),
          IconButton(
            icon: Icon(
              Icons.redo_rounded,
              color: _redoStack.isNotEmpty ? Colors.black87 : Colors.grey[400],
              size: 20,
            ),
            tooltip: 'Redo',
            onPressed: _redoStack.isNotEmpty ? _redo : null,
          ),
          TextButton.icon(
            onPressed: _confirmResetState,
            icon: const Icon(
              Icons.refresh_rounded,
              size: 17,
              color: AppColors.primary,
            ),
            label: const Text(
              'Reset',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.help_outline_rounded,
              color: Colors.grey,
              size: 20,
            ),
            tooltip: 'Tips',
            onPressed: _showTipsDialog,
          ),
        ],
      ),
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            _buildTopCanvasStrip(),
            Expanded(
              child: TextPostPreviewCanvas(
                previewKey: _previewKey,
                aspectRatio: _currentAspectRatio,
                isExporting: _isExporting,
                isTabContentExpanded: _isTabContentExpanded,
                backgroundColor: _backgroundColor,
                bgUseGradient: _bgUseGradient,
                bgColor2: _bgColor2,
                bgGradientAngle: _bgGradientAngle,
                canvasPadding: _canvasPadding,
                bgImage: _bgImage,
                transformationController: _transformationController,
                brightness: _brightness,
                saturation: _saturation,
                hue: _hue,
                maskType: _maskType,
                maskColor: _maskColor,
                maskOpacity: _maskOpacity,
                maskStart: _maskStart,
                maskEnd: _maskEnd,
                text: _textController.text,
                selectedFont: _selectedFont,
                textColor: _textColor,
                fontSize: _fontSize,
                textScale: _textScale,
                lineHeight: _lineHeight,
                letterSpacing: _letterSpacing,
                textAlign: _textAlign,
                textPosition: _textPosition,
                enableTextShadow: _enableTextShadow,
                shadowColor: _shadowColor,
                shadowOffsetX: _shadowOffsetX,
                shadowOffsetY: _shadowOffsetY,
                shadowBlurRadius: _shadowBlurRadius,
                enableTextGlow: _enableTextGlow,
                glowColor: _glowColor,
                glowRadius: _glowRadius,
                showMainBox: _showMainBox,
                mainBoxColor: _mainBoxColor,
                mainBoxOpacity: _mainBoxOpacity,
                mainBoxRadius: _mainBoxRadius,
                warpType: _warpType,
                warpIntensity: _warpIntensity,
                textOpacity: _textOpacity,
                textRotation: _textRotation,
                textFill: _textFill,
                showStroke: _showStroke,
                strokeColor: _strokeColor,
                strokeWidth: _strokeWidth,
                showSnapGuideX: _snapGuideX,
                showSnapGuideY: _snapGuideY,
                patches: _patches,
                selectedPatchIndex: _selectedPatchIndex,
                imageOverlays: _imageOverlays,
                selectedImageOverlayIndex: _selectedImageOverlayIndex,
                textOverlays: _textOverlays,
                selectedTextIndex: _selectedTextIndex,
                onBackgroundTap: () => setState(() {
                  _selectedTextIndex = -1;
                  _selectedPatchIndex = null;
                  _selectedImageOverlayIndex = null;
                  _isTabContentExpanded = false;
                }),
                onMainTextPanStart: () => setState(() {
                  _selectedTextIndex = -1;
                  _selectedPatchIndex = null;
                  _selectedImageOverlayIndex = null;
                }),
                onMainTextPanUpdate: (pos) => setState(() {
                  _selectedTextIndex = -1;
                  _selectedPatchIndex = null;
                  _selectedImageOverlayIndex = null;
                  _textPosition = pos;
                }),
                onSnapGuidesChanged: (sx, sy) {
                  if (_snapGuideX != sx || _snapGuideY != sy) {
                    super.setState(() {
                      _snapGuideX = sx;
                      _snapGuideY = sy;
                    });
                  }
                },
                onMainTextTap: () => setState(() {
                  _selectedTextIndex = -1;
                  _selectedPatchIndex = null;
                  _selectedImageOverlayIndex = null;
                  _selectedTabIndex = 0;
                  _isTabContentExpanded = true;
                }),
                onPatchPanUpdate: (idx, x, y) => setState(() {
                  _patches[idx].x = x;
                  _patches[idx].y = y;
                  _selectedPatchIndex = idx;
                  _selectedTabIndex = 8;
                  _isTabContentExpanded = true;
                }),
                onPatchTap: (idx) => setState(() {
                  _selectedPatchIndex = idx;
                  _selectedTabIndex = 8;
                  _isTabContentExpanded = true;
                }),
                onImageOverlayPanStart: (idx) => setState(() {
                  _selectedImageOverlayIndex = idx;
                  _selectedTabIndex = 7;
                  _isTabContentExpanded = true;
                }),
                onImageOverlayPanUpdate: (idx, x, y) => setState(() {
                  _imageOverlays[idx].x = x;
                  _imageOverlays[idx].y = y;
                }),
                onImageOverlayTap: (idx) => setState(() {
                  _selectedImageOverlayIndex = idx;
                  _selectedTabIndex = 7;
                  _isTabContentExpanded = true;
                }),
                onTextOverlayPanStart: (idx) => setState(() {
                  _selectedTextIndex = idx;
                }),
                onTextOverlayPanUpdate: (idx, x, y) => setState(() {
                  _textOverlays[idx].x = x;
                  _textOverlays[idx].y = y;
                }),
                onTextOverlayTap: (idx) => setState(() {
                  _selectedTextIndex = idx;
                  _selectedTabIndex = 0;
                  _isTabContentExpanded = true;
                }),
              ),
            ),
            _buildControlsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopCanvasStrip() {
    final String layerLabel =
        _selectedTextIndex == -1 ? 'Main' : 'Layer ${_selectedTextIndex + 1}';

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          const Text(
            'Size',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.black54,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _aspectOptions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 5),
              padding: const EdgeInsets.symmetric(vertical: 5),
              itemBuilder: (_, idx) {
                final opt = _aspectOptions[idx];
                final isSelected = _selectedAspectIndex == opt.$2;
                return GestureDetector(
                  onTap: () => setState(() => _selectedAspectIndex = opt.$2),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.black87 : Colors.grey[100],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected
                            ? Colors.black87
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Text(
                      opt.$1,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : Colors.grey[800],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_textOverlays.isNotEmpty) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: _prevLayer,
                    child: const Icon(
                      Icons.chevron_left_rounded,
                      size: 16,
                      color: Colors.blueAccent,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      layerLabel,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.blueAccent,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: _nextLayer,
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: Colors.blueAccent,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildControlsSection() {
    final screenH = MediaQuery.sizeOf(context).height;
    final double expandedHeight = _isTallSheet
        ? (screenH * 0.42).clamp(260.0, 340.0)
        : (screenH * 0.28).clamp(210.0, 250.0);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isTabContentExpanded) ...[
            _buildSheetHeader(),
            SizedBox(
              height: expandedHeight,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: _buildActiveTabContent(),
              ),
            ),
          ],
          _buildControlTabs(),
        ],
      ),
    );
  }

  Widget _buildSheetHeader() {
    final bool isTextContext = _selectedTabIndex <= 4;
    final String layerName =
        _selectedTextIndex == -1 ? 'MAIN POST' : 'LAYER ${_selectedTextIndex + 1}';

    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          if (isTextContext && _textOverlays.isNotEmpty) ...[
            InkWell(
              onTap: _prevLayer,
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(
                  Icons.chevron_left_rounded,
                  size: 18,
                  color: Colors.blueAccent,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.layers_rounded,
              size: 12,
              color: Colors.blueAccent.withValues(alpha: 0.8),
            ),
            const SizedBox(width: 4),
            Text(
              layerName,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Colors.blueAccent,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: _nextLayer,
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: Colors.blueAccent,
                ),
              ),
            ),
          ] else
            Text(
              _tabs[_selectedTabIndex].$2.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Colors.grey[600],
                letterSpacing: 0.8,
              ),
            ),
          const Spacer(),
          InkWell(
            onTap: () => setState(() => _isTallSheet = !_isTallSheet),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Icon(
                _isTallSheet
                    ? Icons.unfold_less_rounded
                    : Icons.unfold_more_rounded,
                size: 16,
                color: Colors.grey[600],
              ),
            ),
          ),
          InkWell(
            onTap: () => setState(() => _isTabContentExpanded = false),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTabContent() {
    final bool isMain = _selectedTextIndex == -1;
    final bool hasValidOverlay = !isMain &&
        _selectedTextIndex >= 0 &&
        _selectedTextIndex < _textOverlays.length;
    final TextPostTextOverlay? overlay =
        hasValidOverlay ? _textOverlays[_selectedTextIndex] : null;

    if (_selectedTabIndex <= 4 && !isMain && overlay == null) {
      return const Center(child: Text('Please select a valid layer'));
    }

    switch (_selectedTabIndex) {
      case 0:
        return TextPostTextTab(
          selectedTextIndex: _selectedTextIndex,
          mainController: _textController,
          textOverlays: _textOverlays,
          defaultFont: _selectedFont,
          defaultColor: _textColor,
          onImportFromMyQuotes: _importFromMyQuotes,
          onSaveToMyQuotes: _saveToMyQuotes,
          onSelectLayer: (idx) => setState(() => _selectedTextIndex = idx),
          onAddLayer: (idx) => setState(() => _selectedTextIndex = idx),
          onTransformCase: (targetCase) {
            setState(() {
              if (isMain) {
                final updated =
                    applyTextPostCase(_textController.text, targetCase);
                _textController.value = TextEditingValue(
                  text: updated,
                  selection: TextSelection.collapsed(offset: updated.length),
                );
              } else {
                overlay!.text = applyTextPostCase(overlay.text, targetCase);
              }
            });
          },
          onDuplicateLayer: !isMain
              ? () => setState(() {
                    final clone = overlay!.copy()
                      ..x = (overlay.x + 0.04).clamp(0.0, 1.0)
                      ..y = (overlay.y + 0.04).clamp(0.0, 1.0);
                    _textOverlays.insert(_selectedTextIndex + 1, clone);
                    _selectedTextIndex = _selectedTextIndex + 1;
                  })
              : null,
          onStateChanged: () => setState(() {}),
        );
      case 1:
        return TextPostTypographyTab(
          isMain: isMain,
          selectedFont: isMain ? _selectedFont : overlay!.font,
          currentAlign: isMain ? _textAlign : overlay!.textAlign,
          fontSize: isMain ? _fontSize : overlay!.fontSize,
          textScale: isMain ? _textScale : overlay!.scale,
          letterSpacing: isMain ? _letterSpacing : overlay!.letterSpacing,
          lineHeight: isMain ? _lineHeight : overlay!.lineHeight,
          opacity: isMain ? _textOpacity : overlay!.opacity,
          rotation: isMain ? _textRotation : overlay!.rotation,
          onFontSelected: (font) => setState(() {
            if (isMain) {
              _selectedFont = font;
            } else {
              overlay!.font = font;
            }
          }),
          onAlignChanged: (align) => setState(() {
            if (isMain) {
              _textAlign = align;
            } else {
              overlay!.textAlign = align;
            }
          }),
          onFontSizeChanged: (v) => setState(() {
            if (isMain) {
              _fontSize = v;
            } else {
              overlay!.fontSize = v;
            }
          }),
          onTextScaleChanged: (v) => setState(() {
            if (isMain) {
              _textScale = v;
            } else {
              overlay!.scale = v;
            }
          }),
          onLetterSpacingChanged: (v) => setState(() {
            if (isMain) {
              _letterSpacing = v;
            } else {
              overlay!.letterSpacing = v;
            }
          }),
          onLineHeightChanged: (v) => setState(() {
            if (isMain) {
              _lineHeight = v;
            } else {
              overlay!.lineHeight = v;
            }
          }),
          onOpacityChanged: (v) => setState(() {
            if (isMain) {
              _textOpacity = v;
            } else {
              overlay!.opacity = v;
            }
          }),
          onRotationChanged: (v) => setState(() {
            if (isMain) {
              _textRotation = v;
            } else {
              overlay!.rotation = v;
            }
          }),
        );
      case 2:
        return TextPostColorsTab(
          isMain: isMain,
          showMainBox: _showMainBox,
          activeTextColor: isMain ? _textColor : overlay!.color,
          activeBoxColor: isMain ? _mainBoxColor : overlay!.boxColor,
          canvasBackgroundColor: _backgroundColor,
          bgUseGradient: _bgUseGradient,
          bgColor2: _bgColor2,
          bgGradientAngle: _bgGradientAngle,
          onTextColorSelected: (color) => setState(() {
            if (isMain) {
              _textColor = color;
            } else {
              overlay!.color = color;
            }
          }),
          onBoxColorSelected: (color) => setState(() {
            if (isMain) {
              _mainBoxColor = color;
            } else {
              overlay!.boxColor = color;
            }
          }),
          onCanvasBackgroundSelected: (color) =>
              setState(() => _backgroundColor = color),
          onPickCustomTextColor: () =>
              _showColorPicker('text', textIndex: _selectedTextIndex),
          onPickCustomBoxColor: () =>
              _showColorPicker('box', textIndex: _selectedTextIndex),
          onPickCustomCanvasBackground: () =>
              _showColorPicker('background', textIndex: _selectedTextIndex),
          onBgUseGradientChanged: (v) => setState(() => _bgUseGradient = v),
          onBgColor2Selected: (c) => setState(() => _bgColor2 = c),
          onPickCustomBgColor2: () =>
              _showColorPicker('bgColor2', textIndex: _selectedTextIndex),
          onBgGradientAngleChanged: (v) =>
              setState(() => _bgGradientAngle = v),
          onApplyGradientPreset: (g) => setState(() {
            _bgUseGradient = true;
            _backgroundColor = g.color1;
            _bgColor2 = g.color2;
            _bgGradientAngle = g.angle;
          }),
          onApplyStylePreset: (p) => setState(() {
            _textColor = p.textColor;
            _backgroundColor = p.bgColor1;
            _bgColor2 = p.bgColor2;
            _bgUseGradient = p.useGradient;
            _bgGradientAngle = p.gradientAngle;
            _showMainBox = p.showBox;
            _mainBoxColor = p.boxColor;
            _mainBoxOpacity = p.boxOpacity;
            _mainBoxRadius = p.boxRadius;
            _enableTextShadow = p.showShadow;
            _shadowColor = p.shadowColor;
            _shadowBlurRadius = p.shadowBlur;
            _enableTextGlow = p.showGlow;
            _glowColor = p.glowColor;
            _glowRadius = p.glowRadius;
            _showStroke = p.showStroke;
            _strokeColor = p.strokeColor;
            _strokeWidth = p.strokeWidth;
          }),
        );
      case 3:
        return TextPostEffectsTab(
          isMain: isMain,
          warpType: isMain ? _warpType : overlay!.warpType,
          warpIntensity: isMain ? _warpIntensity : overlay!.warpIntensity,
          showShadow: isMain ? _enableTextShadow : overlay!.showShadow,
          shadowColor: isMain ? _shadowColor : overlay!.shadowColor,
          shadowX: isMain ? _shadowOffsetX : overlay!.shadowOffsetX,
          shadowY: isMain ? _shadowOffsetY : overlay!.shadowOffsetY,
          shadowBlur: isMain ? _shadowBlurRadius : overlay!.shadowBlur,
          showGlow: isMain ? _enableTextGlow : overlay!.showGlow,
          glowColor: isMain ? _glowColor : overlay!.glowColor,
          glowRadius: isMain ? _glowRadius : overlay!.glowRadius,
          showBox: isMain ? _showMainBox : overlay!.showBox,
          boxOpacity: isMain ? _mainBoxOpacity : overlay!.boxOpacity,
          boxRadius: isMain ? _mainBoxRadius : overlay!.boxRadius,
          textFill: isMain ? _textFill : overlay!.textFill,
          showStroke: isMain ? _showStroke : overlay!.showStroke,
          strokeColor: isMain ? _strokeColor : overlay!.strokeColor,
          strokeWidth: isMain ? _strokeWidth : overlay!.strokeWidth,
          onWarpTypeChanged: (w) => setState(() {
            if (isMain) {
              _warpType = w;
            } else {
              overlay!.warpType = w;
            }
          }),
          onWarpIntensityChanged: (v) => setState(() {
            if (isMain) {
              _warpIntensity = v;
            } else {
              overlay!.warpIntensity = v;
            }
          }),
          onShowShadowChanged: (v) => setState(() {
            if (isMain) {
              _enableTextShadow = v;
            } else {
              overlay!.showShadow = v;
            }
          }),
          onPickShadowColor: () => _showColorPicker('shadow'),
          onShadowXChanged: (v) => setState(() {
            if (isMain) {
              _shadowOffsetX = v;
            } else {
              overlay!.shadowOffsetX = v;
            }
          }),
          onShadowYChanged: (v) => setState(() {
            if (isMain) {
              _shadowOffsetY = v;
            } else {
              overlay!.shadowOffsetY = v;
            }
          }),
          onShadowBlurChanged: (v) => setState(() {
            if (isMain) {
              _shadowBlurRadius = v;
            } else {
              overlay!.shadowBlur = v;
            }
          }),
          onShowGlowChanged: (v) => setState(() {
            if (isMain) {
              _enableTextGlow = v;
            } else {
              overlay!.showGlow = v;
            }
          }),
          onPickGlowColor: () => _showColorPicker('glow'),
          onGlowRadiusChanged: (v) => setState(() {
            if (isMain) {
              _glowRadius = v;
            } else {
              overlay!.glowRadius = v;
            }
          }),
          onShowBoxChanged: (v) => setState(() {
            if (isMain) {
              _showMainBox = v;
            } else {
              overlay!.showBox = v;
            }
          }),
          onBoxOpacityChanged: (v) => setState(() {
            if (isMain) {
              _mainBoxOpacity = v;
            } else {
              overlay!.boxOpacity = v;
            }
          }),
          onBoxRadiusChanged: (v) => setState(() {
            if (isMain) {
              _mainBoxRadius = v;
            } else {
              overlay!.boxRadius = v;
            }
          }),
          onTextFillChanged: (v) => setState(() {
            if (isMain) {
              _textFill = v;
              if (!v && !_showStroke) _showStroke = true;
            } else {
              overlay!.textFill = v;
              if (!v && !overlay.showStroke) overlay.showStroke = true;
            }
          }),
          onShowStrokeChanged: (v) => setState(() {
            if (isMain) {
              _showStroke = v;
            } else {
              overlay!.showStroke = v;
            }
          }),
          onStrokeColorSelected: (c) => setState(() {
            if (isMain) {
              _strokeColor = c;
            } else {
              overlay!.strokeColor = c;
            }
          }),
          onPickStrokeColor: () => _showColorPicker('stroke'),
          onStrokeWidthChanged: (v) => setState(() {
            if (isMain) {
              _strokeWidth = v;
            } else {
              overlay!.strokeWidth = v;
            }
          }),
        );
      case 4:
        return TextPostPositionTab(
          isMain: isMain,
          posX: isMain ? _textPosition.x : overlay!.x,
          posY: isMain ? _textPosition.y : overlay!.y,
          canvasPadding: _canvasPadding,
          onPresetSelected: (target) => setState(() {
            if (isMain) {
              _textPosition = target;
            } else {
              overlay!.x = (target.x + 1) / 2;
              overlay.y = (target.y + 1) / 2;
            }
          }),
          onXChanged: (v) => setState(() {
            if (isMain) {
              _textPosition = Alignment(v, _textPosition.y);
            } else {
              overlay!.x = v;
            }
          }),
          onYChanged: (v) => setState(() {
            if (isMain) {
              _textPosition = Alignment(_textPosition.x, v);
            } else {
              overlay!.y = v;
            }
          }),
          onCanvasPaddingChanged: (v) => setState(() => _canvasPadding = v),
        );
      case 5:
        return TextPostBackgroundPhotoTab(
          hasImage: _bgImage != null,
          brightness: _brightness,
          saturation: _saturation,
          hue: _hue,
          onPickImage: _pickBackgroundImage,
          onClearImage: () => setState(() => _bgImage = null),
          onResetTransform: () => setState(() {
            _transformationController.value = Matrix4.identity();
          }),
          onBrightnessChanged: (v) => setState(() => _brightness = v),
          onSaturationChanged: (v) => setState(() => _saturation = v),
          onHueChanged: (v) => setState(() => _hue = v),
          onResetAdjustments: () => setState(() {
            _brightness = 1.0;
            _saturation = 1.0;
            _hue = 0.0;
          }),
        );
      case 6:
        return TextPostMaskTab(
          maskType: _maskType,
          maskColor: _maskColor,
          maskOpacity: _maskOpacity,
          maskStart: _maskStart,
          maskEnd: _maskEnd,
          onMaskTypeChanged: (t) => setState(() => _maskType = t),
          onPickMaskColor: () => _showColorPicker('mask'),
          onMaskOpacityChanged: (v) => setState(() => _maskOpacity = v),
          onMaskStartChanged: (v) => setState(() => _maskStart = v),
          onMaskEndChanged: (v) => setState(() => _maskEnd = v),
        );
      case 7:
        return TextPostOverlaysTab(
          imageOverlays: _imageOverlays,
          selectedImageOverlayIndex: _selectedImageOverlayIndex,
          onSelectedIndexChanged: (idx) =>
              setState(() => _selectedImageOverlayIndex = idx),
          onStateChanged: () => setState(() {}),
        );
      case 8:
        return TextPostShapesTab(
          patches: _patches,
          selectedPatchIndex: _selectedPatchIndex,
          onSelectedIndexChanged: (idx) =>
              setState(() => _selectedPatchIndex = idx),
          onStateChanged: () => setState(() {}),
        );
      default:
        return TextPostLayersTab(
          textOverlays: _textOverlays,
          selectedTextIndex: _selectedTextIndex,
          onSelectTextIndex: (idx) => setState(() => _selectedTextIndex = idx),
          onAddLayer: () {
            setState(() {
              _textOverlays.add(
                TextPostTextOverlay(
                  text: 'New Text',
                  font: _selectedFont,
                  color: _textColor,
                ),
              );
              _selectedTextIndex = _textOverlays.length - 1;
              _selectedTabIndex = 0;
            });
          },
          onStateChanged: () => setState(() {}),
        );
    }
  }

  Widget _buildControlTabs() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!, width: 1)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Material(
            color: Colors.blueAccent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: _savePost,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.download_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          VerticalDivider(
            width: 1,
            indent: 12,
            endIndent: 12,
            color: Colors.grey[200],
          ),
          const SizedBox(width: 4),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _tabs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 4),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemBuilder: (_, index) {
                final isSelected = _selectedTabIndex == index;
                final tab = _tabs[index];
                final Color baseColor = tab.$3;
                final bool active = isSelected && _isTabContentExpanded;

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
                    duration: const Duration(milliseconds: 180),
                    width: 58,
                    decoration: BoxDecoration(
                      color: active
                          ? baseColor.withValues(alpha: 0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          tab.$1,
                          size: 18,
                          color: active ? baseColor : Colors.grey[500],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tab.$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight:
                                active ? FontWeight.w700 : FontWeight.w500,
                            color: active ? baseColor : Colors.grey[600],
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

  Future<void> _pickBackgroundImage() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      setState(() => _bgImage = File(image.path));
    }
  }

  void _nextLayer() {
    setState(() {
      if (_selectedTextIndex == -1) {
        if (_textOverlays.isNotEmpty) _selectedTextIndex = 0;
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
    final selected = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute<dynamic>(
        builder: (_) => const MyQuotesScreen(selectMode: true),
      ),
    );

    if (selected != null && selected is QuoteItem && mounted) {
      setState(() {
        if (_selectedTextIndex == -1) {
          _textController.text = selected.text;
        } else if (_selectedTextIndex >= 0 &&
            _selectedTextIndex < _textOverlays.length) {
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
          content: Text(
            'Saved to My Quotes!',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showColorPicker(String type, {int? textIndex}) {
    final targetIndex = textIndex ?? _selectedTextIndex;
    final bool isMain = targetIndex == -1;
    if (!isMain && (targetIndex < 0 || targetIndex >= _textOverlays.length)) {
      return;
    }

    Color currentColor;
    String title;
    switch (type) {
      case 'text':
        currentColor = isMain ? _textColor : _textOverlays[targetIndex].color;
        title = 'Text Color';
        break;
      case 'background':
        currentColor = _backgroundColor;
        title = 'Background Color';
        break;
      case 'bgColor2':
        currentColor = _bgColor2;
        title = 'Gradient End Color';
        break;
      case 'stroke':
        currentColor =
            isMain ? _strokeColor : _textOverlays[targetIndex].strokeColor;
        title = 'Outline Color';
        break;
      case 'shadow':
        currentColor =
            isMain ? _shadowColor : _textOverlays[targetIndex].shadowColor;
        title = 'Shadow Color';
        break;
      case 'glow':
        currentColor =
            isMain ? _glowColor : _textOverlays[targetIndex].glowColor;
        title = 'Glow Color';
        break;
      case 'mask':
        currentColor = _maskColor;
        title = 'Mask Color';
        break;
      case 'box':
        currentColor =
            isMain ? _mainBoxColor : _textOverlays[targetIndex].boxColor;
        title = 'Box Color';
        break;
      default:
        currentColor = Colors.white;
        title = 'Color';
    }

    showTextPostColorPickerDialog(
      context: context,
      title: title,
      initialColor: currentColor,
      onColorSelected: (selectedColor) {
        setState(() {
          switch (type) {
            case 'text':
              if (isMain) {
                _textColor = selectedColor;
              } else {
                _textOverlays[targetIndex].color = selectedColor;
              }
              break;
            case 'background':
              _backgroundColor = selectedColor;
              break;
            case 'bgColor2':
              _bgColor2 = selectedColor;
              break;
            case 'stroke':
              if (isMain) {
                _strokeColor = selectedColor;
              } else {
                _textOverlays[targetIndex].strokeColor = selectedColor;
              }
              break;
            case 'shadow':
              if (isMain) {
                _shadowColor = selectedColor;
              } else {
                _textOverlays[targetIndex].shadowColor = selectedColor;
              }
              break;
            case 'glow':
              if (isMain) {
                _glowColor = selectedColor;
              } else {
                _textOverlays[targetIndex].glowColor = selectedColor;
              }
              break;
            case 'mask':
              _maskColor = selectedColor;
              break;
            case 'box':
              if (isMain) {
                _mainBoxColor = selectedColor;
              } else {
                _textOverlays[targetIndex].boxColor = selectedColor;
              }
              break;
          }
        });
      },
    );
  }

  Future<void> _savePost() => TextPostExportService.savePost(
        context: context,
        previewKey: _previewKey,
        aspectRatio: _currentAspectRatio,
        onBeforeExport: () => setState(() {
          _isExporting = true;
          _isTabContentExpanded = false;
        }),
        onAfterExport: () {
          if (mounted) setState(() => _isExporting = false);
        },
      );
}
