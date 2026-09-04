import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:toastification/toastification.dart';
import 'package:archive/archive.dart';

import '../../config/app_theme.dart';
import '../../config/app_config.dart';
import '../../models/watermark_preset.dart';
import '../../models/image_post_preset.dart';
import '../../services/image_post_preset_service.dart';
import '../../services/watermark_preset_service.dart';
import '../../services/analytics_service.dart';
import '../../services/ad_service.dart';
import '../../utils/font_selector.dart';
import '../../utils/image_generator.dart';
import '../../utils/custom_font_manager.dart';
import '../../widgets/advanced_color_picker.dart';
import '../quotes/my_quotes_screen.dart';
import '../../models/quote_item.dart';

class ImagePostMakerScreen extends StatefulWidget {
  final List<String>? sharedImagePaths;
  final bool isActive;

  const ImagePostMakerScreen({Key? key, this.sharedImagePaths, this.isActive = true}) : super(key: key);

  @override
  State<ImagePostMakerScreen> createState() => _ImagePostMakerScreenState();
}

class _Patch {
  double x; // Normalized
  double y; // Normalized
  double width; // Normalized
  double height; // Normalized
  String color;
  double opacity;
  double radius;
  bool isTop;

  _Patch({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.color = "#000000",
    this.opacity = 1.0,
    this.radius = 0.0,
    this.isTop = true,
  });

  Map<String, dynamic> toMap(double w, double h) {
    return {
      'x': x * w,
      'y': y * h,
      'width': width * w,
      'height': height * h,
      'color': color,
      'opacity': opacity,
      'radius': radius,
      'isTop': isTop,
    };
  }
}

class _ImageOverlay {
  String path;
  double x; // Normalized
  double y; // Normalized
  double scale;
  double opacity;
  double rotation;

  _ImageOverlay({
    required this.path,
    this.x = 0.5,
    this.y = 0.5,
    this.scale = 0.2,
    this.opacity = 1.0,
    this.rotation = 0.0,
  });

  Map<String, dynamic> toMap(double w, double h) {
    return {
      'path': path,
      'x': x * w,
      'y': y * h,
      'scale': scale,
      'opacity': opacity,
      'rotation': rotation,
    };
  }
}

String _colorWithAlpha(String hex, double opacity) {
  final int alpha = (opacity * 255).toInt().clamp(0, 255);
  final colorHex = hex.replaceFirst('#', '');
  final rgb = colorHex.length >= 6 ? colorHex.substring(colorHex.length - 6) : colorHex;
  return '#${alpha.toRadixString(16).padLeft(2, '0').toUpperCase()}$rgb';
}

class TextSegment {
  String text;
  String color;
  FontInfo? font;

  TextSegment({
    required this.text,
    required this.color,
    this.font,
  });

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'color': color,
      'font': font?.toMap(),
    };
  }

  factory TextSegment.fromMap(Map<String, dynamic> map) {
    return TextSegment(
      text: map['text'] ?? '',
      color: map['color'] ?? '#000000',
      font: map['font'] != null ? FontInfo.fromMap(Map<String, dynamic>.from(map['font'] as Map)) : null,
    );
  }
}

class _TextOverlay {
  String text;
  double x;
  double y;
  double fontSize;
  String color;
  FontInfo? font;
  bool showShadow;
  String shadowColor;
  double shadowBlur;
  double shadowOffsetX;
  double shadowOffsetY;
  TextAlign textAlign;
  String anchor;
  double scale;
  double lineHeight;
  double letterSpacing;
  double wordSpacing;
  double opacity;
  bool isSplitWord;
  String? groupId;
  String? originalFullText;
  bool isLocked;
  List<TextSegment>? styleSegments;

  _TextOverlay({
    required this.text,
    this.x = 0.5,
    this.y = 0.25,
    this.fontSize = 30.0,
    this.color = "#000000",
    this.font,
    this.showShadow = false,
    this.shadowColor = "#000000",
    this.shadowBlur = 8.0,
    this.shadowOffsetX = 2.0,
    this.shadowOffsetY = 2.0,
    this.textAlign = TextAlign.center,
    this.anchor = "center",
    this.scale = 1.0,
    this.lineHeight = 1.2,
    this.letterSpacing = 0.0,
    this.wordSpacing = 0.0,
    this.opacity = 1.0,
    this.isSplitWord = false,
    this.groupId,
    this.originalFullText,
    this.isLocked = false,
    this.styleSegments,
  });

  Map<String, dynamic> toMap(double width, double height, String resolvedFontPath) {
    return {
      'text': text,
      'x': x * width,
      'y': y * height,
      'fontSize': fontSize * scale,
      'color': _colorWithAlpha(color, opacity),
      'fontPath': resolvedFontPath,
      'showShadow': showShadow,
      'shadowColor': shadowColor,
      'shadowBlur': shadowBlur,
      'shadowOffsetX': shadowOffsetX,
      'shadowOffsetY': shadowOffsetY,
      'textAlign': textAlign.name,
      'maxWidth': width * 0.8 * scale,
      'anchor': anchor,
      'scale': scale,
      'lineHeight': lineHeight,
      'letterSpacing': letterSpacing,
      'wordSpacing': wordSpacing,
    };
  }
}

class _ImagePostMakerScreenState extends State<ImagePostMakerScreen> with WidgetsBindingObserver {
  static const platform = MethodChannel('com.quickpost.app/processor');
  final GlobalKey _repaintKey = GlobalKey();

  File? _selectedImage;
  double _imageAspectRatio = 1.0;
  int _imageWidth = 1080;
  int _imageHeight = 1080;
  bool _isProcessing = false;

  List<_Patch> _patches = [];
  int? _selectedPatchIndex;

  List<_TextOverlay> _textOverlays = [];
  int? _selectedTextOverlayIndex;
  Set<int> _selectedTextOverlayIndices = {};
  bool _multiSelectMode = false;

  List<_ImageOverlay> _imageOverlays = [];
  int? _selectedImageOverlayIndex;

  // Watermark parameters matching WatermarkPreset
  String _watermarkType = 'profile_vertical'; // profile, profile_vertical, profile_dots, text, wire, image, none
  bool _fullScreen = true;
  String _bgColor = '#FFFFFF';
  bool _showBox = false;
  String _boxColor = '#000000';
  double _boxOpacity = 0.3;
  double _boxRadius = 12.0;

  double _watermarkX = 0.5;
  double _watermarkY = 0.85;
  double _fontSize = 30.0;
  double _iconSize = 80.0;
  String _textColor = '#000000';
  String _accentColor = '#888888';
  String _username = 'Username';
  String _handle = '@handle';

  File? _profileImage;
  File? _bgImage;

  FontInfo? _selectedUsernameFont;
  FontInfo? _selectedHandleFont;

  bool _showStoryRing = true;
  bool _isCustomRingColor = false;
  String _storyRingColor = '#FF4081';
  double _storyRingWidth = 5.0;

  bool _isVerified = true;
  String _verifiedBadgeColor = '#1DA1F2';
  String _verifiedBadgeAttachTo = 'handle'; // username or handle

  double _watermarkScale = 1.0;
  double _usernameSize = 36.0;
  double _handleSize = 30.0;

  double _bgBrightness = 1.0;
  double _bgSaturation = 1.0;
  double _bgBlur = 0.0;

  double _videoRadius = 0.0; // In Dart UI we reuse it for image
  double _videoBorderWidth = 0.0;
  String _videoBorderColor = '#000000';
  double _videoScale = 1.0;
  double _videoY = 0.5;

  double _usernameOpacity = 1.0;
  double _handleOpacity = 1.0;

  bool _showUsernameShadow = false;
  String _usernameShadowColor = '#000000';
  double _usernameShadowBlur = 4.0;
  double _usernameShadowOffsetX = 1.0;
  double _usernameShadowOffsetY = 1.0;

  bool _showHandleShadow = false;
  String _handleShadowColor = '#000000';
  double _handleShadowBlur = 4.0;
  double _handleShadowOffsetX = 1.0;
  double _handleShadowOffsetY = 1.0;

  bool _showIconShadow = false;
  String _iconShadowColor = '#000000';
  double _iconShadowBlur = 4.0;
  double _iconShadowOffsetX = 1.0;
  double _iconShadowOffsetY = 1.0;
  // Mask settings
  int _maskType = 0; // 0: None, 1: Bottom, 2: Top, 3: Full, 4: Left, 5: Right
  double _maskOpacity = 0.5;
  double _maskStart = 0.0;
  double _maskEnd = 1.0;
  Color _maskColor = Colors.black;
  bool _showVideoShadow = false;
  String _videoShadowColor = '#000000';
  double _videoShadowBlur = 10.0;
  double _videoShadowSpread = 0.0;
  double _videoShadowOffsetX = 0.0;
  double _videoShadowOffsetY = 0.0;

  // Wire Watermark Specifics
  double _wireRadius = 12.0;
  double _wireWidth = 1.5;
  String _wireColor = '#FFFFFF';
  bool _wireCutout = true;
  bool _wireCutoutDots = true;
  double _wireInset = 40.0;
  String _wireTextPosition = 'bottom';
  double _wireGap = 16.0;

  double _lastPreviewWidth = 360.0;

  int _selectedTabIndex = 6; // Default to Presets
  int _selectedStyleSubTab = 0; // Maintain style subtab state
  int _selectedPresetSubTab = 0; // 0: Watermark Presets, 1: Project Presets
  bool _showControls = true;
  bool _isTabContentExpanded = true;

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _handleController = TextEditingController();
  final TextEditingController _overlayTextController = TextEditingController();
  int? _lastSelectedOverlayIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AnalyticsService().setCurrentScreen(screenName: 'Image Post Maker');

    _usernameController.text = _username;
    _handleController.text = _handle;

    _loadPreset();

