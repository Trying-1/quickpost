import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:toastification/toastification.dart';
import 'package:archive/archive.dart';

import '../../config/app_theme.dart';
import '../../models/watermark_preset.dart';
import '../../models/image_post_preset.dart';
import '../../services/image_post_preset_service.dart';
import '../../services/watermark_preset_service.dart';
import '../../services/analytics_service.dart';
import '../../utils/font_selector.dart';
import '../../utils/custom_font_manager.dart';
import '../quotes/my_quotes_screen.dart';
import '../../models/quote_item.dart';
import 'image_post_maker/models/image_post_overlays.dart';
import 'image_post_maker/services/image_post_export_service.dart';
import 'image_post_maker/widgets/image_post_preview_canvas.dart';
import 'image_post_maker/widgets/tabs/image_post_canvas_tab.dart';
import 'image_post_maker/widgets/tabs/image_post_fonts_tab.dart';
import 'image_post_maker/widgets/tabs/image_post_mask_tab.dart';
import 'image_post_maker/widgets/tabs/image_post_overlays_tab.dart';
import 'image_post_maker/widgets/tabs/image_post_patching_tab.dart';
import 'image_post_maker/widgets/tabs/image_post_presets_tab.dart';
import 'image_post_maker/widgets/tabs/image_post_texts_tab.dart';
import 'image_post_maker/widgets/tabs/image_post_watermark_tabs.dart';

class ImagePostMakerScreen extends StatefulWidget {
  final List<String>? sharedImagePaths;
  final bool isActive;

  const ImagePostMakerScreen({Key? key, this.sharedImagePaths, this.isActive = true}) : super(key: key);

  @override
  State<ImagePostMakerScreen> createState() => _ImagePostMakerScreenState();
}

class _ImagePostMakerScreenState extends State<ImagePostMakerScreen> with WidgetsBindingObserver {
  static const platform = MethodChannel('com.quickpost.app/processor');
  final GlobalKey _repaintKey = GlobalKey();

  File? _selectedImage;
  double _imageAspectRatio = 1.0;
  int _imageWidth = 1080;
  int _imageHeight = 1080;
  bool _isProcessing = false;

  List<ImagePostPatch> _patches = [];
  int? _selectedPatchIndex;

  List<ImagePostTextOverlay> _textOverlays = [];
  int? _selectedTextOverlayIndex;
  Set<int> _selectedTextOverlayIndices = {};
  bool _multiSelectMode = false;

  List<ImagePostOverlayImage> _imageOverlays = [];
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
  double _videoX = 0.5;
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

