import '../../config/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:image_picker/image_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import '../../utils/font_selector.dart';
import '../../services/video_perf_service.dart';
import '../../models/watermark_preset.dart';
import '../../services/watermark_preset_service.dart';
import '../../config/app_config.dart';
import '../../widgets/advanced_color_picker.dart';

class VideoWatermarkScreen extends StatefulWidget {
  final List<String>? sharedVideoPaths;

  const VideoWatermarkScreen({Key? key, this.sharedVideoPaths}) : super(key: key);

  @override
  State<VideoWatermarkScreen> createState() => _VideoWatermarkScreenState();
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

  Map<String, dynamic> toMap(double videoW, double videoH) {
    return {
      'x': x * videoW,
      'y': y * videoH,
      'width': width * videoW,
      'height': height * videoH,
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

  Map<String, dynamic> toMap(double videoW, double videoH) {
    return {
      'path': path,
      'x': x * videoW,
      'y': y * videoH,
      'scale': scale,
      'opacity': opacity,
      'rotation': rotation,
    };
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

  _TextOverlay({
    required this.text,
    this.x = 0.5,
    this.y = 0.5,
    this.fontSize = 50.0,
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
  });

  Map<String, dynamic> toMap(double videoWidth, double videoHeight, String resolvedFontPath) {
    return {
      'text': text,
      'x': x * videoWidth,
      'y': y * videoHeight,
      'fontSize': fontSize * scale,
      'color': color,
      'fontPath': resolvedFontPath,
      'showShadow': showShadow,
      'shadowColor': shadowColor,
      'shadowBlur': shadowBlur,
      'shadowOffsetX': shadowOffsetX,
      'shadowOffsetY': shadowOffsetY,
      'textAlign': textAlign.name,
      'maxWidth': videoWidth * 0.8 * scale,
      'anchor': anchor,
      'scale': scale,
    };
  }
}

class _VideoWatermarkScreenState extends State<VideoWatermarkScreen> {
  static const platform = MethodChannel('com.quickpost.app/processor');

  File? _selectedVideo;
  VideoPlayerController? _videoController;
  double _videoAspectRatio = 16 / 9;
  int _videoWidth = 1080;
  int _videoHeight = 1920;
  bool _isProcessing = false;
  double _progress = 0.0;
  String? _outputPath;
  
  // Input Video Metadata
  int _inputDurationMs = 0;
  int _inputFileSize = 0;
  String _inputFileName = "";
  
  // Output Video Metadata
  int _outputFileSize = 0;
  String _outputFileName = "";

  // Performance Learning
  // Performance Learning
  double _avgRatio = 0.8;
  double _fakeProgress = 0.0;

  List<_Patch> _patches = [];
  int? _selectedPatchIndex;

  List<_TextOverlay> _textOverlays = [];
  int? _selectedTextOverlayIndex;

  List<_ImageOverlay> _imageOverlays = [];
  int? _selectedImageOverlayIndex;

  // Watermark state
  String _username = "Username";
  String _handle = "@userhandle";
  File? _profileImage;
  File? _bgImage;
  double _watermarkX = 0.5; // Normalized
  double _watermarkY = 0.15; // Normalized (TOP)
  double _fontSize = 36.0;
  double _usernameSize = 36.0;
  double _handleSize = 30.0;
  double _iconSize = 80.0;
  double _watermarkScale = 1.0;
  String _textColor = "#000000";
  String _accentColor = "#AAAAAA";
  FontInfo? _selectedUsernameFont;
  FontInfo? _selectedHandleFont;
  
  String _watermarkType = "profile_vertical"; // Vertical type as default
  bool _fullScreen = true; // Canvas on by default
  String _bgColor = "#FFFFFF";
  
   bool _showBox = false;
   String _boxColor = "#000000";
   double _boxOpacity = 0.3;
   double _boxRadius = 12.0;

   bool _showStoryRing = true;
   bool _isCustomRingColor = false;
   String _storyRingColor = "#FF4081";
   double _storyRingWidth = 5.0;
   bool _isVerified = true;
   String _verifiedBadgeColor = "#1DA1F2";
   String _verifiedBadgeAttachTo = "handle"; // "username" or "handle"

   double _bgBrightness = 1.0;
   double _bgSaturation = 1.0;
   double _bgBlur = 0.0;
   double _videoY = 0.5;

   // Formatting Helpers
   String _formatSize(int bytes) {
     if (bytes <= 0) return "0 B";
     const units = ["B", "KB", "MB", "GB", "TB"];
     var size = bytes.toDouble();
     var unitIndex = 0;
     while (size >= 1024 && unitIndex < units.length - 1) {
       size /= 1024;
       unitIndex++;
     }
     return "${size.toStringAsFixed(1)} ${units[unitIndex]}";
   }
    
    // Shadow settings
    bool _showUsernameShadow = false;
    String _usernameShadowColor = "#000000";
    double _usernameShadowBlur = 4.0;

    bool _showHandleShadow = false;
    String _handleShadowColor = "#000000";
    double _handleShadowBlur = 4.0;

    bool _showIconShadow = false;
    String _iconShadowColor = "#000000";
    double _iconShadowBlur = 4.0;
    double _usernameShadowOffsetX = 1.0;
    double _usernameShadowOffsetY = 1.0;
    double _handleShadowOffsetX = 1.0;
    double _handleShadowOffsetY = 1.0;
    double _iconShadowOffsetX = 1.5;
    double _iconShadowOffsetY = 1.5;

  int _selectedTabIndex = 1;
  int _selectedStyleSubTab = 0; // 0: Username, 1: Handle, 2: Icon
  bool _isTabContentExpanded = true;
  String _status = "Initializing...";
  String _currentStep = "";
  final Map<String, int> _stepTimings = {};
  DateTime? _stepStartTime;

  Stopwatch _processStopwatch = Stopwatch();
  String _elapsedTime = "00:00";
  String _remainingTime = "--:--";
  Timer? _uiUpdateTimer;

  void _recordStepTiming(String step) {
    if (_stepStartTime != null && _currentStep.isNotEmpty) {
      final duration = DateTime.now().difference(_stepStartTime!);
      _stepTimings[_currentStep] = (_stepTimings[_currentStep] ?? 0) + duration.inMilliseconds;
    }
    _currentStep = step;
    _stepStartTime = DateTime.now();
  }

  void _loadPreset([WatermarkPreset? preset]) {
    final target = preset ?? WatermarkPresetService.getLatestPreset();
    if (target == null) {
      _selectedUsernameFont = FontInfo(family: 'Metrophobic', displayName: 'Metrophobic');
      _selectedHandleFont = FontInfo(family: 'Metrophobic', displayName: 'Metrophobic');
      return;
    }
    
    setState(() {
      _watermarkType = target.watermarkType;
      _fullScreen = target.fullScreen;
      _bgColor = target.bgColor;
      _showBox = target.showBox;
      _boxColor = target.boxColor;
      _boxOpacity = target.boxOpacity;
      _boxRadius = target.boxRadius;
      _watermarkX = target.watermarkX;
      _watermarkY = target.watermarkY;
      _fontSize = target.fontSize;
      _iconSize = target.iconSize;
      _textColor = target.textColor;
      _accentColor = target.accentColor;
      _username = target.username;
      _handle = target.handle;
      
      // Shadow loading - using defaults if not in preset (for old presets)
      try {
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
      } catch(_) {
        // Fallback for old presets that might have the old single shadow field
        _showUsernameShadow = false;
        _showHandleShadow = false;
        _showIconShadow = false;
        _usernameShadowColor = "#000000";
        _handleShadowColor = "#000000";
        _iconShadowColor = "#000000";
      }
      
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
      
      _selectedUsernameFont = FontInfo(family: target.fontFamily, displayName: target.fontFamily);
      _selectedHandleFont = FontInfo(family: target.handleFontFamily ?? target.fontFamily, displayName: target.handleFontFamily ?? target.fontFamily);
      _showStoryRing = target.showStoryRing;
      _isVerified = target.isVerified;
      _videoY = target.videoY;

      // New design properties
      try {
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
        _bgBlur = target.bgBlur;
      } catch (_) {
        // Defaults for old presets
        _storyRingWidth = 5.0;
        _storyRingColor = "#FF4081";
        _isCustomRingColor = false;
        _verifiedBadgeColor = "#1DA1F2";
        _verifiedBadgeAttachTo = "handle";
        _watermarkScale = 1.0;
        _usernameSize = 36.0;
        _handleSize = 30.0;
        _bgBrightness = 1.0;
        _bgSaturation = 1.0;
        _bgBlur = 0.0;
        _bgBlur = 0.0;
      }
    });
  }

  void _savePreset() async {
    final TextEditingController nameController = TextEditingController(text: 'Style ${WatermarkPresetService.getAllPresets().length + 1}');
    
    final String? name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Local Preset'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Preset Name', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, nameController.text), child: const Text('Save')),
        ],
      ),
    );

    if (name == null || name.trim().isEmpty) return;

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final preset = WatermarkPreset(
      id: id,
      name: name.trim(),
      watermarkType: _watermarkType,
      fullScreen: _fullScreen,
      bgColor: _bgColor,
      showBox: _showBox,
      boxColor: _boxColor,
      boxOpacity: _boxOpacity,
      boxRadius: _boxRadius,
      watermarkX: _watermarkX,
      watermarkY: _watermarkY,
      fontSize: _fontSize,
      iconSize: _iconSize,
      textColor: _textColor,
      accentColor: _accentColor,
      username: _username,
      handle: _handle,
      fontFamily: _selectedUsernameFont?.family ?? 'Metrophobic',
      handleFontFamily: _selectedHandleFont?.family ?? _selectedUsernameFont?.family ?? 'Metrophobic',
      profileImagePath: _profileImage?.path,
      showStoryRing: _showStoryRing,
      isVerified: _isVerified,
      showUsernameShadow: _showUsernameShadow,
      usernameShadowColor: _usernameShadowColor,
      usernameShadowBlur: _usernameShadowBlur,
      showHandleShadow: _showHandleShadow,
      handleShadowColor: _handleShadowColor,
      handleShadowBlur: _handleShadowBlur,
      showIconShadow: _showIconShadow,
      iconShadowColor: _iconShadowColor,
      iconShadowBlur: _iconShadowBlur,
      usernameShadowOffsetX: _usernameShadowOffsetX,
      usernameShadowOffsetY: _usernameShadowOffsetY,
      handleShadowOffsetX: _handleShadowOffsetX,
      handleShadowOffsetY: _handleShadowOffsetY,
      iconShadowOffsetX: _iconShadowOffsetX,
      iconShadowOffsetY: _iconShadowOffsetY,
      videoY: _videoY,
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
    );
    await WatermarkPresetService.savePreset(preset);
    if (mounted) setState(() {});
  }

  void _updatePreset(WatermarkPreset preset) async {
    preset.watermarkType = _watermarkType;
    preset.fullScreen = _fullScreen;
    preset.bgColor = _bgColor;
    preset.showBox = _showBox;
    preset.boxColor = _boxColor;
    preset.boxOpacity = _boxOpacity;
    preset.boxRadius = _boxRadius;
    preset.watermarkX = _watermarkX;
    preset.watermarkY = _watermarkY;
    preset.fontSize = _fontSize;
    preset.iconSize = _iconSize;
    preset.textColor = _textColor;
    preset.accentColor = _accentColor;
    preset.username = _username;
    preset.handle = _handle;
    preset.fontFamily = _selectedUsernameFont?.family ?? 'Metrophobic';
    preset.handleFontFamily = _selectedHandleFont?.family ?? _selectedUsernameFont?.family ?? 'Metrophobic';
    preset.profileImagePath = _profileImage?.path;
    preset.showStoryRing = _showStoryRing;
    preset.isVerified = _isVerified;
    preset.showUsernameShadow = _showUsernameShadow;
    preset.usernameShadowColor = _usernameShadowColor;
    preset.usernameShadowBlur = _usernameShadowBlur;
    preset.showHandleShadow = _showHandleShadow;
    preset.handleShadowColor = _handleShadowColor;
    preset.handleShadowBlur = _handleShadowBlur;
    preset.showIconShadow = _showIconShadow;
    preset.iconShadowColor = _iconShadowColor;
    preset.iconShadowBlur = _iconShadowBlur;
    preset.usernameShadowOffsetX = _usernameShadowOffsetX;
    preset.usernameShadowOffsetY = _usernameShadowOffsetY;
    preset.handleShadowOffsetX = _handleShadowOffsetX;
    preset.handleShadowOffsetY = _handleShadowOffsetY;
    preset.iconShadowOffsetX = _iconShadowOffsetX;
    preset.iconShadowOffsetY = _iconShadowOffsetY;
    preset.videoY = _videoY;
    preset.storyRingWidth = _storyRingWidth;
    preset.storyRingColor = _storyRingColor;
    preset.isCustomRingColor = _isCustomRingColor;
    preset.verifiedBadgeColor = _verifiedBadgeColor;
    preset.verifiedBadgeAttachTo = _verifiedBadgeAttachTo;
    preset.watermarkScale = _watermarkScale;
    preset.usernameSize = _usernameSize;
    preset.handleSize = _handleSize;
    preset.bgBlur = _bgBlur;

    await WatermarkPresetService.savePreset(preset);
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Updated "${preset.name}" with current settings')),
      );
    }
  }

  void _deletePreset(WatermarkPreset preset) async {
    final bool confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Preset'),
        content: Text('Are you sure you want to delete "${preset.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Delete', style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      await WatermarkPresetService.deletePreset(preset.id);
      if (mounted) setState(() {});
    }
  }

  void _renamePreset(WatermarkPreset preset) async {
    final TextEditingController nameController = TextEditingController(text: preset.name);
    final String? newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Preset'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'New Name', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, nameController.text), child: const Text('Rename')),
        ],
      ),
    );

    if (newName != null && newName.trim().isNotEmpty) {
      preset.name = newName.trim();
      await WatermarkPresetService.savePreset(preset);
      setState(() {});
    }
  }

  void _exportPresets() async {
    final json = await WatermarkPresetService.exportPresetsJson();
    try {
      final dynamic success = await platform.invokeMethod('exportPresets', {'json': json});
      if (success == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Presets exported successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  void _importPresets() async {
    try {
      final String? json = await platform.invokeMethod('importPresets');
      if (json != null) {
        final int imported = await WatermarkPresetService.importPresetsJson(json);
        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Imported $imported presets successfully!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }

  @override
  void didUpdateWidget(covariant VideoWatermarkScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sharedVideoPaths != oldWidget.sharedVideoPaths) {
      if (widget.sharedVideoPaths != null && widget.sharedVideoPaths!.isNotEmpty) {
        _loadVideo(File(widget.sharedVideoPaths!.first));
        // Auto-set vertical template at the top for cropper imports
        setState(() {
          _watermarkType = 'profile_vertical';
          _watermarkY = 0.15; // Upper part
          _fullScreen = true; // Canvas on
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _avgRatio = VideoPerfService.getAvgRatio();
    _loadPreset();
    _setupMethodCallHandler();
    if (widget.sharedVideoPaths != null && widget.sharedVideoPaths!.isNotEmpty) {
      _loadVideo(File(widget.sharedVideoPaths!.first));
      // Auto-set vertical template at the top for cropper imports
      setState(() {
        _watermarkType = 'profile_vertical';
        _watermarkY = 0.15; // Upper part
        _fullScreen = true; // Canvas on
      });
    }
  }

  void _setupMethodCallHandler() {
    platform.setMethodCallHandler((call) async {
      if (mounted) {
        if (call.method == 'onProgress') {
          setState(() => _progress = call.arguments as double);
        } else if (call.method == 'onStep') {
          final step = call.arguments as String;
          setState(() {
            _status = step;
            _recordStepTiming(step);
          });
        }
      }
    });
  }

  Future<void> _loadVideo(File file) async {
    setState(() => _selectedVideo = file);
    _videoController?.dispose();
    _videoController = VideoPlayerController.file(file);
    await _videoController!.initialize();
    _videoController!.setLooping(true);
    _videoController!.play();
    setState(() {
      _videoAspectRatio = _videoController!.value.aspectRatio;
    });
    _fetchMetadata(file.path);
  }

  Future<void> _fetchMetadata(String path) async {
     try {
      final meta = await platform.invokeMethod<Map>('getVideoMetadata', {'videoPath': path});
      if (meta != null) {
        setState(() {
          _videoWidth = meta['width'] as int? ?? 1080;
          _videoHeight = meta['height'] as int? ?? 1920;
          _inputDurationMs = meta['durationMs'] as int? ?? 0;
          _inputFileSize = meta['fileSizeBytes'] as int? ?? 0;
          _inputFileName = meta['fileName'] as String? ?? "Video";
        });
      }
    } catch (_) {}
  }

  Future<void> _pickVideo() async {
    final XFile? video = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (video != null) _loadVideo(File(video.path));
  }

  Future<void> _pickProfileImage() async {
    final XFile? img = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (img != null) setState(() => _profileImage = File(img.path));
  }

  Future<void> _processVideo() async {
    if (_selectedVideo == null) return;
    
    // Auto-save the current configuration to the 'Latest' preset right before export
    final latestId = "latest_preset_auto";
    final preset = WatermarkPreset(
      id: latestId,
      name: "Latest Configuration",
      watermarkType: _watermarkType,
      fullScreen: _fullScreen,
      bgColor: _bgColor,
      showBox: _showBox,
      boxColor: _boxColor,
      boxOpacity: _boxOpacity,
      boxRadius: _boxRadius,
      watermarkX: _watermarkX,
      watermarkY: _watermarkY,
      fontSize: _fontSize,
      iconSize: _iconSize,
      textColor: _textColor,
      accentColor: _accentColor,
      username: _username,
      handle: _handle,
      fontFamily: _selectedUsernameFont?.family ?? 'Metrophobic',
      handleFontFamily: _selectedHandleFont?.family ?? _selectedUsernameFont?.family ?? 'Metrophobic',
      profileImagePath: _profileImage?.path,
      showStoryRing: _showStoryRing,
      isVerified: _isVerified,
      showUsernameShadow: _showUsernameShadow,
      usernameShadowColor: _usernameShadowColor,
      usernameShadowBlur: _usernameShadowBlur,
      showHandleShadow: _showHandleShadow,
      handleShadowColor: _handleShadowColor,
      handleShadowBlur: _handleShadowBlur,
      showIconShadow: _showIconShadow,
      iconShadowColor: _iconShadowColor,
      iconShadowBlur: _iconShadowBlur,
      iconShadowOffsetX: _iconShadowOffsetX,
      iconShadowOffsetY: _iconShadowOffsetY,
      videoY: _videoY,
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
    );
    await WatermarkPresetService.savePreset(preset);

    setState(() { 
      _isProcessing = true; 
      _progress = 0.0; 
      _status = "Preparing Video..."; 
      _stepTimings.clear();
      _currentStep = "Initializing";
      _stepStartTime = DateTime.now();
      _elapsedTime = "00:00";
      _remainingTime = "--:--";
    });
    _startProgressTimer();

    try {
      final filename = "Watermark_${DateTime.now().millisecondsSinceEpoch}.mp4";
      final outPath = await platform.invokeMethod<String>('getVideoOutputPath', {'filename': filename});

      
      final usernameFontPath = await _getFontPath(_selectedUsernameFont?.family ?? 'Roboto', _selectedUsernameFont?.displayName ?? 'Roboto', filePath: _selectedUsernameFont?.filePath);
      final handleFontPath = await _getFontPath(_selectedHandleFont?.family ?? _selectedUsernameFont?.family ?? 'Roboto', _selectedHandleFont?.displayName ?? _selectedUsernameFont?.displayName ?? 'Roboto', filePath: _selectedHandleFont?.filePath ?? _selectedUsernameFont?.filePath);

      final List<Map<String, dynamic>> resolvedTextOverlays = [];
      for (final t in _textOverlays) {
        final path = await _getFontPath(t.font?.family ?? 'Roboto', t.font?.displayName ?? 'Roboto', filePath: t.font?.filePath, fontInfo: t.font);
        resolvedTextOverlays.add(t.toMap((_fullScreen ? 1080 : _videoWidth).toDouble(), (_fullScreen ? 1920 : _videoHeight).toDouble(), path));
      }

      final params = {
        'type': _watermarkType,
        'fullScreen': _fullScreen,
        'bgColor': _bgColor,
        'showBox': _showBox,
        'boxColor': _boxColor,
        'boxOpacity': _boxOpacity,
        'boxRadius': _boxRadius,
        'inputPath': _selectedVideo!.path,
        'outputPath': outPath,
        'username': _username,
        'handle': _handle,
        'profileImagePath': _profileImage?.path ?? "",
        'bgImagePath': _bgImage?.path ?? "",
        'x': (_watermarkX * (_fullScreen ? 1080 : _videoWidth)).toInt(),
        'y': (_watermarkY * (_fullScreen ? 1920 : _videoHeight)).toInt(),
        'fontSize': _fontSize.toInt(),
        'iconSize': _iconSize.toInt(),
        'textColor': _textColor,
        'accentColor': _accentColor,
        'fontPath': usernameFontPath,
        'handleFontPath': handleFontPath,
        'isVerified': _isVerified,
        'verifiedBadgeColor': _verifiedBadgeColor,
        'verifiedBadgeAttachTo': _verifiedBadgeAttachTo,
        'watermarkScale': _watermarkScale,
        'showStoryRing': _showStoryRing,
        'storyRingColor': _isCustomRingColor ? _storyRingColor : "gradient",
        'bgBrightness': _bgBrightness,
        'bgSaturation': _bgSaturation,
        'bgBlur': _bgBlur,
        'showUsernameShadow': _showUsernameShadow,
        'usernameShadowColor': _usernameShadowColor,
        'usernameShadowBlur': _usernameShadowBlur,
        'showHandleShadow': _showHandleShadow,
        'handleShadowColor': _handleShadowColor,
        'handleShadowBlur': _handleShadowBlur,
        'showIconShadow': _showIconShadow,
        'iconShadowColor': _iconShadowColor,
        'iconShadowBlur': _iconShadowBlur,
        'usernameShadowOffsetX': _usernameShadowOffsetX,
        'usernameShadowOffsetY': _usernameShadowOffsetY,
        'handleShadowOffsetX': _handleShadowOffsetX,
        'handleShadowOffsetY': _handleShadowOffsetY,
        'iconShadowOffsetX': _iconShadowOffsetX,
        'iconShadowOffsetY': _iconShadowOffsetY,
        'videoY': _videoY,
        'patches': _patches.map((p) => p.toMap((_fullScreen ? 1080 : _videoWidth).toDouble(), (_fullScreen ? 1920 : _videoHeight).toDouble())).toList(),
        'textOverlays': resolvedTextOverlays,
        'imageOverlays': _imageOverlays.map((o) => o.toMap((_fullScreen ? 1080 : _videoWidth).toDouble(), (_fullScreen ? 1920 : _videoHeight).toDouble())).toList(),
      };

      final result = await platform.invokeMethod<String>('addWatermarkToVideo', params);
      
      _uiUpdateTimer?.cancel();
      _processStopwatch.stop();

      if (mounted) {
        // Fetch output metadata
        final outMeta = await platform.invokeMethod<Map>('getVideoMetadata', {'videoPath': result});
        
        // Learn and save performance ratio
        if (_inputDurationMs > 0) {
          final actualRatio = _processStopwatch.elapsedMilliseconds / _inputDurationMs;
          await VideoPerfService.updateRatio(actualRatio);
        }

        setState(() { 
          _recordStepTiming(""); // Finalize last step
          _isProcessing = false; 
          _outputPath = result; 
          if (outMeta != null) {
            _outputFileSize = outMeta['fileSizeBytes'] as int? ?? 0;
            _outputFileName = outMeta['fileName'] as String? ?? "Output";
          }
        });
        _showSuccess();
      }
    } catch (e) {
      _uiUpdateTimer?.cancel();
      _processStopwatch.stop();

      if (mounted) {
        setState(() {
          _recordStepTiming(""); // Finalize
          _isProcessing = false;
        });

        if (e.toString().contains("Processing Canceled")) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Processing canceled by user')),
          );
        } else if (e.toString().contains("PlatformException(PROCESSING_FAILED")) {
          _showError("Failed to export video. Check file sizes or try another template.");
        } else {
          _showError(e.toString());
        }
      }
    }
  }

  void _startProgressTimer() {
    _processStopwatch.reset();
    _processStopwatch.start();
    _uiUpdateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isProcessing) {
        timer.cancel();
        return;
      }
      if (mounted) {
        setState(() {
          final elapsed = _processStopwatch.elapsed;
          _elapsedTime = _formatDuration(elapsed);
          
          // Calculate fake progress based on estimation
          if (_inputDurationMs > 0) {
            final estimatedTotalMs = _inputDurationMs * _avgRatio;
            _fakeProgress = (elapsed.inMilliseconds / estimatedTotalMs).clamp(0.0, 0.99);
          }

          if (_progress > 0.05) {
            final totalEstimatedMs = elapsed.inMilliseconds / _progress;
            final remainingInMs = (totalEstimatedMs - elapsed.inMilliseconds).toInt();
            _remainingTime = _formatDuration(Duration(milliseconds: math.max(0, remainingInMs)));
          } else if (_inputDurationMs > 0) {
            // Fallback to learned avgRatio
            final estimatedTotalMs = _inputDurationMs * _avgRatio;
            final remainingInMs = (estimatedTotalMs - elapsed.inMilliseconds).toInt();
            _remainingTime = _formatDuration(Duration(milliseconds: math.max(0, remainingInMs)));
          } else {
            _remainingTime = "--:--";
          }
        });
      }
    });
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  void _cancelProcess() async {
    try {
      await platform.invokeMethod('cancelWatermarkToVideo');
    } catch (e) {
      print("Cancel error: $e");
    }
  }

  Future<String> _getFontPath(String family, String displayName, {String? filePath, FontInfo? fontInfo}) async {
    // Use the exact FontInfo if provided (preserves weight/style/assetPath),
    // otherwise fall back to family lookup then manual construction.
    final font = fontInfo ?? 
                 FontInfo.getFontByFamily(family) ?? 
                 FontInfo(family: family, displayName: displayName, isCustom: filePath != null, filePath: filePath);
    return await FontInfo.getFontFilePath(font);
  }

  void _showSuccess() {
    showDialog(
      context: context, 
      builder: (c) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 340,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: Colors.green, size: 40),
              ),
              const SizedBox(height: 20),
              const Text(
                'Export Complete!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                'Saved to Gallery & Downloads',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.description_outlined, size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _outputFileName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Input Size', style: TextStyle(color: Colors.grey, fontSize: 11)),
                        Text(_formatSize(_inputFileSize), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Output Size', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        Text(_formatSize(_outputFileSize), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(c),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey[300]!),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Close', style: TextStyle(color: Colors.black87)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(c);
                        OpenFile.open(_outputPath!);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Open Video'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showError(String m) {
    showDialog(context: context, builder: (c) => AlertDialog(title: const Text('Error'), content: Text(m), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))]));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.grey[50], // Restored light background
          body: SafeArea(
            child: Column(
              children: [
                Expanded(child: _buildPreviewArea()),
                if (_selectedVideo != null) ...[
                  if (_isTabContentExpanded) _buildActiveTabContent(),
                  _buildControlTabs(),
                ],
              ],
            ),
          ),
        ),
        if (_isProcessing) _buildProcessingOverlay(),
      ],
    );
  }

  Widget _buildProcessingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Center(
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 30,
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.movie_filter, color: Color(0xFF00796B), size: 28),
              ),
              const SizedBox(height: 24),
              const Text(
                'Processing Video',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              if (_inputFileName.isNotEmpty)
                Text(
                  _inputFileName,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 28),
              Container(
                height: 10,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Stack(
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          width: constraints.maxWidth * _fakeProgress,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF80CBC4), Color(0xFF00796B)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.teal.withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                        );
                      }
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(_fakeProgress * 100).toInt()}% Estimated',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF00796B)),
                  ),
                  Text(
                    _status,
                    style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              // Stats Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildTimeInfo("Elapsed", _elapsedTime),
                    Container(width: 1, height: 30, color: Colors.grey[200]),
                    _buildTimeInfo("Est. Left", _remainingTime),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _cancelProcess,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    'Cancel Process',
                    style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeInfo(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'monospace'),
        ),
      ],
    );
  }

  Widget _buildPreviewArea() {
    if (_selectedVideo == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.movie_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No video selected', style: TextStyle(fontSize: 18, color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _pickVideo,
              icon: const Icon(Icons.video_call),
              label: const Text('Select Input Video'),
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

    final outAspect = _fullScreen ? 9 / 16 : _videoAspectRatio;

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
            child: AspectRatio(
              aspectRatio: outAspect,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return GestureDetector(
                    onPanUpdate: (d) => setState(() {
                      _watermarkX = (d.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
                      _watermarkY = (d.localPosition.dy / constraints.maxHeight).clamp(0.0, 1.0);
                    }),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Background Path
                        if (_bgImage != null)
                          Positioned.fill(
                            child: ImageFiltered(
                              imageFilter: ui.ImageFilter.blur(sigmaX: _bgBlur / 5, sigmaY: _bgBlur / 5),
                              child: ColorFiltered(
                                colorFilter: ColorFilter.matrix([
                                  // Saturation matrix
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
                        // Background Color (only visible if no image or semi-transparent image)
                        if (_bgImage == null)
                           Positioned.fill(child: ColoredBox(color: _parseColor(_bgColor))),

                        // Patches (Bottom Layer)
                        ..._patches.asMap().entries.where((e) => !e.value.isTop).map((entry) {
                           final idx = entry.key;
                           final p = entry.value;
                           return _buildPatchPreview(p, idx, constraints);
                        }).toList(),

                          Align(
                            alignment: Alignment(0, (_videoY - 0.5) * 2),
                            child: AspectRatio(
                              aspectRatio: _videoAspectRatio,
                              child: VideoPlayer(_videoController!),
                            ),
                          ),

                         // Patches (Top Layer)
                         ..._patches.asMap().entries.where((e) => e.value.isTop).map((entry) {
                           final idx = entry.key;
                           final p = entry.value;
                           return _buildPatchPreview(p, idx, constraints);
                         }).toList(),

                        // Text Overlays
                        ..._textOverlays.asMap().entries.map((entry) {
                           final idx = entry.key;
                           final t = entry.value;
                           return _buildTextOverlayPreview(t, idx, constraints);
                        }).toList(),

                        // Image Overlays
                        ..._imageOverlays.asMap().entries.map((entry) {
                           final idx = entry.key;
                           final img = entry.value;
                           return _buildImageOverlayPreview(img, idx, constraints);
                        }).toList(),

                        // Watermark Layer
                        Positioned(
                          left: _watermarkX * constraints.maxWidth,
                          top: _watermarkY * constraints.maxHeight,
                          child: FractionalTranslation(
                            translation: const Offset(-0.5, -0.5),
                            child: _buildWatermarkPreview(constraints.maxWidth / (_fullScreen ? 1080 : _videoWidth) * _watermarkScale),
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
    );
  }

  Widget _buildWatermarkPreview(double scale) {
    if (!_showBox) return _buildWatermarkContent(scale);
    
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
              decoration: _showStoryRing ? BoxDecoration(
                shape: BoxShape.circle,
                gradient: _isCustomRingColor ? null : const SweepGradient(
                  colors: [
                    Color(0xFFFCAF45),
                    Color(0xFFF56040),
                    Color(0xFFE1306C),
                    Color(0xFFC13584),
                    Color(0xFFFCAF45),
                  ],
                ),
                color: _isCustomRingColor ? _parseColor(_storyRingColor) : null,
              ) : null,
              child: Container(
                decoration: _showIconShadow ? BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _parseColor(_iconShadowColor),
                      blurRadius: _iconShadowBlur * scale,
                      offset: Offset(_iconShadowOffsetX * scale, _iconShadowOffsetY * scale),
                    )
                  ],
                ) : null,
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
                        color: _parseColor(_textColor),
                        fontWeight: FontWeight.bold,
                        fontSize: _usernameSize * scale,
                        fontFamily: _selectedUsernameFont?.family,
                        shadows: _showUsernameShadow ? [
                          Shadow(
                            color: _parseColor(_usernameShadowColor),
                            blurRadius: _usernameShadowBlur * scale,
                            offset: Offset(_usernameShadowOffsetX * scale, _usernameShadowOffsetY * scale),
                          )
                        ] : null,
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
                        color: _parseColor(_accentColor),
                        fontSize: _handleSize * scale,
                        fontFamily: _selectedHandleFont?.family,
                        shadows: _showHandleShadow ? [
                          Shadow(
                            color: _parseColor(_handleShadowColor),
                            blurRadius: _handleShadowBlur * scale,
                            offset: Offset(_handleShadowOffsetX * scale, _handleShadowOffsetY * scale),
                          )
                        ] : null,
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
                    decoration: _showStoryRing ? BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: _isCustomRingColor ? null : const SweepGradient(
                        colors: [
                          Color(0xFFFCAF45),
                          Color(0xFFF56040),
                          Color(0xFFE1306C),
                          Color(0xFFC13584),
                          Color(0xFFFCAF45),
                        ],
                      ),
                      color: _isCustomRingColor ? _parseColor(_storyRingColor) : null,
                    ) : null,
                    child: Container(
                      decoration: _showIconShadow ? BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _parseColor(_iconShadowColor),
                            blurRadius: _iconShadowBlur * scale,
                            offset: Offset(_iconShadowOffsetX * scale, _iconShadowOffsetY * scale),
                          )
                        ],
                      ) : null,
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
                              color: _parseColor(_textColor),
                              fontWeight: _selectedUsernameFont?.weight ?? FontWeight.bold,
                              fontStyle: _selectedUsernameFont?.style ?? FontStyle.normal,
                              fontSize: _usernameSize * scale,
                              fontFamily: _selectedUsernameFont?.family,
                              shadows: _showUsernameShadow ? [
                                Shadow(
                                  color: _parseColor(_usernameShadowColor),
                                  blurRadius: _usernameShadowBlur * scale,
                                  offset: Offset(_usernameShadowOffsetX * scale, _usernameShadowOffsetY * scale),
                                )
                              ] : null,
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
                              color: _parseColor(_accentColor),
                              fontWeight: _selectedHandleFont?.weight ?? _selectedUsernameFont?.weight ?? FontWeight.normal,
                              fontStyle: _selectedHandleFont?.style ?? _selectedUsernameFont?.style ?? FontStyle.normal,
                              fontSize: _handleSize * scale,
                              fontFamily: _selectedHandleFont?.family ?? _selectedUsernameFont?.family,
                              shadows: _showHandleShadow ? [
                                Shadow(
                                  color: _parseColor(_handleShadowColor),
                                  blurRadius: _handleShadowBlur * scale,
                                  offset: Offset(_handleShadowOffsetX * scale, _handleShadowOffsetY * scale),
                                )
                              ] : null,
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
                  child: Icon(Icons.more_horiz, color: _parseColor(_accentColor), size: _fontSize * 1.2 * scale),
                ),
              ],
            ],
          ),
        );
      case 'text':
        return Text(
          _username,
          style: TextStyle(
            color: _parseColor(_textColor),
            fontWeight: FontWeight.bold,
            fontSize: _usernameSize * scale,
            fontFamily: _selectedUsernameFont?.family,
            shadows: _showUsernameShadow ? [
              Shadow(
                color: _parseColor(_usernameShadowColor),
                blurRadius: _usernameShadowBlur * scale,
                offset: Offset(_usernameShadowOffsetX * scale, _usernameShadowOffsetY * scale),
              )
            ] : null,
          ),
        );
      case 'image':
        return _profileImage != null 
          ? Image.file(_profileImage!, width: _iconSize * scale, height: _iconSize * scale, fit: BoxFit.contain)
          : Icon(Icons.image, size: _iconSize * scale, color: Colors.grey.shade400);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildControlTabs() {
    final presets = WatermarkPresetService.getAllPresets();
    
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
              onPressed: _isProcessing ? null : _processVideo,
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
              scrollDirection: Axis.horizontal,
              children: [
                _buildTabItem(-1, Icons.add_to_photos, 'Import', AppColors.primary, customOnTap: _pickVideo),
                _buildTabItem(6, Icons.stars, 'Presets', Colors.pink),
                _buildTabItem(0, Icons.branding_watermark, 'Type', Colors.amber),
                _buildTabItem(1, Icons.edit_note, 'Content', Colors.indigo),
                _buildTabItem(8, Icons.text_fields, 'Texts', AppColors.primary),
                _buildTabItem(2, Icons.open_with, 'Position', AppColors.primary),
                _buildTabItem(3, Icons.palette, 'Style', Colors.deepOrange),
                _buildTabItem(4, Icons.font_download, 'Fonts', Colors.teal),
                _buildTabItem(7, Icons.layers, 'Patching', Colors.pink),
                _buildTabItem(9, Icons.photo_library, 'Overlays', Colors.deepPurple),
                _buildTabItem(5, Icons.video_settings, 'Canvas', AppColors.primary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetTabItem(WatermarkPreset preset) {
    return GestureDetector(
      onLongPress: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Preset: ${preset.name}'),
            content: const Text('What would you like to do?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _renamePreset(preset);
                }, 
                child: const Text('Rename')
              ),
              TextButton(
                onPressed: () async {
                  await WatermarkPresetService.deletePreset(preset.id);
                  Navigator.pop(context);
                  setState(() {});
                }, 
                child: const Text('Delete', style: TextStyle(color: Colors.red))
              ),
            ],
          ),
        );
      },
      child: _buildTabItem(-2, Icons.stars, preset.name, Colors.pink, 
        customOnTap: () => _loadPreset(preset)),
    );
  }

  Widget _buildTabItem(int index, IconData icon, String label, Color color, {VoidCallback? customOnTap}) {
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
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey[600], size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isSelected ? color : Colors.grey[600],
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTabContent() {
    return Container(
      height: 240,
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: _buildTabSpecificContent(),
      ),
    );
  }

  Widget _buildTabSpecificContent() {
    switch (_selectedTabIndex) {
      case 0: return _buildTypeTab();
      case 1: return _buildProfileTab(); // Reused for generic "content"
      case 2: return _buildPositionTab();
      case 3: return _buildStyleTab();
      case 4: return _buildFontsTab();
      case 5: return _buildSettingsTab();
      case 6: return _buildPresetsTab();
      case 7: return _buildPatchingTab();
      case 8: return _buildTextOverlayTab();
      case 9: return _buildImageOverlayTab();
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildPresetsTab() {
    final presets = WatermarkPresetService.getAllPresets();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Design Presets', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 16),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: presets.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return GestureDetector(
                  onTap: _savePreset,
                  child: Container(
                    width: 80,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: Colors.pink.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.pink.withOpacity(0.2)),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_circle_outline, color: Colors.pink, size: 32),
                        SizedBox(height: 8),
                        Text('Save New', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.pink)),
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
          const Divider(height: 32),
          const Text('Cloud Sync & Backup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _exportPresets,
                  icon: const Icon(Icons.backup_outlined, size: 18),
                  label: const Text('Export JSON'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _importPresets,
                  icon: const Icon(Icons.restore_outlined, size: 18),
                  label: const Text('Import JSON'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Export your styles to keep them safe even after uninstalling the app.', style: TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ],
    );
  }

  Widget _buildPresetTabTile(WatermarkPreset preset) {
    return GestureDetector(
      onTap: () {
        _loadPreset(preset);
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✨ Loaded "${preset.name}"'), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 1)),
        );
      },
      onLongPress: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Style: ${preset.name}'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _updatePreset(preset);
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
                onPressed: () {
                  Navigator.pop(context);
                  _deletePreset(preset);
                }, 
                child: const Text('Delete', style: TextStyle(color: Colors.red))
              ),
            ],
          ),
        );
      },
      child: Container(
        width: 80,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              preset.watermarkType == 'image' ? Icons.image : 
              preset.watermarkType == 'text' ? Icons.text_fields : Icons.person,
              color: _parseColor(preset.textColor),
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              preset.name, 
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
      onTap: () => setState(() => _watermarkType = type),
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
      default:
        return Container();
    }
  }

  Widget _buildPatchingTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Video Patches', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _patches.add(_Patch(x: 0.1, y: 0.1, width: 0.2, height: 0.1));
                  _selectedPatchIndex = _patches.length - 1;
                });
              },
              icon: const Icon(Icons.add_box, size: 18),
              label: const Text('Add Patch'),
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
           const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("No patches added. Use them to mask or highlight areas.", style: TextStyle(color: Colors.grey, fontSize: 13), textAlign: TextAlign.center,))),
        
        if (_selectedPatchIndex != null && _selectedPatchIndex! < _patches.length) ...[
          _buildActivePatchControls(_patches[_selectedPatchIndex!], _selectedPatchIndex!),
        ] else if (_patches.isNotEmpty)
          const Text("Select a patch on preview to edit", style: TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildTextOverlayPreview(_TextOverlay t, int index, BoxConstraints constraints) {
    final scale = constraints.maxWidth / (_fullScreen ? 1080 : _videoWidth);
    final isSelected = _selectedTextOverlayIndex == index && _selectedTabIndex == 8;
    return Positioned(
      left: t.x * constraints.maxWidth,
      top: t.y * constraints.maxHeight,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5), // Center anchoring
        child: GestureDetector(
          onPanStart: (_) => setState(() => _selectedTextOverlayIndex = index),
          onPanUpdate: (d) => setState(() {
            t.x = (t.x + d.delta.dx / constraints.maxWidth).clamp(0.0, 1.0);
            t.y = (t.y + d.delta.dy / constraints.maxHeight).clamp(0.0, 1.0);
          }),
          child: Container(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.8 * t.scale),
            child: Text(
              t.text,
              textAlign: t.textAlign,
              style: TextStyle(
                fontSize: t.fontSize * scale * t.scale,
                color: _parseColor(t.color),
                fontFamily: t.font?.family,
                fontWeight: t.font?.weight,
                fontStyle: t.font?.style,
                shadows: t.showShadow ? [Shadow(
                  color: _parseColor(t.shadowColor), 
                  blurRadius: t.shadowBlur, 
                  offset: Offset(t.shadowOffsetX, t.shadowOffsetY)
                )] : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextOverlayTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
           mainAxisAlignment: MainAxisAlignment.spaceBetween,
           children: [
             const Text('Text Overlays', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
             ElevatedButton.icon(
               onPressed: () {
                 setState(() {
                   _textOverlays.add(_TextOverlay(
                     text: "New Text",
                     font: FontInfo(family: 'Metrophobic', displayName: 'Metrophobic'),
                   ));
                   _selectedTextOverlayIndex = _textOverlays.length - 1;
                 });
               },
               icon: const Icon(Icons.add_comment, size: 18),
               label: const Text('Add Text'),
               style: ElevatedButton.styleFrom(
                 backgroundColor: AppColors.primary, 
                 foregroundColor: Colors.white, 
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
               ),
             )
           ],
        ),
        const SizedBox(height: 12),
        if (_textOverlays.isEmpty) 
           const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("No text overlays added. Use them to place generic text anywhere.", style: TextStyle(color: Colors.grey, fontSize: 13), textAlign: TextAlign.center))),
        
        if (_selectedTextOverlayIndex != null && _selectedTextOverlayIndex! < _textOverlays.length) ...[
          _buildActiveTextOverlayControls(_textOverlays[_selectedTextOverlayIndex!], _selectedTextOverlayIndex!),
        ] else if (_textOverlays.isNotEmpty)
          const Text("Select a text overlay on preview to edit", style: TextStyle(color: Colors.grey, fontSize: 12)),
      ]
    );
  }

  Widget _buildActiveTextOverlayControls(_TextOverlay t, int index) {
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
                   IconButton(onPressed: () => setState(() { _textOverlays.removeAt(index); _selectedTextOverlayIndex = null; }), icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20)),
                 ],
               ),
               TextFormField(
                 initialValue: t.text,
                 maxLines: null,
                 onChanged: (v) => setState(() => t.text = v),
                 decoration: const InputDecoration(labelText: "Text Content", border: OutlineInputBorder(), isDense: true),
               ),
               const SizedBox(height: 16),
                _buildControlSlider(label: "Font Size", value: t.fontSize, min: 10, max: 200, onChanged: (v) => setState(() => t.fontSize = v)),
                _buildControlSlider(label: "Scale", value: t.scale, min: 0.1, max: 5.0, onChanged: (v) => setState(() => t.scale = v)),
               const SizedBox(height: 8),
               const Text("Text Color", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
               const SizedBox(height: 8),
               _buildColorPicker(t.color, (c) => setState(() => t.color = c)),
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
                          onSelected: (_) => setState(() => t.font = f),
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
                   setState(() {
                     if (index == 0) t.textAlign = TextAlign.left;
                     if (index == 1) t.textAlign = TextAlign.center;
                     if (index == 2) t.textAlign = TextAlign.right;
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
               _buildControlSlider(label: "Horizontal Position (X)", value: t.x, min: 0, max: 1, onChanged: (v) => setState(() => t.x = v)),
               _buildControlSlider(label: "Vertical Position (Y)", value: t.y, min: 0, max: 1, onChanged: (v) => setState(() => t.y = v)),
               const SizedBox(height: 8),
               const Divider(height: 32),
               const Text("Shadow Settings", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
               SwitchListTile(title: const Text("Show Drop Shadow", style: TextStyle(fontSize: 13)), value: t.showShadow, onChanged: (v) => setState(() => t.showShadow = v), dense: true, contentPadding: EdgeInsets.zero),
               if (t.showShadow) ...[
                 _buildControlSlider(label: "Shadow Blur", value: t.shadowBlur, min: 0.1, max: 20.0, onChanged: (v) => setState(() => t.shadowBlur = v)),
                 _buildControlSlider(label: "Offset X", value: t.shadowOffsetX, min: -20.0, max: 20.0, onChanged: (v) => setState(() => t.shadowOffsetX = v)),
                 _buildControlSlider(label: "Offset Y", value: t.shadowOffsetY, min: -20.0, max: 20.0, onChanged: (v) => setState(() => t.shadowOffsetY = v)),
                 const SizedBox(height: 8),
                 const Text("Shadow Color", style: TextStyle(fontSize: 12)),
                 const SizedBox(height: 8),
                 _buildColorPicker(t.shadowColor, (c) => setState(() => t.shadowColor = c)),
               ],
             ]
           )
         )
       ]
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
                 subtitle: const Text("Render patch above video frame", style: TextStyle(fontSize: 11)),
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
               _selectedTabIndex = 7; 
             });
          },
          onTap: () => setState(() => _selectedPatchIndex = idx),
          child: Container(
            decoration: BoxDecoration(
              color: _parseColor(p.color).withOpacity(p.opacity),
              borderRadius: BorderRadius.circular(p.radius * (constraints.maxWidth / 1000)),
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
          onPanStart: (_) => setState(() { _selectedImageOverlayIndex = idx; _selectedTabIndex = 9; }),
          onPanUpdate: (d) => setState(() {
            img.x = (img.x + d.delta.dx / constraints.maxWidth).clamp(0.0, 1.0);
            img.y = (img.y + d.delta.dy / constraints.maxHeight).clamp(0.0, 1.0);
          }),
          onTap: () => setState(() { _selectedImageOverlayIndex = idx; _selectedTabIndex = 9; }),
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
          _buildControlSlider(label: "Scale", value: o.scale, min: 0.02, max: 1.0, onChanged: (v) => setState(() => o.scale = v)),
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

  Widget _buildProfileTab() {
    bool showText = _watermarkType == 'profile' || _watermarkType == 'profile_vertical' || _watermarkType == 'text';
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
            controller: TextEditingController(text: _username)..selection = TextSelection.fromPosition(TextPosition(offset: _username.length)),
          ),
          const SizedBox(height: 12),
        ],
        if (showHandle) ...[
          TextField(
            decoration: const InputDecoration(labelText: 'Handle (@name)', border: OutlineInputBorder()),
            onChanged: (v) => setState(() => _handle = v),
            controller: TextEditingController(text: _handle)..selection = TextSelection.fromPosition(TextPosition(offset: _handle.length)),
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
                    Slider(value: _boxOpacity, min: 0, max: 1, onChanged: (v) => setState(() => _boxOpacity = v)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Corner Radius: ${_boxRadius.toInt()}'),
                    Slider(value: _boxRadius, min: 0, max: 100, onChanged: (v) => setState(() => _boxRadius = v)),
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
        Slider(value: _iconSize, min: 40, max: 400, onChanged: (v) => setState(() => _iconSize = v)),
        _buildControlSlider(label: 'Username Size', value: _usernameSize, min: 20, max: 200, onChanged: (v) => setState(() => _usernameSize = v)),
        _buildControlSlider(label: 'Handle Size', value: _handleSize, min: 20, max: 200, onChanged: (v) => setState(() => _handleSize = v)),
        const SizedBox(height: 8),
        Text('Master Scale: ${_watermarkScale.toStringAsFixed(2)}'),
        Slider(value: _watermarkScale, min: 0.5, max: 2.5, onChanged: (v) => setState(() => _watermarkScale = v)),
        const SizedBox(height: 16),
        const Text('Manual Coordinates (Fine-tune)', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _buildControlSlider(label: 'Horizontal Position (X)', value: _watermarkX, min: 0, max: 1, onChanged: (v) => setState(() => _watermarkX = v)),
        _buildControlSlider(label: 'Vertical Position (Y)', value: _watermarkY, min: 0, max: 1, onChanged: (v) => setState(() => _watermarkY = v)),
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
          Slider(value: blur, min: 0, max: 20, onChanged: onBlurChanged),
          const SizedBox(height: 8),
          const SizedBox(height: 12),
          Row(
            children: [
              const SizedBox(width: 4, child: Text('X', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
              Expanded(child: Slider(value: offsetX, min: -15, max: 15, onChanged: onOffsetXChanged)),
              Text(offsetX.toStringAsFixed(1), style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
          Row(
            children: [
              const SizedBox(width: 4, child: Text('Y', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
              Expanded(child: Slider(value: offsetY, min: -15, max: 15, onChanged: onOffsetYChanged)),
              Text(offsetY.toStringAsFixed(1), style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
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

  Widget _buildSettingsTab() {
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
      ],
    );
  }

  Widget _buildPresetsBar() {
    final presets = WatermarkPresetService.getAllPresets();
    
    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade100)),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: presets.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildAddPresetCard();
          }
          final preset = presets[index - 1];
          return _buildPresetCard(preset);
        },
      ),
    );
  }

  Widget _buildAddPresetCard() {
    return GestureDetector(
      onTap: _savePreset,
      child: Container(
        width: 70,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300, style: BorderStyle.none),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.pink.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Colors.pink, size: 24),
            ),
            const SizedBox(height: 6),
            const Text('Save Style', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.pink)),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetCard(WatermarkPreset preset) {
    return GestureDetector(
      onTap: () => _loadPreset(preset),
      onLongPress: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Preset?'),
            content: Text('Remove "${preset.name}" from your saved styles?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              TextButton(
                onPressed: () async {
                  await WatermarkPresetService.deletePreset(preset.id);
                  Navigator.pop(context);
                  setState(() {});
                }, 
                child: const Text('Delete', style: TextStyle(color: Colors.red))
              ),
            ],
          ),
        );
      },
      child: Container(
        width: 70,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _parseColor(preset.textColor).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                preset.watermarkType == 'image' ? Icons.image : 
                preset.watermarkType == 'text' ? Icons.text_fields : Icons.person,
                color: _parseColor(preset.textColor),
                size: 20,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              preset.name, 
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickBgImage() async {
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (image != null) setState(() => _bgImage = File(image.path));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error picking background: $e')));
    }
  }

  Widget _buildVerifiedBadgeWidget(double scale) {
    return Icon(
      Icons.verified,
      color: _parseColor(_verifiedBadgeColor),
      size: _fontSize * 0.8 * scale * 0.9,
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

  Widget _buildControlSlider({required String label, required double value, required double min, required double max, required ValueChanged<double> onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            Text(value.toStringAsFixed(max <= 2 ? 2 : 1), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          onChanged: onChanged,
          activeColor: AppColors.primary,
        ),
      ],
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

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', 'FF'), radix: 16));
    } catch (_) {
      return Colors.white;
    }
  }

  Widget _buildTextOverlayAlignButton(IconData icon, String label, double xValue, _TextOverlay t) {
    final isSelected = (t.x - xValue).abs() < 0.05;
    return InkWell(
      onTap: () => setState(() => t.x = xValue),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.black, size: 18),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 10, color: isSelected ? Colors.white : Colors.black)),
          ],
        ),
      ),
    );
  }

  Widget _buildTextOverlayAlignYButton(IconData icon, String label, double yValue, _TextOverlay t) {
    final isSelected = (t.y - yValue).abs() < 0.05;
    return InkWell(
      onTap: () => setState(() => t.y = yValue),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.black, size: 18),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 10, color: isSelected ? Colors.white : Colors.black)),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }
}