    if (widget.sharedImagePaths != null && widget.sharedImagePaths!.isNotEmpty) {
      _loadImage(File(widget.sharedImagePaths!.first));
    }
  }

  @override
  void dispose() {
    _saveCurrentAsLatestPreset();
    WidgetsBinding.instance.removeObserver(this);
    _usernameController.dispose();
    _handleController.dispose();
    _overlayTextController.dispose();
    super.dispose();
  }

  void _loadImage(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frameInfo = await codec.getNextFrame();
      setState(() {
        _selectedImage = file;
        _imageWidth = frameInfo.image.width;
        _imageHeight = frameInfo.image.height;
        _imageAspectRatio = _imageWidth / _imageHeight;
      });
    } catch (e) {
      _showToast('Failed to load image: $e', isError: true);
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        _loadImage(File(image.path));
      }
    } catch (e) {
      _showToast('Error picking image: $e', isError: true);
    }
  }

  Future<void> _pickProfileImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) setState(() => _profileImage = File(image.path));
    } catch (e) {
      _showToast('Error picking icon: $e', isError: true);
    }
  }

  Future<void> _pickBgImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) setState(() => _bgImage = File(image.path));
    } catch (e) {
      _showToast('Error picking background image: $e', isError: true);
    }
  }

  FontInfo _getAvailableFontOrFallback(String? family) {
    if (family == null || family.isEmpty) {
      return const FontInfo(family: 'KleeOne', displayName: 'Klee One SemiBold', weight: FontWeight.w600, assetPath: 'assets/fonts/KleeOne-SemiBold.ttf');
    }
    final allFonts = getAllFonts();
    try {
      try {
        final font = allFonts.firstWhere((f) => f.displayName == family);
        if (font.isCustom) {
          if (font.filePath != null && File(font.filePath!).existsSync()) {
            return font;
          }
        } else {
          return font;
        }
      } catch (_) {}

      final font = allFonts.firstWhere((f) => f.family == family);
      if (font.isCustom) {
        if (font.filePath != null && File(font.filePath!).existsSync()) {
          return font;
        }
      } else {
        return font;
      }
    } catch (_) {}
    return const FontInfo(family: 'KleeOne', displayName: 'Klee One SemiBold', weight: FontWeight.w600, assetPath: 'assets/fonts/KleeOne-SemiBold.ttf');
  }

  void _loadWatermarkPreset(WatermarkPreset target) {
    setState(() {
      _watermarkType = target.watermarkType;
      _fullScreen = target.fullScreen;
      _bgColor = target.bgColor;
      _showBox = target.showBox;
      _boxColor = target.boxColor;
      _boxOpacity = target.boxOpacity;
      _boxRadius = target.boxRadius;
      _watermarkX = target.watermarkX;
      _watermarkY = target.videoY; // videoY represents watermarkY in image post
      _fontSize = target.fontSize;
      _iconSize = target.iconSize;
      _textColor = target.textColor;
      _accentColor = target.accentColor;
      _username = target.username;
      _handle = target.handle;
      _selectedUsernameFont = _getAvailableFontOrFallback(target.fontFamily);
      _selectedHandleFont = _getAvailableFontOrFallback(target.handleFontFamily ?? target.fontFamily);
      _showStoryRing = target.showStoryRing;
      _isVerified = target.isVerified;

      if (target.profileImagePath != null && target.profileImagePath!.isNotEmpty) {
        final pf = File(target.profileImagePath!);
        if (pf.existsSync()) {
          _profileImage = pf;
        } else {
          _profileImage = null;
        }
      } else {
        _profileImage = null;
      }

      try {
        _storyRingWidth = target.storyRingWidth;
        _storyRingColor = target.storyRingColor;
        _isCustomRingColor = target.isCustomRingColor;
        _verifiedBadgeColor = target.verifiedBadgeColor;
        _verifiedBadgeAttachTo = target.verifiedBadgeAttachTo;
        _watermarkScale = target.watermarkScale;
        _usernameSize = target.usernameSize;
        _handleSize = target.handleSize;
        _usernameOpacity = target.usernameOpacity;
        _handleOpacity = target.handleOpacity;
        _wireRadius = target.wireRadius;
        _wireWidth = target.wireWidth;
        _wireColor = target.wireColor;
        _wireCutout = target.wireCutout;
        _wireCutoutDots = target.wireCutoutDots;
        _wireInset = target.wireInset;
        _wireTextPosition = target.wireTextPosition;
        _wireGap = target.wireGap;
      } catch (_) {}

      if (_usernameController.text != _username) {
        _usernameController.text = _username;
      }
      if (_handleController.text != _handle) {
        _handleController.text = _handle;
      }
    });
  }

  Future<void> _loadPreset([ImagePostPreset? preset]) async {
    final target = preset ?? ImagePostPresetService.getLatestPreset();
    if (target == null) {
      _selectedUsernameFont = const FontInfo(family: 'KleeOne', displayName: 'Klee One SemiBold', weight: FontWeight.w600, assetPath: 'assets/fonts/KleeOne-SemiBold.ttf');
      _selectedHandleFont = const FontInfo(family: 'KleeOne', displayName: 'Klee One SemiBold', weight: FontWeight.w600, assetPath: 'assets/fonts/KleeOne-SemiBold.ttf');
      return;
    }

    if (target.customFonts.isNotEmpty) {
      for (final fontMap in target.customFonts) {
        final family = fontMap['family'];
        final filePath = fontMap['filePath'];
        if (family != null && filePath != null) {
          final alreadyRegistered = CustomFontManager().fonts.any((f) => f.familyName == family);
          if (!alreadyRegistered) {
            final fontFile = File(filePath);
            if (await fontFile.exists()) {
              await CustomFontManager().addFont(fontFile);
            }
          }
        }
      }
    }

    setState(() {
      _watermarkType = target.watermarkType;
      _fullScreen = target.fullScreen;
      _bgColor = target.bgColor;
      _showBox = target.showBox;
      _boxColor = target.boxColor;
      _boxOpacity = target.boxOpacity;
      _boxRadius = target.boxRadius;
      _videoRadius = target.videoRadius;
      _videoBorderWidth = target.videoBorderWidth;
      _videoBorderColor = target.videoBorderColor;
      _wireRadius = target.wireRadius;
      _wireWidth = target.wireWidth;
      _wireColor = target.wireColor;
      _wireCutout = target.wireCutout;
      _wireCutoutDots = target.wireCutoutDots;
      _wireInset = target.wireInset;
      _wireTextPosition = target.wireTextPosition;
      _wireGap = target.wireGap;
      _watermarkX = target.watermarkX;
      _watermarkY = target.watermarkY;
      _fontSize = target.fontSize;
      _iconSize = target.iconSize;
      _textColor = target.textColor;
      _accentColor = target.accentColor;
      _username = target.username;
      _handle = target.handle;

      _usernameController.text = _username;
      _handleController.text = _handle;

      _showUsernameShadow = target.showUsernameShadow;
      _usernameShadowColor = target.usernameShadowColor;
      _usernameShadowBlur = target.usernameShadowBlur;
      _showHandleShadow = target.showHandleShadow;
      _handleShadowColor = target.handleShadowColor;
      _handleShadowBlur = target.handleShadowBlur;
      _showIconShadow = target.showIconShadow;
      _iconShadowColor = target.iconShadowColor;
      _iconShadowBlur = target.iconShadowBlur;

      _usernameShadowOffsetX = target.usernameShadowOffsetX;
      _usernameShadowOffsetY = target.usernameShadowOffsetY;
      _handleShadowOffsetX = target.handleShadowOffsetX;
      _handleShadowOffsetY = target.handleShadowOffsetY;
      _iconShadowOffsetX = target.iconShadowOffsetX;
      _iconShadowOffsetY = target.iconShadowOffsetY;

      if (target.profileImagePath != null && target.profileImagePath!.isNotEmpty) {
        final pf = File(target.profileImagePath!);
        if (pf.existsSync()) {
          _profileImage = pf;
        } else {
          _profileImage = null;
        }
      } else {
        _profileImage = null;
      }

      if (target.bgImagePath != null && target.bgImagePath!.isNotEmpty) {
        final bf = File(target.bgImagePath!);
        if (bf.existsSync()) {
          _bgImage = bf;
        } else {
          _bgImage = null;
        }
      } else {
        _bgImage = null;
      }

      if (target.selectedImagePath != null && target.selectedImagePath!.isNotEmpty) {
        final sf = File(target.selectedImagePath!);
        if (sf.existsSync()) {
          _selectedImage = sf;
          _loadImage(sf);
        } else {
          _selectedImage = null;
        }
      } else {
        _selectedImage = null;
      }

      _selectedUsernameFont = _getAvailableFontOrFallback(target.fontFamily);
      _selectedHandleFont = _getAvailableFontOrFallback(target.handleFontFamily ?? target.fontFamily);
      _showStoryRing = target.showStoryRing;
      _isVerified = target.isVerified;
      _videoY = target.videoY;

      _storyRingWidth = target.storyRingWidth;
      _storyRingColor = target.storyRingColor;
      _isCustomRingColor = target.isCustomRingColor;
      _verifiedBadgeColor = target.verifiedBadgeColor;
      _verifiedBadgeAttachTo = target.verifiedBadgeAttachTo;
      _watermarkScale = target.watermarkScale;
      _usernameSize = target.usernameSize;
      _handleSize = target.handleSize;
      _bgBrightness = target.bgBrightness;
      _bgSaturation = target.bgSaturation;
      _bgBlur = target.bgBlur;
      _videoRadius = target.videoRadius;
      _videoBorderWidth = target.videoBorderWidth;
      _videoBorderColor = target.videoBorderColor;
      _videoScale = target.videoScale;
      _usernameOpacity = target.usernameOpacity;
      _handleOpacity = target.handleOpacity;
      _wireRadius = target.wireRadius;
      _wireWidth = target.wireWidth;
      _wireColor = target.wireColor;
      _wireCutout = target.wireCutout;
      _wireCutoutDots = target.wireCutoutDots;
      _wireInset = target.wireInset;
      _wireTextPosition = target.wireTextPosition;
      _wireGap = target.wireGap;

      _showVideoShadow = target.showVideoShadow;
      _videoShadowColor = target.videoShadowColor;
      _videoShadowBlur = target.videoShadowBlur;
      _videoShadowSpread = target.videoShadowSpread;
      _videoShadowOffsetX = target.videoShadowOffsetX;
      _videoShadowOffsetY = target.videoShadowOffsetY;

      _maskType = target.maskType;
      _maskOpacity = target.maskOpacity;
      _maskStart = target.maskStart;
      _maskEnd = target.maskEnd;
      try {
        final hexStr = target.maskColor.replaceFirst('#', '');
        _maskColor = Color(int.parse('FF$hexStr', radix: 16));
      } catch (e) {
        _maskColor = Colors.black;
      }

      // Load patches
      _patches = target.patches.map((p) => _Patch(
        x: p['x'] ?? 0.0,
        y: p['y'] ?? 0.0,
        width: p['width'] ?? 0.1,
        height: p['height'] ?? 0.1,
        color: p['color'] ?? '#000000',
        opacity: (p['opacity'] as num?)?.toDouble() ?? 1.0,
        radius: (p['radius'] as num?)?.toDouble() ?? 0.0,
        isTop: p['isTop'] ?? true,
      )).toList();

      // Load text overlays
      _textOverlays = target.textOverlays.map((t) => _TextOverlay(
        text: t['text'] ?? '',
        x: t['x'] ?? 0.5,
        y: t['y'] ?? 0.25,
        fontSize: (t['fontSize'] as num?)?.toDouble() ?? 30.0,
        color: t['color'] ?? '#000000',
        font: t['font'] != null
            ? FontInfo.fromMap(Map<String, dynamic>.from(t['font'] as Map))
            : FontInfo.getFontByFamily(t['fontFamily'] ?? ''),
        showShadow: t['showShadow'] ?? false,
        shadowColor: t['shadowColor'] ?? '#000000',
        shadowBlur: (t['shadowBlur'] as num?)?.toDouble() ?? 8.0,
        shadowOffsetX: (t['shadowOffsetX'] as num?)?.toDouble() ?? 2.0,
        shadowOffsetY: (t['shadowOffsetY'] as num?)?.toDouble() ?? 2.0,
        textAlign: TextAlign.values.firstWhere(
          (e) => e.name == t['textAlign'], 
          orElse: () => TextAlign.center
        ),
        anchor: t['anchor'] ?? 'center',
        scale: (t['scale'] as num?)?.toDouble() ?? 1.0,
        lineHeight: (t['lineHeight'] as num?)?.toDouble() ?? 1.2,
        letterSpacing: (t['letterSpacing'] as num?)?.toDouble() ?? 0.0,
        wordSpacing: (t['wordSpacing'] as num?)?.toDouble() ?? 0.0,
        opacity: (t['opacity'] as num?)?.toDouble() ?? 1.0,
        isSplitWord: t['isSplitWord'] ?? false,
        groupId: t['groupId'],
        originalFullText: t['originalFullText'],
        isLocked: t['isLocked'] ?? false,
        styleSegments: t['styleSegments'] != null
            ? (t['styleSegments'] as List<dynamic>).map((s) => TextSegment.fromMap(Map<String, dynamic>.from(s as Map))).toList()
            : null,
      )).toList();

      // Load image overlays
      _imageOverlays = target.imageOverlays.map((io) => _ImageOverlay(
        path: io['path'] ?? '',
        x: io['x'] ?? 0.5,
        y: io['y'] ?? 0.5,
        scale: (io['scale'] as num?)?.toDouble() ?? 0.2,
        opacity: (io['opacity'] as num?)?.toDouble() ?? 1.0,
        rotation: (io['rotation'] as num?)?.toDouble() ?? 0.0,
      )).toList();
    });
  }

  void _savePresetDialog() {
    final TextEditingController nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Preset'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Preset Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final presetId = DateTime.now().millisecondsSinceEpoch.toString();
              final p = await _copyAssetsAndBuildPreset(presetId, nameCtrl.text.trim());
              await ImagePostPresetService.savePreset(p);
              Navigator.pop(context);
              setState(() {});
              _showToast('Preset saved!');
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _updateProjectPreset(ImagePostPreset preset) async {
    final p = await _copyAssetsAndBuildPreset(preset.id, preset.name);
    await ImagePostPresetService.savePreset(p);
    if (mounted) {
      setState(() {});
      _showToast('✅ Updated project template "${preset.name}" with current settings');
    }
  }

  void _updateWatermarkPreset(WatermarkPreset preset) async {
    preset.watermarkType = _watermarkType;
    preset.fullScreen = _fullScreen;
    preset.bgColor = _bgColor;
    preset.showBox = _showBox;
    preset.boxColor = _boxColor;
    preset.boxOpacity = _boxOpacity;
    preset.boxRadius = _boxRadius;
    preset.watermarkX = _watermarkX;
    preset.watermarkY = _watermarkY; // videoY represents watermarkY in image post
    preset.fontSize = _fontSize;
    preset.iconSize = _iconSize;
    preset.textColor = _textColor;
    preset.accentColor = _accentColor;
    preset.username = _username;
    preset.handle = _handle;
    preset.fontFamily = _selectedUsernameFont?.displayName ?? 'Klee One SemiBold';
    preset.handleFontFamily = _selectedHandleFont?.displayName ?? _selectedUsernameFont?.displayName ?? 'Klee One SemiBold';
    preset.profileImagePath = _profileImage?.path;
    preset.showStoryRing = _showStoryRing;
    preset.isVerified = _isVerified;
    preset.showUsernameShadow = _showUsernameShadow;
    preset.usernameShadowColor = _usernameShadowColor;
    preset.usernameShadowBlur = _usernameShadowBlur;
    preset.usernameShadowOffsetX = _usernameShadowOffsetX;
    preset.usernameShadowOffsetY = _usernameShadowOffsetY;
    preset.showHandleShadow = _showHandleShadow;
    preset.handleShadowColor = _handleShadowColor;
    preset.handleShadowBlur = _handleShadowBlur;
    preset.handleShadowOffsetX = _handleShadowOffsetX;
    preset.handleShadowOffsetY = _handleShadowOffsetY;
    preset.showIconShadow = _showIconShadow;
    preset.iconShadowColor = _iconShadowColor;
    preset.iconShadowBlur = _iconShadowBlur;
    preset.iconShadowOffsetX = _iconShadowOffsetX;
    preset.iconShadowOffsetY = _iconShadowOffsetY;
    preset.storyRingWidth = _storyRingWidth;
    preset.storyRingColor = _storyRingColor;
    preset.isCustomRingColor = _isCustomRingColor;
    preset.verifiedBadgeColor = _verifiedBadgeColor;
    preset.verifiedBadgeAttachTo = _verifiedBadgeAttachTo;
    preset.watermarkScale = _watermarkScale;
    preset.usernameSize = _usernameSize;
    preset.handleSize = _handleSize;
    preset.bgBrightness = _bgBrightness;
    preset.bgSaturation = _bgSaturation;
    preset.bgBlur = _bgBlur;
    preset.videoRadius = _videoRadius;
    preset.videoBorderWidth = _videoBorderWidth;
    preset.videoBorderColor = _videoBorderColor;
    preset.videoScale = _videoScale;
    preset.videoY = _videoY;
    preset.usernameOpacity = _usernameOpacity;
    preset.handleOpacity = _handleOpacity;
    preset.wireRadius = _wireRadius;
    preset.wireWidth = _wireWidth;
    preset.wireColor = _wireColor;
    preset.wireCutout = _wireCutout;
    preset.wireCutoutDots = _wireCutoutDots;
    preset.wireInset = _wireInset;
    preset.wireTextPosition = _wireTextPosition;
    preset.wireGap = _wireGap;

    await WatermarkPresetService.savePreset(preset);
    if (mounted) {
      setState(() {});
      _showToast('✅ Updated watermark style "${preset.name}" with current settings');
    }
  }

  void _renamePreset(ImagePostPreset preset) {
    final TextEditingController nameCtrl = TextEditingController(text: preset.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Preset'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Preset Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final renamedPreset = ImagePostPreset(
                id: preset.id,
                name: nameCtrl.text.trim(),
                watermarkType: preset.watermarkType,
                fullScreen: preset.fullScreen,
                bgColor: preset.bgColor,
                showBox: preset.showBox,
                boxColor: preset.boxColor,
                boxOpacity: preset.boxOpacity,
                boxRadius: preset.boxRadius,
                videoRadius: preset.videoRadius,
                videoBorderWidth: preset.videoBorderWidth,
                videoBorderColor: preset.videoBorderColor,
                wireRadius: preset.wireRadius,
                wireWidth: preset.wireWidth,
                wireColor: preset.wireColor,
                wireCutout: preset.wireCutout,
                wireCutoutDots: preset.wireCutoutDots,
                wireInset: preset.wireInset,
                wireTextPosition: preset.wireTextPosition,
                wireGap: preset.wireGap,
                watermarkX: preset.watermarkX,
                watermarkY: preset.watermarkY,
                fontSize: preset.fontSize,
                iconSize: preset.iconSize,
                textColor: preset.textColor,
                accentColor: preset.accentColor,
                fontFamily: preset.fontFamily,
                handleFontFamily: preset.handleFontFamily,
                username: preset.username,
                handle: preset.handle,
                profileImagePath: preset.profileImagePath,
                showStoryRing: preset.showStoryRing,
                isVerified: preset.isVerified,
                videoY: preset.videoY,
                storyRingColor: preset.storyRingColor,
                storyRingWidth: preset.storyRingWidth,
                isCustomRingColor: preset.isCustomRingColor,
                verifiedBadgeColor: preset.verifiedBadgeColor,
                verifiedBadgeAttachTo: preset.verifiedBadgeAttachTo,
                watermarkScale: preset.watermarkScale,
                usernameSize: preset.usernameSize,
                handleSize: preset.handleSize,
                bgBrightness: preset.bgBrightness,
                bgSaturation: preset.bgSaturation,
                bgBlur: preset.bgBlur,
                videoScale: preset.videoScale,
                usernameOpacity: preset.usernameOpacity,
                handleOpacity: preset.handleOpacity,
                showUsernameShadow: preset.showUsernameShadow,
                usernameShadowColor: preset.usernameShadowColor,
                usernameShadowBlur: preset.usernameShadowBlur,
                usernameShadowOffsetX: preset.usernameShadowOffsetX,
                usernameShadowOffsetY: preset.usernameShadowOffsetY,
                showHandleShadow: preset.showHandleShadow,
                handleShadowColor: preset.handleShadowColor,
                handleShadowBlur: preset.handleShadowBlur,
                handleShadowOffsetX: preset.handleShadowOffsetX,
                handleShadowOffsetY: preset.handleShadowOffsetY,
                showIconShadow: preset.showIconShadow,
                iconShadowColor: preset.iconShadowColor,
                iconShadowBlur: preset.iconShadowBlur,
                iconShadowOffsetX: preset.iconShadowOffsetX,
                iconShadowOffsetY: preset.iconShadowOffsetY,
                showVideoShadow: preset.showVideoShadow,
                videoShadowColor: preset.videoShadowColor,
                videoShadowBlur: preset.videoShadowBlur,
                videoShadowSpread: preset.videoShadowSpread,
                videoShadowOffsetX: preset.videoShadowOffsetX,
                videoShadowOffsetY: preset.videoShadowOffsetY,
                patches: preset.patches,
                textOverlays: preset.textOverlays,
                imageOverlays: preset.imageOverlays,
              );
              await ImagePostPresetService.savePreset(renamedPreset);
              Navigator.pop(context);
              setState(() {});
              _showToast('Preset renamed!');
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _exportPresets() async {
    setState(() => _isProcessing = true);
    try {
      final zipData = await ImagePostPresetService.exportPresetsZip();
      if (zipData == null) {
        throw Exception('ZIP generation failed');
      }
      final dynamic success = await platform.invokeMethod('exportFile', {
        'bytes': Uint8List.fromList(zipData),
        'filename': 'QuickPost_ImagePost_Presets.zip',
        'mimeType': 'application/zip',
      });
      if (success == true && mounted) {
        _showToast('Presets exported successfully!');
      }
    } catch (e) {
      if (mounted) _showToast('Export failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _importPresets() async {
    setState(() => _isProcessing = true);
    try {
      final String? path = await platform.invokeMethod('importFile', {
        'mimeType': '*/*',
      });
      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          final ext = path.split('.').last.toLowerCase();
          int imported = 0;
          if (ext == 'zip') {
            final bytes = await file.readAsBytes();
            imported = await ImagePostPresetService.importPresetsZip(bytes);
          } else {
            // Assume JSON
            final jsonStr = await file.readAsString();
            imported = await ImagePostPresetService.importPresetsJson(jsonStr);
          }
          if (mounted) {
            setState(() {});
            _showToast('Imported $imported presets successfully!');
          }
        }
      }
    } catch (e) {
      if (mounted) _showToast('Import failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _exportProjectZip() async {
    setState(() => _isProcessing = true);
    try {
      final archive = Archive();
      final Map<String, dynamic> projectJson = {
        'version': 1,
        'watermarkType': _watermarkType,
        'fullScreen': _fullScreen,
        'bgColor': _bgColor,
        'showBox': _showBox,
        'boxColor': _boxColor,
        'boxOpacity': _boxOpacity,
        'boxRadius': _boxRadius,
        'videoRadius': _videoRadius,
        'videoBorderWidth': _videoBorderWidth,
        'videoBorderColor': _videoBorderColor,
        'wireRadius': _wireRadius,
        'wireWidth': _wireWidth,
        'wireColor': _wireColor,
        'wireCutout': _wireCutout,
        'wireCutoutDots': _wireCutoutDots,
        'wireInset': _wireInset,
        'wireTextPosition': _wireTextPosition,
        'wireGap': _wireGap,
        'watermarkX': _watermarkX,
        'watermarkY': _watermarkY,
        'fontSize': _fontSize,
        'iconSize': _iconSize,
        'textColor': _textColor,
        'accentColor': _accentColor,
        'username': _username,
        'handle': _handle,
        'usernameFontFamily': _selectedUsernameFont?.family ?? 'System',
        'handleFontFamily': _selectedHandleFont?.family ?? 'System',
        'showStoryRing': _showStoryRing,
        'isVerified': _isVerified,
        'videoY': _videoY,
        'storyRingColor': _storyRingColor,
        'storyRingWidth': _storyRingWidth,
        'isCustomRingColor': _isCustomRingColor,
        'verifiedBadgeColor': _verifiedBadgeColor,
        'verifiedBadgeAttachTo': _verifiedBadgeAttachTo,
        'watermarkScale': _watermarkScale,
        'usernameSize': _usernameSize,
        'handleSize': _handleSize,
        'bgBrightness': _bgBrightness,
        'bgSaturation': _bgSaturation,
        'bgBlur': _bgBlur,
        'videoScale': _videoScale,
        'usernameOpacity': _usernameOpacity,
        'handleOpacity': _handleOpacity,
        'showUsernameShadow': _showUsernameShadow,
        'usernameShadowColor': _usernameShadowColor,
        'usernameShadowBlur': _usernameShadowBlur,
        'usernameShadowOffsetX': _usernameShadowOffsetX,
        'usernameShadowOffsetY': _usernameShadowOffsetY,
        'showHandleShadow': _showHandleShadow,
        'handleShadowColor': _handleShadowColor,
        'handleShadowBlur': _handleShadowBlur,
        'handleShadowOffsetX': _handleShadowOffsetX,
        'handleShadowOffsetY': _handleShadowOffsetY,
        'showIconShadow': _showIconShadow,
        'iconShadowColor': _iconShadowColor,
        'iconShadowBlur': _iconShadowBlur,
        'iconShadowOffsetX': _iconShadowOffsetX,
        'iconShadowOffsetY': _iconShadowOffsetY,
        'showVideoShadow': _showVideoShadow,
        'videoShadowColor': _videoShadowColor,
        'videoShadowBlur': _videoShadowBlur,
        'videoShadowSpread': _videoShadowSpread,
        'videoShadowOffsetX': _videoShadowOffsetX,
        'videoShadowOffsetY': _videoShadowOffsetY,
        'maskType': _maskType,
        'maskOpacity': _maskOpacity,
        'maskStart': _maskStart,
        'maskEnd': _maskEnd,
        'maskColor': '#${_maskColor.value.toRadixString(16).padLeft(8, '0').substring(2)}',
      };

      // Add profile image
      if (_profileImage != null && await _profileImage!.exists()) {
        final bytes = await _profileImage!.readAsBytes();
        final ext = _profileImage!.path.split('.').last;
        final name = 'profile_image.$ext';
        archive.addFile(ArchiveFile('assets/$name', bytes.length, bytes));
        projectJson['profileImageFile'] = name;
      }

      // Add selected main image
      if (_selectedImage != null && await _selectedImage!.exists()) {
        final bytes = await _selectedImage!.readAsBytes();
        final ext = _selectedImage!.path.split('.').last;
        final name = 'selected_image.$ext';
        archive.addFile(ArchiveFile('assets/$name', bytes.length, bytes));
        projectJson['selectedImageFile'] = name;
      }

      // Add background image
      if (_bgImage != null && await _bgImage!.exists()) {
        final bytes = await _bgImage!.readAsBytes();
        final ext = _bgImage!.path.split('.').last;
        final name = 'bg_image.$ext';
        archive.addFile(ArchiveFile('assets/$name', bytes.length, bytes));
        projectJson['bgImageFile'] = name;
      }

      // Add shape patches
      projectJson['patches'] = _patches.map((patch) => {
        'x': patch.x,
        'y': patch.y,
        'width': patch.width,
        'height': patch.height,
        'color': patch.color,
        'opacity': patch.opacity,
        'radius': patch.radius,
        'isTop': patch.isTop,
      }).toList();

      // Add custom fonts registry
      final List<Map<String, dynamic>> customFontsMetadata = [];

      // Check username font
      if (_selectedUsernameFont != null && _selectedUsernameFont!.isCustom && _selectedUsernameFont!.filePath != null) {
        final file = File(_selectedUsernameFont!.filePath!);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final fileName = _selectedUsernameFont!.filePath!.split('/').last;
          archive.addFile(ArchiveFile('fonts/$fileName', bytes.length, bytes));
          customFontsMetadata.add({
            'family': _selectedUsernameFont!.family,
            'displayName': _selectedUsernameFont!.displayName,
            'fileName': fileName,
          });
        }
      }

      // Check handle font
      if (_selectedHandleFont != null && _selectedHandleFont!.isCustom && _selectedHandleFont!.filePath != null && _selectedHandleFont!.family != _selectedUsernameFont?.family) {
        final file = File(_selectedHandleFont!.filePath!);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final fileName = _selectedHandleFont!.filePath!.split('/').last;
          archive.addFile(ArchiveFile('fonts/$fileName', bytes.length, bytes));
          customFontsMetadata.add({
            'family': _selectedHandleFont!.family,
            'displayName': _selectedHandleFont!.displayName,
            'fileName': fileName,
          });
        }
      }

      // Add text overlays and their custom fonts
      final List<Map<String, dynamic>> textOverlaysList = [];
      for (int i = 0; i < _textOverlays.length; i++) {
        final t = _textOverlays[i];
        String? fontFileName;
        if (t.font != null && t.font!.isCustom && t.font!.filePath != null) {
          final file = File(t.font!.filePath!);
          if (await file.exists()) {
            fontFileName = t.font!.filePath!.split('/').last;
            // Check if already added to archive
            final alreadyAdded = customFontsMetadata.any((f) => f['fileName'] == fontFileName);
            if (!alreadyAdded) {
              final bytes = await file.readAsBytes();
              archive.addFile(ArchiveFile('fonts/$fontFileName', bytes.length, bytes));
              customFontsMetadata.add({
                'family': t.font!.family,
                'displayName': t.font!.displayName,
                'fileName': fontFileName,
              });
            }
          }
        }

        textOverlaysList.add({
          'text': t.text,
          'x': t.x,
          'y': t.y,
          'fontSize': t.fontSize,
          'color': t.color,
          'fontFamily': t.font?.family ?? '',
          'font': t.font?.toMap(),
          'fontFileName': fontFileName,
          'showShadow': t.showShadow,
          'shadowColor': t.shadowColor,
          'shadowBlur': t.shadowBlur,
          'shadowOffsetX': t.shadowOffsetX,
          'shadowOffsetY': t.shadowOffsetY,
          'textAlign': t.textAlign.name,
          'anchor': t.anchor,
          'scale': t.scale,
          'lineHeight': t.lineHeight,
          'letterSpacing': t.letterSpacing,
          'wordSpacing': t.wordSpacing,
          'opacity': t.opacity,
          'isSplitWord': t.isSplitWord,
          'groupId': t.groupId,
          'originalFullText': t.originalFullText,
          'isLocked': t.isLocked,
          'styleSegments': t.styleSegments?.map((s) => s.toMap()).toList(),
        });
      }
      projectJson['textOverlays'] = textOverlaysList;
      projectJson['customFonts'] = customFontsMetadata;

      // Add image overlays
      final List<Map<String, dynamic>> imageOverlaysList = [];
      for (int i = 0; i < _imageOverlays.length; i++) {
        final io = _imageOverlays[i];
        final file = File(io.path);
        String? overlayFileName;
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final ext = io.path.split('.').last;
          overlayFileName = 'overlay_$i.$ext';
          archive.addFile(ArchiveFile('image_overlays/$overlayFileName', bytes.length, bytes));
        }
        imageOverlaysList.add({
          'fileName': overlayFileName,
          'x': io.x,
          'y': io.y,
          'scale': io.scale,
          'opacity': io.opacity,
          'rotation': io.rotation,
        });
      }
      projectJson['imageOverlays'] = imageOverlaysList;

      // Add project.json to archive
      final jsonStr = jsonEncode(projectJson);
      final jsonBytes = utf8.encode(jsonStr);
      archive.addFile(ArchiveFile('project.json', jsonBytes.length, jsonBytes));

      // Encode ZIP
      final zipEncoder = ZipEncoder();
      final zipData = zipEncoder.encode(archive);

      if (zipData == null) {
        throw Exception('ZIP encoding failed');
      }

      // Save ZIP file via native Storage Access Framework
      final dynamic success = await platform.invokeMethod('exportFile', {
        'bytes': Uint8List.fromList(zipData),
        'filename': 'QuickPost_ImagePost_Project.zip',
        'mimeType': 'application/zip',
      });

      if (success == true && mounted) {
        _showToast('Project exported successfully!');
      }
    } catch (e) {
      if (mounted) _showToast('Export failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _importProjectZip() async {
    setState(() => _isProcessing = true);
    try {
      final String? zipPath = await platform.invokeMethod('importFile', {
        'mimeType': 'application/zip',
      });
      if (zipPath == null) {
        setState(() => _isProcessing = false);
        return;
      }

      final file = File(zipPath);
      if (!await file.exists()) {
        throw Exception('Selected zip file does not exist locally');
      }

      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // Find project.json
      final projectJsonFile = archive.findFile('project.json');
      if (projectJsonFile == null) {
        throw Exception('Invalid project: project.json missing in archive');
      }

      final jsonStr = utf8.decode(projectJsonFile.content as List<int>);
      final Map<String, dynamic> projectJson = jsonDecode(jsonStr);

      final appDir = await getApplicationDocumentsDirectory();
      final importTimestamp = DateTime.now().millisecondsSinceEpoch;
      final targetDir = Directory('${appDir.path}/imported_project_$importTimestamp');
      await targetDir.create(recursive: true);

      // Extract all custom fonts first
      final customFontsMetadata = projectJson['customFonts'] as List<dynamic>? ?? [];
      final Map<String, String> fontNameMapping = {}; // maps archived family name to new registered family name

      for (final fontMeta in customFontsMetadata) {
        final family = fontMeta['family'] as String;
        final displayName = fontMeta['displayName'] as String;
        final fileName = fontMeta['fileName'] as String;

        final archivedFontFile = archive.findFile('fonts/$fileName');
        if (archivedFontFile != null) {
          final fontData = archivedFontFile.content as List<int>;
          final fontFile = File('${targetDir.path}/$fileName');
          await fontFile.writeAsBytes(fontData);

          // Add to CustomFontManager
          final entry = await CustomFontManager().addFont(fontFile);
          if (entry != null) {
            fontNameMapping[family] = entry.familyName;
          }
        }
      }

      // Extract profile image
      File? profileImage;
      if (projectJson['profileImageFile'] != null) {
        final fileName = projectJson['profileImageFile'] as String;
        final archivedFile = archive.findFile('assets/$fileName');
        if (archivedFile != null) {
          profileImage = File('${targetDir.path}/$fileName');
          await profileImage.writeAsBytes(archivedFile.content as List<int>);
        }
      }

      // Extract main selected image
      File? selectedImage;
      if (projectJson['selectedImageFile'] != null) {
        final fileName = projectJson['selectedImageFile'] as String;
        final archivedFile = archive.findFile('assets/$fileName');
        if (archivedFile != null) {
          selectedImage = File('${targetDir.path}/$fileName');
          await selectedImage.writeAsBytes(archivedFile.content as List<int>);
        }
      }

      // Extract background image
      File? bgImage;
      if (projectJson['bgImageFile'] != null) {
        final fileName = projectJson['bgImageFile'] as String;
        final archivedFile = archive.findFile('assets/$fileName');
        if (archivedFile != null) {
          bgImage = File('${targetDir.path}/$fileName');
          await bgImage.writeAsBytes(archivedFile.content as List<int>);
        }
      }

      // Extract shape patches
      final patchesData = projectJson['patches'] as List<dynamic>? ?? [];
      final List<_Patch> patches = patchesData.map((p) => _Patch(
        x: (p['x'] as num).toDouble(),
        y: (p['y'] as num).toDouble(),
        width: (p['width'] as num).toDouble(),
        height: (p['height'] as num).toDouble(),
        color: p['color'] as String,
        opacity: (p['opacity'] as num).toDouble(),
        radius: (p['radius'] as num).toDouble(),
        isTop: p['isTop'] as bool? ?? true,
      )).toList();

      // Extract text overlays (mapping custom fonts to their new registered families)
      final textOverlaysData = projectJson['textOverlays'] as List<dynamic>? ?? [];
      final List<_TextOverlay> textOverlays = textOverlaysData.map((t) {
        FontInfo font;
        if (t['font'] != null) {
          final loadedFont = FontInfo.fromMap(Map<String, dynamic>.from(t['font'] as Map));
          if (fontNameMapping.containsKey(loadedFont.family)) {
            font = FontInfo(
              family: fontNameMapping[loadedFont.family]!,
              displayName: loadedFont.displayName,
              isCustom: loadedFont.isCustom,
              filePath: loadedFont.filePath,
              assetPath: loadedFont.assetPath,
              weight: loadedFont.weight,
              style: loadedFont.style,
            );
          } else {
            font = loadedFont;
          }
        } else {
          final originalFamily = t['fontFamily'] as String? ?? '';
          final newFamily = fontNameMapping[originalFamily] ?? originalFamily;
          font = FontInfo.getFontByFamily(newFamily) ?? FontInfo(family: newFamily, displayName: newFamily);
        }

        return _TextOverlay(
          text: t['text'] as String,
          x: (t['x'] as num).toDouble(),
          y: (t['y'] as num).toDouble(),
          fontSize: (t['fontSize'] as num).toDouble(),
          color: t['color'] as String,
          font: font,
          showShadow: t['showShadow'] as bool? ?? false,
          shadowColor: t['shadowColor'] as String? ?? '#000000',
          shadowBlur: (t['shadowBlur'] as num?)?.toDouble() ?? 8.0,
          shadowOffsetX: (t['shadowOffsetX'] as num?)?.toDouble() ?? 2.0,
          shadowOffsetY: (t['shadowOffsetY'] as num?)?.toDouble() ?? 2.0,
          textAlign: TextAlign.values.firstWhere(
            (e) => e.name == t['textAlign'],
            orElse: () => TextAlign.center,
          ),
          anchor: t['anchor'] as String? ?? 'center',
          scale: (t['scale'] as num?)?.toDouble() ?? 1.0,
          lineHeight: (t['lineHeight'] as num?)?.toDouble() ?? 1.2,
          letterSpacing: (t['letterSpacing'] as num?)?.toDouble() ?? 0.0,
          wordSpacing: (t['wordSpacing'] as num?)?.toDouble() ?? 0.0,
          opacity: (t['opacity'] as num?)?.toDouble() ?? 1.0,
          isSplitWord: t['isSplitWord'] as bool? ?? false,
          groupId: t['groupId'] as String?,
          originalFullText: t['originalFullText'] as String?,
          isLocked: t['isLocked'] as bool? ?? false,
          styleSegments: t['styleSegments'] != null
              ? (t['styleSegments'] as List<dynamic>).map((s) => TextSegment.fromMap(Map<String, dynamic>.from(s as Map))).toList()
              : null,
        );
      }).toList();

      // Extract image overlays
      final imageOverlaysData = projectJson['imageOverlays'] as List<dynamic>? ?? [];
      final List<_ImageOverlay> imageOverlays = [];
      for (final io in imageOverlaysData) {
        final fileName = io['fileName'] as String?;
        if (fileName != null) {
          final archivedFile = archive.findFile('image_overlays/$fileName');
          if (archivedFile != null) {
            final overlayFile = File('${targetDir.path}/$fileName');
            await overlayFile.writeAsBytes(archivedFile.content as List<int>);

            imageOverlays.add(_ImageOverlay(
              path: overlayFile.path,
              x: (io['x'] as num).toDouble(),
              y: (io['y'] as num).toDouble(),
              scale: (io['scale'] as num).toDouble(),
              opacity: (io['opacity'] as num).toDouble(),
              rotation: (io['rotation'] as num).toDouble(),
            ));
          }
        }
      }

      // Update workspace state
      setState(() {
        _watermarkType = projectJson['watermarkType'] as String? ?? 'profile_vertical';
        _fullScreen = projectJson['fullScreen'] as bool? ?? true;
        _bgColor = projectJson['bgColor'] as String? ?? '#FFFFFF';
        _showBox = projectJson['showBox'] as bool? ?? false;
        _boxColor = projectJson['boxColor'] as String? ?? '#000000';
        _boxOpacity = (projectJson['boxOpacity'] as num?)?.toDouble() ?? 0.3;
        _boxRadius = (projectJson['boxRadius'] as num?)?.toDouble() ?? 12.0;
        _videoRadius = (projectJson['videoRadius'] as num?)?.toDouble() ?? 0.0;
        _videoBorderWidth = (projectJson['videoBorderWidth'] as num?)?.toDouble() ?? 0.0;
        _videoBorderColor = projectJson['videoBorderColor'] as String? ?? '#000000';
        _wireRadius = (projectJson['wireRadius'] as num?)?.toDouble() ?? 12.0;
        _wireWidth = (projectJson['wireWidth'] as num?)?.toDouble() ?? 1.5;
        _wireColor = projectJson['wireColor'] as String? ?? '#FFFFFF';
        _wireCutout = projectJson['wireCutout'] as bool? ?? true;
        _wireCutoutDots = projectJson['wireCutoutDots'] as bool? ?? true;
        _wireInset = (projectJson['wireInset'] as num?)?.toDouble() ?? 40.0;
        _wireTextPosition = projectJson['wireTextPosition'] as String? ?? 'bottom';
        _wireGap = (projectJson['wireGap'] as num?)?.toDouble() ?? 16.0;
        _watermarkX = (projectJson['watermarkX'] as num?)?.toDouble() ?? 0.5;
        _watermarkY = (projectJson['watermarkY'] as num?)?.toDouble() ?? 0.85;
        _fontSize = (projectJson['fontSize'] as num?)?.toDouble() ?? 30.0;
        _iconSize = (projectJson['iconSize'] as num?)?.toDouble() ?? 80.0;
        _textColor = projectJson['textColor'] as String? ?? '#000000';
        _accentColor = projectJson['accentColor'] as String? ?? '#888888';
        _username = projectJson['username'] as String? ?? 'Username';
        _handle = projectJson['handle'] as String? ?? '@handle';

        _usernameController.text = _username;
        _handleController.text = _handle;

        final origUserFont = projectJson['usernameFontFamily'] as String? ?? 'System';
        final newUserFont = fontNameMapping[origUserFont] ?? origUserFont;
        _selectedUsernameFont = FontInfo.getFontByFamily(newUserFont) ?? FontInfo(family: newUserFont, displayName: newUserFont);

        final origHandleFont = projectJson['handleFontFamily'] as String? ?? 'System';
        final newHandleFont = fontNameMapping[origHandleFont] ?? origHandleFont;
        _selectedHandleFont = FontInfo.getFontByFamily(newHandleFont) ?? FontInfo(family: newHandleFont, displayName: newHandleFont);

        _showStoryRing = projectJson['showStoryRing'] as bool? ?? true;
        _isVerified = projectJson['isVerified'] as bool? ?? true;
        _videoY = (projectJson['videoY'] as num?)?.toDouble() ?? 0.5;
        _storyRingColor = projectJson['storyRingColor'] as String? ?? '#FF4081';
        _storyRingWidth = (projectJson['storyRingWidth'] as num?)?.toDouble() ?? 5.0;
        _isCustomRingColor = projectJson['isCustomRingColor'] as bool? ?? false;
        _verifiedBadgeColor = projectJson['verifiedBadgeColor'] as String? ?? '#1DA1F2';
        _verifiedBadgeAttachTo = projectJson['verifiedBadgeAttachTo'] as String? ?? 'handle';
        _watermarkScale = (projectJson['watermarkScale'] as num?)?.toDouble() ?? 1.0;
        _usernameSize = (projectJson['usernameSize'] as num?)?.toDouble() ?? 36.0;
        _handleSize = (projectJson['handleSize'] as num?)?.toDouble() ?? 30.0;
        _bgBrightness = (projectJson['bgBrightness'] as num?)?.toDouble() ?? 1.0;
        _bgSaturation = (projectJson['bgSaturation'] as num?)?.toDouble() ?? 1.0;
        _bgBlur = (projectJson['bgBlur'] as num?)?.toDouble() ?? 0.0;
        _videoScale = (projectJson['videoScale'] as num?)?.toDouble() ?? 1.0;
        _usernameOpacity = (projectJson['usernameOpacity'] as num?)?.toDouble() ?? 1.0;
        _handleOpacity = (projectJson['handleOpacity'] as num?)?.toDouble() ?? 1.0;
        _showUsernameShadow = projectJson['showUsernameShadow'] as bool? ?? false;
        _usernameShadowColor = projectJson['usernameShadowColor'] as String? ?? '#000000';
        _usernameShadowBlur = (projectJson['usernameShadowBlur'] as num?)?.toDouble() ?? 4.0;
        _usernameShadowOffsetX = (projectJson['usernameShadowOffsetX'] as num?)?.toDouble() ?? 1.0;
        _usernameShadowOffsetY = (projectJson['usernameShadowOffsetY'] as num?)?.toDouble() ?? 1.0;
        _showHandleShadow = projectJson['showHandleShadow'] as bool? ?? false;
        _handleShadowColor = projectJson['handleShadowColor'] as String? ?? '#000000';
        _handleShadowBlur = (projectJson['handleShadowBlur'] as num?)?.toDouble() ?? 4.0;
        _handleShadowOffsetX = (projectJson['handleShadowOffsetX'] as num?)?.toDouble() ?? 1.0;
        _handleShadowOffsetY = (projectJson['handleShadowOffsetY'] as num?)?.toDouble() ?? 1.0;
        _showIconShadow = projectJson['showIconShadow'] as bool? ?? false;
        _iconShadowColor = projectJson['iconShadowColor'] as String? ?? '#000000';
        _iconShadowBlur = (projectJson['iconShadowBlur'] as num?)?.toDouble() ?? 4.0;
        _iconShadowOffsetX = (projectJson['iconShadowOffsetX'] as num?)?.toDouble() ?? 1.0;
        _iconShadowOffsetY = (projectJson['iconShadowOffsetY'] as num?)?.toDouble() ?? 1.0;
        _showVideoShadow = projectJson['showVideoShadow'] as bool? ?? false;
        _videoShadowColor = projectJson['videoShadowColor'] as String? ?? '#000000';
        _videoShadowBlur = (projectJson['videoShadowBlur'] as num?)?.toDouble() ?? 10.0;
        _videoShadowSpread = (projectJson['videoShadowSpread'] as num?)?.toDouble() ?? 0.0;
        _videoShadowOffsetX = (projectJson['videoShadowOffsetX'] as num?)?.toDouble() ?? 0.0;
        _videoShadowOffsetY = (projectJson['videoShadowOffsetY'] as num?)?.toDouble() ?? 0.0;

        _maskType = projectJson['maskType'] as int? ?? 0;
        _maskOpacity = (projectJson['maskOpacity'] as num?)?.toDouble() ?? 0.5;
        _maskStart = (projectJson['maskStart'] as num?)?.toDouble() ?? 0.0;
        _maskEnd = (projectJson['maskEnd'] as num?)?.toDouble() ?? 1.0;
        try {
          final hexStr = (projectJson['maskColor'] as String? ?? '#000000').replaceFirst('#', '');
          _maskColor = Color(int.parse('FF$hexStr', radix: 16));
        } catch (e) {
          _maskColor = Colors.black;
        }

        _profileImage = profileImage;
        _selectedImage = selectedImage;
        _bgImage = bgImage;
        _patches = patches;
        _textOverlays = textOverlays;
        _imageOverlays = imageOverlays;
      });

      _showToast('Project imported successfully!');
    } catch (e) {
      if (mounted) _showToast('Import failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
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
      final String quoteString = selected.author.isNotEmpty
          ? '${selected.text}\n— ${selected.author}'
          : selected.text;

      setState(() {
        if (_selectedTextOverlayIndex != null &&
            _selectedTextOverlayIndex! < _textOverlays.length) {
          _textOverlays[_selectedTextOverlayIndex!].text = quoteString;
        } else {
          _textOverlays.add(_TextOverlay(
            text: quoteString,
            y: 0.35,
            fontSize: 28.0,
            font: const FontInfo(
              family: 'KleeOne',
              displayName: 'Klee One SemiBold',
              weight: FontWeight.w600,
              assetPath: 'assets/fonts/KleeOne-SemiBold.ttf',
            ),
          ));
          _selectedTextOverlayIndex = _textOverlays.length - 1;
          _selectedTextOverlayIndices.clear();
          _selectedTextOverlayIndices.add(_selectedTextOverlayIndex!);
        }
      });
    }
  }

  Future<ImagePostPreset> _copyAssetsAndBuildPreset(String id, String name) async {
    final appDir = await getApplicationDocumentsDirectory();
    final destDir = Directory('${appDir.path}/image_post_presets_assets/$id');
    if (await destDir.exists()) {
      try {
        await destDir.delete(recursive: true);
      } catch (_) {}
    }
    await destDir.create(recursive: true);

    String? profilePath;
    if (_profileImage != null && await _profileImage!.exists()) {
      final ext = _profileImage!.path.split('.').last;
      final file = File('${destDir.path}/profile_image.$ext');
      await _profileImage!.copy(file.path);
      profilePath = file.path;
    }

    String? bgImagePath;
    if (_bgImage != null && await _bgImage!.exists()) {
      final ext = _bgImage!.path.split('.').last;
      final file = File('${destDir.path}/bg_image.$ext');
      await _bgImage!.copy(file.path);
      bgImagePath = file.path;
    }

    String? selectedImagePath;
    if (_selectedImage != null && await _selectedImage!.exists()) {
      final ext = _selectedImage!.path.split('.').last;
      final file = File('${destDir.path}/selected_image.$ext');
      await _selectedImage!.copy(file.path);
      selectedImagePath = file.path;
    }

    final List<Map<String, dynamic>> resolvedImageOverlays = [];
    for (int i = 0; i < _imageOverlays.length; i++) {
      final io = _imageOverlays[i];
      final file = File(io.path);
      if (await file.exists()) {
        final ext = io.path.split('.').last;
        final destFile = File('${destDir.path}/overlay_$i.$ext');
        await file.copy(destFile.path);
        resolvedImageOverlays.add({
          'path': destFile.path,
          'x': io.x,
          'y': io.y,
          'scale': io.scale,
          'opacity': io.opacity,
          'rotation': io.rotation,
        });
      }
    }
    final List<Map<String, dynamic>> savedCustomFonts = [];
    final Set<String> processedFontFamilies = {};

    Future<void> copyFontIfCustom(FontInfo? font) async {
      if (font == null || !font.isCustom || font.filePath == null) return;
      if (processedFontFamilies.contains(font.family)) return;

      final fontFile = File(font.filePath!);
      if (await fontFile.exists()) {
        final fontDir = Directory('${destDir.path}/fonts');
        if (!await fontDir.exists()) {
          await fontDir.create(recursive: true);
        }
        final ext = font.filePath!.split('.').last;
        final destFontFile = File('${fontDir.path}/${font.family}.$ext');
        await fontFile.copy(destFontFile.path);

        savedCustomFonts.add({
          'family': font.family,
          'displayName': font.displayName,
          'filePath': destFontFile.path,
        });
        processedFontFamilies.add(font.family);
      }
    }

    await copyFontIfCustom(_selectedUsernameFont);
    await copyFontIfCustom(_selectedHandleFont);
    for (final t in _textOverlays) {
      await copyFontIfCustom(t.font);
    }

    return ImagePostPreset(
      id: id,
      name: name,
      watermarkType: _watermarkType,
      fullScreen: _fullScreen,
      bgColor: _bgColor,
      showBox: _showBox,
      boxColor: _boxColor,
      boxOpacity: _boxOpacity,
      boxRadius: _boxRadius,
      videoRadius: _videoRadius,
      videoBorderWidth: _videoBorderWidth,
      videoBorderColor: _videoBorderColor,
      wireRadius: _wireRadius,
      wireWidth: _wireWidth,
      wireColor: _wireColor,
      wireCutout: _wireCutout,
      wireCutoutDots: _wireCutoutDots,
      wireInset: _wireInset,
      wireTextPosition: _wireTextPosition,
      wireGap: _wireGap,
      maskType: _maskType,
      maskOpacity: _maskOpacity,
      maskStart: _maskStart,
      maskEnd: _maskEnd,
      maskColor: '#${_maskColor.value.toRadixString(16).padLeft(8, '0').substring(2)}',
      watermarkX: _watermarkX,
      watermarkY: _watermarkY,
      fontSize: _fontSize,
      iconSize: _iconSize,
      textColor: _textColor,
      accentColor: _accentColor,
      fontFamily: _selectedUsernameFont?.displayName ?? 'Klee One SemiBold',
      handleFontFamily: _selectedHandleFont?.displayName ?? 'Klee One SemiBold',
      username: _username,
      handle: _handle,
      profileImagePath: profilePath,
      bgImagePath: bgImagePath,
      selectedImagePath: selectedImagePath,
      showStoryRing: _showStoryRing,
      isVerified: _isVerified,
      videoY: _videoY,
      storyRingColor: _storyRingColor,
      storyRingWidth: _storyRingWidth,
      isCustomRingColor: _isCustomRingColor,
      verifiedBadgeColor: _verifiedBadgeColor,
      verifiedBadgeAttachTo: _verifiedBadgeAttachTo,
      watermarkScale: _watermarkScale,
      usernameSize: _usernameSize,
      handleSize: _handleSize,
      bgBrightness: _bgBrightness,
      bgSaturation: _bgSaturation,
      bgBlur: _bgBlur,
      videoScale: _videoScale,
      usernameOpacity: _usernameOpacity,
      handleOpacity: _handleOpacity,
      showUsernameShadow: _showUsernameShadow,
      usernameShadowColor: _usernameShadowColor,
      usernameShadowBlur: _usernameShadowBlur,
      usernameShadowOffsetX: _usernameShadowOffsetX,
      usernameShadowOffsetY: _usernameShadowOffsetY,
      showHandleShadow: _showHandleShadow,
      handleShadowColor: _handleShadowColor,
      handleShadowBlur: _handleShadowBlur,
      handleShadowOffsetX: _handleShadowOffsetX,
      handleShadowOffsetY: _handleShadowOffsetY,
      showIconShadow: _showIconShadow,
      iconShadowColor: _iconShadowColor,
      iconShadowBlur: _iconShadowBlur,
      iconShadowOffsetX: _iconShadowOffsetX,
      iconShadowOffsetY: _iconShadowOffsetY,
      showVideoShadow: _showVideoShadow,
      videoShadowColor: _videoShadowColor,
      videoShadowBlur: _videoShadowBlur,
      videoShadowSpread: _videoShadowSpread,
      videoShadowOffsetX: _videoShadowOffsetX,
      videoShadowOffsetY: _videoShadowOffsetY,
      patches: _patches.map((patch) => {
        'x': patch.x,
        'y': patch.y,
        'width': patch.width,
        'height': patch.height,
        'color': patch.color,
        'opacity': patch.opacity,
        'radius': patch.radius,
        'isTop': patch.isTop,
      }).toList(),
      textOverlays: _textOverlays.map((t) => {
        'text': t.text,
        'x': t.x,
        'y': t.y,
        'fontSize': t.fontSize,
        'color': t.color,
        'fontFamily': t.font?.family ?? '',
        'font': t.font?.toMap(),
        'showShadow': t.showShadow,
        'shadowColor': t.shadowColor,
        'shadowBlur': t.shadowBlur,
        'shadowOffsetX': t.shadowOffsetX,
        'shadowOffsetY': t.shadowOffsetY,
        'textAlign': t.textAlign.name,
        'anchor': t.anchor,
        'scale': t.scale,
        'lineHeight': t.lineHeight,
        'letterSpacing': t.letterSpacing,
        'wordSpacing': t.wordSpacing,
        'opacity': t.opacity,
        'isSplitWord': t.isSplitWord,
        'groupId': t.groupId,
        'originalFullText': t.originalFullText,
        'isLocked': t.isLocked,
        'styleSegments': t.styleSegments?.map((s) => s.toMap()).toList(),
      }).toList(),
      imageOverlays: resolvedImageOverlays,
      customFonts: savedCustomFonts,
    );
  }

  Future<void> _saveCurrentAsLatestPreset() async {
    try {
      final p = await _copyAssetsAndBuildPreset('latest_preset_auto', 'Latest Configuration');
      await ImagePostPresetService.savePreset(p);
    } catch (_) {}
  }

  void _showToast(String msg, {bool isError = false}) {
    toastification.show(
      context: context,
      title: Text(msg),
      autoCloseDuration: const Duration(seconds: 3),
      type: isError ? ToastificationType.error : ToastificationType.success,
      style: ToastificationStyle.flatColored,
    );
  }

  Future<void> _exportPost() async {
    if (_selectedImage == null) {
      _showToast('Please select a background image', isError: true);
      return;
    }

    await _saveCurrentAsLatestPreset();

    final prevPatchIdx = _selectedPatchIndex;
    final prevTextIdx = _selectedTextOverlayIndex;
    final prevTextIndices = Set<int>.from(_selectedTextOverlayIndices);
    final prevImgIdx = _selectedImageOverlayIndex;

    setState(() {
      _isProcessing = true;
      _selectedPatchIndex = -1;
      _selectedTextOverlayIndex = -1;
      _selectedTextOverlayIndices.clear();
      _selectedImageOverlayIndex = -1;
    });

    // Wait for the UI to rebuild and paint a clean frame without selection borders
    await Future.delayed(const Duration(milliseconds: 100));
    await WidgetsBinding.instance.endOfFrame;
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      final outAspect = _fullScreen ? 9 / 16 : _imageAspectRatio;
      final int baseWidth = 1080;
      final int exportWidth = baseWidth;
      final int exportHeight = (baseWidth / outAspect).round();

      final String? savedPath = await ImageGenerator.savePostToGallery(
        text: '',
        imageFile: _selectedImage,
        transform: null,
        selectedFont: null,
        templateKey: _repaintKey,
        outputWidth: exportWidth,
        outputHeight: exportHeight,
      );

      if (savedPath != null) {
        AdService().showInterstitialAd();
        _showToast('✅ Saved successfully to gallery!');
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Export Success'),
            content: Text('Saved to: $savedPath'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  OpenFile.open(savedPath);
                },
                child: const Text('Open'),
              ),
            ],
          ),
        );
      } else {
        _showToast('Failed to save image', isError: true);
      }
    } catch (e) {
      _showToast('Error exporting: $e', isError: true);
    } finally {
      setState(() {
        _isProcessing = false;
        _selectedPatchIndex = prevPatchIdx;
        _selectedTextOverlayIndex = prevTextIdx;
        _selectedTextOverlayIndices = prevTextIndices;
        _selectedImageOverlayIndex = prevImgIdx;
      });
    }
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', 'FF'), radix: 16));
    } catch (_) {
      return Colors.white;
    }
  }

  Color _parseColorWithAlpha(String hex, double opacity) {
    return _parseColor(hex).withOpacity(opacity);
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 720;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Stack(
        children: [
          SafeArea(
            child: isTablet
                ? Row(
                    children: [
                      Expanded(flex: 5, child: _buildPreviewArea()),
                      const VerticalDivider(width: 1),
                      Expanded(
                        flex: 4,
                        child: Column(
                          children: [
                            if (_isTabContentExpanded)
                              Expanded(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.all(16.0),
                                  child: _buildSelectedTabContent(),
                                ),
                              )
                            else
                              const Spacer(),
                            _buildControlTabs(),
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Expanded(child: _buildPreviewArea()),
                      if (_isTabContentExpanded)
                        Container(
                          height: 240,
                          color: Colors.white,
                          padding: const EdgeInsets.all(16.0),
                          child: SingleChildScrollView(
                            child: _buildSelectedTabContent(),
                          ),
                        ),
                      _buildControlTabs(),
                    ],
                  ),
          ),
          if (_isProcessing)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.4),
                child: const Center(
                  child: Card(
                    margin: EdgeInsets.all(32),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 20),
                          Text(
                            'Processing image post...\nPlease wait',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPreviewArea() {
    if (_selectedImage == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.image_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No background image selected', style: TextStyle(fontSize: 18, color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.photo_library),
              label: const Text('Select Background Image'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      );
    }

    final outAspect = _fullScreen ? 9 / 16 : _imageAspectRatio;

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            decoration: BoxDecoration(
              color: _parseColor(_bgColor),
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
            ),
            clipBehavior: Clip.antiAlias,
            child: RepaintBoundary(
              key: _repaintKey,
              child: AspectRatio(
                aspectRatio: outAspect,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return GestureDetector(
                      onTap: () => setState(() => _showControls = !_showControls),
                      onPanUpdate: (d) => setState(() {
                        _watermarkX = (d.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
                        _watermarkY = (d.localPosition.dy / constraints.maxHeight).clamp(0.0, 1.0);
                      }),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Canvas Background Image
                          if (_bgImage != null)
                            Positioned.fill(
                              child: ImageFiltered(
                                imageFilter: ui.ImageFilter.blur(sigmaX: _bgBlur / 5, sigmaY: _bgBlur / 5),
                                child: ColorFiltered(
                                  colorFilter: ColorFilter.matrix([
                                    0.213 + 0.787 * _bgSaturation, 0.715 - 0.715 * _bgSaturation, 0.072 - 0.072 * _bgSaturation, 0, 0,
                                    0.213 - 0.213 * _bgSaturation, 0.715 + 0.285 * _bgSaturation, 0.072 - 0.072 * _bgSaturation, 0, 0,
                                    0.213 - 0.213 * _bgSaturation, 0.715 - 0.715 * _bgSaturation, 0.072 + 0.928 * _bgSaturation, 0, 0,
                                    0, 0, 0, 1, 0,
                                  ]),
                                  child: ImageFiltered(
                                    imageFilter: ui.ColorFilter.mode(
                                      Colors.black.withOpacity((1.0 - _bgBrightness).clamp(0.0, 1.0)),
                                      BlendMode.darken,
                                    ),
                                    child: Image.file(_bgImage!, fit: BoxFit.cover),
                                  ),
                                ),
                              ),
                            ),
                          // Solid Color Canvas Fallback
                          if (_bgImage == null)
                            Positioned.fill(child: ColoredBox(color: _parseColor(_bgColor))),

                          // Patches (Bottom Layer)
                          ..._patches.asMap().entries.where((e) => !e.value.isTop).map((entry) {
                            return _buildPatchPreview(entry.value, entry.key, constraints);
                          }).toList(),

                          // Main Overlay Image
                          Align(
                            alignment: Alignment(0, (_videoY - 0.5) * 2),
                            child: Transform.scale(
                              scale: _videoScale,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(_videoRadius),
                                  border: _videoBorderWidth > 0 ? Border.all(
                                    color: _parseColor(_videoBorderColor),
                                    width: _videoBorderWidth,
                                  ) : null,
                                  boxShadow: _showVideoShadow ? [
                                    BoxShadow(
                                      color: _parseColor(_videoShadowColor),
                                      blurRadius: _videoShadowBlur,
                                      offset: Offset(_videoShadowOffsetX, _videoShadowOffsetY),
                                      spreadRadius: _videoShadowSpread,
                                    )
                                  ] : null,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(_videoRadius),
                                  child: AspectRatio(
                                    aspectRatio: _imageAspectRatio,
                                    child: Stack(
                                      children: [
                                        Positioned.fill(child: Image.file(_selectedImage!, fit: BoxFit.cover)),
                                        if (_watermarkType == 'wire')
                                          Positioned.fill(
                                            child: LayoutBuilder(
                                              builder: (context, videoConstraints) {
                                                _lastPreviewWidth = videoConstraints.maxWidth;
                                                final double previewScale = videoConstraints.maxWidth / 1080.0 * _watermarkScale;
                                                return _buildWatermarkPreview(previewScale);
                                              },
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          if (_maskType != 0) _buildMaskOverlay(),

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

                          // Watermark Overlay (Standard Profile / Text / Logo modes)
                          if (_watermarkType != 'wire')
                            Positioned(
                              left: _watermarkX * constraints.maxWidth,
                              top: _watermarkY * constraints.maxHeight,
                              child: FractionalTranslation(
                                translation: const Offset(-0.5, -0.5),
                                child: _buildWatermarkPreview(constraints.maxWidth / 1080.0 * _watermarkScale),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMaskOverlay() {
    if (_maskType == 0) return const SizedBox.shrink();

    Alignment? begin, end;
    if (_maskType == 1) {
      // Bottom
      begin = Alignment.topCenter;
      end = Alignment.bottomCenter;
    } else if (_maskType == 2) {
      // Top
      begin = Alignment.bottomCenter;
      end = Alignment.topCenter;
    } else if (_maskType == 4) {
      // Left
      begin = Alignment.centerRight;
      end = Alignment.centerLeft;
    } else if (_maskType == 5) {
      // Right
      begin = Alignment.centerLeft;
      end = Alignment.centerRight;
    }

    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            color: _maskType == 3
                ? _maskColor.withValues(alpha: _maskOpacity)
                : null,
            gradient: (begin != null && end != null)
                ? LinearGradient(
                    begin: begin,
                    end: end,
                    colors: [
                      Colors.transparent,
                      _maskColor.withValues(alpha: _maskOpacity)
                    ],
                    stops: [
                      _maskStart.clamp(0.0, 1.0),
                      _maskEnd.clamp(0.0, 1.0),
                    ],
                  )
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildPatchPreview(_Patch p, int idx, BoxConstraints constraints) {
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
          });
        },
        onTap: () => setState(() {
          _selectedPatchIndex = idx;
          _selectedTabIndex = 7;
          _isTabContentExpanded = true;
        }),
        child: Container(
          decoration: BoxDecoration(
            color: _parseColor(p.color).withOpacity(p.opacity),
            borderRadius: BorderRadius.circular(p.radius * (constraints.maxWidth / 1080.0)),
            border: _selectedPatchIndex == idx ? Border.all(color: Colors.white, width: 2) : null,
          ),
        ),
      ),
    );
  }

  Widget _buildImageOverlayPreview(_ImageOverlay img, int idx, BoxConstraints constraints) {
    final isSelected = _selectedImageOverlayIndex == idx && _selectedTabIndex == 9;
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
          }),
          onPanUpdate: (d) => setState(() {
            img.x = (img.x + d.delta.dx / constraints.maxWidth).clamp(0.0, 1.0);
            img.y = (img.y + d.delta.dy / constraints.maxHeight).clamp(0.0, 1.0);
          }),
          onTap: () => setState(() {
            _selectedImageOverlayIndex = idx;
            _selectedTabIndex = 9;
            _isTabContentExpanded = true;
          }),
          child: Transform.rotate(
            angle: img.rotation * (math.pi / 180),
            child: Opacity(
              opacity: img.opacity,
              child: Container(
                decoration: isSelected ? BoxDecoration(border: Border.all(color: Colors.deepPurple, width: 2), borderRadius: BorderRadius.circular(4)) : null,
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
    final isSelected = _selectedTextOverlayIndices.contains(idx) && _selectedTabIndex == 8;

    return Positioned(
      left: t.x * constraints.maxWidth,
      top: t.y * constraints.maxHeight,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: GestureDetector(
          onPanStart: t.isLocked ? null : (_) => setState(() {
            _selectedTextOverlayIndex = idx;
            if (!_selectedTextOverlayIndices.contains(idx)) {
              if (!_multiSelectMode) {
                _selectedTextOverlayIndices.clear();
              }
              _selectedTextOverlayIndices.add(idx);
            }
          }),
          onPanUpdate: t.isLocked ? null : (d) => setState(() {
            final double dx = d.delta.dx / constraints.maxWidth;
            final double dy = d.delta.dy / constraints.maxHeight;
            for (final selectedIdx in _selectedTextOverlayIndices) {
              if (selectedIdx < _textOverlays.length) {
                final o = _textOverlays[selectedIdx];
                if (!o.isLocked) {
                  o.x = (o.x + dx).clamp(0.0, 1.0);
                  o.y = (o.y + dy).clamp(0.0, 1.0);
                }
              }
            }
          }),
          onTap: () => setState(() {
            if (_multiSelectMode) {
              if (_selectedTextOverlayIndices.contains(idx)) {
                _selectedTextOverlayIndices.remove(idx);
                if (_selectedTextOverlayIndex == idx) {
                  _selectedTextOverlayIndex = _selectedTextOverlayIndices.isNotEmpty ? _selectedTextOverlayIndices.first : null;
                }
              } else {
                _selectedTextOverlayIndices.add(idx);
                _selectedTextOverlayIndex = idx;
              }
            } else {
              _selectedTextOverlayIndices.clear();
              _selectedTextOverlayIndices.add(idx);
              _selectedTextOverlayIndex = idx;
            }
            _selectedTabIndex = 8;
            _isTabContentExpanded = true;
          }),
          child: Opacity(
            opacity: t.opacity,
            child: Container(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.92 * t.scale),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: isSelected
                  ? BoxDecoration(border: Border.all(color: AppColors.primary, width: 1.5), borderRadius: BorderRadius.circular(4))
                  : null,
              child: t.styleSegments != null && t.styleSegments!.isNotEmpty
                  ? Text.rich(
                      TextSpan(
                        children: t.styleSegments!.map((seg) => TextSpan(
                          text: seg.text + ' ',
                          style: TextStyle(
                            color: _parseColor(seg.color),
                            fontFamily: seg.font?.family,
                            fontWeight: seg.font?.weight,
                            fontStyle: seg.font?.style,
                          ),
                        )).toList(),
                      ),
                      textAlign: t.textAlign,
                      style: TextStyle(
                        fontSize: t.fontSize * (constraints.maxWidth / 1080.0) * t.scale,
                        height: t.lineHeight,
                        letterSpacing: t.letterSpacing,
                        wordSpacing: t.wordSpacing,
                        shadows: t.showShadow
                            ? [
                                Shadow(
                                  color: _parseColor(t.shadowColor),
                                  blurRadius: t.shadowBlur,
                                  offset: Offset(t.shadowOffsetX, t.shadowOffsetY),
                                )
                              ]
                            : null,
                      ),
                    )
                  : Text(
                      t.text,
                      textAlign: t.textAlign,
                      style: TextStyle(
                        color: _parseColor(t.color),
                        fontSize: t.fontSize * (constraints.maxWidth / 1080.0) * t.scale,
                        fontFamily: t.font?.family,
                        height: t.lineHeight,
                        letterSpacing: t.letterSpacing,
                        wordSpacing: t.wordSpacing,
                        shadows: t.showShadow
                            ? [
                                Shadow(
                                  color: _parseColor(t.shadowColor),
                                  blurRadius: t.shadowBlur,
                                  offset: Offset(t.shadowOffsetX, t.shadowOffsetY),
                                )
                              ]
                            : null,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWatermarkPreview(double scale) {
    if (!_showBox || _watermarkType == 'wire') return _buildWatermarkContent(scale);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _parseColor(_boxColor).withOpacity(_boxOpacity),
        borderRadius: BorderRadius.circular(_boxRadius * scale),
      ),
      child: _buildWatermarkContent(scale),
    );
  }

  Widget _buildWatermarkContent(double scale) {
    if (_watermarkType == 'none') return const SizedBox.shrink();
    switch (_watermarkType) {
      case 'profile_vertical':
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: _showStoryRing ? EdgeInsets.all(_storyRingWidth * scale) : EdgeInsets.zero,
              decoration: _showStoryRing
                  ? BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: _isCustomRingColor
                          ? null
                          : const SweepGradient(
                              colors: [
                                Color(0xFFFCAF45),
                                Color(0xFFF56040),
                                Color(0xFFE1306C),
                                Color(0xFFC13584),
                                Color(0xFFFCAF45),
                              ],
                            ),
                      color: _isCustomRingColor ? _parseColor(_storyRingColor) : null,
                    )
                  : null,
              child: Container(
                decoration: _showIconShadow
                    ? BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _parseColor(_iconShadowColor),
                            blurRadius: _iconShadowBlur * scale,
                            offset: Offset(_iconShadowOffsetX * scale, _iconShadowOffsetY * scale),
                          )
                        ],
                      )
                    : null,
                child: CircleAvatar(
                  radius: (_iconSize * scale) / 2,
                  backgroundColor: Colors.grey.shade400,
                  backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                  child: _profileImage == null ? Icon(Icons.person, size: _iconSize * scale * 0.6, color: Colors.white) : null,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _username,
                      style: TextStyle(
                        color: _parseColorWithAlpha(_textColor, _usernameOpacity),
                        fontWeight: FontWeight.bold,
                        fontSize: _usernameSize * scale,
                        fontFamily: _selectedUsernameFont?.family,
                        shadows: _showUsernameShadow
                            ? [
                                Shadow(
                                  color: _parseColor(_usernameShadowColor),
                                  blurRadius: _usernameShadowBlur * scale,
                                  offset: Offset(_usernameShadowOffsetX * scale, _usernameShadowOffsetY * scale),
                                )
                              ]
                            : null,
                      ),
                    ),
                    if (_isVerified && _verifiedBadgeAttachTo == 'username') ...[
                      const SizedBox(width: 4),
                      _buildVerifiedBadgeWidget(scale),
                    ],
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _handle,
                      style: TextStyle(
                        color: _parseColorWithAlpha(_accentColor, _handleOpacity),
                        fontSize: _handleSize * scale,
                        fontFamily: _selectedHandleFont?.family,
                        shadows: _showHandleShadow
                            ? [
                                Shadow(
                                  color: _parseColor(_handleShadowColor),
                                  blurRadius: _handleShadowBlur * scale,
                                  offset: Offset(_handleShadowOffsetX * scale, _handleShadowOffsetY * scale),
                                )
                              ]
                            : null,
                      ),
                    ),
                    if (_isVerified && _verifiedBadgeAttachTo == 'handle') ...[
                      const SizedBox(width: 4),
                      _buildVerifiedBadgeWidget(scale),
                    ],
                  ],
                ),
              ],
            ),
          ],
        );
      case 'profile':
      case 'profile_dots':
        final isSocial = _watermarkType == 'profile_dots';
        return SizedBox(
          width: isSocial ? (1080 * scale) : null,
          child: Row(
            mainAxisSize: isSocial ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: isSocial ? MainAxisAlignment.spaceBetween : MainAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: _showStoryRing ? EdgeInsets.all(_storyRingWidth * scale) : EdgeInsets.zero,
                    decoration: _showStoryRing
                        ? BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: _isCustomRingColor
                                ? null
                                : const SweepGradient(
                                    colors: [
                                      Color(0xFFFCAF45),
                                      Color(0xFFF56040),
                                      Color(0xFFE1306C),
                                      Color(0xFFC13584),
                                      Color(0xFFFCAF45),
                                    ],
                                  ),
                            color: _isCustomRingColor ? _parseColor(_storyRingColor) : null,
                          )
                        : null,
                    child: Container(
                      decoration: _showIconShadow
                          ? BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: _parseColor(_iconShadowColor),
                                  blurRadius: _iconShadowBlur * scale,
                                  offset: Offset(_iconShadowOffsetX * scale, _iconShadowOffsetY * scale),
                                )
                              ],
                            )
                          : null,
                      child: CircleAvatar(
                        radius: (_iconSize * scale) / 2,
                        backgroundColor: Colors.grey.shade400,
                        backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                        child: _profileImage == null ? Icon(Icons.person, size: _iconSize * scale * 0.6, color: Colors.white) : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _username,
                            style: TextStyle(
                              color: _parseColorWithAlpha(_textColor, _usernameOpacity),
                              fontWeight: _selectedUsernameFont?.weight ?? FontWeight.bold,
                              fontStyle: _selectedUsernameFont?.style ?? FontStyle.normal,
                              fontSize: _usernameSize * scale,
                              fontFamily: _selectedUsernameFont?.family,
                              shadows: _showUsernameShadow
                                  ? [
                                      Shadow(
                                        color: _parseColor(_usernameShadowColor),
                                        blurRadius: _usernameShadowBlur * scale,
                                        offset: Offset(_usernameShadowOffsetX * scale, _usernameShadowOffsetY * scale),
                                      )
                                    ]
                                  : null,
                            ),
                          ),
                          if (_isVerified && _verifiedBadgeAttachTo == 'username') ...[
                            const SizedBox(width: 6),
                            _buildVerifiedBadgeWidget(scale),
                          ],
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _handle,
                            style: TextStyle(
                              color: _parseColorWithAlpha(_accentColor, _handleOpacity),
                              fontWeight: _selectedHandleFont?.weight ?? _selectedUsernameFont?.weight ?? FontWeight.normal,
                              fontStyle: _selectedHandleFont?.style ?? _selectedUsernameFont?.style ?? FontStyle.normal,
                              fontSize: _handleSize * scale,
                              fontFamily: _selectedHandleFont?.family ?? _selectedUsernameFont?.family,
                              shadows: _showHandleShadow
                                  ? [
                                      Shadow(
                                        color: _parseColor(_handleShadowColor),
                                        blurRadius: _handleShadowBlur * scale,
                                        offset: Offset(_handleShadowOffsetX * scale, _handleShadowOffsetY * scale),
                                      )
                                    ]
                                  : null,
                            ),
                          ),
                          if (_isVerified && _verifiedBadgeAttachTo == 'handle') ...[
                            const SizedBox(width: 6),
                            _buildVerifiedBadgeWidget(scale),
                          ],
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              if (isSocial) ...[
                Padding(
                  padding: EdgeInsets.only(bottom: _fontSize * 0.2 * scale, right: 12 * scale),
                  child: Icon(Icons.more_horiz, color: _parseColorWithAlpha(_accentColor, _handleOpacity), size: _fontSize * 1.2 * scale),
                ),
              ],
            ],
          ),
        );
      case 'text':
        return Text(
          _username,
          style: TextStyle(
            color: _parseColorWithAlpha(_textColor, _usernameOpacity),
            fontWeight: FontWeight.bold,
            fontSize: _usernameSize * scale,
            fontFamily: _selectedUsernameFont?.family,
            shadows: _showUsernameShadow
                ? [
                    Shadow(
                      color: _parseColor(_usernameShadowColor),
                      blurRadius: _usernameShadowBlur * scale,
                      offset: Offset(_usernameShadowOffsetX * scale, _usernameShadowOffsetY * scale),
                    )
                  ]
                : null,
          ),
        );
      case 'wire':
        final double inset = _wireInset * scale;
        final textPainter = TextPainter(
          text: TextSpan(
            text: _username,
            style: TextStyle(
              fontWeight: _selectedUsernameFont?.weight ?? FontWeight.bold,
              fontStyle: _selectedUsernameFont?.style ?? FontStyle.normal,
              fontSize: _usernameSize * scale,
              fontFamily: _selectedUsernameFont?.family,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final double textWidth = textPainter.width;

        final textWidget = _showBox
            ? Container(
                padding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 6 * scale),
                decoration: BoxDecoration(
                  color: _parseColor(_boxColor).withOpacity(_boxOpacity),
                  borderRadius: BorderRadius.circular(_boxRadius * scale),
                ),
                child: Text(
                  _username,
                  style: TextStyle(
                    color: _parseColorWithAlpha(_textColor, _usernameOpacity),
                    fontWeight: _selectedUsernameFont?.weight ?? FontWeight.bold,
                    fontStyle: _selectedUsernameFont?.style ?? FontStyle.normal,
                    fontSize: _usernameSize * scale,
                    fontFamily: _selectedUsernameFont?.family,
                    shadows: _showUsernameShadow
                        ? [
                            Shadow(
                              color: _parseColor(_usernameShadowColor),
                              blurRadius: _usernameShadowBlur * scale,
                              offset: Offset(_usernameShadowOffsetX * scale, _usernameShadowOffsetY * scale),
                            )
                          ]
                        : null,
                  ),
                ),
              )
            : Text(
                _username,
                style: TextStyle(
                  color: _parseColorWithAlpha(_textColor, _usernameOpacity),
                  fontWeight: _selectedUsernameFont?.weight ?? FontWeight.bold,
                  fontStyle: _selectedUsernameFont?.style ?? FontStyle.normal,
                  fontSize: _usernameSize * scale,
                  fontFamily: _selectedUsernameFont?.family,
                  shadows: _showUsernameShadow
                      ? [
                          Shadow(
                            color: _parseColor(_usernameShadowColor),
                            blurRadius: _usernameShadowBlur * scale,
                            offset: Offset(_usernameShadowOffsetX * scale, _usernameShadowOffsetY * scale),
                          )
                        ]
                      : null,
                ),
              );

        return Stack(
          children: [
            Positioned(
              left: inset,
              top: inset,
              right: inset,
              bottom: inset,
              child: CustomPaint(
                painter: WireFramePainter(
                  radius: _wireRadius,
                  width: _wireWidth,
                  color: _parseColorWithAlpha(_wireColor, _handleOpacity),
                  textWidth: textWidth,
                  scale: scale,
                  hasCutout: _wireCutout,
                  hasCutoutDots: _wireCutoutDots,
                  textPosition: _wireTextPosition,
                  wireGap: _wireGap,
                ),
              ),
            ),
            if (_wireTextPosition == 'bottom')
              Positioned(
                left: 0,
                right: 0,
                bottom: _showBox
                    ? (inset - (_usernameSize * scale / 2.0) - (6 * scale))
                    : (_wireCutout ? (inset - (_usernameSize * scale / 2.0)) : (inset + (8 * scale))),
                child: Center(child: textWidget),
              )
            else if (_wireTextPosition == 'top')
              Positioned(
                left: 0,
                right: 0,
                top: _showBox
                    ? (inset - (_usernameSize * scale / 2.0) - (6 * scale))
                    : (_wireCutout ? (inset - (_usernameSize * scale / 2.0)) : (inset + (8 * scale))),
                child: Center(child: textWidget),
              )
            else if (_wireTextPosition == 'left')
              Positioned(
                top: 0,
                bottom: 0,
                left: _showBox
                    ? (inset - (_usernameSize * scale / 2.0) - (6 * scale))
                    : (_wireCutout ? (inset - (_usernameSize * scale / 2.0)) : (inset + (8 * scale))),
                child: Center(
                  child: RotatedBox(
                    quarterTurns: 1,
                    child: textWidget,
                  ),
                ),
              )
            else // right
              Positioned(
                top: 0,
                bottom: 0,
                right: _showBox
                    ? (inset - (_usernameSize * scale / 2.0) - (6 * scale))
                    : (_wireCutout ? (inset - (_usernameSize * scale / 2.0)) : (inset + (8 * scale))),
                child: Center(
                  child: RotatedBox(
                    quarterTurns: 1,
                    child: textWidget,
                  ),
                ),
              ),
          ],
        );
      case 'image':
        return _profileImage != null
            ? Image.file(_profileImage!, width: _iconSize * scale, height: _iconSize * scale, fit: BoxFit.contain)
            : Icon(Icons.image, size: _iconSize * scale, color: Colors.grey.shade400);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildVerifiedBadgeWidget(double scale) {
    return Icon(
      Icons.verified,
      color: _parseColor(_verifiedBadgeColor),
      size: _usernameSize * 0.8 * scale * 0.9,
    );
  }

  Widget _buildControlTabs() {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _exportPost,
              child: const Text('Export', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              key: const PageStorageKey<String>('image_post_maker_tabs_list'),
              scrollDirection: Axis.horizontal,
              children: [
                _buildTabItem(-1, Icons.add_to_photos, 'Import', AppColors.primary, customOnTap: _pickImage),
                _buildTabItem(6, Icons.stars, 'Presets', Colors.pink),
                _buildTabItem(-2, Icons.upload_file, 'Exp Project', Colors.purple, customOnTap: _exportProjectZip),
                _buildTabItem(-3, Icons.file_download, 'Imp Project', Colors.purple, customOnTap: _importProjectZip),
                _buildTabItem(-4, Icons.drive_folder_upload, _selectedPresetSubTab == 0 ? 'Exp Style' : 'Exp Preset', Colors.indigo, customOnTap: () {
                  if (_selectedPresetSubTab == 0) {
                    _exportWatermarkPresets();
                  } else {
                    _exportPresets();
                  }
                }),
                _buildTabItem(-5, Icons.folder_open, _selectedPresetSubTab == 0 ? 'Imp Style' : 'Imp Preset', Colors.indigo, customOnTap: () {
                  if (_selectedPresetSubTab == 0) {
                    _importWatermarkPresets();
                  } else {
                    _importPresets();
                  }
                }),
                _buildTabItem(0, Icons.branding_watermark, 'Type', Colors.amber),
                _buildTabItem(1, Icons.edit_note, 'Content', Colors.indigo),
                _buildTabItem(8, Icons.text_fields, 'Texts', AppColors.primary),
                _buildTabItem(2, Icons.open_with, 'Position', AppColors.primary),
                _buildTabItem(3, Icons.palette, 'Style', Colors.deepOrange),
                _buildTabItem(4, Icons.font_download, 'Fonts', Colors.teal),
                _buildTabItem(7, Icons.layers, 'Patching', Colors.pink),
                _buildTabItem(9, Icons.photo_library, 'Overlays', Colors.deepPurple),
                _buildTabItem(5, Icons.video_settings, 'Canvas', AppColors.primary),
                _buildTabItem(10, Icons.gradient, 'Mask', Colors.pinkAccent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, IconData icon, String label, Color accent, {VoidCallback? customOnTap}) {
    final isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: customOnTap ?? () {
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
        width: 75,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? accent.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? accent : Colors.grey[600], size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isSelected ? accent : Colors.grey[600],
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedTabContent() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildTypeTab();
      case 1:
        return _buildProfileTab();
      case 2:
        return _buildPositionTab();
      case 3:
        return _buildStyleTab();
      case 4:
        return _buildFontsTab();
      case 5:
        return _buildCanvasTab();
      case 6:
        return _buildPresetTab();
      case 7:
        return _buildPatchingTab();
      case 8:
        return _buildTextsTab();
      case 9:
        return _buildImageOverlayTab();
      case 10:
        return _buildMaskTab();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildPresetSubTabButton(int index, String label, IconData icon) {
    final isSelected = _selectedPresetSubTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedPresetSubTab = index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withOpacity(0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary.withOpacity(0.3) : Colors.grey.shade300,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: isSelected ? AppColors.primary : Colors.grey.shade600),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? AppColors.primary : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresetTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildPresetSubTabButton(0, 'Watermark Presets', Icons.branding_watermark),
            const SizedBox(width: 12),
            _buildPresetSubTabButton(1, 'Project Presets', Icons.dashboard),
          ],
        ),
        const SizedBox(height: 16),
        if (_selectedPresetSubTab == 0)
          _buildWatermarkPresetTabContent()
        else
          _buildProjectPresetTabContent(),
      ],
    );
  }

  Widget _buildWatermarkPresetTabContent() {
    final presets = WatermarkPresetService.getAllPresets();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Watermark Styles', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ElevatedButton.icon(
              onPressed: _saveWatermarkPresetDialog,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Save Current'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, 
                foregroundColor: Colors.white, 
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: presets.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return GestureDetector(
                  onTap: _saveWatermarkPresetDialog,
                  child: Container(
                    width: 140,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_circle_outline, size: 28, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('Save Style', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                );
              }
              final preset = presets[index - 1];
              return _buildWatermarkPresetTabTile(preset);
            },
          ),
        ),
        const SizedBox(height: 12),
        const Text('Long-press a style to rename or delete.', style: TextStyle(fontSize: 11, color: Colors.grey)),
        if (AppConfig.showWatermarkBackupButtons) ...[
          const Divider(height: 24),
          const Text('Watermark Styles Backup (JSON)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _exportWatermarkPresets,
                  icon: const Icon(Icons.upload_file, size: 18),
                  label: const Text('Export JSON'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _importWatermarkPresets,
                  icon: const Icon(Icons.file_download, size: 18),
                  label: const Text('Import JSON'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Export or import your saved watermark styles database as a JSON file.', style: TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ],
    );
  }

  Widget _buildWatermarkPresetTabTile(WatermarkPreset preset) {
    return GestureDetector(
      onTap: () {
        _loadWatermarkPreset(preset);
         _showToast('✨ Loaded style "${preset.name}"');
      },
      onLongPress: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Style Preset: ${preset.name}'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _updateWatermarkPreset(preset);
                }, 
                child: const Text('Update Settings')
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _renameWatermarkPreset(preset);
                }, 
                child: const Text('Rename')
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await WatermarkPresetService.deletePreset(preset.id);
                  setState(() {});
                  _showToast('Style preset deleted!');
                }, 
                child: const Text('Delete', style: TextStyle(color: Colors.red))
              ),
            ],
          ),
        );
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200, width: 1),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                preset.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                preset.watermarkType.toUpperCase(),
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveWatermarkPresetDialog() {
    final TextEditingController nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Watermark Style'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Style Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(context);
              
              final id = 'wp_${DateTime.now().millisecondsSinceEpoch}';
              final preset = WatermarkPreset(
                id: id,
                name: nameCtrl.text.trim(),
                watermarkType: _watermarkType,
                fullScreen: _fullScreen,
                bgColor: _bgColor,
                showBox: _showBox,
                boxColor: _boxColor,
                boxOpacity: _boxOpacity,
                boxRadius: _boxRadius,
                watermarkX: _watermarkX,
                watermarkY: _watermarkY, // videoY in preset model represents watermarkY in image maker
                fontSize: _fontSize,
                iconSize: _iconSize,
                textColor: _textColor,
                accentColor: _accentColor,
                username: _username,
                handle: _handle,
                fontFamily: _selectedUsernameFont?.family ?? 'KleeOne',
                handleFontFamily: _selectedHandleFont?.family ?? _selectedUsernameFont?.family ?? 'KleeOne',
                profileImagePath: _profileImage?.path,
                showStoryRing: _showStoryRing,
                isVerified: _isVerified,
                showUsernameShadow: _showUsernameShadow,
                usernameShadowColor: _usernameShadowColor,
                usernameShadowBlur: _usernameShadowBlur,
                usernameShadowOffsetX: _usernameShadowOffsetX,
                usernameShadowOffsetY: _usernameShadowOffsetY,
                showHandleShadow: _showHandleShadow,
                handleShadowColor: _handleShadowColor,
                handleShadowBlur: _handleShadowBlur,
                handleShadowOffsetX: _handleShadowOffsetX,
                handleShadowOffsetY: _handleShadowOffsetY,
                showIconShadow: _showIconShadow,
                iconShadowColor: _iconShadowColor,
                iconShadowBlur: _iconShadowBlur,
                iconShadowOffsetX: _iconShadowOffsetX,
                iconShadowOffsetY: _iconShadowOffsetY,
                storyRingWidth: _storyRingWidth,
                storyRingColor: _storyRingColor,
                isCustomRingColor: _isCustomRingColor,
                verifiedBadgeColor: _verifiedBadgeColor,
                verifiedBadgeAttachTo: _verifiedBadgeAttachTo,
                watermarkScale: _watermarkScale,
                usernameSize: _usernameSize,
                handleSize: _handleSize,
                bgBrightness: _bgBrightness,
                bgSaturation: _bgSaturation,
                bgBlur: _bgBlur,
                videoRadius: _videoRadius,
                videoBorderWidth: _videoBorderWidth,
                videoBorderColor: _videoBorderColor,
                videoScale: _videoScale,
                videoY: _videoY,
                usernameOpacity: _usernameOpacity,
                handleOpacity: _handleOpacity,
                wireRadius: _wireRadius,
                wireWidth: _wireWidth,
                wireColor: _wireColor,
                wireCutout: _wireCutout,
                wireCutoutDots: _wireCutoutDots,
                wireInset: _wireInset,
                wireTextPosition: _wireTextPosition,
                wireGap: _wireGap,
              );
              await WatermarkPresetService.savePreset(preset);
              setState(() {});
              _showToast('Watermark style saved!');
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _renameWatermarkPreset(WatermarkPreset preset) {
    final TextEditingController nameCtrl = TextEditingController(text: preset.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Style Preset'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Preset Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(context);
              preset.name = nameCtrl.text.trim();
              await WatermarkPresetService.savePreset(preset);
              setState(() {});
              _showToast('Preset renamed!');
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _exportWatermarkPresets() async {
    final json = await WatermarkPresetService.exportPresetsJson();
    try {
      final dynamic success = await platform.invokeMethod('exportPresets', {'json': json, 'filename': 'QuickPost_Watermark_Presets.json'});
      if (success == true && mounted) {
        _showToast('Watermark presets exported successfully!');
      }
    } catch (e) {
      if (mounted) _showToast('Export failed: $e', isError: true);
    }
  }

  void _importWatermarkPresets() async {
    try {
      final String? json = await platform.invokeMethod('importPresets');
      if (json != null) {
        final int imported = await WatermarkPresetService.importPresetsJson(json);
        if (mounted) {
          setState(() {});
          _showToast('Imported $imported watermark styles successfully!');
        }
      }
    } catch (e) {
      if (mounted) _showToast('Import failed: $e', isError: true);
    }
  }

  Widget _buildProjectPresetTabContent() {
    final presets = ImagePostPresetService.getAllPresets();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Project Templates', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ElevatedButton.icon(
              onPressed: _savePresetDialog,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Save Current'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, 
                foregroundColor: Colors.white, 
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: presets.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return GestureDetector(
                  onTap: _savePresetDialog,
                  child: Container(
                    width: 140,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_circle_outline, size: 28, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('Save Preset', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                );
              }
              final preset = presets[index - 1];
              return _buildPresetTabTile(preset);
            },
          ),
        ),
        const SizedBox(height: 12),
        const Text('Long-press a style to rename or delete.', style: TextStyle(fontSize: 11, color: Colors.grey)),
        if (AppConfig.showWatermarkBackupButtons) ...[
          const Divider(height: 24),
          const Text('Project Templates Backup (ZIP)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _exportPresets,
                  icon: const Icon(Icons.upload_file, size: 18),
                  label: const Text('Export Templates (ZIP)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _importPresets,
                  icon: const Icon(Icons.file_download, size: 18),
                  label: const Text('Import Templates (ZIP)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Export or import all your saved project templates database (including background images, overlay images, custom fonts, and profiles) as a single ZIP file.', style: TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _exportProjectZip,
                  icon: const Icon(Icons.backup_outlined, size: 18),
                  label: const Text('Export ZIP'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _importProjectZip,
                  icon: const Icon(Icons.restore_outlined, size: 18),
                  label: const Text('Import ZIP'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Export the entire project including all images, overlays, and custom fonts into a single portable zip file.', style: TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ],
    );
  }

  Widget _buildPresetTabTile(ImagePostPreset preset) {
    return GestureDetector(
      onTap: () async {
        await _loadPreset(preset);
         _showToast('✨ Loaded "${preset.name}"');
      },
      onLongPress: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Preset: ${preset.name}'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _updateProjectPreset(preset);
                }, 
                child: const Text('Update Settings')
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _renamePreset(preset);
                }, 
                child: const Text('Rename')
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await ImagePostPresetService.deletePreset(preset.id);
                  setState(() {});
                  _showToast('Preset deleted!');
                }, 
                child: const Text('Delete', style: TextStyle(color: Colors.red))
              ),
            ],
          ),
        );
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200, width: 1),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.stars, color: Colors.amber, size: 20),
            const SizedBox(height: 8),
            Text(
              preset.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 2),
            Text(
              preset.watermarkType.toUpperCase(),
              style: TextStyle(color: Colors.grey[500], fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Watermark Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 16),
        SizedBox(
          height: 120,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildTypeChip('profile', 'Standard', 'Icon + Text (H)'),
              _buildTypeChip('profile_vertical', 'Vertical', 'Icon + Text (V)'),
              _buildTypeChip('profile_dots', 'Social', 'Standard + Menu'),
              _buildTypeChip('wire', 'Wire', 'Line + Bottom Text'),
              _buildTypeChip('text', 'Minimal', 'Text Only'),
              _buildTypeChip('image', 'Logo', 'Image Only'),
              _buildTypeChip('none', 'None', 'Disable All'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTypeChip(String type, String label, String sub) {
    final isSelected = _watermarkType == type;

    return GestureDetector(
      onTap: () => setState(() {
        _watermarkType = type;
        if (type != 'wire' && _selectedStyleSubTab == 4) {
          _selectedStyleSubTab = 0;
        }
      }),
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? AppColors.primary : Colors.grey.shade200, width: isSelected ? 2 : 1),
          boxShadow: isSelected ? [BoxShadow(color: AppColors.primary.withOpacity(0.1), blurRadius: 10)] : null,
        ),
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
                child: Center(
                  child: _buildMiniPreview(type),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
            Text(sub, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniPreview(String type) {
    if (type == 'none') {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.visibility_off_outlined, color: Colors.grey, size: 24),
          SizedBox(height: 4),
          Text('No Watermark', style: TextStyle(color: Colors.grey, fontSize: 8)),
        ],
      );
    }
    switch (type) {
      case 'profile':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(radius: 6, backgroundColor: AppColors.primary),
            const SizedBox(width: 4),
            const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('User', style: TextStyle(fontSize: 6, fontWeight: FontWeight.bold, color: Colors.black54)),
                Text('@handle', style: TextStyle(fontSize: 4, color: Colors.black38)),
              ],
            )
          ],
        );
      case 'profile_vertical':
        return const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(radius: 8, backgroundColor: AppColors.primary),
            SizedBox(height: 4),
            Text('Username', style: TextStyle(fontSize: 5, fontWeight: FontWeight.bold, color: Colors.black54)),
            Text('@handle', style: TextStyle(fontSize: 4, color: Colors.black38)),
          ],
        );
      case 'profile_dots':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(radius: 6, backgroundColor: AppColors.primary),
            const SizedBox(width: 4),
            const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('User', style: TextStyle(fontSize: 6, fontWeight: FontWeight.bold, color: Colors.black54)),
                Text('@handle', style: TextStyle(fontSize: 4, color: Colors.black38)),
              ],
            ),
            const SizedBox(width: 4),
            Icon(Icons.more_horiz, color: Colors.grey.shade400, size: 8),
          ],
        );
      case 'text':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(2)),
          child: const Text('ABC', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black45)),
        );
      case 'image':
        return const Icon(Icons.image, size: 20, color: Colors.black26);
      case 'wire':
        return Container(
          width: 30,
          height: 40,
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black26, width: 0.5),
          ),
          child: const Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(bottom: 2),
              child: Text('User', style: TextStyle(fontSize: 4, color: Colors.black54)),
            ),
          ),
        );
      default:
        return Container();
    }
  }

  Widget _buildProfileTab() {
    bool showText = _watermarkType == 'profile' || _watermarkType == 'profile_vertical' || _watermarkType == 'text' || _watermarkType == 'wire';
    bool showHandle = _watermarkType == 'profile' || _watermarkType == 'profile_vertical';
    bool showImage = _watermarkType == 'profile' || _watermarkType == 'profile_vertical' || _watermarkType == 'image';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Content Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        if (showText) ...[
          TextField(
            decoration: InputDecoration(
              labelText: _watermarkType == 'text' ? 'Watermark Text' : 'Username', 
              border: const OutlineInputBorder()
            ),
            onChanged: (v) => setState(() => _username = v),
            controller: _usernameController,
          ),
          const SizedBox(height: 12),
        ],
        if (showHandle) ...[
          TextField(
            decoration: const InputDecoration(labelText: 'Handle (@name)', border: OutlineInputBorder()),
            onChanged: (v) => setState(() => _handle = v),
            controller: _handleController,
          ),
          const SizedBox(height: 12),
        ],
        if (showImage) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: _profileImage != null 
                ? ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.file(_profileImage!, width: 40, height: 40, fit: BoxFit.cover))
                : const Icon(Icons.image, size: 40),
            title: Text(_watermarkType == 'image' ? 'Select Logo Image' : 'Profile Icon'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickProfileImage,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade300)),
          ),
        ],
        const Divider(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Background Box', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Switch(value: _showBox, onChanged: (v) => setState(() => _showBox = v)),
          ],
        ),
        if (_showBox) ...[
          const Text('Box Color'),
          const SizedBox(height: 8),
          _buildColorPicker(_boxColor, (c) => setState(() => _boxColor = c)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Opacity: ${(_boxOpacity * 100).toInt()}%'),
                    _buildSliderWithButtons(value: _boxOpacity, min: 0, max: 1, onChanged: (v) => setState(() => _boxOpacity = v)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Corner Radius: ${_boxRadius.toInt()}'),
                    _buildSliderWithButtons(value: _boxRadius, min: 0, max: 100, onChanged: (v) => setState(() => _boxRadius = v)),
                  ],
                ),
              ),
            ],
          ),
        ],
        const Divider(height: 32),
        _buildSectionHeader("Branding", Icons.stars),
        const SizedBox(height: 8),
        SwitchListTile(
          title: const Text("Show Story Ring", style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(_isCustomRingColor ? "Custom solid color circle" : "Purple-Orange IG gradient circle", style: const TextStyle(fontSize: 12)),
          value: _showStoryRing,
          onChanged: (v) => setState(() => _showStoryRing = v),
          secondary: const Icon(Icons.circle_outlined, color: AppColors.primary),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
        if (_showStoryRing) ...[
          Padding(
            padding: const EdgeInsets.only(left: 48, bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildRingStyleButton(false, "Gradient"),
                    const SizedBox(width: 8),
                    _buildRingStyleButton(true, "Custom"),
                  ],
                ),
                  const SizedBox(height: 12),
                  _buildControlSlider(
                    label: 'Ring Width',
                    value: _storyRingWidth,
                    min: 1.0,
                    max: 20.0,
                    onChanged: (v) => setState(() => _storyRingWidth = v),
                  ),
                if (_isCustomRingColor) ...[
                  const SizedBox(height: 12),
                  const Text("Ring Color", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 8),
                  _buildColorPicker(_storyRingColor, (c) => setState(() => _storyRingColor = c)),
                ],
              ],
            ),
          ),
        ],
        SwitchListTile(
          title: const Text("Verified Badge", style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text("Blue tick indicator for your profile", style: TextStyle(fontSize: 12)),
          value: _isVerified,
          onChanged: (v) => setState(() => _isVerified = v),
          secondary: const Icon(Icons.verified, color: AppColors.primary),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
        if (_isVerified) ...[
          Padding(
            padding: const EdgeInsets.only(left: 48, bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Position", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildVerifiedPositionButton("username", "Username"),
                    const SizedBox(width: 8),
                    _buildVerifiedPositionButton("handle", "Handle"),
                  ],
                ),
                const SizedBox(height: 12),
                const Text("Badge Color", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 8),
                _buildColorPicker(_verifiedBadgeColor, (c) => setState(() => _verifiedBadgeColor = c)),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPositionTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Alignment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildAlignButton(Icons.align_horizontal_left, "Left", 0.15),
            _buildAlignButton(Icons.align_horizontal_center, "Center", 0.5),
            _buildAlignButton(Icons.align_horizontal_right, "Right", 0.85),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildAlignYButton(Icons.vertical_align_top, "Top", 0.15),
            _buildAlignYButton(Icons.vertical_align_center, "Middle", 0.5),
            _buildAlignYButton(Icons.vertical_align_bottom, "Bottom", 0.85),
          ],
        ),
        const Divider(height: 32),
        const Text('Manual Sizing', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 16),
        Text('Icon Size: ${_iconSize.toInt()}'),
        _buildSliderWithButtons(value: _iconSize, min: 40, max: 400, onChanged: (v) => setState(() => _iconSize = v)),
        _buildControlSlider(label: 'Username Size', value: _usernameSize, min: 20, max: 200, onChanged: (v) => setState(() => _usernameSize = v)),
        _buildControlSlider(label: 'Handle Size', value: _handleSize, min: 20, max: 200, onChanged: (v) => setState(() => _handleSize = v)),
        const SizedBox(height: 8),
        Text('Master Scale: ${_watermarkScale.toStringAsFixed(2)}'),
        _buildSliderWithButtons(value: _watermarkScale, min: 0.5, max: 2.5, onChanged: (v) => setState(() => _watermarkScale = v)),
        const SizedBox(height: 16),
        const Text('Manual Coordinates (Fine-tune)', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        if (_watermarkType != 'wire') ...[
          _buildControlSlider(label: 'Horizontal Position (X)', value: _watermarkX, min: 0, max: 1, onChanged: (v) => setState(() => _watermarkX = v)),
          _buildControlSlider(label: 'Vertical Position (Y)', value: _watermarkY, min: 0, max: 1, onChanged: (v) => setState(() => _watermarkY = v)),
        ],
      ],
    );
  }

  Widget _buildAlignButton(IconData icon, String label, double xValue) {
    final isSelected = (_watermarkX - xValue).abs() < 0.05;
    return InkWell(
      onTap: () => setState(() => _watermarkX = xValue),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.black),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 10, color: isSelected ? Colors.white : Colors.black)),
          ],
        ),
      ),
    );
  }

  Widget _buildAlignYButton(IconData icon, String label, double yValue) {
    final isSelected = (_watermarkY - yValue).abs() < 0.05;
    return InkWell(
      onTap: () => setState(() => _watermarkY = yValue),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.black),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 10, color: isSelected ? Colors.white : Colors.black)),
          ],
        ),
      ),
    );
  }

  Widget _buildStyleTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildSubTabButton(0, 'Username', Icons.person_outline),
            _buildSubTabButton(1, 'Handle', Icons.alternate_email),
            _buildSubTabButton(2, 'Icon', Icons.image_outlined),
            _buildSubTabButton(3, 'Main Image', Icons.image_search),
            if (_watermarkType == 'wire')
              _buildSubTabButton(4, 'Wire', Icons.border_outer),
          ],
        ),
        const SizedBox(height: 20),
        IndexedStack(
          index: _selectedStyleSubTab,
          children: [
            // --- Username Style ---
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Username Color', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                _buildColorPicker(_textColor, (c) => setState(() => _textColor = c)),
                const SizedBox(height: 16),
                _buildControlSlider(label: "Username Opacity", value: _usernameOpacity, min: 0.0, max: 1.0, onChanged: (v) => setState(() => _usernameOpacity = v)),
                const Divider(height: 32),
                _buildShadowControlSection(
                  title: 'Username Shadow',
                  showShadow: _showUsernameShadow,
                  onToggleShadow: (v) => setState(() => _showUsernameShadow = v),
                  shadowColor: _usernameShadowColor,
                  onColorChanged: (c) => setState(() => _usernameShadowColor = c),
                  blur: _usernameShadowBlur,
                  onBlurChanged: (v) => setState(() => _usernameShadowBlur = v),
                  offsetX: _usernameShadowOffsetX,
                  onOffsetXChanged: (v) => setState(() => _usernameShadowOffsetX = v),
                  offsetY: _usernameShadowOffsetY,
                  onOffsetYChanged: (v) => setState(() => _usernameShadowOffsetY = v),
                ),
              ],
            ),
            
            // --- Handle Style ---
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Handle Color', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                _buildColorPicker(_accentColor, (c) => setState(() => _accentColor = c)),
                const SizedBox(height: 16),
                _buildControlSlider(label: "Handle Opacity", value: _handleOpacity, min: 0.0, max: 1.0, onChanged: (v) => setState(() => _handleOpacity = v)),
                const Divider(height: 32),
                _buildShadowControlSection(
                  title: 'Handle Shadow',
                  showShadow: _showHandleShadow,
                  onToggleShadow: (v) => setState(() => _showHandleShadow = v),
                  shadowColor: _handleShadowColor,
                  onColorChanged: (c) => setState(() => _handleShadowColor = c),
                  blur: _handleShadowBlur,
                  onBlurChanged: (v) => setState(() => _handleShadowBlur = v),
                  offsetX: _handleShadowOffsetX,
                  onOffsetXChanged: (v) => setState(() => _handleShadowOffsetX = v),
                  offsetY: _handleShadowOffsetY,
                  onOffsetYChanged: (v) => setState(() => _handleShadowOffsetY = v),
                ),
              ],
            ),
            
            // --- Icon Style ---
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Icon Options', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 16),
                _buildShadowControlSection(
                  title: 'Icon Shadow',
                  showShadow: _showIconShadow,
                  onToggleShadow: (v) => setState(() => _showIconShadow = v),
                  shadowColor: _iconShadowColor,
                  onColorChanged: (c) => setState(() => _iconShadowColor = c),
                  blur: _iconShadowBlur,
                  onBlurChanged: (v) => setState(() => _iconShadowBlur = v),
                  offsetX: _iconShadowOffsetX,
                  onOffsetXChanged: (v) => setState(() => _iconShadowOffsetX = v),
                  offsetY: _iconShadowOffsetY,
                  onOffsetYChanged: (v) => setState(() => _iconShadowOffsetY = v),
                ),
              ],
            ),

            // --- Image/Main Image Style ---
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Main Image Canvas Options', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 16),
                _buildShadowControlSection(
                  title: 'Main Image Drop Shadow',
                  showShadow: _showVideoShadow,
                  onToggleShadow: (v) => setState(() => _showVideoShadow = v),
                  shadowColor: _videoShadowColor,
                  onColorChanged: (c) => setState(() => _videoShadowColor = c),
                  blur: _videoShadowBlur,
                  onBlurChanged: (v) => setState(() => _videoShadowBlur = v),
                  offsetX: _videoShadowOffsetX,
                  onOffsetXChanged: (v) => setState(() => _videoShadowOffsetX = v),
                  offsetY: _videoShadowOffsetY,
                  onOffsetYChanged: (v) => setState(() => _videoShadowOffsetY = v),
                  spread: _videoShadowSpread,
                  onSpreadChanged: (v) => setState(() => _videoShadowSpread = v),
                ),
                const SizedBox(height: 16),
                _buildControlSlider(
                  label: 'Image Scale',
                  value: _videoScale,
                  min: 0.1,
                  max: 3.0,
                  onChanged: (v) => setState(() => _videoScale = v),
                ),
                const SizedBox(height: 16),
                _buildControlSlider(
                  label: 'Corner Radius',
                  value: _videoRadius,
                  min: 0.0,
                  max: 200.0,
                  onChanged: (v) => setState(() => _videoRadius = v),
                ),
                const SizedBox(height: 16),
                _buildControlSlider(
                  label: 'Border Width',
                  value: _videoBorderWidth,
                  min: 0.0,
                  max: 50.0,
                  onChanged: (v) => setState(() => _videoBorderWidth = v),
                ),
                if (_videoBorderWidth > 0) ...[
                  const SizedBox(height: 12),
                  const Text('Border Color', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 8),
                  _buildColorPicker(_videoBorderColor, (c) => setState(() => _videoBorderColor = c)),
                ],
              ],
            ),
            // --- Wire Style ---
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Wire Frame Options', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 16),
                _buildControlSlider(
                  label: 'Wire Inset (Margin)',
                  value: _wireInset,
                  min: 0.0,
                  max: 150.0,
                  onChanged: (v) => setState(() => _wireInset = v),
                ),
                const SizedBox(height: 16),
                _buildControlSlider(
                  label: 'Wire Corner Radius',
                  value: _wireRadius,
                  min: 0.0,
                  max: 100.0,
                  onChanged: (v) => setState(() => _wireRadius = v),
                ),
                const SizedBox(height: 16),
                _buildControlSlider(
                  label: 'Wire Width (Thickness)',
                  value: _wireWidth,
                  min: 0.5,
                  max: 10.0,
                  onChanged: (v) => setState(() => _wireWidth = v),
                ),
                const SizedBox(height: 16),
                const Text('Wire Color', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
                _buildColorPicker(_wireColor, (c) => setState(() => _wireColor = c)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Cutout text from wire', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    Switch(
                      value: _wireCutout,
                      activeColor: AppColors.primary,
                      onChanged: (v) => setState(() {
                        _wireCutout = v;
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Show dots on cutout ends',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _wireCutout ? Colors.black : Colors.grey,
                      ),
                    ),
                    Switch(
                      value: _wireCutoutDots,
                      activeColor: AppColors.primary,
                      onChanged: _wireCutout
                          ? (v) => setState(() => _wireCutoutDots = v)
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Text Position on Wire', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: ['top', 'bottom', 'left', 'right'].map((pos) {
                    final isSelected = _wireTextPosition == pos;
                    return ChoiceChip(
                      label: Text(
                        pos[0].toUpperCase() + pos.substring(1),
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      backgroundColor: Colors.grey[200],
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _wireTextPosition = pos;
                          });
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Wire Cutout Gap: ${_wireGap.toStringAsFixed(0)} px',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _wireCutout ? Colors.black : Colors.grey,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _wireGap,
                  min: 0.0,
                  max: 100.0,
                  divisions: 100,
                  activeColor: AppColors.primary,
                  inactiveColor: Colors.grey[200],
                  onChanged: _wireCutout
                      ? (v) => setState(() => _wireGap = v)
                      : null,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSubTabButton(int index, String label, IconData icon) {
    final isSelected = _selectedStyleSubTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedStyleSubTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? AppColors.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? AppColors.primary : Colors.grey, size: 18),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: isSelected ? AppColors.primary : Colors.grey,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShadowControlSection({
    required String title,
    required bool showShadow,
    required ValueChanged<bool> onToggleShadow,
    required String shadowColor,
    required ValueChanged<String> onColorChanged,
    required double blur,
    required ValueChanged<double> onBlurChanged,
    required double offsetX,
    required ValueChanged<double> onOffsetXChanged,
    required double offsetY,
    required ValueChanged<double> onOffsetYChanged,
    double? spread,
    ValueChanged<double>? onSpreadChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            Switch(value: showShadow, onChanged: onToggleShadow),
          ],
        ),
        if (showShadow) ...[
          const SizedBox(height: 8),
          const Text('Color', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          _buildColorPicker(shadowColor, onColorChanged),
          const SizedBox(height: 16),
          Text('Blur Radius: ${blur.toInt()}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          _buildSliderWithButtons(value: blur, min: 0, max: 20, onChanged: onBlurChanged),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Text('X', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    Expanded(child: _buildSliderWithButtons(value: offsetX, min: -20, max: 20, onChanged: onOffsetXChanged)),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    const Text('Y', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    Expanded(child: _buildSliderWithButtons(value: offsetY, min: -20, max: 20, onChanged: onOffsetYChanged)),
                  ],
                ),
              ),
            ],
          ),
          if (spread != null && onSpreadChanged != null) ...[
            const SizedBox(height: 8),
            Text('Spread Radius: ${spread.toInt()}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            _buildSliderWithButtons(value: spread, min: -20, max: 20, onChanged: onSpreadChanged),
          ],
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
        ),
      ],
    );
  }

  Widget _buildFontsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildSubTabButtonSmall(0, 'Username', Icons.person_outline),
            _buildSubTabButtonSmall(1, 'Handle', Icons.alternate_email),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Font Family', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 12),
        SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: getAllFonts().length,
            itemBuilder: (context, index) {
              final font = getAllFonts()[index];
              final bool isSelected = _selectedStyleSubTab == 0 
                  ? _selectedUsernameFont == font
                  : _selectedHandleFont == font;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(
                    font.displayName,
                    style: TextStyle(
                      fontFamily: font.family,
                      fontWeight: font.weight,
                      fontStyle: font.style,
                      color: isSelected ? Colors.white : Colors.black87,
                      fontSize: 12,
                    ),
                  ),
                  selected: isSelected,
                  showCheckmark: false,
                  onSelected: (val) {
                    setState(() {
                      if (_selectedStyleSubTab == 0) {
                        _selectedUsernameFont = font;
                      } else {
                        _selectedHandleFont = font;
                      }
                    });
                  },
                  selectedColor: AppColors.primary,
                  backgroundColor: Colors.grey.shade100,
                  checkmarkColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSubTabButtonSmall(int index, String label, IconData icon) {
    final isSelected = _selectedStyleSubTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedStyleSubTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withOpacity(0.05) : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: isSelected ? AppColors.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? AppColors.primary : Colors.grey, size: 14),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? AppColors.primary : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCanvasTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Canvas Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Switch(
              value: _fullScreen, 
              onChanged: (v) => setState(() => _fullScreen = v),
            ),
          ],
        ),
        const Text('Enable 9:16 Fullscreen Padding', style: TextStyle(fontSize: 12, color: Colors.grey)),
        if (_fullScreen) ...[
          const SizedBox(height: 16),
          const Text('Background Mode', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: _bgImage != null 
               ? ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.file(_bgImage!, width: 40, height: 40, fit: BoxFit.cover))
               : const Icon(Icons.wallpaper, size: 40),
            title: const Text('Background Image'),
            subtitle: Text(_bgImage == null ? 'None selected' : 'Change background image'),
            trailing: _bgImage != null 
              ? IconButton(onPressed: () => setState(() => _bgImage = null), icon: const Icon(Icons.close, color: Colors.red))
              : const Icon(Icons.chevron_right),
            onTap: _pickBgImage,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade300)),
          ),
          if (_bgImage == null) ...[
            const SizedBox(height: 20),
            const Text('Background Color'),
            const SizedBox(height: 8),
            _buildColorPicker(_bgColor, (c) => setState(() => _bgColor = c)),
          ] else ...[
            const SizedBox(height: 16),
            _buildControlSlider(
              label: 'Brightness',
              value: _bgBrightness,
              min: 0.0,
              max: 2.0,
              onChanged: (v) => setState(() => _bgBrightness = v),
            ),
            _buildControlSlider(
              label: 'Saturation',
              value: _bgSaturation,
              min: 0.0,
              max: 2.0,
              onChanged: (v) => setState(() => _bgSaturation = v),
            ),
            _buildControlSlider(
              label: 'Blur',
              value: _bgBlur,
              min: 0.0,
              max: 100.0,
              onChanged: (v) => setState(() => _bgBlur = v),
            ),
          ],
        ],
        const Divider(height: 32),
        const Text('Image Placement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        _buildControlSlider(
          label: 'Vertical Alignment (Y)',
          value: _videoY,
          min: 0.0,
          max: 1.0,
          onChanged: (v) => setState(() => _videoY = v),
        ),
        const SizedBox(height: 16),
        _buildControlSlider(
          label: 'Image Scale',
          value: _videoScale,
          min: 0.1,
          max: 3.0,
          onChanged: (v) => setState(() => _videoScale = v),
        ),
        const SizedBox(height: 8),
        _buildControlSlider(
          label: 'Corner Radius',
          value: _videoRadius,
          min: 0.0,
          max: 200.0,
          onChanged: (v) => setState(() => _videoRadius = v),
        ),
        const SizedBox(height: 16),
        _buildControlSlider(
          label: 'Border Width',
          value: _videoBorderWidth,
          min: 0.0,
          max: 50.0,
          onChanged: (v) => setState(() => _videoBorderWidth = v),
        ),
        if (_videoBorderWidth > 0) ...[
          const SizedBox(height: 12),
          const Text('Border Color', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 8),
          _buildColorPicker(_videoBorderColor, (c) => setState(() => _videoBorderColor = c)),
        ],
        const Divider(height: 32),
      ],
    );
  }

  Widget _buildPatchingTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Patches Overlay (Shapes)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _patches.add(_Patch(x: 0.25, y: 0.25, width: 0.5, height: 0.1));
                  _selectedPatchIndex = _patches.length - 1;
                });
              },
              icon: const Icon(Icons.add_box, size: 18),
              label: const Text('Add Patch'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_patches.isEmpty)
           const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("No patches added. Use them to mask or highlight areas.", style: TextStyle(color: Colors.grey, fontSize: 13), textAlign: TextAlign.center,))),
        if (_patches.isNotEmpty) ...[
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _patches.length,
              itemBuilder: (context, idx) {
                final isSelected = _selectedPatchIndex == idx;
                return GestureDetector(
                  onTap: () => setState(() => _selectedPatchIndex = idx),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isSelected ? AppColors.primary : Colors.grey.shade300),
                    ),
                    child: Center(
                      child: Text(
                        'Patch #${idx + 1}',
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (_selectedPatchIndex != null && _selectedPatchIndex! < _patches.length) ...[
          _buildActivePatchControls(_patches[_selectedPatchIndex!], _selectedPatchIndex!),
        ] else if (_patches.isNotEmpty)
          const Text("Select a patch on preview to edit", style: TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildActivePatchControls(_Patch p, int index) {
     return Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         Container(
           padding: const EdgeInsets.all(12),
           decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
           child: Column(
             children: [
               Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   Text("Patch #${index + 1}", style: const TextStyle(fontWeight: FontWeight.bold)),
                   IconButton(onPressed: () => setState(() { _patches.removeAt(index); _selectedPatchIndex = null; }), icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20)),
                 ],
               ),
               _buildControlSlider(label: "Width", value: p.width, min: 0.01, max: 1.0, onChanged: (v) => setState(() => p.width = v)),
               _buildControlSlider(label: "Height", value: p.height, min: 0.01, max: 1.0, onChanged: (v) => setState(() => p.height = v)),
               const SizedBox(height: 12),
               const Text("Color"),
               const SizedBox(height: 8),
               _buildColorPicker(p.color, (c) => setState(() => p.color = c)),
               const SizedBox(height: 12),
               SwitchListTile(
                 title: const Text("Keep on Top", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                 subtitle: const Text("Render patch above main image frame", style: TextStyle(fontSize: 11)),
                 value: p.isTop,
                 onChanged: (v) => setState(() => p.isTop = v),
                 dense: true,
                 contentPadding: EdgeInsets.zero,
               ),
               _buildControlSlider(label: "Opacity", value: p.opacity, min: 0.0, max: 1.0, onChanged: (v) => setState(() => p.opacity = v)),
               _buildControlSlider(label: "Radius", value: p.radius, min: 0.0, max: 200.0, onChanged: (v) => setState(() => p.radius = v)),
             ],
           ),
         ),
       ],
     );
  }

  Widget _buildTextsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Text Overlays', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _textOverlays.add(_TextOverlay(
                        text: "New Text",
                        y: 0.25,
                        fontSize: 30.0,
                        font: const FontInfo(family: 'KleeOne', displayName: 'Klee One SemiBold', weight: FontWeight.w600, assetPath: 'assets/fonts/KleeOne-SemiBold.ttf'),
                      ));
                      _selectedTextOverlayIndex = _textOverlays.length - 1;
                    });
                  },
                  icon: const Icon(Icons.add_comment, size: 16),
                  label: const Text('Add Text', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary, 
                    foregroundColor: Colors.white, 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    elevation: 0,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _importFromMyQuotes,
                  icon: const Icon(Icons.format_quote, size: 16),
                  label: const Text('Import Quote', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal, 
                    foregroundColor: Colors.white, 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_textOverlays.isEmpty) 
           const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("No text overlays added. Use them to place generic text anywhere.", style: TextStyle(color: Colors.grey, fontSize: 13), textAlign: TextAlign.center))),
        if (_textOverlays.isNotEmpty) ...[
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _textOverlays.length,
              itemBuilder: (context, idx) {
                final isSelected = _selectedTextOverlayIndex == idx;
                return GestureDetector(
                  onTap: () => setState(() => _selectedTextOverlayIndex = idx),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isSelected ? AppColors.primary : Colors.grey.shade300),
                    ),
                    child: Center(
                      child: Text(
                        'Text #${idx + 1}',
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (_selectedTextOverlayIndex != null && _selectedTextOverlayIndex! < _textOverlays.length) ...[
          _buildActiveTextOverlayControls(_textOverlays[_selectedTextOverlayIndex!], _selectedTextOverlayIndex!),
        ] else if (_textOverlays.isNotEmpty)
          const Text("Select a text overlay on preview to edit", style: TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  void _updateSelectedTextOverlays(void Function(_TextOverlay overlay) updater) {
    setState(() {
      for (final idx in _selectedTextOverlayIndices) {
        if (idx < _textOverlays.length) {
          updater(_textOverlays[idx]);
        }
      }
    });
  }

  void _splitTextOverlayIntoWords(_TextOverlay t, int index) {
    final String textToSplit = t.isSplitWord ? (t.originalFullText ?? t.text) : t.text;
    if (textToSplit.trim().isEmpty) return;

    final String gid = t.groupId ?? 'split_grp_${DateTime.now().millisecondsSinceEpoch}';

    final double outAspect = _fullScreen ? 9 / 16 : _imageAspectRatio;
    final double refWidth = 1080.0;
    final double refHeight = 1080.0 / outAspect;

    final double maxTextWidth = refWidth * 0.92 * t.scale;

    final TextStyle style = TextStyle(
      fontSize: t.fontSize * t.scale,
      fontFamily: t.font?.family,
      height: t.lineHeight,
      letterSpacing: t.letterSpacing,
      wordSpacing: t.wordSpacing,
    );

    final fullPainter = TextPainter(
      text: TextSpan(text: textToSplit, style: style),
      textDirection: ui.TextDirection.ltr,
      textAlign: t.textAlign,
    )..layout(maxWidth: maxTextWidth.clamp(0.0, double.infinity));

    final double fullTextWidth = fullPainter.width;
    final double fullTextHeight = fullPainter.height;

    double centerX = t.x * refWidth;
    double centerY = t.y * refHeight;
    if (t.isSplitWord) {
      final List<_TextOverlay> groupOverlays = _textOverlays.where((x) => x.groupId == gid).toList();
      if (groupOverlays.isNotEmpty) {
        double sumX = 0;
        double sumY = 0;
        for (final x in groupOverlays) {
          sumX += x.x;
          sumY += x.y;
        }
        centerX = (sumX / groupOverlays.length) * refWidth;
        centerY = (sumY / groupOverlays.length) * refHeight;
      }
    }

    final double blockLeft = centerX - fullTextWidth / 2;
    final double blockTop = centerY - fullTextHeight / 2;

    final wordRegex = RegExp(r'\S+');
    final matches = wordRegex.allMatches(textToSplit).toList();

    final List<_TextOverlay> splitOverlays = [];

    for (int i = 0; i < matches.length; i++) {
      final match = matches[i];
      final String wordStr = match.group(0)!;
      final range = TextSelection(baseOffset: match.start, extentOffset: match.end);
      final boxes = fullPainter.getBoxesForSelection(range);

      if (boxes.isEmpty) continue;

      final box = boxes.first;

      final double wordLeft = blockLeft + box.left;
      final double wordTop = blockTop + box.top;
      final double wordW = box.right - box.left;
      final double wordH = box.bottom - box.top;

      final double wordCenterX = wordLeft + wordW / 2;
      final double wordCenterY = wordTop + wordH / 2;

      final double newX = (wordCenterX / refWidth).clamp(0.0, 1.0);
      final double newY = (wordCenterY / refHeight).clamp(0.0, 1.0);

      String wordColor = t.color;
      FontInfo? wordFont = t.font;
      if (t.styleSegments != null && i < t.styleSegments!.length) {
        wordColor = t.styleSegments![i].color;
        wordFont = t.styleSegments![i].font ?? t.font;
      }

      splitOverlays.add(_TextOverlay(
        text: wordStr,
        x: newX,
        y: newY,
        fontSize: t.fontSize,
        color: wordColor,
        font: wordFont,
        showShadow: t.showShadow,
        shadowColor: t.shadowColor,
        shadowBlur: t.shadowBlur,
        shadowOffsetX: t.shadowOffsetX,
        shadowOffsetY: t.shadowOffsetY,
        textAlign: TextAlign.center,
        scale: t.scale,
        lineHeight: t.lineHeight,
        letterSpacing: t.letterSpacing,
        wordSpacing: t.wordSpacing,
        opacity: t.opacity,
        isSplitWord: true,
        groupId: gid,
        originalFullText: textToSplit,
        isLocked: true,
      ));
    }

    if (splitOverlays.isNotEmpty) {
      setState(() {
        if (t.isSplitWord) {
          int insertIndex = _textOverlays.indexWhere((x) => x.groupId == gid);
          if (insertIndex == -1) insertIndex = index;
          _textOverlays.removeWhere((x) => x.groupId == gid);
          _textOverlays.insertAll(insertIndex, splitOverlays);
          _selectedTextOverlayIndices.clear();
          for (int idx = 0; idx < _textOverlays.length; idx++) {
            if (_textOverlays[idx].groupId == gid) {
              _selectedTextOverlayIndices.add(idx);
            }
          }
          _selectedTextOverlayIndex = insertIndex;
        } else {
          _textOverlays.removeAt(index);
          _textOverlays.insertAll(index, splitOverlays);
          _selectedTextOverlayIndices.clear();
          for (int idx = index; idx < index + splitOverlays.length; idx++) {
            _selectedTextOverlayIndices.add(idx);
          }
          _selectedTextOverlayIndex = index;
        }
      });
    }
  }

  void _revertSplitToClassic(_TextOverlay t, int index, {required bool preserveStyle}) {
    final String? gid = t.groupId;
    if (gid == null) return;

    final List<_TextOverlay> groupOverlays = _textOverlays.where((x) => x.groupId == gid).toList();
    if (groupOverlays.isEmpty) return;

    double sumX = 0;
    double sumY = 0;
    for (final x in groupOverlays) {
      sumX += x.x;
      sumY += x.y;
    }
    final double avgX = sumX / groupOverlays.length;
    final double avgY = sumY / groupOverlays.length;

    final _TextOverlay first = groupOverlays.first;

    List<TextSegment>? segments;
    if (preserveStyle) {
      segments = groupOverlays.map((x) => TextSegment(
        text: x.text,
        color: x.color,
        font: x.font,
      )).toList();
    }

    final classicOverlay = _TextOverlay(
      text: t.originalFullText ?? groupOverlays.map((x) => x.text).join(' '),
      x: avgX,
      y: avgY,
      fontSize: first.fontSize,
      color: first.color,
      font: first.font,
      showShadow: first.showShadow,
      shadowColor: first.shadowColor,
      shadowBlur: first.shadowBlur,
      shadowOffsetX: first.shadowOffsetX,
      shadowOffsetY: first.shadowOffsetY,
      textAlign: first.textAlign,
      scale: first.scale,
      lineHeight: first.lineHeight,
      letterSpacing: first.letterSpacing,
      wordSpacing: first.wordSpacing,
      opacity: first.opacity,
      isSplitWord: false,
      styleSegments: segments,
    );

    setState(() {
      int insertIndex = _textOverlays.indexWhere((x) => x.groupId == gid);
      if (insertIndex == -1) insertIndex = index;
      _textOverlays.removeWhere((x) => x.groupId == gid);
      _textOverlays.insert(insertIndex, classicOverlay);
      _selectedTextOverlayIndices.clear();
      _selectedTextOverlayIndices.add(insertIndex);
      _selectedTextOverlayIndex = insertIndex;
    });
  }

  void _showRevertToClassicDialog(_TextOverlay t, int index) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Revert to Classic"),
          content: const Text(
              "Do you want to preserve the separate colors and fonts of each word as a styled block, or reset them to use a single style?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _revertSplitToClassic(t, index, preserveStyle: false);
              },
              child: const Text("Reset Style"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _revertSplitToClassic(t, index, preserveStyle: true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text("Preserve Style"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActiveTextOverlayControls(_TextOverlay t, int index) {
    if (_lastSelectedOverlayIndex != index || _overlayTextController.text != t.text) {
      _lastSelectedOverlayIndex = index;
      _overlayTextController.text = t.text;
    }
     return Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         Container(
           padding: const EdgeInsets.all(12),
           decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Text #${index + 1}", style: const TextStyle(fontWeight: FontWeight.bold)),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.format_quote, size: 20, color: Colors.teal),
                          tooltip: 'Import Quote',
                          onPressed: _importFromMyQuotes,
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.copy, size: 20, color: Colors.blueGrey),
                          tooltip: 'Copy Text',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: t.text));
                            _showToast('Text copied to clipboard');
                          },
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.clear, size: 20, color: Colors.orange),
                          tooltip: 'Clear Text',
                          onPressed: () => setState(() => t.text = ''),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => setState(() {
                            _textOverlays.removeAt(index);
                            _selectedTextOverlayIndices.clear();
                            _selectedTextOverlayIndex = null;
                          }),
                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                          tooltip: 'Delete',
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  key: ValueKey("text_field_${index}"),
                  controller: _overlayTextController,
                  maxLines: null,
                  onChanged: (v) => setState(() => t.text = v),
                  decoration: InputDecoration(labelText: t.isSplitWord ? "Word Text" : "Text Content", border: const OutlineInputBorder(), isDense: true),
                ),
                if (t.isSplitWord && t.originalFullText != null) ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    key: ValueKey("orig_text_field_${index}"),
                    initialValue: t.originalFullText,
                    maxLines: null,
                    onChanged: (v) {
                      final gid = t.groupId;
                      if (gid != null) {
                        setState(() {
                          for (var x in _textOverlays) {
                            if (x.groupId == gid) {
                              x.originalFullText = v;
                            }
                          }
                        });
                      }
                    },
                    decoration: const InputDecoration(labelText: "Original Full Text", border: OutlineInputBorder(), isDense: true),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: t.text.trim().isEmpty && (t.originalFullText?.trim().isEmpty ?? true)
                            ? null
                            : () => _splitTextOverlayIntoWords(t, index),
                        icon: const Icon(Icons.space_bar, size: 18),
                        label: Text(
                            t.isSplitWord ? 'Re-split Words' : 'Split to Words',
                            style: const TextStyle(fontSize: 11)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C63FF).withOpacity(0.1),
                          foregroundColor: const Color(0xFF6C63FF),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (t.isSplitWord) ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showRevertToClassicDialog(t, index),
                          icon: const Icon(Icons.undo, size: 16),
                          label: const Text('Classic', style: TextStyle(fontSize: 11)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.withOpacity(0.1),
                            foregroundColor: Colors.orange,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Container(
                      decoration: BoxDecoration(
                        color: t.isLocked
                            ? Colors.orange.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: Icon(
                          t.isLocked ? Icons.lock : Icons.lock_open,
                          color: t.isLocked ? Colors.orange : Colors.grey,
                          size: 20,
                        ),
                        onPressed: () => _updateSelectedTextOverlays((o) => o.isLocked = !o.isLocked),
                        tooltip: t.isLocked ? 'Unlock Position' : 'Lock Position',
                      ),
                    ),
                  ],
                ),
                if (t.isSplitWord) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Multi-Select', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Switch(
                            value: _multiSelectMode,
                            onChanged: (v) => setState(() => _multiSelectMode = v),
                            activeColor: const Color(0xFF6C63FF),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () {
                              final gid = t.groupId;
                              if (gid != null) {
                                setState(() {
                                  _selectedTextOverlayIndices.clear();
                                  for (int idx = 0; idx < _textOverlays.length; idx++) {
                                    if (_textOverlays[idx].groupId == gid) {
                                      _selectedTextOverlayIndices.add(idx);
                                    }
                                  }
                                });
                              }
                            },
                            child: const Text('All', style: TextStyle(fontSize: 11)),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedTextOverlayIndices.clear();
                                if (_selectedTextOverlayIndex != null) {
                                  _selectedTextOverlayIndices.add(_selectedTextOverlayIndex!);
                                }
                              });
                            },
                            child: const Text('Clear', style: TextStyle(fontSize: 11, color: Colors.red)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 38,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _textOverlays.length,
                      itemBuilder: (context, idx) {
                        final item = _textOverlays[idx];
                        if (item.groupId != t.groupId) return const SizedBox.shrink();
                        final bool isSel = _selectedTextOverlayIndices.contains(idx);
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(
                              item.text,
                              style: TextStyle(
                                color: isSel ? Colors.white : Colors.black87,
                              ),
                            ),
                            selected: isSel,
                            selectedColor: const Color(0xFF6C63FF),
                            backgroundColor: Colors.grey[100],
                            onSelected: (selected) {
                              setState(() {
                                if (_multiSelectMode) {
                                  if (selected) {
                                    _selectedTextOverlayIndices.add(idx);
                                    _selectedTextOverlayIndex = idx;
                                  } else {
                                    if (_selectedTextOverlayIndices.length > 1) {
                                      _selectedTextOverlayIndices.remove(idx);
                                      if (_selectedTextOverlayIndex == idx) {
                                        _selectedTextOverlayIndex = _selectedTextOverlayIndices.first;
                                      }
                                    }
                                  }
                                } else {
                                  _selectedTextOverlayIndices.clear();
                                  _selectedTextOverlayIndices.add(idx);
                                  _selectedTextOverlayIndex = idx;
                                }
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _buildControlSlider(label: "Font Size", value: t.fontSize, min: 10, max: 200, onChanged: (v) => _updateSelectedTextOverlays((o) => o.fontSize = v)),
                _buildControlSlider(label: "Scale", value: t.scale, min: 0.1, max: 5.0, onChanged: (v) => _updateSelectedTextOverlays((o) => o.scale = v)),
                _buildControlSlider(label: "Line Spacing", value: t.lineHeight, min: 0.5, max: 3.0, onChanged: (v) => _updateSelectedTextOverlays((o) => o.lineHeight = v)),
                _buildControlSlider(label: "Letter Spacing", value: t.letterSpacing, min: -5.0, max: 20.0, onChanged: (v) => _updateSelectedTextOverlays((o) => o.letterSpacing = v)),
                _buildControlSlider(label: "Word Spacing", value: t.wordSpacing, min: -10.0, max: 50.0, onChanged: (v) => _updateSelectedTextOverlays((o) => o.wordSpacing = v)),
               const SizedBox(height: 8),
               const Text("Text Color", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
               const SizedBox(height: 8),
               _buildColorPicker(t.color, (c) => _updateSelectedTextOverlays((o) => o.color = c)),
               const SizedBox(height: 16),
               _buildControlSlider(label: "Opacity", value: t.opacity, min: 0.0, max: 1.0, onChanged: (v) => _updateSelectedTextOverlays((o) => o.opacity = v)),
               const SizedBox(height: 16),
               const Text("Font Style", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
               const SizedBox(height: 8),
               SizedBox(
                  height: 48,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: getAllFonts().length,
                    itemBuilder: (context, index) {
                      final f = getAllFonts()[index];
                      final bool isSelected = t.font == f;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            f.displayName,
                            style: TextStyle(
                              fontFamily: f.family,
                              fontWeight: f.weight,
                              fontStyle: f.style,
                              fontSize: 12,
                              color: isSelected ? Colors.white : Colors.black87,
                            ),
                          ),
                          selected: isSelected,
                          showCheckmark: false,
                          selectedColor: AppColors.primary,
                          backgroundColor: Colors.grey.shade100,
                          onSelected: (_) => _updateSelectedTextOverlays((o) => o.font = f),
                        ),
                      );
                    },
                  ),
                ),
               const SizedBox(height: 16),
               const Text("Alignment", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
               const SizedBox(height: 8),
               ToggleButtons(
                 isSelected: [
                   t.textAlign == TextAlign.left,
                   t.textAlign == TextAlign.center,
                   t.textAlign == TextAlign.right,
                 ],
                 onPressed: (index) {
                   _updateSelectedTextOverlays((o) {
                     if (index == 0) o.textAlign = TextAlign.left;
                     if (index == 1) o.textAlign = TextAlign.center;
                     if (index == 2) o.textAlign = TextAlign.right;
                   });
                 },
                 borderRadius: BorderRadius.circular(8),
                 constraints: const BoxConstraints(minHeight: 36, minWidth: 48),
                 children: const [
                   Icon(Icons.format_align_left, size: 20),
                   Icon(Icons.format_align_center, size: 20),
                   Icon(Icons.format_align_right, size: 20),
                 ],
               ),
               const SizedBox(height: 16),
               const Divider(height: 32),
               const Text("Positioning", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
               const SizedBox(height: 12),
               const Text("Quick Horizontal", style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
               const SizedBox(height: 8),
               Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildTextOverlayAlignButton(Icons.align_horizontal_left, "Left", 0.1, t),
                    _buildTextOverlayAlignButton(Icons.align_horizontal_center, "Center", 0.5, t),
                    _buildTextOverlayAlignButton(Icons.align_horizontal_right, "Right", 0.9, t),
                  ],
                ),
                const SizedBox(height: 12),
                const Text("Quick Vertical", style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildTextOverlayAlignYButton(Icons.align_vertical_top, "Top", 0.1, t),
                    _buildTextOverlayAlignYButton(Icons.align_vertical_center, "Middle", 0.5, t),
                    _buildTextOverlayAlignYButton(Icons.align_vertical_bottom, "Bottom", 0.9, t),
                  ],
                ),
                const SizedBox(height: 16),
                const Text("Fine-tune Positioning", style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _buildControlSlider(label: "Horizontal Position (X)", value: t.x, min: 0, max: 1, onChanged: (v) => _updateSelectedTextOverlays((o) => o.x = v)),
                _buildControlSlider(label: "Vertical Position (Y)", value: t.y, min: 0, max: 1, onChanged: (v) => _updateSelectedTextOverlays((o) => o.y = v)),
                const SizedBox(height: 8),
                const Divider(height: 32),
                const Text("Shadow Settings", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                SwitchListTile(title: const Text("Show Drop Shadow", style: TextStyle(fontSize: 13)), value: t.showShadow, onChanged: (v) => _updateSelectedTextOverlays((o) => o.showShadow = v), dense: true, contentPadding: EdgeInsets.zero),
                if (t.showShadow) ...[
                  _buildControlSlider(label: "Shadow Blur", value: t.shadowBlur, min: 0.1, max: 20.0, onChanged: (v) => _updateSelectedTextOverlays((o) => o.shadowBlur = v)),
                  _buildControlSlider(label: "Offset X", value: t.shadowOffsetX, min: -20.0, max: 20.0, onChanged: (v) => _updateSelectedTextOverlays((o) => o.shadowOffsetX = v)),
                  _buildControlSlider(label: "Offset Y", value: t.shadowOffsetY, min: -20.0, max: 20.0, onChanged: (v) => _updateSelectedTextOverlays((o) => o.shadowOffsetY = v)),
                  const SizedBox(height: 8),
                  const Text("Shadow Color", style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 8),
                  _buildColorPicker(t.shadowColor, (c) => _updateSelectedTextOverlays((o) => o.shadowColor = c)),
                ],
             ]
           )
         )
       ]
     );
  }

  Widget _buildTextOverlayAlignButton(IconData icon, String label, double x, _TextOverlay t) {
    bool isSelected = (t.x - x).abs() < 0.02;
    return InkWell(
      onTap: () => _updateSelectedTextOverlays((o) => o.x = x),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.black),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 10, color: isSelected ? Colors.white : Colors.black)),
          ],
        ),
      ),
    );
  }

  Widget _buildTextOverlayAlignYButton(IconData icon, String label, double y, _TextOverlay t) {
    bool isSelected = (t.y - y).abs() < 0.02;
    return InkWell(
      onTap: () => _updateSelectedTextOverlays((o) => o.y = y),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.black),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 10, color: isSelected ? Colors.white : Colors.black)),
          ],
        ),
      ),
    );
  }

  Widget _buildImageOverlayTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Image Overlays', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ElevatedButton.icon(
              onPressed: () async {
                final picker = ImagePicker();
                final picked = await picker.pickImage(source: ImageSource.gallery);
                if (picked != null) {
                  setState(() {
                    _imageOverlays.add(_ImageOverlay(path: picked.path));
                    _selectedImageOverlayIndex = _imageOverlays.length - 1;
                  });
                }
              },
              icon: const Icon(Icons.add_photo_alternate, size: 18),
              label: const Text('Add Image'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text('Add images, GIFs, PNGs, or stickers for CTA overlays.', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        const SizedBox(height: 12),
        if (_imageOverlays.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("No image overlays added.\nPick an image, GIF, or sticker to overlay.", style: TextStyle(color: Colors.grey, fontSize: 13), textAlign: TextAlign.center))),
        if (_imageOverlays.isNotEmpty) ...[
          SizedBox(
            height: 64,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _imageOverlays.length,
              itemBuilder: (context, i) {
                final o = _imageOverlays[i];
                final isSelected = _selectedImageOverlayIndex == i;
                return GestureDetector(
                  onTap: () => setState(() => _selectedImageOverlayIndex = i),
                  child: Container(
                    width: 58,
                    height: 58,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isSelected ? Colors.deepPurple : Colors.grey.shade300, width: isSelected ? 2.5 : 1),
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
          const SizedBox(height: 12),
        ],
        if (_selectedImageOverlayIndex != null && _selectedImageOverlayIndex! < _imageOverlays.length) ...[
          _buildActiveImageOverlayControls(_imageOverlays[_selectedImageOverlayIndex!], _selectedImageOverlayIndex!),
        ] else if (_imageOverlays.isNotEmpty)
          const Text("Select an overlay on preview to edit", style: TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildActiveImageOverlayControls(_ImageOverlay o, int index) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Overlay #${index + 1}", style: const TextStyle(fontWeight: FontWeight.bold)),
              Row(
                children: [
                  IconButton(
                    onPressed: () async {
                      final picker = ImagePicker();
                      final picked = await picker.pickImage(source: ImageSource.gallery);
                      if (picked != null) setState(() => o.path = picked.path);
                    },
                    icon: const Icon(Icons.swap_horiz, color: Colors.deepPurple, size: 20),
                    tooltip: 'Replace Image',
                  ),
                  IconButton(
                    onPressed: () => setState(() { _imageOverlays.removeAt(index); _selectedImageOverlayIndex = null; }),
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  ),
                ],
              ),
            ],
          ),
          _buildControlSlider(label: "Scale", value: o.scale, min: 0.02, max: 3.0, onChanged: (v) => setState(() => o.scale = v)),
          _buildControlSlider(label: "Opacity", value: o.opacity, min: 0.0, max: 1.0, onChanged: (v) => setState(() => o.opacity = v)),
          _buildControlSlider(label: "Rotation", value: o.rotation, min: 0, max: 360, onChanged: (v) => setState(() => o.rotation = v)),
          const Divider(height: 24),
          const Text("Positioning", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildImgAlignBtn(Icons.align_horizontal_left, "Left", 0.15, null, o),
              _buildImgAlignBtn(Icons.align_horizontal_center, "Center", 0.5, null, o),
              _buildImgAlignBtn(Icons.align_horizontal_right, "Right", 0.85, null, o),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildImgAlignBtn(Icons.align_vertical_top, "Top", null, 0.1, o),
              _buildImgAlignBtn(Icons.align_vertical_center, "Mid", null, 0.5, o),
              _buildImgAlignBtn(Icons.align_vertical_bottom, "Bottom", null, 0.9, o),
            ],
          ),
          const SizedBox(height: 8),
          _buildControlSlider(label: "Horizontal (X)", value: o.x, min: 0, max: 1, onChanged: (v) => setState(() => o.x = v)),
          _buildControlSlider(label: "Vertical (Y)", value: o.y, min: 0, max: 1, onChanged: (v) => setState(() => o.y = v)),
        ],
      ),
    );
  }

  Widget _buildImgAlignBtn(IconData icon, String label, double? x, double? y, _ImageOverlay o) {
    return InkWell(
      onTap: () => setState(() {
        if (x != null) o.x = x;
        if (y != null) o.y = y;
      }),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
        child: Column(
          children: [
            Icon(icon, size: 18, color: Colors.grey.shade700),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }

  Widget _buildRingStyleButton(bool isCustom, String label) {
    bool isSelected = _isCustomRingColor == isCustom;
    return InkWell(
      onTap: () => setState(() => _isCustomRingColor = isCustom),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppColors.primary : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildVerifiedPositionButton(String value, String label) {
    bool isSelected = _verifiedBadgeAttachTo == value;
    return InkWell(
      onTap: () => setState(() => _verifiedBadgeAttachTo = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppColors.primary : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildPreciseBtn({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, size: 14, color: Colors.black87),
      ),
    );
  }

  Widget _buildSliderWithButtons({
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    double? step,
    Color activeColor = AppColors.primary,
  }) {
    final double range = max - min;
    final double increment = step ?? (range <= 2 ? 0.05 : (range <= 10 ? 0.5 : (range / 20).roundToDouble().clamp(1.0, 10.0)));
    
    return Row(
      children: [
        _buildPreciseBtn(
          icon: Icons.remove,
          onTap: () => onChanged((value - increment).clamp(min, max)),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              activeTrackColor: activeColor,
              inactiveTrackColor: activeColor.withOpacity(0.1),
              thumbColor: activeColor,
              overlayColor: activeColor.withOpacity(0.12),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
        _buildPreciseBtn(
          icon: Icons.add,
          onTap: () => onChanged((value + increment).clamp(min, max)),
        ),
      ],
    );
  }

  Widget _buildControlSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    double? step,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            Text(value.toStringAsFixed(max <= 2 ? 2 : 1),
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ],
        ),
        _buildSliderWithButtons(
          value: value,
          min: min,
          max: max,
          onChanged: onChanged,
          step: step,
        ),
      ],
    );
  }

  Widget _buildMaskTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Mask Type', Icons.gradient),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildMaskTypeOption(0, Icons.block, 'None'),
              const SizedBox(width: 8),
              _buildMaskTypeOption(1, Icons.vertical_align_bottom, 'Bottom'),
              const SizedBox(width: 8),
              _buildMaskTypeOption(2, Icons.vertical_align_top, 'Top'),
              const SizedBox(width: 8),
              _buildMaskTypeOption(4, Icons.align_horizontal_left_rounded, 'Left'),
              const SizedBox(width: 8),
              _buildMaskTypeOption(5, Icons.align_horizontal_right_rounded, 'Right'),
              const SizedBox(width: 8),
              _buildMaskTypeOption(3, Icons.format_color_fill, 'Full'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildControlSlider(
          label: 'Mask Range Start',
          value: _maskStart,
          min: 0.0,
          max: 1.0,
          onChanged: (v) => setState(() => _maskStart = v),
        ),
        const SizedBox(height: 16),
        _buildControlSlider(
          label: 'Mask Range End',
          value: _maskEnd,
          min: 0.0,
          max: 1.0,
          onChanged: (v) => setState(() => _maskEnd = v),
        ),
        const SizedBox(height: 16),
        _buildControlSlider(
          label: 'Mask Opacity',
          value: _maskOpacity,
          min: 0.0,
          max: 1.0,
          onChanged: (v) => setState(() => _maskOpacity = v),
        ),
        const SizedBox(height: 24),
        _buildSectionHeader('Mask Color', Icons.color_lens),
        const SizedBox(height: 12),
        _buildColorPicker(
          '#${_maskColor.value.toRadixString(16).padLeft(8, '0').substring(2)}',
          (hex) => setState(() => _maskColor = _parseColor(hex)),
        ),
      ],
    );
  }

  Widget _buildMaskTypeOption(int type, IconData icon, String label) {
    final bool isSelected = _maskType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _maskType = type;
        });
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withOpacity(0.1)
                  : Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.grey[200]!),
            ),
            child: Icon(icon,
                color: isSelected ? AppColors.primary : Colors.grey[400]),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isSelected ? AppColors.primary : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorPicker(String currentColor, Function(String) onPick) {
    final colors = ['#FFFFFF', '#000000', '#FFD700', '#FF4444', '#00E676', '#2979FF', '#FF4081', '#AA00FF'];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Custom Color Button
        GestureDetector(
          onTap: () async {
            Color selectedColor = _parseColor(currentColor);
            await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Custom Color', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                        onColorChanged: (color) => selectedColor = color,
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            final hex = '#${selectedColor.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
                            onPick(hex);
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
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade300, width: 2),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
            child: const Icon(Icons.colorize_rounded, size: 18, color: Colors.black54),
          ),
        ),
        ...colors.map((c) => GestureDetector(
          onTap: () => onPick(c),
          child: Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              color: _parseColor(c),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade300, width: 2),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
          ),
        )),
      ],
    );
  }
}