  int _selectedTabIndex = 6; // Default to Presets
  int _selectedStyleSubTab = 0; // Maintain style subtab state
  int _selectedPresetSubTab = 0; // 0: Watermark Presets, 1: Project Presets
  bool _showControls = true;
  bool _isTabContentExpanded = true;

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _handleController = TextEditingController();

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
      _videoX = target.videoX;
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
      _patches = target.patches.map((p) => ImagePostPatch(
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
      _textOverlays = target.textOverlays.map((t) => ImagePostTextOverlay(
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
      _imageOverlays = target.imageOverlays.map((io) => ImagePostOverlayImage(
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
    preset.videoX = _videoX;
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
                videoX: preset.videoX,
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
      final filePath = await ImagePostPresetService.exportPresetsToFile();
      if (mounted) {
        _showToast('Presets exported to Downloads/Quick Post Backup');
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
        'videoX': _videoX,
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

      final backupDir = await ImagePostPresetService.getBackupDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${backupDir.path}/imagepost_project_$timestamp.zip');
      await file.writeAsBytes(zipData);

      try {
        await platform.invokeMethod('scanMediaFile', {
          'filePath': file.path,
          'mimeType': 'application/zip',
        });
      } catch (_) {}

      if (mounted) {
        _showToast('Project exported to Downloads/Quick Post Backup');
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
      final List<ImagePostPatch> patches = patchesData.map((p) => ImagePostPatch(
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
      final List<ImagePostTextOverlay> textOverlays = textOverlaysData.map((t) {
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

        return ImagePostTextOverlay(
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
      final List<ImagePostOverlayImage> imageOverlays = [];
      for (final io in imageOverlaysData) {
        final fileName = io['fileName'] as String?;
        if (fileName != null) {
          final archivedFile = archive.findFile('image_overlays/$fileName');
          if (archivedFile != null) {
            final overlayFile = File('${targetDir.path}/$fileName');
            await overlayFile.writeAsBytes(archivedFile.content as List<int>);

            imageOverlays.add(ImagePostOverlayImage(
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
        _videoX = (projectJson['videoX'] as num?)?.toDouble() ?? 0.5;
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
          final double defaultY = _textOverlays.isEmpty ? _calculateFirstTextAboveVideoY() : 0.35;
          _textOverlays.add(ImagePostTextOverlay(
            text: quoteString,
            x: _videoX,
            y: defaultY,
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
      videoX: _videoX,
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

  Future<void> _exportPost() {
    final prevPatchIdx = _selectedPatchIndex;
    final prevTextIdx = _selectedTextOverlayIndex;
    final prevTextIndices = Set<int>.from(_selectedTextOverlayIndices);
    final prevImgIdx = _selectedImageOverlayIndex;

    return ImagePostExportService.exportPost(
      context: context,
      selectedImage: _selectedImage,
      repaintKey: _repaintKey,
      fullScreen: _fullScreen,
      imageAspectRatio: _imageAspectRatio,
      saveLatestPreset: _saveCurrentAsLatestPreset,
      onBeforeExport: () => setState(() {
        _isProcessing = true;
        _selectedPatchIndex = -1;
        _selectedTextOverlayIndex = -1;
        _selectedTextOverlayIndices.clear();
        _selectedImageOverlayIndex = -1;
      }),
      onAfterExport: () => setState(() {
        _isProcessing = false;
        _selectedPatchIndex = prevPatchIdx;
        _selectedTextOverlayIndex = prevTextIdx;
        _selectedTextOverlayIndices = prevTextIndices;
        _selectedImageOverlayIndex = prevImgIdx;
      }),
      showToast: _showToast,
    );
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
    return ImagePostPreviewCanvas(
      repaintKey: _repaintKey,
      selectedImage: _selectedImage,
      bgImage: _bgImage,
      profileImage: _profileImage,
      fullScreen: _fullScreen,
      imageAspectRatio: _imageAspectRatio,
      bgColor: _bgColor,
      bgBrightness: _bgBrightness,
      bgSaturation: _bgSaturation,
      bgBlur: _bgBlur,
      videoRadius: _videoRadius,
      videoBorderWidth: _videoBorderWidth,
      videoBorderColor: _videoBorderColor,
      videoScale: _videoScale,
      videoX: _videoX,
      videoY: _videoY,
      showVideoShadow: _showVideoShadow,
      videoShadowColor: _videoShadowColor,
      videoShadowBlur: _videoShadowBlur,
      videoShadowSpread: _videoShadowSpread,
      videoShadowOffsetX: _videoShadowOffsetX,
      videoShadowOffsetY: _videoShadowOffsetY,
      maskType: _maskType,
      maskColor: _maskColor,
      maskOpacity: _maskOpacity,
      maskStart: _maskStart,
      maskEnd: _maskEnd,
      watermarkType: _watermarkType,
      watermarkX: _watermarkX,
      watermarkY: _watermarkY,
      watermarkScale: _watermarkScale,
      showBox: _showBox,
      boxColor: _boxColor,
      boxOpacity: _boxOpacity,
      boxRadius: _boxRadius,
      fontSize: _fontSize,
      iconSize: _iconSize,
      textColor: _textColor,
      accentColor: _accentColor,
      username: _username,
      handle: _handle,
      selectedUsernameFont: _selectedUsernameFont,
      selectedHandleFont: _selectedHandleFont,
      usernameSize: _usernameSize,
      handleSize: _handleSize,
      usernameOpacity: _usernameOpacity,
      handleOpacity: _handleOpacity,
      showStoryRing: _showStoryRing,
      isCustomRingColor: _isCustomRingColor,
      storyRingColor: _storyRingColor,
      storyRingWidth: _storyRingWidth,
      isVerified: _isVerified,
      verifiedBadgeColor: _verifiedBadgeColor,
      verifiedBadgeAttachTo: _verifiedBadgeAttachTo,
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
      wireRadius: _wireRadius,
      wireWidth: _wireWidth,
      wireColor: _wireColor,
      wireCutout: _wireCutout,
      wireCutoutDots: _wireCutoutDots,
      wireInset: _wireInset,
      wireTextPosition: _wireTextPosition,
      wireGap: _wireGap,
      patches: _patches,
      selectedPatchIndex: _selectedPatchIndex ?? -1,
      textOverlays: _textOverlays,
      selectedTextOverlayIndices: _selectedTextOverlayIndices,
      imageOverlays: _imageOverlays,
      selectedImageOverlayIndex: _selectedImageOverlayIndex ?? -1,
      selectedTabIndex: _selectedTabIndex,
      multiSelectMode: _multiSelectMode,
      onPickImage: _pickImage,
      onCanvasTap: () => setState(() => _showControls = !_showControls),
      onWatermarkPanUpdate: (x, y) => setState(() {
        _watermarkX = x;
        _watermarkY = y;
      }),
      onPatchPanUpdate: (idx, x, y) => setState(() {
        _patches[idx].x = x;
        _patches[idx].y = y;
        _selectedPatchIndex = idx;
      }),
      onPatchTap: (idx) => setState(() {
        _selectedPatchIndex = idx;
        _selectedTabIndex = 7;
        _isTabContentExpanded = true;
      }),
      onImageOverlayPanStart: (idx) => setState(() {
        _selectedImageOverlayIndex = idx;
      }),
      onImageOverlayPanUpdate: (idx, x, y) => setState(() {
        _imageOverlays[idx].x = x;
        _imageOverlays[idx].y = y;
      }),
      onImageOverlayTap: (idx) => setState(() {
        _selectedImageOverlayIndex = idx;
        _selectedTabIndex = 9;
        _isTabContentExpanded = true;
      }),
      onTextOverlayPanStart: (idx) => setState(() {
        _selectedTextOverlayIndex = idx;
        if (!_selectedTextOverlayIndices.contains(idx)) {
          if (!_multiSelectMode) _selectedTextOverlayIndices.clear();
          _selectedTextOverlayIndices.add(idx);
        }
      }),
      onSelectedTextOverlaysPanUpdate: (dx, dy) => setState(() {
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
      onTextOverlayTap: (idx) => setState(() {
        if (_multiSelectMode) {
          if (_selectedTextOverlayIndices.contains(idx)) {
            _selectedTextOverlayIndices.remove(idx);
            if (_selectedTextOverlayIndex == idx) {
              _selectedTextOverlayIndex = _selectedTextOverlayIndices.isNotEmpty
                  ? _selectedTextOverlayIndices.first
                  : null;
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
        return ImagePostTypeTab(
          watermarkType: _watermarkType,
          onTypeSelected: (type) => setState(() {
            _watermarkType = type;
            if (type != 'wire' && _selectedStyleSubTab == 4) {
              _selectedStyleSubTab = 0;
            }
          }),
        );
      case 1:
        return ImagePostProfileTab(
          watermarkType: _watermarkType,
          usernameController: _usernameController,
          handleController: _handleController,
          profileImage: _profileImage,
          showBox: _showBox,
          boxColor: _boxColor,
          boxOpacity: _boxOpacity,
          boxRadius: _boxRadius,
          showStoryRing: _showStoryRing,
          isCustomRingColor: _isCustomRingColor,
          storyRingWidth: _storyRingWidth,
          storyRingColor: _storyRingColor,
          isVerified: _isVerified,
          verifiedBadgeAttachTo: _verifiedBadgeAttachTo,
          verifiedBadgeColor: _verifiedBadgeColor,
          onUsernameChanged: (v) => setState(() => _username = v),
          onHandleChanged: (v) => setState(() => _handle = v),
          onPickProfileImage: _pickProfileImage,
          onShowBoxChanged: (v) => setState(() => _showBox = v),
          onBoxColorChanged: (c) => setState(() => _boxColor = c),
          onBoxOpacityChanged: (v) => setState(() => _boxOpacity = v),
          onBoxRadiusChanged: (v) => setState(() => _boxRadius = v),
          onShowStoryRingChanged: (v) => setState(() => _showStoryRing = v),
          onRingStyleChanged: (c) => setState(() => _isCustomRingColor = c),
          onStoryRingWidthChanged: (v) => setState(() => _storyRingWidth = v),
          onStoryRingColorChanged: (c) => setState(() => _storyRingColor = c),
          onVerifiedChanged: (v) => setState(() => _isVerified = v),
          onVerifiedAttachToChanged: (v) =>
              setState(() => _verifiedBadgeAttachTo = v),
          onVerifiedBadgeColorChanged: (c) =>
              setState(() => _verifiedBadgeColor = c),
        );
      case 2:
        return ImagePostPositionTab(
          watermarkType: _watermarkType,
          watermarkX: _watermarkX,
          watermarkY: _watermarkY,
          iconSize: _iconSize,
          usernameSize: _usernameSize,
          handleSize: _handleSize,
          watermarkScale: _watermarkScale,
          onWatermarkXChanged: (v) => setState(() => _watermarkX = v),
          onWatermarkYChanged: (v) => setState(() => _watermarkY = v),
          onIconSizeChanged: (v) => setState(() => _iconSize = v),
          onUsernameSizeChanged: (v) => setState(() => _usernameSize = v),
          onHandleSizeChanged: (v) => setState(() => _handleSize = v),
          onWatermarkScaleChanged: (v) => setState(() => _watermarkScale = v),
        );
      case 3:
        return ImagePostStyleTab(
          watermarkType: _watermarkType,
          selectedStyleSubTab: _selectedStyleSubTab,
          onSubTabChanged: (idx) => setState(() => _selectedStyleSubTab = idx),
          textColor: _textColor,
          usernameOpacity: _usernameOpacity,
          showUsernameShadow: _showUsernameShadow,
          usernameShadowColor: _usernameShadowColor,
          usernameShadowBlur: _usernameShadowBlur,
          usernameShadowOffsetX: _usernameShadowOffsetX,
          usernameShadowOffsetY: _usernameShadowOffsetY,
          onTextColorChanged: (c) => setState(() => _textColor = c),
          onUsernameOpacityChanged: (v) => setState(() => _usernameOpacity = v),
          onShowUsernameShadowChanged: (v) =>
              setState(() => _showUsernameShadow = v),
          onUsernameShadowColorChanged: (c) =>
              setState(() => _usernameShadowColor = c),
          onUsernameShadowBlurChanged: (v) =>
              setState(() => _usernameShadowBlur = v),
          onUsernameShadowOffsetXChanged: (v) =>
              setState(() => _usernameShadowOffsetX = v),
          onUsernameShadowOffsetYChanged: (v) =>
              setState(() => _usernameShadowOffsetY = v),
          accentColor: _accentColor,
          handleOpacity: _handleOpacity,
          showHandleShadow: _showHandleShadow,
          handleShadowColor: _handleShadowColor,
          handleShadowBlur: _handleShadowBlur,
          handleShadowOffsetX: _handleShadowOffsetX,
          handleShadowOffsetY: _handleShadowOffsetY,
          onAccentColorChanged: (c) => setState(() => _accentColor = c),
          onHandleOpacityChanged: (v) => setState(() => _handleOpacity = v),
          onShowHandleShadowChanged: (v) =>
              setState(() => _showHandleShadow = v),
          onHandleShadowColorChanged: (c) =>
              setState(() => _handleShadowColor = c),
          onHandleShadowBlurChanged: (v) =>
              setState(() => _handleShadowBlur = v),
          onHandleShadowOffsetXChanged: (v) =>
              setState(() => _handleShadowOffsetX = v),
          onHandleShadowOffsetYChanged: (v) =>
              setState(() => _handleShadowOffsetY = v),
          showIconShadow: _showIconShadow,
          iconShadowColor: _iconShadowColor,
          iconShadowBlur: _iconShadowBlur,
          iconShadowOffsetX: _iconShadowOffsetX,
          iconShadowOffsetY: _iconShadowOffsetY,
          onShowIconShadowChanged: (v) => setState(() => _showIconShadow = v),
          onIconShadowColorChanged: (c) =>
              setState(() => _iconShadowColor = c),
          onIconShadowBlurChanged: (v) => setState(() => _iconShadowBlur = v),
          onIconShadowOffsetXChanged: (v) =>
              setState(() => _iconShadowOffsetX = v),
          onIconShadowOffsetYChanged: (v) =>
              setState(() => _iconShadowOffsetY = v),
          showVideoShadow: _showVideoShadow,
          videoShadowColor: _videoShadowColor,
          videoShadowBlur: _videoShadowBlur,
          videoShadowOffsetX: _videoShadowOffsetX,
          videoShadowOffsetY: _videoShadowOffsetY,
          videoShadowSpread: _videoShadowSpread,
          videoScale: _videoScale,
          videoRadius: _videoRadius,
          videoBorderWidth: _videoBorderWidth,
          videoBorderColor: _videoBorderColor,
          onShowVideoShadowChanged: (v) =>
              setState(() => _showVideoShadow = v),
          onVideoShadowColorChanged: (c) =>
              setState(() => _videoShadowColor = c),
          onVideoShadowBlurChanged: (v) =>
              setState(() => _videoShadowBlur = v),
          onVideoShadowOffsetXChanged: (v) =>
              setState(() => _videoShadowOffsetX = v),
          onVideoShadowOffsetYChanged: (v) =>
              setState(() => _videoShadowOffsetY = v),
          onVideoShadowSpreadChanged: (v) =>
              setState(() => _videoShadowSpread = v),
          onVideoScaleChanged: (v) => setState(() => _videoScale = v),
          onVideoRadiusChanged: (v) => setState(() => _videoRadius = v),
          onVideoBorderWidthChanged: (v) =>
              setState(() => _videoBorderWidth = v),
          onVideoBorderColorChanged: (c) =>
              setState(() => _videoBorderColor = c),
          wireInset: _wireInset,
          wireRadius: _wireRadius,
          wireWidth: _wireWidth,
          wireColor: _wireColor,
          wireCutout: _wireCutout,
          wireCutoutDots: _wireCutoutDots,
          wireTextPosition: _wireTextPosition,
          wireGap: _wireGap,
          onWireInsetChanged: (v) => setState(() => _wireInset = v),
          onWireRadiusChanged: (v) => setState(() => _wireRadius = v),
          onWireWidthChanged: (v) => setState(() => _wireWidth = v),
          onWireColorChanged: (c) => setState(() => _wireColor = c),
          onWireCutoutChanged: (v) => setState(() => _wireCutout = v),
          onWireCutoutDotsChanged: (v) => setState(() => _wireCutoutDots = v),
          onWireTextPositionChanged: (p) =>
              setState(() => _wireTextPosition = p),
          onWireGapChanged: (v) => setState(() => _wireGap = v),
        );
      case 4:
        return ImagePostFontsTab(
          selectedStyleSubTab: _selectedStyleSubTab,
          selectedUsernameFont: _selectedUsernameFont,
          selectedHandleFont: _selectedHandleFont,
          onSubTabChanged: (idx) => setState(() => _selectedStyleSubTab = idx),
          onFontSelected: (font) => setState(() {
            if (_selectedStyleSubTab == 0) {
              _selectedUsernameFont = font;
            } else {
              _selectedHandleFont = font;
            }
          }),
        );
      case 5:
        return ImagePostCanvasTab(
          fullScreen: _fullScreen,
          bgImage: _bgImage,
          bgColor: _bgColor,
          bgBrightness: _bgBrightness,
          bgSaturation: _bgSaturation,
          bgBlur: _bgBlur,
          videoX: _videoX,
          videoY: _videoY,
          videoScale: _videoScale,
          videoRadius: _videoRadius,
          videoBorderWidth: _videoBorderWidth,
          videoBorderColor: _videoBorderColor,
          watermarkType: _watermarkType,
          onToggleFramedPreset: () => setState(() {
            final isFramed = _videoScale == 0.85 &&
                _videoBorderWidth == 1.5 &&
                _videoBorderColor.toUpperCase() == '#FFFFFF' &&
                _bgColor == '#000000' &&
                _bgImage == null &&
                _watermarkType == 'none';
            if (isFramed) {
              _videoScale = 1.0;
              _videoBorderWidth = 0.0;
            } else {
              _videoScale = 0.85;
              _videoBorderWidth = 1.5;
              _videoBorderColor = '#FFFFFF';
              _bgColor = '#000000';
              _bgImage = null;
              _watermarkType = 'none';
              if (!_fullScreen) _fullScreen = true;
            }
          }),
          onFullScreenChanged: (v) => setState(() => _fullScreen = v),
          onPickBgImage: _pickBgImage,
          onClearBgImage: () => setState(() => _bgImage = null),
          onBgColorChanged: (c) => setState(() => _bgColor = c),
          onBgBrightnessChanged: (v) => setState(() => _bgBrightness = v),
          onBgSaturationChanged: (v) => setState(() => _bgSaturation = v),
          onBgBlurChanged: (v) => setState(() => _bgBlur = v),
          onVideoXChanged: (v) => setState(() => _videoX = v),
          onVideoYChanged: (v) => setState(() => _videoY = v),
          onVideoScaleChanged: (v) => setState(() => _videoScale = v),
          onVideoRadiusChanged: (v) => setState(() => _videoRadius = v),
          onVideoBorderWidthChanged: (v) =>
              setState(() => _videoBorderWidth = v),
          onVideoBorderColorChanged: (c) =>
              setState(() => _videoBorderColor = c),
        );
      case 6:
        return ImagePostPresetsTab(
          selectedPresetSubTab: _selectedPresetSubTab,
          onSubTabChanged: (idx) => setState(() => _selectedPresetSubTab = idx),
          onSaveWatermarkPreset: _saveWatermarkPresetDialog,
          onLoadWatermarkPreset: _loadWatermarkPreset,
          onUpdateWatermarkPreset: _updateWatermarkPreset,
          onRenameWatermarkPreset: _renameWatermarkPreset,
          onExportWatermarkPresets: _exportWatermarkPresets,
          onImportWatermarkPresets: _importWatermarkPresets,
          onSaveProjectPreset: _savePresetDialog,
          onLoadProjectPreset: _loadPreset,
          onUpdateProjectPreset: _updateProjectPreset,
          onRenameProjectPreset: _renamePreset,
          onExportPresets: _exportPresets,
          onImportPresets: _importPresets,
          onExportProjectZip: _exportProjectZip,
          onImportProjectZip: _importProjectZip,
          onShowToast: _showToast,
          onStateChanged: () => setState(() {}),
        );
      case 7:
        return ImagePostPatchingTab(
          patches: _patches,
          selectedPatchIndex: _selectedPatchIndex,
          onSelectedIndexChanged: (idx) =>
              setState(() => _selectedPatchIndex = idx),
          onStateChanged: () => setState(() {}),
        );
      case 8:
        return ImagePostTextsTab(
          textOverlays: _textOverlays,
          selectedTextOverlayIndex: _selectedTextOverlayIndex,
          selectedTextOverlayIndices: _selectedTextOverlayIndices,
          multiSelectMode: _multiSelectMode,
          fullScreen: _fullScreen,
          imageAspectRatio: _imageAspectRatio,
          videoX: _videoX,
          videoY: _videoY,
          videoScale: _videoScale,
          onSelectedIndexChanged: (idx) =>
              setState(() => _selectedTextOverlayIndex = idx),
          onSelectedIndicesChanged: (next) =>
              setState(() => _selectedTextOverlayIndices = next),
          onMultiSelectChanged: (v) => setState(() => _multiSelectMode = v),
          onImportFromMyQuotes: _importFromMyQuotes,
          onShowToast: _showToast,
          onStateChanged: () => setState(() {}),
        );
      case 9:
        return ImagePostOverlaysTab(
          imageOverlays: _imageOverlays,
          selectedImageOverlayIndex: _selectedImageOverlayIndex,
          onSelectedIndexChanged: (idx) =>
              setState(() => _selectedImageOverlayIndex = idx),
          onStateChanged: () => setState(() {}),
        );
      case 10:
        return ImagePostMaskTab(
          maskType: _maskType,
          maskStart: _maskStart,
          maskEnd: _maskEnd,
          maskOpacity: _maskOpacity,
          maskColor: _maskColor,
          onMaskTypeChanged: (t) => setState(() => _maskType = t),
          onMaskStartChanged: (v) => setState(() => _maskStart = v),
          onMaskEndChanged: (v) => setState(() => _maskEnd = v),
          onMaskOpacityChanged: (v) => setState(() => _maskOpacity = v),
          onMaskColorChanged: (c) => setState(() => _maskColor = c),
        );
      default:
        return const SizedBox.shrink();
    }
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
                videoX: _videoX,
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
    try {
      final filePath = await WatermarkPresetService.exportPresetsToFile();
      if (mounted) {
        _showToast('Watermark presets exported to Downloads/Quick Post Backup');
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

  double _calculateFirstTextAboveVideoY() {
    final double canvasAspect = _fullScreen ? (9.0 / 16.0) : _imageAspectRatio;
    final double normScaledH;
    if (_imageAspectRatio >= canvasAspect) {
      normScaledH = (canvasAspect / _imageAspectRatio) * _videoScale;
    } else {
      normScaledH = _videoScale;
    }
    final double videoTopEdge = _videoY * (1.0 - normScaledH);
    final double gapAndHalfHeight = 0.045;
    final double targetY = videoTopEdge - gapAndHalfHeight;
    
    if (targetY >= 0.05) {
      return targetY;
    } else if (videoTopEdge >= 0.06) {
      return 0.05;
    } else {
      return 0.12;
    }
  }

}


