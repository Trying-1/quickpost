import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:image_picker/image_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import '../../utils/font_selector.dart';
import '../../models/watermark_preset.dart';
import '../../services/watermark_preset_service.dart';

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

  _TextOverlay({
    required this.text,
    this.x = 0.5,
    this.y = 0.5,
    this.fontSize = 50.0,
    this.color = "#FFFFFF",
    this.font,
    this.showShadow = true,
    this.shadowColor = "#000000",
    this.shadowBlur = 8.0,
    this.shadowOffsetX = 2.0,
    this.shadowOffsetY = 2.0,
  });

  Map<String, dynamic> toMap(double videoWidth, double videoHeight, String resolvedFontPath) {
    return {
      'text': text,
      'x': x * videoWidth,
      'y': y * videoHeight,
      'fontSize': fontSize,
      'color': color,
      'fontPath': resolvedFontPath,
      'showShadow': showShadow,
      'shadowColor': shadowColor,
      'shadowBlur': shadowBlur,
      'shadowOffsetX': shadowOffsetX,
      'shadowOffsetY': shadowOffsetY,
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

  List<_Patch> _patches = [];
  int? _selectedPatchIndex;

  List<_TextOverlay> _textOverlays = [];
  int? _selectedTextOverlayIndex;

  // Watermark state
  String _username = "John Doe";
  String _handle = "@johndoe_arise";
  File? _profileImage;
  File? _bgImage;
  double _watermarkX = 0.5; // Normalized
  double _watermarkY = 0.15; // Normalized (TOP)
  double _fontSize = 36.0;
  double _iconSize = 80.0;
  String _textColor = "#FFFFFF";
  String _accentColor = "#AAAAAA";
  FontInfo? _selectedUsernameFont;
  FontInfo? _selectedHandleFont;
  
  String _watermarkType = "profile_vertical"; // Vertical type as default
  bool _fullScreen = true; // Canvas on by default
  String _bgColor = "#000000";
  
   bool _showBox = false;
   String _boxColor = "#000000";
   double _boxOpacity = 0.3;
   double _boxRadius = 12.0;

   bool _showStoryRing = true;
   bool _isVerified = true;

   double _bgBrightness = 1.0;
   double _bgSaturation = 1.0;
   double _bgBlur = 0.0;
    
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

  int _selectedTabIndex = 0;
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
    );
    await WatermarkPresetService.savePreset(preset);
    if (mounted) setState(() {});
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

  @override
  void initState() {
    super.initState();
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

      
      final usernameFontPath = await _getFontPath(_selectedUsernameFont?.family ?? 'Roboto', _selectedUsernameFont?.displayName ?? 'Roboto');
      final handleFontPath = await _getFontPath(_selectedHandleFont?.family ?? _selectedUsernameFont?.family ?? 'Roboto', _selectedHandleFont?.displayName ?? _selectedUsernameFont?.displayName ?? 'Roboto');

      final List<Map<String, dynamic>> resolvedTextOverlays = [];
      for (final t in _textOverlays) {
        final path = await _getFontPath(t.font?.family ?? 'Roboto', t.font?.displayName ?? 'Roboto');
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
        'showStoryRing': _showStoryRing,
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
        'patches': _patches.map((p) => p.toMap((_fullScreen ? 1080 : _videoWidth).toDouble(), (_fullScreen ? 1920 : _videoHeight).toDouble())).toList(),
        'textOverlays': resolvedTextOverlays,
      };

      final result = await platform.invokeMethod<String>('addWatermarkToVideo', params);
      
      _uiUpdateTimer?.cancel();
      _processStopwatch.stop();

      if (mounted) {
        setState(() { 
          _recordStepTiming(""); // Finalize last step
          _isProcessing = false; 
          _outputPath = result; 
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
          if (_progress > 0.05) {
            final totalEstimatedMs = elapsed.inMilliseconds / _progress;
            final remaining = Duration(milliseconds: (totalEstimatedMs - elapsed.inMilliseconds).toInt());
            _remainingTime = _formatDuration(remaining);
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

  Future<String> _getFontPath(String family, String displayName) async {
    // Map font display names to their asset file paths
    const fontAssetMap = {
      'Roboto': 'Roboto-Regular.ttf',
      'Roboto Bold': 'Roboto-Bold.ttf',
      'Roboto Italic': 'Roboto-Italic.ttf',
      'Roboto Bold Italic': 'Roboto-BoldItalic.ttf',
      'Akony': 'akony.ttf',
      'AllertaStencil': 'AllertaStencil-Regular.ttf',
      'AlmendraDisplay': 'AlmendraDisplay-Regular.ttf',
      'Alumni Sans': 'AlumniSans-Regular.ttf',
      'Alumni Sans Bold': 'AlumniSans-Bold.ttf',
      'Alumni Sans Black': 'AlumniSans-Black.ttf',
      'Alumni Sans Light': 'AlumniSans-Light.ttf',
      'Alumni Sans Medium': 'AlumniSans-Medium.ttf',
      'Alumni Sans SemiBold': 'AlumniSans-SemiBold.ttf',
      'Alumni Sans Thin': 'AlumniSans-Thin.ttf',
      'Alumni Sans ExtraLight': 'AlumniSans-ExtraLight.ttf',
      'Alumni Sans ExtraBold': 'AlumniSans-ExtraBold.ttf',
      'Alumni Sans Italic': 'AlumniSans-Italic.ttf',
      'Alumni Sans Pinstripe': 'AlumniSansPinstripe-Regular.ttf',
      'Barrio': 'Barrio-Regular.ttf',
      'Bellota': 'Bellota-Regular.ttf',
      'Bellota Bold': 'Bellota-Bold.ttf',
      'Bellota Light': 'Bellota-Light.ttf',
      'Bellota Italic': 'Bellota-Italic.ttf',
      'BhuTukaExpandedOne': 'BhuTukaExpandedOne-Regular.ttf',
      'Bokor': 'Bokor-Regular.ttf',
      'BungeeHairline': 'BungeeHairline-Regular.ttf',
      'Caramel': 'Caramel-Regular.ttf',
      'Centralwell': 'Centralwell.ttf',
      'ChalkBoard': 'Chalk Board.ttf',
      'Explora': 'Explora-Regular.ttf',
      'GrandifloraOne': 'GrandifloraOne-Regular.ttf',
      'Klee One SemiBold': 'KleeOne-SemiBold.ttf',
      'Lacquer': 'Lacquer-Regular.ttf',
      'LibreBarcode39Text': 'LibreBarcode39Text-Regular.ttf',
      'LuckiestGuy': 'LuckiestGuy-Regular.ttf',
      'MajorMonoDisplay': 'MajorMonoDisplay-Regular.ttf',
      'Metrophobic': 'Metrophobic-Regular.ttf',
      'Michroma': 'Michroma-Regular.ttf',
      'Milker': 'Milker.otf',
      'Modernline': 'modernline.otf',
      'Modernline Bold': 'modernline bold.otf',
      'NCL Neovibes': 'NCLNeovibes-Demo.otf',
      'NewRocker': 'NewRocker-Regular.ttf',
      'NewTegomin': 'NewTegomin-Regular.ttf',
      'Poppins': 'Poppins-Regular.ttf',
      'Poppins Bold': 'Poppins-Bold.ttf',
      'Poppins Black': 'Poppins-Black.ttf',
      'Poppins Light': 'Poppins-Light.ttf',
      'Poppins Medium': 'Poppins-Medium.ttf',
      'Poppins SemiBold': 'Poppins-SemiBold.ttf',
      'Poppins Thin': 'Poppins-Thin.ttf',
      'Poppins ExtraLight': 'Poppins-ExtraLight.ttf',
      'Poppins ExtraBold': 'Poppins-ExtraBold.ttf',
      'Poppins Italic': 'Poppins-Italic.ttf',
      'Protest Revolution': 'ProtestRevolution-Regular.ttf',
      'Religath': 'RELIGATH-Demo.otf',
      'Sour Gummy': 'SourGummy-VariableFont_wdth,wght.ttf',
    };

    final assetFile = fontAssetMap[displayName];
    if (assetFile == null) return '/system/fonts/Roboto-Regular.ttf';

    try {
      final tempDir = await getTemporaryDirectory();
      final targetFile = File('${tempDir.path}/font_$assetFile');
      
      // Cache: skip copy if already exists
      if (await targetFile.exists()) return targetFile.path;

      final byteData = await rootBundle.load('assets/fonts/$assetFile');
      await targetFile.writeAsBytes(byteData.buffer.asUint8List());
      return targetFile.path;
    } catch (e) {
      print('Font copy failed for $family: $e');
      return '/system/fonts/Roboto-Regular.ttf';
    }
  }

  void _showSuccess() {
    showDialog(
      context: context, 
      builder: (c) => AlertDialog(
        title: const Text('Export Complete! 🎉'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your video has been saved to the Gallery.', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('Processing Breakdown:', style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 8),
            ..._stepTimings.entries.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(e.key, style: const TextStyle(fontSize: 12))),
                  Text('${(e.value / 1000).toStringAsFixed(1)}s', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(c);
              OpenFile.open(_outputPath!);
            },
            child: const Text('Open Video')
          ),
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Close')
          )
        ]
      )
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
      color: Colors.black87,
      child: Center(
        child: Container(
          width: 320,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 5,
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                   SizedBox(
                    width: 100,
                    height: 100,
                    child: CircularProgressIndicator(
                      value: _progress,
                      strokeWidth: 8,
                      backgroundColor: Colors.blue.withOpacity(0.1),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  ),
                  Text(
                    '${(_progress * 100).toInt()}%',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              const Text(
                'Watermarking Video',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              Text(
                _status,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[700], fontSize: 15, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 32),
              // Timing Stats
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildTimeInfo("Elapsed", _elapsedTime),
                  const SizedBox(width: 8, child: VerticalDivider()),
                  _buildTimeInfo("Remaining", _remainingTime),
                ],
              ),
              const SizedBox(height: 40),
              // Cancel Button
              TextButton.icon(
                onPressed: _cancelProcess,
                icon: const Icon(Icons.close, color: Colors.redAccent, size: 20),
                label: const Text(
                  'Cancel Process',
                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.redAccent.withOpacity(0.1),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                backgroundColor: Colors.blue,
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

                         Center(
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

                        // Watermark Layer
                        Positioned(
                          left: _watermarkX * constraints.maxWidth,
                          top: _watermarkY * constraints.maxHeight,
                          child: FractionalTranslation(
                            translation: const Offset(-0.5, -0.5),
                            child: _buildWatermarkPreview(constraints.maxWidth / (_fullScreen ? 1080 : _videoWidth)),
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
    switch (_watermarkType) {
      case 'profile_vertical':
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: _showStoryRing ? const EdgeInsets.all(3) : EdgeInsets.zero,
              decoration: _showStoryRing ? BoxDecoration(
                shape: BoxShape.circle,
                gradient: const SweepGradient(
                  colors: [
                    Color(0xFFFCAF45),
                    Color(0xFFF56040),
                    Color(0xFFE1306C),
                    Color(0xFFC13584),
                    Color(0xFFFCAF45),
                  ],
                ),
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
                Text(
                  _username,
                  style: TextStyle(
                    color: _parseColor(_textColor),
                    fontWeight: FontWeight.bold,
                    fontSize: _fontSize * scale,
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _handle,
                      style: TextStyle(
                        color: _parseColor(_accentColor),
                        fontSize: _fontSize * 0.8 * scale,
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
                    if (_isVerified) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.verified, color: Colors.blue, size: _fontSize * 0.8 * scale * 0.9),
                    ],
                  ],
                ),
              ],
            ),
          ],
        );
      case 'profile':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: _showStoryRing ? const EdgeInsets.all(3) : EdgeInsets.zero,
              decoration: _showStoryRing ? BoxDecoration(
                shape: BoxShape.circle,
                gradient: const SweepGradient(
                  colors: [
                    Color(0xFFFCAF45), // Yellow
                    Color(0xFFF56040), // Orange
                    Color(0xFFE1306C), // Magenta
                    Color(0xFFC13584), // Purple
                    Color(0xFFFCAF45), // Close
                  ],
                ),
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
                Text(
                  _username,
                  style: TextStyle(
                    color: _parseColor(_textColor),
                    fontWeight: FontWeight.bold,
                    fontSize: _fontSize * scale,
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _handle,
                      style: TextStyle(
                        color: _parseColor(_accentColor),
                        fontSize: _fontSize * 0.8 * scale,
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
                    if (_isVerified) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.verified, color: Colors.blue, size: _fontSize * 0.8 * scale * 0.9),
                    ],
                  ],
                ),
              ],
            ),
          ],
        );
      case 'text':
        return Text(
          _username,
          style: TextStyle(
            color: _parseColor(_textColor),
            fontWeight: FontWeight.bold,
            fontSize: _fontSize * scale,
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
                backgroundColor: Colors.blue,
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
                _buildTabItem(-1, Icons.add_to_photos, 'Import', Colors.blue, customOnTap: _pickVideo),
                _buildTabItem(6, Icons.stars, 'Presets', Colors.pink),
                _buildTabItem(0, Icons.branding_watermark, 'Type', Colors.amber),
                _buildTabItem(1, Icons.edit_note, 'Content', Colors.indigo),
                _buildTabItem(8, Icons.text_fields, 'Texts', Colors.deepPurple),
                _buildTabItem(2, Icons.open_with, 'Position', Colors.blue),
                _buildTabItem(3, Icons.palette, 'Style', Colors.deepOrange),
                _buildTabItem(4, Icons.font_download, 'Fonts', Colors.teal),
                _buildTabItem(7, Icons.layers, 'Patching', Colors.pink),
                _buildTabItem(5, Icons.video_settings, 'Canvas', Colors.purple),
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
              _buildTypeChip('text', 'Minimal', 'Text Only'),
              _buildTypeChip('image', 'Logo', 'Image Only'),
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
          border: Border.all(color: isSelected ? Colors.blue : Colors.grey.shade200, width: isSelected ? 2 : 1),
          boxShadow: isSelected ? [BoxShadow(color: Colors.blue.withOpacity(0.1), blurRadius: 10)] : null,
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
    switch (type) {
      case 'profile':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(radius: 6, backgroundColor: Colors.blueAccent),
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
            CircleAvatar(radius: 8, backgroundColor: Colors.blueAccent),
            SizedBox(height: 4),
            Text('Username', style: TextStyle(fontSize: 5, fontWeight: FontWeight.bold, color: Colors.black54)),
            Text('@handle', style: TextStyle(fontSize: 4, color: Colors.black38)),
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
      child: GestureDetector(
        onPanStart: (_) => setState(() => _selectedTextOverlayIndex = index),
        onPanUpdate: (d) => setState(() {
          t.x = (t.x + d.delta.dx / constraints.maxWidth).clamp(0.0, 1.0);
          t.y = (t.y + d.delta.dy / constraints.maxHeight).clamp(0.0, 1.0);
        }),
        child: Container(
          padding: const EdgeInsets.all(4),
          child: Text(
            t.text,
            style: TextStyle(
              fontSize: t.fontSize * scale,
              color: _parseColor(t.color),
              fontFamily: t.font?.family,
              shadows: t.showShadow ? [Shadow(
                color: _parseColor(t.shadowColor), 
                blurRadius: t.shadowBlur, 
                offset: Offset(t.shadowOffsetX, t.shadowOffsetY)
              )] : null,
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
                   _textOverlays.add(_TextOverlay(text: "New Text"));
                   _selectedTextOverlayIndex = _textOverlays.length - 1;
                 });
               },
               icon: const Icon(Icons.add_comment, size: 18),
               label: const Text('Add Text'),
               style: ElevatedButton.styleFrom(
                 backgroundColor: Colors.deepPurple, 
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
                 onChanged: (v) => setState(() => t.text = v),
                 decoration: const InputDecoration(labelText: "Text Content", border: OutlineInputBorder(), isDense: true),
               ),
               const SizedBox(height: 16),
               _buildControlSlider(label: "Font Size", value: t.fontSize, min: 10, max: 200, onChanged: (v) => setState(() => t.fontSize = v)),
               const SizedBox(height: 8),
               const Text("Text Color", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
               const SizedBox(height: 8),
               _buildColorPicker((c) => setState(() => t.color = c)),
               const SizedBox(height: 16),
               const Text("Font Style", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
               const SizedBox(height: 8),
               SizedBox(
                 height: 48, 
                 child: ListView(
                   scrollDirection: Axis.horizontal, 
                   children: getAllFonts().map((f) => Padding(
                     padding: const EdgeInsets.only(right: 8), 
                     child: ChoiceChip(
                       label: Text(f.displayName, style: TextStyle(fontFamily: f.family, fontSize: 12, color: t.font?.family == f.family ? Colors.white : Colors.black87)), 
                       selected: t.font?.family == f.family, 
                       showCheckmark: false,
                       selectedColor: Colors.deepPurple,
                       onSelected: (_) => setState(() => t.font = f)
                     )
                   )).toList()
                 )
               ),
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
                 _buildColorPicker((c) => setState(() => t.shadowColor = c)),
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
               _buildColorPicker((c) => setState(() => p.color = c)),
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
          _buildColorPicker((c) => setState(() => _boxColor = c)),
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
          subtitle: const Text("Purple-Orange IG gradient circle", style: TextStyle(fontSize: 12)),
          value: _showStoryRing,
          onChanged: (v) => setState(() => _showStoryRing = v),
          secondary: const Icon(Icons.circle_outlined, color: Colors.purple),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
        SwitchListTile(
          title: const Text("Verified Badge", style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text("Blue tick next to display name", style: TextStyle(fontSize: 12)),
          value: _isVerified,
          onChanged: (v) => setState(() => _isVerified = v),
          secondary: const Icon(Icons.verified, color: Colors.blue),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
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
        Text('Font Size: ${_fontSize.toInt()}'),
        Slider(value: _fontSize, min: 20, max: 200, onChanged: (v) => setState(() => _fontSize = v)),
        const SizedBox(height: 16),
        const Text('Manual Coordinates (Fine-tune)', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
        Row(
          children: [
            const Text('X'),
            Expanded(child: Slider(value: _watermarkX, min: 0, max: 1, onChanged: (v) => setState(() => _watermarkX = v))),
            const Text('Y'),
            Expanded(child: Slider(value: _watermarkY, min: 0, max: 1, onChanged: (v) => setState(() => _watermarkY = v))),
          ],
        ),
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
          color: isSelected ? Colors.blue : Colors.grey.shade100,
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
          color: isSelected ? Colors.blue : Colors.grey.shade100,
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
                _buildColorPicker((c) => setState(() => _textColor = c)),
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
                _buildColorPicker((c) => setState(() => _accentColor = c)),
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
                color: isSelected ? Colors.blue : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? Colors.blue : Colors.grey, size: 18),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: isSelected ? Colors.blue : Colors.grey,
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
          _buildColorPicker(onColorChanged),
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
        Icon(icon, size: 20, color: Colors.blue),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue),
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
                  ? _selectedUsernameFont?.displayName == font.displayName
                  : _selectedHandleFont?.displayName == font.displayName;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(
                    font.displayName,
                    style: TextStyle(
                      fontFamily: font.family,
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
                  selectedColor: Colors.blue,
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
            color: isSelected ? Colors.blue.withOpacity(0.05) : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: isSelected ? Colors.blue : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? Colors.blue : Colors.grey, size: 14),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.blue : Colors.grey,
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
              onChanged: (v) => setState(() => _fullScreen = v)
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
             _buildColorPicker((c) => setState(() => _bgColor = c)),
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
               max: 50.0,
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

  Widget _buildControlSlider({required String label, required double value, required double min, required double max, required ValueChanged<double> onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            Text(value.toStringAsFixed(1), style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          onChanged: onChanged,
          activeColor: Colors.blue,
        ),
      ],
    );
  }

  Widget _buildColorPicker(Function(String) onPick) {
    final colors = ['#FFFFFF', '#000000', '#FFD700', '#FF4444', '#00E676', '#2979FF', '#FF4081', '#AA00FF'];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: colors.map((c) => GestureDetector(
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
      )).toList(),
    );
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', 'FF'), radix: 16));
    } catch (_) {
      return Colors.white;
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }
}