class WireFramePainter extends CustomPainter {
  final double radius;
  final double width;
  final Color color;
  final double textWidth;
  final double scale;
  final bool hasCutout;
  final bool hasCutoutDots;
  final String textPosition;
  final double wireGap;

  WireFramePainter({
    required this.radius,
    required this.width,
    required this.color,
    required this.textWidth,
    required this.scale,
    required this.hasCutout,
    required this.hasCutoutDots,
    this.textPosition = 'bottom',
    this.wireGap = 16.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..isAntiAlias = true;

    final double left = 0;
    final double top = 0;
    final double right = size.width;
    final double bottom = size.height;

    final double r = radius.clamp(0, size.width / 2 < size.height / 2 ? size.width / 2 : size.height / 2);
    final double diameter = r * 2;

    if (!hasCutout) {
      if (r > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(left, top, right, bottom),
            Radius.circular(r),
          ),
          paint,
        );
      } else {
        canvas.drawRect(Rect.fromLTRB(left, top, right, bottom), paint);
      }
      return;
    }

    final double centerVal = (textPosition == 'left' || textPosition == 'right') ? size.height / 2 : size.width / 2;
    final double cutoutHalf = (textWidth + (wireGap * scale)) / 2;
    final double cutoutStart = centerVal - cutoutHalf;
    final double cutoutEnd = centerVal + cutoutHalf;

    final path = Path();

    if (r <= 0) {
      if (textPosition == 'bottom') {
        path.moveTo(left, top);
        path.lineTo(right, top);
        path.lineTo(right, bottom);
        if (cutoutEnd < right) {
          path.lineTo(cutoutEnd, bottom);
        }
        path.moveTo(cutoutStart, bottom);
        if (cutoutStart > left) {
          path.lineTo(left, bottom);
        }
        path.lineTo(left, top);
      } else if (textPosition == 'top') {
        path.moveTo(left, bottom);
        path.lineTo(left, top);
        if (cutoutStart > left) {
          path.lineTo(cutoutStart, top);
        }
        path.moveTo(cutoutEnd, top);
        if (cutoutEnd < right) {
          path.lineTo(right, top);
        }
        path.lineTo(right, bottom);
        path.lineTo(left, bottom);
      } else if (textPosition == 'left') {
        path.moveTo(right, top);
        path.lineTo(right, bottom);
        path.lineTo(left, bottom);
        if (cutoutEnd < bottom) {
          path.lineTo(left, cutoutEnd);
        }
        path.moveTo(left, cutoutStart);
        if (cutoutStart > top) {
          path.lineTo(left, cutoutStart);
        }
        path.lineTo(left, top);
        path.lineTo(right, top);
      } else {
        path.moveTo(left, top);
        path.lineTo(right, top);
        if (cutoutStart > top) {
          path.lineTo(right, cutoutStart);
        }
        path.moveTo(right, cutoutEnd);
        if (cutoutEnd < bottom) {
          path.lineTo(right, bottom);
        }
        path.lineTo(left, bottom);
        path.lineTo(left, top);
      }
      canvas.drawPath(path, paint);

      if (hasCutoutDots) {
        final dotPaint = Paint()
          ..color = color
          ..style = PaintingStyle.fill
          ..isAntiAlias = true;
        final double dotRadius = width * 1.5;
        if (textPosition == 'bottom') {
          canvas.drawCircle(Offset(cutoutStart, bottom), dotRadius, dotPaint);
          canvas.drawCircle(Offset(cutoutEnd, bottom), dotRadius, dotPaint);
        } else if (textPosition == 'top') {
          canvas.drawCircle(Offset(cutoutStart, top), dotRadius, dotPaint);
          canvas.drawCircle(Offset(cutoutEnd, top), dotRadius, dotPaint);
        } else if (textPosition == 'left') {
          canvas.drawCircle(Offset(left, cutoutStart), dotRadius, dotPaint);
          canvas.drawCircle(Offset(left, cutoutEnd), dotRadius, dotPaint);
        } else {
          canvas.drawCircle(Offset(right, cutoutStart), dotRadius, dotPaint);
          canvas.drawCircle(Offset(right, cutoutEnd), dotRadius, dotPaint);
        }
      }
      return;
    }

    if (textPosition == 'bottom') {
      path.moveTo(left + r, top);
      path.lineTo(right - r, top);
      path.arcTo(Rect.fromLTWH(right - diameter, top, diameter, diameter), -3.141592653589793 / 2, 3.141592653589793 / 2, false);
      path.lineTo(right, bottom - r);
      path.arcTo(Rect.fromLTWH(right - diameter, bottom - diameter, diameter, diameter), 0, 3.141592653589793 / 2, false);
      if (cutoutEnd < right - r) {
        path.lineTo(cutoutEnd, bottom);
      }
      path.moveTo(cutoutStart, bottom);
      if (cutoutStart > left + r) {
        path.lineTo(left + r, bottom);
      }
      path.arcTo(Rect.fromLTWH(left, bottom - diameter, diameter, diameter), 3.141592653589793 / 2, 3.141592653589793 / 2, false);
      path.lineTo(left, top + r);
      path.arcTo(Rect.fromLTWH(left, top, diameter, diameter), 3.141592653589793, 3.141592653589793 / 2, false);
    } else if (textPosition == 'top') {
      path.moveTo(left, bottom - r);
      path.lineTo(left, top + r);
      path.arcTo(Rect.fromLTWH(left, top, diameter, diameter), 3.141592653589793, 3.141592653589793 / 2, false);
      if (cutoutStart > left + r) {
        path.lineTo(cutoutStart, top);
      }
      path.moveTo(cutoutEnd, top);
      if (cutoutEnd < right - r) {
        path.lineTo(right - r, top);
      }
      path.arcTo(Rect.fromLTWH(right - diameter, top, diameter, diameter), -3.141592653589793 / 2, 3.141592653589793 / 2, false);
      path.lineTo(right, bottom - r);
      path.arcTo(Rect.fromLTWH(right - diameter, bottom - diameter, diameter, diameter), 0, 3.141592653589793 / 2, false);
      path.lineTo(left + r, bottom);
      path.arcTo(Rect.fromLTWH(left, bottom - diameter, diameter, diameter), 3.141592653589793 / 2, 3.141592653589793 / 2, false);
    } else if (textPosition == 'left') {
      path.moveTo(left + r, top);
      path.lineTo(right - r, top);
      path.arcTo(Rect.fromLTWH(right - diameter, top, diameter, diameter), -3.141592653589793 / 2, 3.141592653589793 / 2, false);
      path.lineTo(right, bottom - r);
      path.arcTo(Rect.fromLTWH(right - diameter, bottom - diameter, diameter, diameter), 0, 3.141592653589793 / 2, false);
      path.lineTo(left + r, bottom);
      path.arcTo(Rect.fromLTWH(left, bottom - diameter, diameter, diameter), 3.141592653589793 / 2, 3.141592653589793 / 2, false);
      if (cutoutEnd < bottom - r) {
        path.lineTo(left, cutoutEnd);
      }
      path.moveTo(left, cutoutStart);
      if (cutoutStart > top + r) {
        path.lineTo(left, top + r);
      }
      path.arcTo(Rect.fromLTWH(left, top, diameter, diameter), 3.141592653589793, 3.141592653589793 / 2, false);
    } else {
      path.moveTo(right - r, bottom);
      path.lineTo(left + r, bottom);
      path.arcTo(Rect.fromLTWH(left, bottom - diameter, diameter, diameter), 3.141592653589793 / 2, 3.141592653589793 / 2, false);
      path.lineTo(left, top + r);
      path.arcTo(Rect.fromLTWH(left, top, diameter, diameter), 3.141592653589793, 3.141592653589793 / 2, false);
      path.lineTo(right - r, top);
      path.arcTo(Rect.fromLTWH(right - diameter, top, diameter, diameter), -3.141592653589793 / 2, 3.141592653589793 / 2, false);
      if (cutoutStart > top + r) {
        path.lineTo(right, cutoutStart);
      }
      path.moveTo(right, cutoutEnd);
      if (cutoutEnd < bottom - r) {
        path.lineTo(right, bottom - r);
      }
      path.arcTo(Rect.fromLTWH(right - diameter, bottom - diameter, diameter, diameter), 0, 3.141592653589793 / 2, false);
    }

    canvas.drawPath(path, paint);

    if (hasCutoutDots) {
      final dotPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;
      final double dotRadius = width * 1.5;
      if (textPosition == 'bottom') {
        canvas.drawCircle(Offset(cutoutStart, bottom), dotRadius, dotPaint);
        canvas.drawCircle(Offset(cutoutEnd, bottom), dotRadius, dotPaint);
      } else if (textPosition == 'top') {
        canvas.drawCircle(Offset(cutoutStart, top), dotRadius, dotPaint);
        canvas.drawCircle(Offset(cutoutEnd, top), dotRadius, dotPaint);
      } else if (textPosition == 'left') {
        canvas.drawCircle(Offset(left, cutoutStart), dotRadius, dotPaint);
        canvas.drawCircle(Offset(left, cutoutEnd), dotRadius, dotPaint);
      } else {
        canvas.drawCircle(Offset(right, cutoutStart), dotRadius, dotPaint);
        canvas.drawCircle(Offset(right, cutoutEnd), dotRadius, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant WireFramePainter oldDelegate) {
    return oldDelegate.radius != radius ||
        oldDelegate.width != width ||
        oldDelegate.color != color ||
        oldDelegate.textWidth != textWidth ||
        oldDelegate.scale != scale ||
        oldDelegate.hasCutout != hasCutout ||
        oldDelegate.hasCutoutDots != hasCutoutDots ||
        oldDelegate.textPosition != textPosition ||
        oldDelegate.wireGap != wireGap;
  }
}
