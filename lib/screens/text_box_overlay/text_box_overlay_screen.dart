import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:image_picker/image_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:get_thumbnail_video/index.dart';
import 'package:get_thumbnail_video/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import '../video_creator/widgets/duration_selector_widget.dart';
import '../video_creator/widgets/audio_selector_widget.dart';
import '../../services/analytics_service.dart';
import '../../services/ad_service.dart';
import '../../utils/font_selector.dart';
import '../../config/app_theme.dart';
import '../../widgets/advanced_color_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';
import '../../utils/watermark_settings.dart';

class TextBoxOverlayScreen extends StatefulWidget {
  final List<String>? sharedImagePaths;
  final bool isActive;

  const TextBoxOverlayScreen({Key? key, this.sharedImagePaths, this.isActive = true}) : super(key: key);

  @override
  State<TextBoxOverlayScreen> createState() => _TextBoxOverlayScreenState();
}

class _TextBoxOverlayScreenState extends State<TextBoxOverlayScreen> with WidgetsBindingObserver {
  File? _selectedAudio;
  String? _audioDuration;
  bool _isPlayingAudio = false;

  static const platform = MethodChannel('com.quickpost.app/processor');
  
  // State
  File? _selectedVideo;
  File? _selectedImage;
  String? _thumbnailPath;
  VideoPlayerController? _videoController;
  double _videoAspectRatio = 16 / 9;
  int _videoWidth = 1080;
  int _videoHeight = 1920;
  bool _isProcessing = false;
  bool _isMuted = false;
  bool _showControls = true;
  double _progress = 0.0;
  String? _outputPath;
  Timer? _progressTimer;
  String _status = "Processing video...";
  String _elapsedTime = "00:00";
  String _remainingTime = "--:--";
  final Stopwatch _processStopwatch = Stopwatch();
  int _inputFileSize = 0;
  int _outputFileSize = 0;
  
  // Canvas Settings (9:16, 1:1, or original)
  bool _fullScreen = false;
  bool _forceSquare = false;
  File? _bgImage;
  List<XFile> _gridImages = [];
  int _gridColumns = 2;
  double _gridGap = 0.0;
  String _gridGapColor = "#FFFFFF";
  final List<String> _gridHistory = [];
  Map<String, Map<String, dynamic>> _bgLayoutConfigs = {};
  Timer? _gridDebounce;
  String _bgColor = "#FFFFFF";
  double _bgBrightness = 1.0;
  double _bgSaturation = 1.0;
  double _bgBlur = 0.0;
  double _videoX = 0.5;
  double _videoY = 0.5;
  double _videoScale = 1.0;
  double _videoRadius = 0.0;
  double _videoBorderWidth = 0.0;
  String _videoBorderColor = "#FFFFFF";
  bool _showVideoShadow = false;
  String _videoShadowColor = "#000000";
  double _videoShadowBlur = 10.0;
  double _videoShadowSpread = 0.0;
  double _videoShadowOffsetX = 0.0;
  double _videoShadowOffsetY = 0.0;
  int _canvasSubTab = 0; // 0: Background, 1: Video
  int _selectedColorSubTab = 0; // 0: Text, 1: Box, 2: Highlight
  
  // Image to Video settings
  int _imageDuration = 8; // default to 8s if no audio
  double _fadeInDuration = 1.0;
  String _imageTransition = 'none'; // 'none' or 'fade'
  bool _isImageInput = false;

  // Audio settings
  double _audioVolume = 1.0;
  bool _loopAudio = true;
  
  // Tab state
  int _selectedTabIndex = 0; // 0 Text, 1 Font, 2 Colors, 3 Position, 4 Settings, 5 Video
  bool _isTabContentExpanded = false;
  
  // Text box settings
  String _textContent = "Your text here...";
  FontInfo? _selectedFont;
  double _fontSize = 40.0;
  double _boxHeight = 80.0;
  double _userBoxHeight = 80.0;
  List<double> _heightPresets = [80.0, 120.0, 160.0, 220.0];
  String _textColor = "#000000"; // default black
  double _textOpacity = 1.0;
  String _boxColor = "#FFFFFF";  // default white
  double _boxOpacity = 1.0;
  String _boxStyle = 'plain'; // 'plain' or 'paper_cut'
  
  double _paperCutRoughness = 15.0;
  int _paperCutSeed = 42;
  double _paperCutShadowAmount = 16.0;
  String _paperCutShadowColor = "#000000";

  bool _showTextShadow = false;
  double _shadowX = 2.0;
  double _shadowY = 2.0;
  String _shadowColor = "#000000";

  String _textBoxPosition = 'top'; // 'top' or 'bottom'
  double _horizontalPadding = 12.0;
  double _verticalPadding = 8.0;
  double _textScale = 1.0;
  String _hAlign = 'center'; // 'left', 'center', 'right'
  String _vAlign = 'middle'; // 'top', 'middle', 'bottom'
  double _lineHeight = 1.2;
  
  // Encoding settings
  String _preset = 'veryfast';
  double _crf = 23.0;
  bool _addOutro = false;
  
  Map<int, String> _wordColors = {};
  Map<int, String> _wordBgColors = {};
  String _highlightType = 'marker'; // 'marker' (background) or 'text' (foreground)
  Set<int> _selectedWordIndices = {};
  
  List<String> _videoHistory = [];
  Map<String, String> _videoThumbnails = {};
  Timer? _periodicSaveTimer;

  // Controllers
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _textColorController = TextEditingController();
  final TextEditingController _boxColorController = TextEditingController();
  final TextEditingController _paperCutShadowColorController = TextEditingController();

  final Map<String, String> _fontFileCache = {};


  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadVideoHistory();
    _loadGridHistory();
    _selectedFont = FontInfo(family: 'Poppins-SemiBold', displayName: 'Poppins SemiBold', weight: FontWeight.w600, assetPath: 'assets/fonts/Poppins-SemiBold.ttf');
    
    _loadAutoSavedSettings();
    _setupMethodCallHandler();
    _handleSharedImages();
    AnalyticsService().setCurrentScreen(screenName: 'Text Box Overlay');
    
    _periodicSaveTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _autoSaveCurrentSettings();
    });
  }

  Future<void> _loadGridHistory() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final gridsDir = Directory('${dir.path}/grids');
      if (await gridsDir.exists()) {
        final List<FileSystemEntity> entities = gridsDir.listSync().toList();
        entities.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
        if (mounted) {
          setState(() {
            _gridHistory.clear();
            _gridHistory.addAll(entities
                .where((e) => e is File && (e.path.endsWith('.png') || e.path.endsWith('.jpg') || e.path.endsWith('.jpeg')))
                .map((e) => e.path)
                .toList());
          });
        }
      }
    } catch (e) {
      debugPrint('[TextBoxOverlay] Error loading grid history: $e');
    }
  }

  Future<void> _loadVideoHistory() async {
    final dir = await getApplicationDocumentsDirectory();
    final videosDir = Directory('${dir.path}/recent_videos');
    if (await videosDir.exists()) {
      final List<FileSystemEntity> entities = videosDir.listSync().toList();
      entities.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
      
      final List<String> videos = [];
      final Map<String, String> thumbs = {};
      for (var entity in entities) {
        if (entity.path.endsWith('.mp4') || entity.path.endsWith('.mov') || entity.path.endsWith('.mkv')) {
          videos.add(entity.path);
          final thumbPath = entity.path.replaceAll(RegExp(r'\.(mp4|mov|mkv)$'), '.jpg');
          if (File(thumbPath).existsSync()) {
            thumbs[entity.path] = thumbPath;
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _videoHistory = videos;
          _videoThumbnails = thumbs;
        });
      }
    }
  }

  Future<void> _addToVideoHistory(String path) async {
    if (_videoHistory.contains(path)) return; // Already in history, maybe just imported from history
    
    final dir = await getApplicationDocumentsDirectory();
    final videosDir = Directory('${dir.path}/recent_videos');
    if (!await videosDir.exists()) await videosDir.create(recursive: true);
    
    final fileName = 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final savedVideoPath = '${videosDir.path}/$fileName';
    await File(path).copy(savedVideoPath);
    
    final XFile thumbX = await VideoThumbnail.thumbnailFile(
      video: savedVideoPath,
      thumbnailPath: videosDir.path,
      imageFormat: ImageFormat.JPEG,
      maxWidth: 512,
      quality: 50,
    );
    
    final thumbPath = thumbX.path;
    final savedThumbPath = savedVideoPath.replaceAll('.mp4', '.jpg');
    if (thumbPath.isNotEmpty) {
      await File(thumbPath).rename(savedThumbPath);
    }
    
    if (mounted) {
      setState(() {
        _videoHistory.insert(0, savedVideoPath);
        _videoThumbnails[savedVideoPath] = savedThumbPath;
      });
    }
  }

  Future<void> _loadAutoSavedSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey('textbox_textContent')) {
        setState(() {
          _textContent = prefs.getString('textbox_textContent') ?? "YOUR TEXT HERE";
          final fontFam = prefs.getString('textbox_fontFamily');
          if (fontFam != null) {
            _selectedFont = getAllFonts().firstWhere(
              (f) => f.family == fontFam, 
              orElse: () => const FontInfo(family: 'Poppins-SemiBold', displayName: 'Poppins SemiBold', weight: FontWeight.w600, assetPath: 'assets/fonts/Poppins-SemiBold.ttf')
            );
          }
          _fontSize = prefs.getDouble('textbox_fontSize') ?? 40.0;
          _textColor = prefs.getString('textbox_textColor') ?? "#000000";
          _textOpacity = (prefs.getDouble('textbox_textOpacity') ?? 1.0).clamp(0.0, 1.0);
          _boxColor = prefs.getString('textbox_boxColor') ?? "#FFFFFF";
          _boxOpacity = prefs.getDouble('textbox_boxOpacity') ?? 1.0;
          _boxStyle = prefs.getString('textbox_boxStyle') ?? 'plain';
          _paperCutRoughness = prefs.getDouble('textbox_paperCutRoughness') ?? 15.0;
          _paperCutSeed = prefs.getInt('textbox_paperCutSeed') ?? 42;
          _paperCutShadowAmount = prefs.getDouble('textbox_paperCutShadowAmount') ?? 16.0;
          _paperCutShadowColor = prefs.getString('textbox_paperCutShadowColor') ?? "#000000";
          _showTextShadow = prefs.getBool('textbox_showTextShadow') ?? false;
          _shadowX = prefs.getDouble('textbox_shadowX') ?? 2.0;
          _shadowY = prefs.getDouble('textbox_shadowY') ?? 2.0;
          _shadowColor = prefs.getString('textbox_shadowColor') ?? "#000000";
          _textBoxPosition = prefs.getString('textbox_textBoxPosition') ?? 'top';
          _horizontalPadding = prefs.getDouble('textbox_horizontalPadding') ?? 12.0;
          _verticalPadding = prefs.getDouble('textbox_verticalPadding') ?? 8.0;
          _textScale = prefs.getDouble('textbox_textScale') ?? 1.0;
          _hAlign = prefs.getString('textbox_hAlign') ?? 'center';
          _vAlign = prefs.getString('textbox_vAlign') ?? 'middle';
          _lineHeight = prefs.getDouble('textbox_lineHeight') ?? 1.2;
          _preset = prefs.getString('textbox_preset') ?? 'veryfast';
          _crf = prefs.getDouble('textbox_crf') ?? 23.0;
          _addOutro = prefs.getBool('textbox_addOutro') ?? false;
          
          final wcStr = prefs.getString('textbox_wordColors');
          if (wcStr != null) {
            try {
              final Map<String, dynamic> wcMap = json.decode(wcStr);
              _wordColors = wcMap.map((key, value) => MapEntry(int.parse(key), value as String));
            } catch (_) {}
          }
          final wbgStr = prefs.getString('textbox_wordBgColors');
          if (wbgStr != null) {
            try {
              final Map<String, dynamic> wbgMap = json.decode(wbgStr);
              _wordBgColors = wbgMap.map((key, value) => MapEntry(int.parse(key), value as String));
            } catch (_) {}
          }

          _fullScreen = prefs.getBool('textbox_fullScreen') ?? false;
          _forceSquare = prefs.getBool('textbox_forceSquare') ?? false;
          _bgColor = prefs.getString('textbox_bgColor') ?? "#FFFFFF";
          _bgBrightness = prefs.getDouble('textbox_bgBrightness') ?? 1.0;
          _bgSaturation = prefs.getDouble('textbox_bgSaturation') ?? 1.0;
          _bgBlur = prefs.getDouble('textbox_bgBlur') ?? 0.0;
          _videoX = prefs.getDouble('textbox_videoX') ?? 0.5;
          _videoY = prefs.getDouble('textbox_videoY') ?? 0.5;
          _videoScale = prefs.getDouble('textbox_videoScale') ?? 1.0;
          _videoRadius = prefs.getDouble('textbox_videoRadius') ?? 0.0;
          _videoBorderWidth = prefs.getDouble('textbox_videoBorderWidth') ?? 0.0;
          _videoBorderColor = prefs.getString('textbox_videoBorderColor') ?? "#FFFFFF";
          _showVideoShadow = prefs.getBool('textbox_showVideoShadow') ?? false;
          _videoShadowColor = prefs.getString('textbox_videoShadowColor') ?? "#000000";
          _videoShadowBlur = prefs.getDouble('textbox_videoShadowBlur') ?? 10.0;
          _videoShadowSpread = prefs.getDouble('textbox_videoShadowSpread') ?? 0.0;
          _videoShadowOffsetX = prefs.getDouble('textbox_videoShadowOffsetX') ?? 0.0;
          _videoShadowOffsetY = prefs.getDouble('textbox_videoShadowOffsetY') ?? 0.0;
          final bgConfigsStr = prefs.getString('textbox_bg_layout_configs');
          if (bgConfigsStr != null) {
            try {
              final Map<String, dynamic> decoded = json.decode(bgConfigsStr);
              _bgLayoutConfigs = decoded.map((k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)));
            } catch (_) {}
          }

          final bgImgPath = prefs.getString('textbox_bgImagePath');
          if (bgImgPath != null && File(bgImgPath).existsSync()) {
            _bgImage = File(bgImgPath);
            _applyBgLayoutForImage(bgImgPath);
          }
          _gridColumns = prefs.getInt('textbox_gridColumns') ?? 2;
          _gridGap = prefs.getDouble('textbox_gridGap') ?? 0.0;
          _gridGapColor = prefs.getString('textbox_gridGapColor') ?? "#FFFFFF";
          final gridPaths = prefs.getStringList('textbox_gridImagePaths');
          if (gridPaths != null && gridPaths.isNotEmpty) {
            final valid = gridPaths.where((p) => File(p).existsSync()).toList();
            _gridImages = valid.map((p) => XFile(p)).toList();
          }
          
          final savedPresets = prefs.getStringList('textbox_height_presets');
          if (savedPresets != null && savedPresets.isNotEmpty) {
            final parsed = savedPresets.map((e) => double.tryParse(e)).whereType<double>().take(4).toList();
            if (parsed.length == 4) {
              _heightPresets = parsed;
            }
          }
          
          _textController.text = _textContent;
          _userBoxHeight = prefs.getDouble('textbox_userBoxHeight') ?? prefs.getDouble('textbox_boxHeight') ?? 80.0;
          _boxHeight = math.max(_userBoxHeight, _calculateDynamicBoxHeight(text: _textContent));
          _textColorController.text = _textColor.replaceFirst('#', '');
          _boxColorController.text = _boxColor.replaceFirst('#', '');
          _paperCutShadowColorController.text = _paperCutShadowColor.replaceFirst('#', '');
        });
      } else {
        _textController.text = _textContent;
        _userBoxHeight = 80.0;
        _boxHeight = math.max(_userBoxHeight, _calculateDynamicBoxHeight(text: _textContent));
        _textColorController.text = _textColor.replaceFirst('#', '');
        _boxColorController.text = _boxColor.replaceFirst('#', '');
        _paperCutShadowColorController.text = _paperCutShadowColor.replaceFirst('#', '');
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  Future<void> _autoSaveCurrentSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('textbox_textContent', _textContent);
      if (_selectedFont != null) await prefs.setString('textbox_fontFamily', _selectedFont!.family);
      await prefs.setDouble('textbox_fontSize', _fontSize);
      await prefs.setDouble('textbox_boxHeight', _boxHeight);
      await prefs.setDouble('textbox_userBoxHeight', _userBoxHeight);
      await prefs.setStringList('textbox_height_presets', _heightPresets.map((e) => e.toString()).toList());
      await prefs.setString('textbox_textColor', _textColor);
      await prefs.setDouble('textbox_textOpacity', _textOpacity);
      await prefs.setString('textbox_boxColor', _boxColor);
      await prefs.setDouble('textbox_boxOpacity', _boxOpacity);
      await prefs.setString('textbox_boxStyle', _boxStyle);
      await prefs.setDouble('textbox_paperCutRoughness', _paperCutRoughness);
      await prefs.setInt('textbox_paperCutSeed', _paperCutSeed);
      await prefs.setDouble('textbox_paperCutShadowAmount', _paperCutShadowAmount);
      await prefs.setString('textbox_paperCutShadowColor', _paperCutShadowColor);
      await prefs.setBool('textbox_showTextShadow', _showTextShadow);
      await prefs.setDouble('textbox_shadowX', _shadowX);
      await prefs.setDouble('textbox_shadowY', _shadowY);
      await prefs.setString('textbox_shadowColor', _shadowColor);
      await prefs.setString('textbox_textBoxPosition', _textBoxPosition);
      await prefs.setDouble('textbox_horizontalPadding', _horizontalPadding);
      await prefs.setDouble('textbox_verticalPadding', _verticalPadding);
      await prefs.setDouble('textbox_textScale', _textScale);
      await prefs.setString('textbox_hAlign', _hAlign);
      await prefs.setString('textbox_vAlign', _vAlign);
      await prefs.setDouble('textbox_lineHeight', _lineHeight);
      await prefs.setString('textbox_preset', _preset);
      await prefs.setDouble('textbox_crf', _crf);
      await prefs.setBool('textbox_addOutro', _addOutro);
      
      final wcMap = _wordColors.map((key, value) => MapEntry(key.toString(), value));
      await prefs.setString('textbox_wordColors', json.encode(wcMap));
      final wbgMap = _wordBgColors.map((key, value) => MapEntry(key.toString(), value));
      await prefs.setString('textbox_wordBgColors', json.encode(wbgMap));

      await prefs.setBool('textbox_fullScreen', _fullScreen);
      await prefs.setBool('textbox_forceSquare', _forceSquare);
      await prefs.setString('textbox_bgColor', _bgColor);
      await prefs.setDouble('textbox_bgBrightness', _bgBrightness);
      await prefs.setDouble('textbox_bgSaturation', _bgSaturation);
      await prefs.setDouble('textbox_bgBlur', _bgBlur);
      await prefs.setDouble('textbox_videoX', _videoX);
      await prefs.setDouble('textbox_videoY', _videoY);
      await prefs.setDouble('textbox_videoScale', _videoScale);
      await prefs.setDouble('textbox_videoRadius', _videoRadius);
      await prefs.setDouble('textbox_videoBorderWidth', _videoBorderWidth);
      await prefs.setString('textbox_videoBorderColor', _videoBorderColor);
      await prefs.setBool('textbox_showVideoShadow', _showVideoShadow);
      await prefs.setString('textbox_videoShadowColor', _videoShadowColor);
      await prefs.setDouble('textbox_videoShadowBlur', _videoShadowBlur);
      await prefs.setDouble('textbox_videoShadowSpread', _videoShadowSpread);
      await prefs.setDouble('textbox_videoShadowOffsetX', _videoShadowOffsetX);
      await prefs.setDouble('textbox_videoShadowOffsetY', _videoShadowOffsetY);
      if (_bgImage != null) {
        await prefs.setString('textbox_bgImagePath', _bgImage!.path);
      } else {
        await prefs.remove('textbox_bgImagePath');
      }
      await prefs.setInt('textbox_gridColumns', _gridColumns);
      await prefs.setDouble('textbox_gridGap', _gridGap);
      await prefs.setString('textbox_gridGapColor', _gridGapColor);
      final gridPaths = _gridImages.map((e) => e.path).toList();
      await prefs.setStringList('textbox_gridImagePaths', gridPaths);

      _saveCurrentBgLayout();
      await prefs.setString('textbox_bg_layout_configs', json.encode(_bgLayoutConfigs));
    } catch (e) {
      // Ignore
    }
  }

  void _saveCurrentBgLayout() {
    if (_bgImage != null) {
      _bgLayoutConfigs[_bgImage!.path] = {
        'videoScale': _videoScale,
        'videoX': _videoX,
        'videoY': _videoY,
        'videoRadius': _videoRadius,
        'videoBorderWidth': _videoBorderWidth,
        'videoBorderColor': _videoBorderColor,
      };
    }
  }

  void _applyBgLayoutForImage(String imagePath) {
    final config = _bgLayoutConfigs[imagePath];
    if (config != null) {
      if (config['videoScale'] != null) _videoScale = (config['videoScale'] as num).toDouble();
      if (config['videoX'] != null) _videoX = (config['videoX'] as num).toDouble();
      if (config['videoY'] != null) _videoY = (config['videoY'] as num).toDouble();
      if (config['videoRadius'] != null) _videoRadius = (config['videoRadius'] as num).toDouble();
      if (config['videoBorderWidth'] != null) _videoBorderWidth = (config['videoBorderWidth'] as num).toDouble();
      if (config['videoBorderColor'] != null) _videoBorderColor = config['videoBorderColor'] as String;
    }
  }

  double _calculateDynamicBoxHeight({required String text}) {
    if (text.trim().isEmpty) return 40.0;
    final normalized = text.replaceAll('\r\n', '\n');
    final String measureText = normalized.endsWith('\n') ? '$normalized ' : normalized;
    
    // Create a TextPainter to measure the text with wrapping
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: measureText,
        style: TextStyle(
          fontSize: _fontSize * _textScale,
          height: _lineHeight,
          fontFamily: _selectedFont?.family,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: _hAlign == 'left' ? TextAlign.left : (_hAlign == 'right' ? TextAlign.right : TextAlign.center),
    );

    // Use a fixed width for the calculation. 
    // Since _videoWidth is the actual resolution, we use it minus padding.
    final double horizontalPaddingTotal = (_horizontalPadding + 12) * 2;
    final double availableWidth = (_videoWidth.toDouble() - horizontalPaddingTotal).clamp(100.0, 2000.0);
    
    textPainter.layout(maxWidth: availableWidth);
    
    final contentHeight = textPainter.height;
    final paddingHeight = _verticalPadding * 2;
    final height = contentHeight + paddingHeight;

    if (height < 40.0) return 40.0;
    if (height > 600.0) return 600.0; // Increased max height to allow more text
    return height;
  }

  void _recomputeBoxHeightForText() {
    final next = math.max(_userBoxHeight, _calculateDynamicBoxHeight(text: _textContent));
    if ((next - _boxHeight).abs() < 0.1) return;
    setState(() {
      _boxHeight = next;
    });
  }

  @override
  void didUpdateWidget(covariant TextBoxOverlayScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sharedImagePaths != oldWidget.sharedImagePaths) {
      _handleSharedImages();
    }
    if (!widget.isActive && oldWidget.isActive) {
      _pauseVideo();
    }
  }

  void _pauseVideo() {
    if (mounted && _videoController != null && _videoController!.value.isPlaying) {
      _videoController!.pause();
      setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _pauseVideo();
    }
  }

  void _handleSharedImages() {
    debugPrint('[TextBoxOverlay] _handleSharedImages called: paths=${widget.sharedImagePaths}');
    if (widget.sharedImagePaths != null && widget.sharedImagePaths!.isNotEmpty) {
      final path = widget.sharedImagePaths!.first;
      final file = File(path);
      debugPrint('[TextBoxOverlay] Processing file: $path, exists: ${file.existsSync()}');
      if (file.existsSync()) {
        final isVideo = path.toLowerCase().endsWith('.mp4') || 
                        path.toLowerCase().endsWith('.mov') || 
                        path.toLowerCase().endsWith('.mkv');
        
        setState(() {
          if (isVideo) {
            _selectedVideo = file;
            _selectedImage = null;
            _isImageInput = false;
            _thumbnailPath = null;
            _initializeVideoPlayer(file);
            _fetchVideoMetadata(path);
            _generateThumbnail(path);
          } else {
            _selectedImage = file;
            _selectedVideo = null;
            _isImageInput = true;
            _thumbnailPath = path;
            _fetchImageMetadata(path);
          }
          debugPrint('[TextBoxOverlay] Input set: isVideo=$isVideo, path=${file.path}');
        });
      } else {
        debugPrint('[TextBoxOverlay] ERROR: File does not exist at path: $path');
        if (path.startsWith('content://')) {
          debugPrint('[TextBoxOverlay] Path appears to be a content URI, which might be why File.existsSync() failed.');
        }
      }
    } else {
      debugPrint('[TextBoxOverlay] No shared image paths provided.');
    }
  }

  Future<void> _fetchImageMetadata(String imagePath) async {
    try {
      final data = await File(imagePath).readAsBytes();
      final image = await decodeImageFromList(data);
      setState(() {
        _videoWidth = image.width;
        _videoHeight = image.height;
        _videoAspectRatio = image.width / image.height;
      });
      debugPrint('[TextBoxOverlay] Image dimensions: ${_videoWidth}x${_videoHeight}');
    } catch (e) {
      debugPrint('[TextBoxOverlay] Error fetching image metadata: $e');
    }
  }

  Future<String> _getSelectedFontPath() async {
    if (_selectedFont == null) return '/system/fonts/Roboto-Regular.ttf';
    
    final cached = _fontFileCache[_selectedFont!.family];
    if (cached != null) return cached;

    final path = await FontInfo.getFontFilePath(_selectedFont!);
    _fontFileCache[_selectedFont!.family] = path;
    return path;
  }
  
  @override
  void dispose() {
    _periodicSaveTimer?.cancel();
    _autoSaveCurrentSettings();
    WidgetsBinding.instance.removeObserver(this);
    _progressTimer?.cancel();
    _textController.dispose();
    _textColorController.dispose();
    _boxColorController.dispose();
    _paperCutShadowColorController.dispose();
    _videoController?.dispose();
    super.dispose();
  }
  
  void _setupMethodCallHandler() {
    platform.setMethodCallHandler((call) async {
      if (!mounted) return;
      switch (call.method) {
        case 'onProgress':
          setState(() {
            _progress = (call.arguments as num).toDouble();
          });
          break;
        case 'onStep':
          setState(() {
            _status = call.arguments as String;
          });
          break;
        case 'onAudioComplete':
          setState(() {
            _isPlayingAudio = false;
          });
          break;
      }
    });
  }
  
  Future<void> _selectVideo() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? media = await showModalBottomSheet<XFile?>(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.movie_outlined),
                title: const Text('Select Video'),
                onTap: () async {
                  final video = await picker.pickVideo(source: ImageSource.gallery);
                  Navigator.pop(context, video);
                },
              ),
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: const Text('Select Image'),
                onTap: () async {
                  final image = await picker.pickImage(source: ImageSource.gallery);
                  Navigator.pop(context, image);
                },
              ),
            ],
          ),
        ),
      );
      
      if (media != null) {
        final path = media.path;
        final isVideo = path.toLowerCase().endsWith('.mp4') || 
                        path.toLowerCase().endsWith('.mov') || 
                        path.toLowerCase().endsWith('.mkv');
        
        setState(() {
          if (isVideo) {
            _selectedVideo = File(path);
            _selectedImage = null;
            _isImageInput = false;
            _thumbnailPath = null;
            _initializeVideoPlayer(_selectedVideo!);
            _fetchVideoMetadata(path);
            _generateThumbnail(path);
            _addToVideoHistory(path);
          } else {
            _selectedImage = File(path);
            _selectedVideo = null;
            _isImageInput = true;
            _thumbnailPath = path;
            _fetchImageMetadata(path);
          }
        });
      }
    } catch (e) {
      _showErrorDialog('Error selecting media', e.toString());
    }
  }

  Future<void> _pickAudio() async {
    // This method is now replaced by AudioSelectorWidget in the UI
    // and used through the _buildAudioTab() method.
  }

  void _removeAudio() {
    setState(() {
      _selectedAudio = null;
      _audioDuration = null;
      _isPlayingAudio = false;
    });
  }

  Future<void> _initializeVideoPlayer(File videoFile) async {
    _videoController?.dispose();
    _videoController = VideoPlayerController.file(videoFile);
    try {
      await _videoController!.initialize();
      _videoController!.setLooping(true);
      _videoController!.play();
      _videoController!.addListener(_videoListener);
      setState(() {
        _videoAspectRatio = _videoController!.value.aspectRatio;
      });
    } catch (e) {
      debugPrint('[TextBoxOverlay] Error initializing video player: $e');
    }
  }

  void _videoListener() {
    if (!mounted) return;
    setState(() {});
  }

  void _togglePlayPause() {
    if (_videoController == null) return;
    setState(() {
      _videoController!.value.isPlaying ? _videoController!.pause() : _videoController!.play();
    });
  }

  void _toggleMute() {
    if (_videoController == null) return;
    setState(() {
      _isMuted = !_isMuted;
      _videoController!.setVolume(_isMuted ? 0 : 1);
    });
  }

  Future<void> _fetchVideoMetadata(String videoPath) async {
    try {
      final metadata = await platform.invokeMethod<Map>('getVideoMetadata', {
        'videoPath': videoPath,
      });
      if (metadata != null) {
        setState(() {
          _videoWidth = metadata['width'] as int? ?? 1080;
          _videoHeight = metadata['height'] as int? ?? 1920;
          debugPrint('[TextBoxOverlay] Video dimensions: ${_videoWidth}x${_videoHeight}');
        });
      }
    } catch (e) {
      debugPrint('[TextBoxOverlay] Error fetching metadata: $e');
    }
  }

  Future<void> _generateThumbnail(String videoPath) async {
    try {
      // Get video dimensions to set correct AspectRatio for preview
      final XFile thumbX = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: (await getTemporaryDirectory()).path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 1280,
        quality: 75,
      );
      
      final String thumb = thumbX.path;
      if (thumb.isNotEmpty) {
        // Use Image.file to get dimensions
        final data = await File(thumb).readAsBytes();
        final image = await decodeImageFromList(data);
        
        setState(() {
          _thumbnailPath = thumb;
          _videoAspectRatio = image.width / image.height;
        });
      }
    } catch (e) {
      debugPrint('[TextBoxOverlay] Error generating thumbnail: $e');
    }
  }

  Future<void> _pickBgImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        final dir = await getApplicationDocumentsDirectory();
        final gridsDir = Directory('${dir.path}/grids');
        if (!await gridsDir.exists()) await gridsDir.create(recursive: true);

        final ext = picked.path.contains('.') ? picked.path.split('.').last : 'jpg';
        final savedFile = File('${gridsDir.path}/bg_${DateTime.now().millisecondsSinceEpoch}.$ext');
        await File(picked.path).copy(savedFile.path);

        setState(() {
          _saveCurrentBgLayout();
          _bgImage = savedFile;
          _applyBgLayoutForImage(savedFile.path);
          if (!_gridHistory.contains(savedFile.path)) {
            _gridHistory.insert(0, savedFile.path);
          }
        });
        _autoSaveCurrentSettings();
      }
    } catch (e) {
      debugPrint('[TextBoxOverlay] Error picking background image: $e');
    }
  }

  Future<void> _pickAndCreateGridBgImage(int columns) async {
    try {
      final int requiredImages = columns * columns;
      final List<XFile> images;
      if (columns == 1) {
        final img = await ImagePicker().pickImage(source: ImageSource.gallery);
        if (img == null) return;
        images = [img];
      } else {
        images = await ImagePicker().pickMultiImage();
        if (images.length != requiredImages) {
          _showToast('Please select exactly $requiredImages images for the grid.', isError: true);
          return;
        }
      }
      
      final dir = await getApplicationDocumentsDirectory();
      final sourcesDir = Directory('${dir.path}/grid_sources');
      if (!await sourcesDir.exists()) await sourcesDir.create(recursive: true);

      final List<XFile> persistentImages = [];
      final now = DateTime.now().millisecondsSinceEpoch;
      for (int i = 0; i < images.length; i++) {
        final ext = images[i].path.contains('.') ? images[i].path.split('.').last : 'jpg';
        final persistentFile = File('${sourcesDir.path}/grid_src_${now}_$i.$ext');
        await File(images[i].path).copy(persistentFile.path);
        persistentImages.add(XFile(persistentFile.path));
      }

      _gridImages = persistentImages;
      _gridColumns = columns;
      await _generateGridBgImage();
      _autoSaveCurrentSettings();
    } catch (e) {
      _showToast('Error picking grid images: $e', isError: true);
    }
  }

  Future<void> _generateGridBgImage() async {
    if (_gridImages.isEmpty) return;
    
    _gridDebounce?.cancel();
    _gridDebounce = Timer(const Duration(milliseconds: 150), () async {
      try {
        final int gridW = 1080;
        final int gridH = _fullScreen ? 1920 : (_forceSquare ? 1080 : 1080);
        final double gap = _gridGap;
        final double actualCellW = (gridW - gap * (_gridColumns + 1)) / _gridColumns;
        final double actualCellH = (gridH - gap * (_gridColumns + 1)) / _gridColumns;
        
        final ui.PictureRecorder recorder = ui.PictureRecorder();
        final ui.Canvas canvas = ui.Canvas(recorder);
        
        if (gap > 0) {
          final paint = Paint()..color = _parseHexColor(_gridGapColor, Colors.white);
          canvas.drawRect(Rect.fromLTWH(0, 0, gridW.toDouble(), gridH.toDouble()), paint);
        }
        
        for (int i = 0; i < _gridImages.length; i++) {
          final data = await File(_gridImages[i].path).readAsBytes();
          final ui.Image img = await decodeImageFromList(data);
          
          final int col = i % _gridColumns;
          final int row = i ~/ _gridColumns;
          
          final double destX = gap + col * (actualCellW + gap);
          final double destY = gap + row * (actualCellH + gap);
          
          final double srcAspect = img.width / img.height;
          final double dstAspect = actualCellW / actualCellH;
          
          double srcW = img.width.toDouble();
          double srcH = img.height.toDouble();
          double srcX = 0;
          double srcY = 0;
          
          if (srcAspect > dstAspect) {
            srcW = srcH * dstAspect;
            srcX = (img.width - srcW) / 2;
          } else {
            srcH = srcW / dstAspect;
            srcY = (img.height - srcH) / 2;
          }
          
          canvas.drawImageRect(
            img,
            Rect.fromLTWH(srcX, srcY, srcW, srcH),
            Rect.fromLTWH(destX, destY, actualCellW, actualCellH),
            Paint(),
          );
        }
        
        final ui.Image finalImg = await recorder.endRecording().toImage(gridW, gridH);
        final ByteData? byteData = await finalImg.toByteData(format: ui.ImageByteFormat.png);
        
        if (byteData != null) {
          final dir = await getApplicationDocumentsDirectory();
          final gridsDir = Directory('${dir.path}/grids');
          if (!await gridsDir.exists()) await gridsDir.create(recursive: true);
          
          final file = File('${gridsDir.path}/grid_bg_${DateTime.now().millisecondsSinceEpoch}.png');
          await file.writeAsBytes(byteData.buffer.asUint8List());
          
          if (!mounted) return;
          await precacheImage(FileImage(file), context);
          
          if (!mounted) return;
          setState(() {
            _saveCurrentBgLayout();
            _bgImage = file;
            _applyBgLayoutForImage(file.path);
            if (!_gridHistory.contains(file.path)) {
              _gridHistory.insert(0, file.path);
            }
          });
          _autoSaveCurrentSettings();
        }
      } catch (e) {
        _showToast('Error creating grid: $e', isError: true);
      }
    });
  }

  void _showToast(String message, {bool isError = false}) {
    // All snackbar and toast notifications removed per user request
  }

  Future<void> _processVideo() async {
    if (_selectedVideo == null && _selectedImage == null) {
      _showErrorDialog('No Media Selected', 'Please select a video or image first.');
      return;
    }
    AnalyticsService().logSaveAction(feature: 'text_box_overlay', type: _isImageInput ? 'image_to_video' : 'video');
    
    if (_selectedVideo != null && _selectedVideo!.existsSync()) {
      _inputFileSize = _selectedVideo!.lengthSync();
    } else if (_selectedImage != null && _selectedImage!.existsSync()) {
      _inputFileSize = _selectedImage!.lengthSync();
    } else {
      _inputFileSize = 0;
    }
    _outputFileSize = 0;

    _processStopwatch.reset();
    _processStopwatch.start();
    _elapsedTime = "00:00";
    _remainingTime = "--:--";
    _status = _isImageInput ? "Creating video from image..." : "Applying text overlay...";

    setState(() {
      _isProcessing = true;
      _progress = 0.0;
    });
    
    try {
      debugPrint('[TextBoxOverlay] Starting processing. isImageInput=$_isImageInput');

      final double finalBoxHeight = _boxHeight;

      _progressTimer?.cancel();
      const estimatedDuration = Duration(seconds: 20);
      _progressTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
        if (!_isProcessing) {
          timer.cancel();
          return;
        }
        if (mounted) {
          setState(() {
            final elapsed = _processStopwatch.elapsed;
            _elapsedTime = _formatDuration(elapsed);

            if (_progress < 0.95) {
              final ratio = elapsed.inMilliseconds / estimatedDuration.inMilliseconds;
              if (ratio > _progress) {
                _progress = ratio.clamp(0.0, 0.95);
              }
            }

            if (_progress > 0.05) {
              final totalEstimatedMs = elapsed.inMilliseconds / _progress;
              final remainingInMs = (totalEstimatedMs - elapsed.inMilliseconds).toInt();
              _remainingTime = _formatDuration(Duration(milliseconds: math.max(0, remainingInMs)));
            } else {
              final remainingInMs = (estimatedDuration.inMilliseconds - elapsed.inMilliseconds).toInt();
              _remainingTime = _formatDuration(Duration(milliseconds: math.max(0, remainingInMs)));
            }
          });
        }
      });

      // Get an output path from the native side
      final outputPath = await platform.invokeMethod<String>('getVideoOutputPath', {
        'filename': 'TextBox_${DateTime.now().millisecondsSinceEpoch}.mp4',
      });

      if (outputPath == null) {
        throw Exception('Failed to get output path for processed video');
      }

      final String fontPath = await _getSelectedFontPath();

      String inputPath;
      String method;
      Map<String, dynamic> params;

      // Always generate box image, which now contains both the background and text
      String? boxImagePath = await _generateBoxImage(_videoWidth.toDouble(), finalBoxHeight);

      if (_isImageInput) {
        inputPath = _selectedImage!.path;
        method = 'addTextToImageVideo';
        params = {
          'inputPath': inputPath,
          'outputPath': outputPath,
          'text': " ", // Text is rendered in Flutter PNG
          'fontSize': (_fontSize * _textScale).toInt(),
          'fontColor': _textColor,
          'boxColor': _boxColor,
          'boxHeight': finalBoxHeight.toInt(),
          'horizontalPadding': _horizontalPadding.toInt(),
          'verticalPadding': _verticalPadding.toInt(),
          'hAlign': _hAlign,
          'vAlign': _vAlign,
          'lineHeight': _lineHeight,
          'position': _textBoxPosition,
          'fontPath': fontPath,
          'preset': _preset,
          'crf': _crf.toInt(),
          'showShadow': _showTextShadow,
          'shadowColor': _shadowColor,
          'shadowX': _shadowX.toInt(),
          'shadowY': _shadowY.toInt(),
          'duration': _imageDuration.toDouble(),
          'fadeInDuration': _fadeInDuration,
          'transition': _imageTransition,
          'audioPath': _selectedAudio?.path,
          'audioVolume': _audioVolume,
          'loopAudio': _loopAudio,
          'boxImagePath': boxImagePath,
          'boxOverlap': _boxStyle == 'paper_cut' ? _paperCutRoughness.toInt() + _paperCutShadowAmount.toInt() : 0,
        };
      } else if (_fullScreen || _forceSquare) {
        inputPath = _selectedVideo!.path;
        method = 'addWatermarkToVideo';
        final int targetW = _fullScreen ? 1080 : (_forceSquare ? 1080 : _videoWidth);
        final int targetH = _fullScreen ? 1920 : (_forceSquare ? 1080 : _videoHeight);
        
        final double aspectIn = _videoWidth / _videoHeight;
        final double aspectOut = targetW / targetH;
        final double sY = aspectIn > aspectOut ? aspectOut / aspectIn : 1.0;
        final double sX = aspectIn < aspectOut ? aspectIn / aspectOut : 1.0;

        final double videoDrawW = targetW * sX * _videoScale;
        final double videoDrawH = targetH * sY * _videoScale;

        final double videoCenterX = targetW * (0.5 + (_videoX - 0.5) * (1.0 - sX * _videoScale));
        final double videoCenterY = targetH * (0.5 - (0.5 - _videoY) * (1.0 - sY * _videoScale));
        final double videoTopY = videoCenterY - (videoDrawH / 2.0);
        final double videoBottomY = videoCenterY + (videoDrawH / 2.0);

        final double boxScaleRatio = videoDrawW / _videoWidth;
        final double boxDrawH = finalBoxHeight * boxScaleRatio;
        final double overlapPx = (_boxStyle == 'paper_cut' ? _paperCutRoughness + _paperCutShadowAmount : 0) * boxScaleRatio;

        final double boxCenterY = _textBoxPosition == 'top'
            ? (videoTopY - (boxDrawH / 2.0) + overlapPx)
            : (videoBottomY + (boxDrawH / 2.0) - overlapPx);

        final double boxScaleFraction = sX * _videoScale;

        final List<Map<String, dynamic>> imageOverlays = [];
        if (boxImagePath != null) {
          imageOverlays.add({
            'path': boxImagePath,
            'x': videoCenterX,
            'y': boxCenterY,
            'scale': boxScaleFraction,
            'opacity': 1.0,
            'rotation': 0.0,
          });
        }

        params = {
          'inputPath': inputPath,
          'outputPath': outputPath,
          'type': 'none',
          'fullScreen': _fullScreen,
          'forceSquareBg': _forceSquare,
          'bgColor': _bgColor,
          'bgImagePath': _bgImage?.path ?? '',
          'bgBrightness': _bgBrightness,
          'bgSaturation': _bgSaturation,
          'bgBlur': _bgBlur,
          'videoX': _videoX,
          'videoY': _videoY,
          'videoScale': _videoScale,
          'videoRadius': _videoRadius,
          'videoBorderWidth': _videoBorderWidth,
          'videoBorderColor': _videoBorderColor,
          'showVideoShadow': _showVideoShadow,
          'videoShadowColor': _videoShadowColor,
          'videoShadowBlur': _videoShadowBlur,
          'videoShadowSpread': _videoShadowSpread,
          'videoShadowOffsetX': _videoShadowOffsetX,
          'videoShadowOffsetY': _videoShadowOffsetY,
          'imageOverlays': imageOverlays,
          'audioPath': _selectedAudio?.path,
          'addOutro': _addOutro && WatermarkSettings.enableOutro,
        };
      } else {
        inputPath = _selectedVideo!.path;
        method = 'addTextToVideo';
        params = {
          'inputPath': inputPath,
          'outputPath': outputPath,
          'text': " ", // Text is rendered in Flutter PNG
          'x': 0,
          'y': 0,
          'fontSize': (_fontSize * _textScale).toInt(),
          'fontColor': _textColor,
          'boxColor': _boxColor,
          'boxHeight': finalBoxHeight.toInt(),
          'horizontalPadding': _horizontalPadding.toInt(),
          'verticalPadding': _verticalPadding.toInt(),
          'hAlign': _hAlign,
          'vAlign': _vAlign,
          'lineHeight': _lineHeight,
          'position': _textBoxPosition,
          'fontPath': fontPath,
          'preset': _preset,
          'crf': _crf.toInt(),
          'addOutro': _addOutro,
          'showShadow': _showTextShadow,
          'shadowColor': _shadowColor,
          'shadowX': _shadowX.toInt(),
          'shadowY': _shadowY.toInt(),
          'audioPath': _selectedAudio?.path,
          'audioVolume': _audioVolume,
          'loopAudio': _loopAudio,
          'boxImagePath': boxImagePath,
          'boxOverlap': _boxStyle == 'paper_cut' ? _paperCutRoughness.toInt() + _paperCutShadowAmount.toInt() : 0,
        };
      }

      debugPrint('[TextBoxOverlay] Calling $method with params: $params');

      final result = await platform.invokeMethod<String>(method, params);
      
      final finalPath = result ?? outputPath;
      final outFile = File(finalPath);
      if (outFile.existsSync()) {
        _outputFileSize = outFile.lengthSync();
      }

      _processStopwatch.stop();
      _progressTimer?.cancel();

      setState(() {
        _isProcessing = false;
        _outputPath = finalPath;
        _progress = 1.0;
      });
      
      debugPrint('[TextBoxOverlay] Processing completed, output=$_outputPath');
      _showSuccessDialog();
      
    } catch (e) {
      _processStopwatch.stop();
      _progressTimer?.cancel();
      setState(() {
        _isProcessing = false;
      });
      
      debugPrint('[TextBoxOverlay] Error during processing: $e');
      _showErrorDialog('Processing Failed', e.toString());
    }
  }
  
  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(message),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = (math.log(bytes) / math.log(1024)).floor();
    return ((bytes / math.pow(1024, i)).toStringAsFixed(1)) + ' ' + suffixes[i];
  }

  void _cancelProcess() async {
    try {
      await platform.invokeMethod('cancelWatermarkToVideo');
    } catch (e) {
      debugPrint("Cancel error: $e");
    }
    _progressTimer?.cancel();
    _processStopwatch.stop();
    if (mounted) {
      setState(() {
        _isProcessing = false;
        _status = "Canceled";
      });
    }
  }

  Color _parseHexColor(String value, Color fallback) {
    try {
      var v = value.trim();
      if (v.isEmpty) return fallback;
      if (v.startsWith('#')) {
        v = v.substring(1);
      }
      if (v.length == 6) {
        v = 'FF$v';
      }
      if (v.length != 8) return fallback;
      final intColor = int.parse(v, radix: 16);
      return Color(intColor);
    } catch (_) {
      return fallback;
    }
  }
  
  String _colorToHex(Color color) {
    final value = color.value.toRadixString(16).padLeft(8, '0').toUpperCase();
    // Drop alpha, keep RRGGBB
    return '#${value.substring(2)}';
  }

  Future<void> _pickColor({required bool isText, bool isShadow = false, bool isPaperCutShadow = false}) async {
    final initial = _parseHexColor(
      isPaperCutShadow ? _paperCutShadowColor : (isShadow ? _shadowColor : (isText ? _textColor : _boxColor)),
      isPaperCutShadow || isShadow || isText ? Colors.black : Colors.white,
    );

    final String originalTextColor = _textColor;
    final String originalBoxColor = _boxColor;
    final String originalShadowColor = _shadowColor;
    final String originalPaperCutShadowColor = _paperCutShadowColor;

    HSVColor hsv = HSVColor.fromColor(initial);
    Color tempColor = hsv.toColor();

    final TextEditingController hexController = TextEditingController(
      text: _colorToHex(tempColor).replaceFirst('#', ''),
    );

    String? errorText;

    void applyTempToPreview() {
      final hex = _colorToHex(tempColor);
      setState(() {
        if (isPaperCutShadow) {
          _paperCutShadowColor = hex;
        } else if (isShadow) {
          _shadowColor = hex;
        } else if (isText) {
          if (_selectedWordIndices.isNotEmpty) {
            if (_highlightType == 'marker') {
              for (final i in _selectedWordIndices) {
                _wordBgColors[i] = hex;
              }
            } else {
              for (final i in _selectedWordIndices) {
                _wordColors[i] = hex;
              }
            }
          } else {
            _textColor = hex;
          }
        } else {
          _boxColor = hex;
        }
      });
    }

    void revertPreview() {
      setState(() {
        _textColor = originalTextColor;
        _boxColor = originalBoxColor;
        _shadowColor = originalShadowColor;
        _paperCutShadowColor = originalPaperCutShadowColor;
      });
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      barrierColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: StatefulBuilder(
              builder: (context, setStateSheet) {
                void syncFromHsv({bool updatePreview = true}) {
                  tempColor = hsv.toColor();
                  hexController.text = _colorToHex(tempColor).replaceFirst('#', '');
                  hexController.selection = TextSelection.collapsed(offset: hexController.text.length);
                  if (updatePreview) applyTempToPreview();
                }

                void syncFromHex(String value) {
                  final v = value.trim();
                  if (v.length != 6) return;
                  final parsed = _parseHexColor('#$v', tempColor);
                  hsv = HSVColor.fromColor(parsed);
                  tempColor = parsed;
                  applyTempToPreview();
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            isShadow ? 'Shadow Color' : (isText ? 'Text Color' : 'Box Color'),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            revertPreview();
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final double size = constraints.maxWidth < 260 ? constraints.maxWidth : 260;

                          void updateSv(Offset localPosition) {
                            final dx = localPosition.dx.clamp(0.0, size);
                            final dy = localPosition.dy.clamp(0.0, size);
                            final s = (dx / size).clamp(0.0, 1.0);
                            final v = (1.0 - (dy / size)).clamp(0.0, 1.0);
                            hsv = hsv.withSaturation(s).withValue(v);
                            syncFromHsv();
                          }

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onPanDown: (d) => setStateSheet(() {
                                  updateSv(d.localPosition);
                                  errorText = null;
                                }),
                                onPanUpdate: (d) => setStateSheet(() {
                                  updateSv(d.localPosition);
                                  errorText = null;
                                }),
                                child: Stack(
                                  children: [
                                    Container(
                                      width: size,
                                      height: size,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.grey.shade300),
                                        gradient: LinearGradient(
                                          colors: [Colors.white, HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor()],
                                        ),
                                      ),
                                    ),
                                    Container(
                                      width: size,
                                      height: size,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        gradient: const LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [Colors.transparent, Colors.black],
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      left: (hsv.saturation * size).clamp(0.0, size) - 8,
                                      top: ((1.0 - hsv.value) * size).clamp(0.0, size) - 8,
                                      child: Container(
                                        width: 16,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 2),
                                          boxShadow: [
                                            BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 4),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const SizedBox(
                                    width: 28,
                                    child: Text('Hue', style: TextStyle(fontSize: 12)),
                                  ),
                                  Expanded(
                                    child: Slider(
                                      value: hsv.hue,
                                      min: 0,
                                      max: 360,
                                      onChanged: (v) {
                                        setStateSheet(() {
                                          hsv = hsv.withHue(v);
                                          syncFromHsv();
                                          errorText = null;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Hex (RRGGBB)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: hexController,
                      decoration: InputDecoration(
                        prefixText: '#',
                        hintText: 'FFFFFF',
                        errorText: errorText,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F]')),
                        LengthLimitingTextInputFormatter(6),
                      ],
                      onChanged: (value) {
                        final v = value.trim();
                        if (v.length != 6) {
                          setStateSheet(() {
                            errorText = null;
                          });
                          return;
                        }
                        try {
                          setStateSheet(() {
                            syncFromHex(v);
                            errorText = null;
                          });
                        } catch (_) {
                          setStateSheet(() {
                            errorText = 'Invalid hex';
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              revertPreview();
                              Navigator.of(context).pop();
                            },
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              if (hexController.text.trim().length == 6) {
                                final candidate = _parseHexColor('#${hexController.text.trim()}', tempColor);
                                tempColor = candidate;
                                hsv = HSVColor.fromColor(candidate);
                              }
                              final hex = _colorToHex(tempColor);
                              setState(() {
                                if (isPaperCutShadow) {
                                  _paperCutShadowColor = hex;
                                  final digits = hex.replaceFirst('#', '');
                                  _paperCutShadowColorController.value = TextEditingValue(
                                    text: digits,
                                    selection: TextSelection.collapsed(offset: digits.length),
                                  );
                                } else if (isShadow) {
                                  _shadowColor = hex;
                                } else if (isText) {
                                  if (_selectedWordIndices.isNotEmpty) {
                                    if (_highlightType == 'marker') {
                                      for (final i in _selectedWordIndices) {
                                        _wordBgColors[i] = hex;
                                      }
                                    } else {
                                      for (final i in _selectedWordIndices) {
                                        _wordColors[i] = hex;
                                      }
                                    }
                                  } else {
                                    _textColor = hex;
                                    final digits = hex.replaceFirst('#', '');
                                    _textColorController.value = TextEditingValue(
                                      text: digits,
                                      selection: TextSelection.collapsed(offset: digits.length),
                                    );
                                  }
                                } else {
                                  _boxColor = hex;
                                  final digits = hex.replaceFirst('#', '');
                                  _boxColorController.value = TextEditingValue(
                                    text: digits,
                                    selection: TextSelection.collapsed(offset: digits.length),
                                  );
                                }
                              });
                              Navigator.of(context).pop();
                            },
                            child: const Text('Apply'),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildColorSlider(
    String label,
    int value,
    Color activeColor,
    ValueChanged<int> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 20,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
        ),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: 0,
            max: 255,
            divisions: 255,
            activeColor: activeColor,
            onChanged: (v) => onChanged(v.toInt()),
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            value.toString().padLeft(3, ' '),
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
  
  void _showSuccessDialog() {
    AdService().showInterstitialAd();
    final fileName = _outputPath != null ? _outputPath!.split('/').last : 'video.mp4';
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
                            fileName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (_inputFileSize > 0 || _outputFileSize > 0) ...[
                      const Divider(height: 24),
                      if (_inputFileSize > 0)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Input Size', style: TextStyle(color: Colors.grey, fontSize: 11)),
                            Text(_formatSize(_inputFileSize), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11)),
                          ],
                        ),
                      if (_outputFileSize > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Output Size', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            Text(_formatSize(_outputFileSize), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary)),
                          ],
                        ),
                      ],
                    ],
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
                        if (_outputPath != null) {
                          OpenFile.open(_outputPath!);
                        }
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
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Preview Section
                if (_selectedVideo != null || _selectedImage != null)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () {
                        if (_isTabContentExpanded) {
                          setState(() => _isTabContentExpanded = false);
                        }
                      },
                      child: Center(
                        child: SingleChildScrollView(
                          child: _buildPreviewArea(),
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () {
                        if (_isTabContentExpanded) {
                          setState(() => _isTabContentExpanded = false);
                        }
                      },
                      child: Stack(
                        children: [
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.movie_outlined, size: 64, color: Colors.grey),
                                const SizedBox(height: 16),
                                const Text(
                                  'No video or image selected',
                                  style: TextStyle(fontSize: 18, color: Colors.grey),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  onPressed: _selectVideo,
                                  icon: const Icon(Icons.add_photo_alternate),
                                  label: const Text('Select Media'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                // Control Tabs
                if (_selectedVideo != null || _selectedImage != null) ...[
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _isTabContentExpanded ? _buildActiveTabContent() : const SizedBox.shrink(),
                  ),
                  _buildControlTabs(),
                ],
              ],
            ),
            if (_isProcessing) Positioned.fill(child: _buildProcessingOverlay()),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Background Music',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          AudioSelectorWidget(
            selectedAudio: _selectedAudio,
            audioDuration: _audioDuration,
            isPlayingAudio: _isPlayingAudio,
            onAudioSelected: (audio, duration) {
              setState(() {
                _selectedAudio = audio;
                _audioDuration = duration;
                
                // Parse duration "mm:ss" to seconds and sync video duration
                if (duration != null && duration.contains(':')) {
                  final parts = duration.split(':');
                  if (parts.length == 2) {
                    final mins = int.tryParse(parts[0]) ?? 0;
                    final secs = int.tryParse(parts[1]) ?? 0;
                    final totalSecs = (mins * 60) + secs;
                    if (totalSecs > 0) {
                      _imageDuration = totalSecs;
                    }
                  }
                }
              });
            },
            onAudioRemoved: () {
              setState(() {
                _selectedAudio = null;
                _audioDuration = null;
                _isPlayingAudio = false;
                _imageDuration = 8; // Reset to 8s default when audio is removed
              });
            },
            onPlaybackToggle: (isPlaying) {
              setState(() => _isPlayingAudio = isPlaying);
            },
            isProcessing: _isProcessing,
          ),
          if (_selectedAudio != null) ...[
            const SizedBox(height: 24),
            const Text(
              'Audio Settings',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildControlSlider(
              label: 'Volume',
              value: _audioVolume,
              min: 0.0,
              max: 2.0,
              divisions: 20,
              onChanged: (value) {
                setState(() {
                  _audioVolume = value;
                });
              },
            ),
            SwitchListTile(
              title: const Text('Loop Audio'),
              subtitle: const Text('Repeat audio if video is longer'),
              value: _loopAudio,
              onChanged: (value) {
                setState(() {
                  _loopAudio = value;
                });
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImageToVideoTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Image to Video Options',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          DurationSelectorWidget(
            duration: _imageDuration,
            onDurationChanged: (value) {
              setState(() {
                _imageDuration = value;
              });
            },
            isProcessing: _isProcessing,
          ),
          const SizedBox(height: 24),
          const Text(
            'Transition Style',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTransitionChip('None', 'none', Icons.block),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTransitionChip('Fade In', 'fade', Icons.blur_on),
              ),
            ],
          ),
          if (_imageTransition == 'fade') ...[
            const SizedBox(height: 24),
            const Text(
              'Fade In Duration (seconds)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('fadeInDuration'),
              initialValue: _fadeInDuration.toStringAsFixed(1),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                helperText: 'Range: 0.1 - 5.0 seconds',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              enabled: !_isProcessing,
              onChanged: (value) {
                final parsed = double.tryParse(value);
                if (parsed != null && parsed >= 0.1 && parsed <= 5.0) {
                  setState(() {
                    _fadeInDuration = parsed;
                  });
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTransitionChip(String label, String value, IconData icon) {
    final isSelected = _imageTransition == value;
    final color = Colors.orange;
    
    return InkWell(
      onTap: _isProcessing ? null : () {
        setState(() {
          _imageTransition = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? color : Colors.grey[600],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlignChip(String label, String value, IconData icon, bool isHorizontal) {
    final isSelected = isHorizontal ? _hAlign == value : _vAlign == value;
    return Expanded(
      child: ChoiceChip(
        label: Icon(icon, size: 18, color: isSelected ? Colors.white : Colors.grey),
        selected: isSelected,
        onSelected: (s) {
          if (s) {
            setState(() {
              if (isHorizontal) _hAlign = value;
              else _vAlign = value;
            });
          }
        },
        selectedColor: Colors.blue,
      ),
    );
  }

  Widget _buildVideoSelectionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.movie_outlined, color: Colors.blue),
              const SizedBox(width: 8),
              const Text(
                'Select Video',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (_selectedVideo != null)
                TextButton(
                  onPressed: _selectVideo,
                  child: const Text('Change'),
                ),
            ],
          ),
          if (_selectedVideo == null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _selectVideo,
                icon: const Icon(Icons.video_library),
                label: const Text('Choose from Gallery'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _selectedVideo!.path.split('/').last,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPreviewArea() {
    final bool isCanvasMode = _fullScreen || _forceSquare;
    final double outAspect = _fullScreen ? 9 / 16 : (_forceSquare ? 1.0 : _videoAspectRatio);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final previewWidth = constraints.maxWidth;
          final double containerHeight = isCanvasMode ? (previewWidth / outAspect) : (previewWidth / _videoAspectRatio);
          final double scaleFactor = _videoWidth / previewWidth;

          final boxHeight = _boxHeight / scaleFactor;
          final previewFontSize = (_fontSize * _textScale) / scaleFactor;
          final previewHorizontalPadding = _horizontalPadding / scaleFactor;
          final previewVerticalPadding = _verticalPadding / scaleFactor;

          Alignment textAlignment;
          TextAlign textAlign;
          if (_vAlign == 'top') {
            textAlignment = _hAlign == 'left' ? Alignment.topLeft : (_hAlign == 'right' ? Alignment.topRight : Alignment.topCenter);
          } else if (_vAlign == 'bottom') {
            textAlignment = _hAlign == 'left' ? Alignment.bottomLeft : (_hAlign == 'right' ? Alignment.bottomRight : Alignment.bottomCenter);
          } else {
            textAlignment = _hAlign == 'left' ? Alignment.centerLeft : (_hAlign == 'right' ? Alignment.centerRight : Alignment.center);
          }
          
          if (_hAlign == 'left') textAlign = TextAlign.left;
          else if (_hAlign == 'right') textAlign = TextAlign.right;
          else textAlign = TextAlign.center;

          final mediaContent = _isImageInput && _selectedImage != null
              ? Image.file(
                  _selectedImage!,
                  fit: isCanvasMode ? BoxFit.cover : BoxFit.contain,
                )
              : ((_videoController != null && _videoController!.value.isInitialized)
                  ? GestureDetector(
                      onTap: () => setState(() => _showControls = !_showControls),
                      child: AspectRatio(
                        aspectRatio: _videoAspectRatio,
                        child: VideoPlayer(_videoController!),
                      ),
                    )
                  : (_thumbnailPath != null
                      ? Image.file(
                          File(_thumbnailPath!),
                          fit: isCanvasMode ? BoxFit.cover : BoxFit.contain,
                        )
                      : const Center(child: CircularProgressIndicator())));

          final videoControlsOverlay = (!_isImageInput && _videoController != null && _videoController!.value.isInitialized && _showControls)
              ? Positioned.fill(
                  child: Container(
                    color: Colors.black26,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: Icon(_isMuted ? Icons.volume_off : Icons.volume_up, color: Colors.white),
                              onPressed: _toggleMute,
                            ),
                          ],
                        ),
                        Center(
                          child: IconButton(
                            iconSize: 48,
                            icon: Icon(
                              _videoController!.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                              color: Colors.white,
                            ),
                            onPressed: _togglePlayPause,
                          ),
                        ),
                        Column(
                          children: [
                            VideoProgressIndicator(
                              _videoController!,
                              allowScrubbing: true,
                              colors: const VideoProgressColors(
                                playedColor: Colors.blue,
                                bufferedColor: Colors.white24,
                                backgroundColor: Colors.white12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
              : null;

          final textWidget = Container(
            width: previewWidth,
            height: boxHeight,
            alignment: textAlignment,
            padding: EdgeInsets.symmetric(
              horizontal: previewHorizontalPadding + (12 / scaleFactor),
              vertical: previewVerticalPadding,
            ),
            child: RichText(
              textAlign: textAlign,
              softWrap: true,
              overflow: TextOverflow.visible,
              text: _buildWordColoredTextSpan(
                text: _textContent,
                wordColors: _wordColors,
                wordBgColors: _wordBgColors,
                defaultColor: _parseHexColor(_textColor, Colors.black),
                textOpacity: _textOpacity,
                fontSize: previewFontSize,
                fontFamily: _selectedFont?.family,
                height: _lineHeight,
                showShadow: _showTextShadow,
                shadowColor: _parseHexColor(_shadowColor, Colors.black).withOpacity(0.5),
                shadowOffset: Offset(_shadowX, _shadowY),
                shadowBlur: 0.0,
              ),
            ),
          );

          final double previewRoughness = _paperCutRoughness / scaleFactor;
          final double previewShadowPadding = _paperCutShadowAmount / scaleFactor;
          final double overlapAmount = _boxStyle == 'paper_cut' ? previewRoughness + previewShadowPadding : 0;

          final boxWidget = _boxStyle == 'paper_cut' 
              ? CustomPaint(
                  painter: TornPaperPainter(
                    color: _parseHexColor(_boxColor, Colors.white).withOpacity(_boxOpacity),
                    isTop: _textBoxPosition == 'top',
                    roughness: previewRoughness,
                    seed: _paperCutSeed,
                    shadowPadding: previewShadowPadding,
                    shadowColor: _parseHexColor(_paperCutShadowColor, Colors.black).withOpacity(0.5),
                  ),
                  child: textWidget,
                )
              : Container(
                  width: previewWidth,
                  height: boxHeight,
                  color: _parseHexColor(_boxColor, Colors.white).withOpacity(_boxOpacity),
                  child: textWidget,
                );

          final mediaWidget = SizedBox(
            width: previewWidth,
            height: previewWidth / _videoAspectRatio,
            child: Stack(
              children: [
                mediaContent,
                if (videoControlsOverlay != null) videoControlsOverlay,
              ],
            ),
          );

          final cardWidget = Container(
            width: previewWidth,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_videoRadius),
              border: _videoBorderWidth > 0
                  ? Border.all(
                      color: _parseHexColor(_videoBorderColor, Colors.white),
                      width: _videoBorderWidth,
                    )
                  : null,
              boxShadow: _showVideoShadow
                  ? [
                      BoxShadow(
                        color: _parseHexColor(_videoShadowColor, Colors.black),
                        blurRadius: _videoShadowBlur,
                        offset: Offset(_videoShadowOffsetX, _videoShadowOffsetY),
                        spreadRadius: _videoShadowSpread,
                      )
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_videoRadius),
              child: Stack(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _textBoxPosition == 'top'
                        ? [
                            SizedBox(height: boxHeight - overlapAmount),
                            mediaWidget,
                          ]
                        : [
                            mediaWidget,
                            SizedBox(height: boxHeight - overlapAmount),
                          ],
                  ),
                  Positioned(
                    top: _textBoxPosition == 'top' ? 0 : null,
                    bottom: _textBoxPosition == 'bottom' ? 0 : null,
                    left: 0,
                    right: 0,
                    child: boxWidget,
                  ),
                ],
              ),
            ),
          );

          if (isCanvasMode) {
            return Center(
              child: Container(
                decoration: BoxDecoration(
                  color: _parseHexColor(_bgColor, Colors.black),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
                ),
                clipBehavior: Clip.antiAlias,
                child: AspectRatio(
                  aspectRatio: outAspect,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Background Image / Color
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
                        )
                      else
                        Positioned.fill(child: ColoredBox(color: _parseHexColor(_bgColor, Colors.black))),

                      // Positioned / Scaled / Bordered Video + Box Card
                      Builder(
                        builder: (context) {
                          final double unscaledCardH = (previewWidth / _videoAspectRatio) + (boxHeight - overlapAmount);
                          final double scaledCardW = previewWidth * _videoScale;
                          final double scaledCardH = unscaledCardH * _videoScale;
                          final double videoOffsetDx = (_videoX - 0.5) * (previewWidth - scaledCardW);
                          final double videoOffsetDy = (_videoY - 0.5) * (containerHeight - scaledCardH);

                          return Center(
                            child: Transform.translate(
                              offset: Offset(videoOffsetDx, videoOffsetDy),
                              child: Transform.scale(
                                scale: _videoScale,
                                child: cardWidget,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return cardWidget;
        },
      ),
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
          // Export Button
          if (_selectedVideo != null || _selectedImage != null)
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _processVideo,
                child: const Text('Save', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          Expanded(
            child: ListView(
              key: const PageStorageKey<String>('text_box_overlay_tabs_list'),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              children: [
                _buildTabItem(0, Icons.format_quote, 'Text', Colors.teal),
                _buildTabItem(1, Icons.font_download_outlined, 'Font', Colors.green),
                _buildTabItem(2, Icons.palette_outlined, 'Colors', Colors.deepOrange),
                _buildTabItem(3, Icons.vertical_align_center, 'Position', Colors.blue),
                _buildTabItem(4, Icons.settings_outlined, 'Settings', Colors.purple),
                _buildTabItem(5, Icons.movie_outlined, 'Video', Colors.indigo),
                if (_isImageInput) _buildTabItem(6, Icons.image_outlined, 'Image Opts', Colors.orange),
                _buildTabItem(7, Icons.library_music, 'Audio', Colors.pink),
                _buildTabItem(8, Icons.aspect_ratio, 'Canvas', Colors.cyan),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, IconData icon, String label, Color color) {
    final isSelected = _selectedTabIndex == index;
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

  Widget _buildQuickActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4.5),
                Flexible(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabSpecificContent() {
    switch (_selectedTabIndex) {
      case 0: // Text
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Text Content', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                if (_textContent.isNotEmpty)
                  Text(
                    '${_textContent.length} chars',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildQuickActionBtn(
                  icon: Icons.calendar_today_rounded,
                  label: 'Date',
                  color: AppColors.primary,
                  onTap: () {
                    final text = _getFormattedDate(false);
                    _textController.text = text;
                    setState(() {
                      _textContent = text;
                      final minReq = _calculateDynamicBoxHeight(text: text);
                      _boxHeight = math.max(_userBoxHeight, minReq);
                    });
                  },
                ),
                const SizedBox(width: 6),
                _buildQuickActionBtn(
                  icon: Icons.event_note_rounded,
                  label: '+ Day',
                  color: Colors.indigo,
                  onTap: () {
                    final text = _getFormattedDate(true);
                    _textController.text = text;
                    setState(() {
                      _textContent = text;
                      final minReq = _calculateDynamicBoxHeight(text: text);
                      _boxHeight = math.max(_userBoxHeight, minReq);
                    });
                  },
                ),
                const SizedBox(width: 6),
                _buildQuickActionBtn(
                  icon: Icons.copy_rounded,
                  label: 'Copy',
                  color: Colors.teal.shade700,
                  onTap: () {
                    if (_textContent.isNotEmpty) {
                      Clipboard.setData(ClipboardData(text: _textContent));
                      _showToast('Text copied to clipboard');
                    } else {
                      _showToast('Nothing to copy', isError: true);
                    }
                  },
                ),
                const SizedBox(width: 6),
                _buildQuickActionBtn(
                  icon: Icons.clear_rounded,
                  label: 'Clear',
                  color: Colors.deepOrange.shade600,
                  onTap: () {
                    _textController.clear();
                    setState(() {
                      _textContent = '';
                      final minReq = _calculateDynamicBoxHeight(text: '');
                      _boxHeight = math.max(_userBoxHeight, minReq);
                      _wordColors.clear();
                      _wordBgColors.clear();
                      _selectedWordIndices.clear();
                    });
                    _showToast('Text cleared');
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _textController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter overlay text...',
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              onChanged: (v) {
                setState(() {
                  _textContent = v;
                  final minReq = _calculateDynamicBoxHeight(text: v);
                  _boxHeight = math.max(_userBoxHeight, minReq);
                });
              },
            ),
            const SizedBox(height: 16),
            if (_textContent.trim().isNotEmpty) ...[
              _buildWordSelectionChips(),
              if (_selectedWordIndices.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(child: _buildMarkerPresetsRow()),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _selectedTabIndex = 2;
                            _selectedColorSubTab = 2;
                            _isTabContentExpanded = true;
                          });
                        },
                        icon: const Icon(Icons.palette_outlined, size: 14),
                        label: const Text('More', style: TextStyle(fontSize: 11)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
            const Text('Position', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Top')),
                    selected: _textBoxPosition == 'top',
                    onSelected: (s) => setState(() => _textBoxPosition = 'top'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Bottom')),
                    selected: _textBoxPosition == 'bottom',
                    onSelected: (s) => setState(() => _textBoxPosition = 'bottom'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Horizontal Alignment', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildAlignChip('Left', 'left', Icons.align_horizontal_left, true),
                const SizedBox(width: 8),
                _buildAlignChip('Center', 'center', Icons.align_horizontal_center, true),
                const SizedBox(width: 8),
                _buildAlignChip('Right', 'right', Icons.align_horizontal_right, true),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Vertical Alignment', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildAlignChip('Top', 'top', Icons.align_vertical_top, false),
                const SizedBox(width: 8),
                _buildAlignChip('Middle', 'middle', Icons.align_vertical_center, false),
                const SizedBox(width: 8),
                _buildAlignChip('Bottom', 'bottom', Icons.align_vertical_bottom, false),
              ],
            ),
            const SizedBox(height: 16),
            _buildHeightPresetsSection(),
          ],
        );
      case 1: // Font
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_textContent.trim().isNotEmpty) ...[
              _buildWordSelectionChips(),
              if (_selectedWordIndices.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(child: _buildMarkerPresetsRow()),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _selectedTabIndex = 2;
                            _selectedColorSubTab = 2;
                            _isTabContentExpanded = true;
                          });
                        },
                        icon: const Icon(Icons.palette_outlined, size: 14),
                        label: const Text('More', style: TextStyle(fontSize: 11)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
            const Text('Font Settings', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildControlSlider(
              label: 'Size',
              value: _fontSize,
              min: 20, max: 100,
              onChanged: (v) {
                setState(() {
                  _fontSize = v;
                  final minReq = _calculateDynamicBoxHeight(text: _textContent);
                  _boxHeight = math.max(_userBoxHeight, minReq);
                });
              },
            ),
            const SizedBox(height: 8),
            const Text('Font Family'),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: getAllFonts().length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final font = getAllFonts()[index];
                  final isSelected = _selectedFont == font;
                  return ChoiceChip(
                    label: Text(
                      font.displayName,
                      style: TextStyle(
                        fontFamily: font.family,
                        fontWeight: font.weight,
                        fontStyle: font.style,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedFont = font;
                          final minReq = _calculateDynamicBoxHeight(text: _textContent);
                          _boxHeight = math.max(_userBoxHeight, minReq);
                        });
                      }
                    },
                  );
                },
              ),
            ),
          ],
        );
      case 2: // Colors & Style
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Color & Style', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20, color: Colors.grey),
                  tooltip: 'Reset Colors',
                  onPressed: () {
                    setState(() {
                      _textColor = "#000000";
                      _textOpacity = 1.0;
                      _boxColor = "#FFFFFF";
                      _boxOpacity = 1.0;
                      _showTextShadow = false;
                      _shadowColor = "#000000";
                      _shadowX = 2.0;
                      _shadowY = 2.0;
                      _wordColors.clear();
                      _wordBgColors.clear();
                      _selectedWordIndices.clear();
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildColorSubTabButton(0, 'Text', Icons.title),
                _buildColorSubTabButton(1, 'Box', Icons.check_box_outline_blank),
                _buildColorSubTabButton(2, 'Highlight', Icons.highlight_outlined),
              ],
            ),
            const SizedBox(height: 20),
            IndexedStack(
              index: _selectedColorSubTab,
              children: [
                // --- SubTab 0: Text Color, Opacity & Shadow ---
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Text Color', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    _buildPaletteColorPicker(_textColor, (c) => setState(() => _textColor = c)),
                    const SizedBox(height: 16),
                    _buildCanvasControlSlider(
                      label: 'Text Opacity',
                      value: _textOpacity,
                      min: 0.0,
                      max: 1.0,
                      onChanged: (v) => setState(() => _textOpacity = v),
                    ),
                    const Divider(height: 32),
                    _buildCanvasShadowSection(
                      title: 'Text Shadow',
                      showShadow: _showTextShadow,
                      onToggleShadow: (v) => setState(() => _showTextShadow = v),
                      shadowColor: _shadowColor,
                      onColorChanged: (c) => setState(() => _shadowColor = c),
                      blur: 0.0,
                      onBlurChanged: (_) {},
                      offsetX: _shadowX,
                      onOffsetXChanged: (v) => setState(() => _shadowX = v),
                      offsetY: _shadowY,
                      onOffsetYChanged: (v) => setState(() => _shadowY = v),
                    ),
                  ],
                ),

                // --- SubTab 1: Box Color & Opacity ---
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Box Background Color', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    _buildPaletteColorPicker(_boxColor, (c) => setState(() => _boxColor = c)),
                    const SizedBox(height: 16),
                    _buildCanvasControlSlider(
                      label: 'Box Opacity',
                      value: _boxOpacity,
                      min: 0.0,
                      max: 1.0,
                      onChanged: (v) => setState(() => _boxOpacity = v),
                    ),
                  ],
                ),

                // --- SubTab 2: Word Highlighting & Book Markers ---
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Word & Marker Highlighting', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        if (_wordBgColors.isNotEmpty || _wordColors.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _wordBgColors.clear();
                                _wordColors.clear();
                              });
                              _autoSaveCurrentSettings();
                              _showToast('All highlights cleared');
                            },
                            child: const Text(
                              'Clear All',
                              style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Highlight words with book marker backgrounds or custom text colors.',
                      style: TextStyle(fontSize: 11.5, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    if (_textContent.trim().isNotEmpty) ...[
                      _buildWordSelectionChips(),
                      if (_selectedWordIndices.isNotEmpty) ...[
                        // Mode Selector: Marker Background vs Text Color
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _highlightType = 'marker'),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 7),
                                    decoration: BoxDecoration(
                                      color: _highlightType == 'marker' ? Colors.white : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: _highlightType == 'marker' ? [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.06),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1),
                                        ),
                                      ] : null,
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.brush,
                                          size: 14,
                                          color: _highlightType == 'marker' ? AppColors.primary : Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          'Marker Background',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: _highlightType == 'marker' ? FontWeight.bold : FontWeight.w500,
                                            color: _highlightType == 'marker' ? AppColors.primary : Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _highlightType = 'text'),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 7),
                                    decoration: BoxDecoration(
                                      color: _highlightType == 'text' ? Colors.white : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: _highlightType == 'text' ? [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.06),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1),
                                        ),
                                      ] : null,
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.format_color_text,
                                          size: 14,
                                          color: _highlightType == 'text' ? AppColors.primary : Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          'Text Color',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: _highlightType == 'text' ? FontWeight.bold : FontWeight.w500,
                                            color: _highlightType == 'text' ? AppColors.primary : Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_highlightType == 'marker') ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Book Highlighter Markers',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              Text(
                                '${_selectedWordIndices.length} word(s)',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildMarkerPresetsRow(),
                          const SizedBox(height: 10),
                          const Text(
                            'Custom Marker Color',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54),
                          ),
                          const SizedBox(height: 6),
                          _buildPaletteColorPicker(
                            _selectedWordIndices.isNotEmpty && _wordBgColors.containsKey(_selectedWordIndices.first)
                                ? _wordBgColors[_selectedWordIndices.first]!
                                : "#FFEE58",
                            (c) {
                              setState(() {
                                for (final idx in _selectedWordIndices) {
                                  _wordBgColors[idx] = c;
                                }
                              });
                              _autoSaveCurrentSettings();
                            },
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                for (final idx in _selectedWordIndices) {
                                  _wordBgColors.remove(idx);
                                }
                              });
                              _autoSaveCurrentSettings();
                            },
                            icon: const Icon(Icons.clear, size: 15, color: Colors.red),
                            label: const Text('Remove Marker on Selected', style: TextStyle(color: Colors.red, fontSize: 11.5)),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.red.shade200),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ] else ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Text Color for Selected Word(s)',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              Text(
                                '${_selectedWordIndices.length} word(s)',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildPaletteColorPicker(
                            _selectedWordIndices.isNotEmpty && _wordColors.containsKey(_selectedWordIndices.first)
                                ? _wordColors[_selectedWordIndices.first]!
                                : "#FFD700",
                            (c) {
                              setState(() {
                                for (final idx in _selectedWordIndices) {
                                  _wordColors[idx] = c;
                                }
                              });
                              _autoSaveCurrentSettings();
                            },
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                for (final idx in _selectedWordIndices) {
                                  _wordColors.remove(idx);
                                }
                              });
                              _autoSaveCurrentSettings();
                            },
                            icon: const Icon(Icons.clear, size: 15, color: Colors.red),
                            label: const Text('Reset Text Color on Selected', style: TextStyle(color: Colors.red, fontSize: 11.5)),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.red.shade200),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ],
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.touch_app, size: 16, color: Colors.grey),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Tap on word(s) above to apply book marker highlights or text colors.',
                                  style: TextStyle(fontSize: 11.5, color: Colors.black54),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ],
            ),
          ],
        );
      case 3: // Layout
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Box Layout', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('Box Style', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Plain Box')),
                    selected: _boxStyle == 'plain',
                    onSelected: (s) => setState(() => _boxStyle = 'plain'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Paper Cut Edge')),
                    selected: _boxStyle == 'paper_cut',
                    onSelected: (s) => setState(() => _boxStyle = 'paper_cut'),
                  ),
                ),
              ],
            ),
            if (_boxStyle == 'paper_cut') ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Paper Cut Roughness', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _paperCutSeed = DateTime.now().millisecondsSinceEpoch;
                      });
                    },
                    icon: const Icon(Icons.shuffle, size: 16),
                    label: const Text('Randomize'),
                  ),
                ],
              ),
              _buildControlSlider(
                label: 'Paper Cut Roughness',
                value: _paperCutRoughness,
                min: 0, max: 40,
                onChanged: (v) => setState(() => _paperCutRoughness = v),
              ),
              const SizedBox(height: 8),
              _buildControlSlider(
                label: 'Paper Cut Shadow Amount',
                value: _paperCutShadowAmount,
                min: 0, max: 40,
                onChanged: (v) => setState(() => _paperCutShadowAmount = v),
              ),
              const SizedBox(height: 12),
              const Text('Paper Cut Shadow Color', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildPaletteColorPicker(
                _paperCutShadowColor,
                (c) => setState(() => _paperCutShadowColor = c),
              ),
            ],
            const SizedBox(height: 16),
            _buildHeightPresetsSection(),
            const SizedBox(height: 12),
            _buildControlSlider(
              label: 'Box Height',
              value: _boxHeight.clamp(40.0, 400.0),
              min: 40, max: 400,
              onChanged: (v) => setState(() {
                _userBoxHeight = v;
                _boxHeight = v;
              }),
            ),
            const SizedBox(height: 8),
            _buildControlSlider(
              label: 'Text Scale',
              value: _textScale,
              min: 0.5, max: 2.0,
              onChanged: (v) {
                setState(() {
                  _textScale = v;
                  final minReq = _calculateDynamicBoxHeight(text: _textContent);
                  _boxHeight = math.max(_userBoxHeight, minReq);
                });
              },
            ),
            const SizedBox(height: 8),
            _buildControlSlider(
              label: 'Line Height',
              value: _lineHeight,
              min: 0.8, max: 2.5,
              onChanged: (v) {
                setState(() {
                  _lineHeight = v;
                  final minReq = _calculateDynamicBoxHeight(text: _textContent);
                  _boxHeight = math.max(_userBoxHeight, minReq);
                });
              },
            ),
            const SizedBox(height: 8),
            _buildControlSlider(
              label: 'Horizontal Padding',
              value: _horizontalPadding,
              min: 0, max: 100,
              onChanged: (v) => setState(() => _horizontalPadding = v),
            ),
            const SizedBox(height: 8),
            _buildControlSlider(
              label: 'Vertical Padding',
              value: _verticalPadding,
              min: 0, max: 100,
              onChanged: (v) {
                setState(() {
                  _verticalPadding = v;
                  final minReq = _calculateDynamicBoxHeight(text: _textContent);
                  _boxHeight = math.max(_userBoxHeight, minReq);
                });
              },
            ),
          ],
        );
      case 4: // Settings
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Export Quality', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _preset,
              decoration: const InputDecoration(labelText: 'FFmpeg Preset'),
              items: ['ultrafast', 'veryfast', 'fast', 'medium'].map((p) => 
                DropdownMenuItem(value: p, child: Text(p.toUpperCase()))
              ).toList(),
              onChanged: (v) => setState(() => _preset = v!),
            ),
            const SizedBox(height: 16),
            _buildControlSlider(
              label: 'Quality (CRF) - Lower is better',
              value: _crf,
              min: 18, max: 32,
              onChanged: (v) => setState(() => _crf = v),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Add App Outro (Logo)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('Appends 1.5s logo watermark at the end of the video', style: TextStyle(fontSize: 12, color: Colors.grey)),
              value: _addOutro,
              activeColor: AppColors.primary,
              onChanged: (v) => setState(() => _addOutro = v),
            ),
          ],
        );
      case 5: // Video
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Video Selection', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (_selectedVideo != null) ...[
              Text(
                'Current: ${_selectedVideo!.path.split('/').last}',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _selectVideo,
                icon: const Icon(Icons.video_library),
                label: Text(_selectedVideo == null ? 'Choose from Gallery' : 'Change Video'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            if (_videoHistory.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Recent Videos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _videoHistory.length,
                  itemBuilder: (context, index) {
                    final path = _videoHistory[index];
                    final thumbPath = _videoThumbnails[path];
                    final isSelected = _selectedVideo?.path == path;
                    
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedVideo = File(path);
                          _selectedImage = null;
                          _isImageInput = false;
                          _thumbnailPath = thumbPath;
                          _initializeVideoPlayer(_selectedVideo!);
                          _fetchVideoMetadata(path);
                        });
                      },
                      child: Container(
                        width: 60,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: isSelected ? Colors.indigo : Colors.grey.shade300, width: isSelected ? 2 : 1),
                          borderRadius: BorderRadius.circular(8),
                          image: thumbPath != null
                              ? DecorationImage(
                                  image: FileImage(File(thumbPath)),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: thumbPath == null ? const Icon(Icons.movie, color: Colors.grey) : null,
                      ),
                    );
                  },
                ),
              ),
            ],
            if (_selectedVideo != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _processVideo,
                  icon: const Icon(Icons.save),
                  label: const Text('Save'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        );
      case 6: // Image Opts
        return _buildImageToVideoTab();
      case 7: // Audio
        return _buildAudioTab();
      case 8: // Canvas
        return _buildCanvasTab();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildCanvasTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Canvas Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Builder(builder: (context) {
                  final isFramed = (_videoScale == 0.85 && _videoBorderWidth == 1.5 && _videoBorderColor.toUpperCase() == "#FFFFFF" && _bgColor == "#000000" && _bgImage == null);
                  return InkWell(
                    onTap: () {
                      setState(() {
                        if (isFramed) {
                          _videoScale = 1.0;
                          _videoBorderWidth = 0.0;
                        } else {
                          _videoScale = 0.85;
                          _videoBorderWidth = 1.5;
                          _videoBorderColor = "#FFFFFF";
                          _bgColor = "#000000";
                          _saveCurrentBgLayout();
                          _bgImage = null;
                          _gridImages.clear();
                          if (!_fullScreen && !_forceSquare) {
                            _fullScreen = true;
                          }
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isFramed ? Colors.cyan.withOpacity(0.12) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isFramed ? Colors.cyan : Colors.grey.shade300,
                          width: isFramed ? 1.4 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isFramed ? Icons.check : Icons.crop_free,
                            size: 13,
                            color: isFramed ? Colors.cyan.shade700 : Colors.grey.shade800,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '0.85x Frame',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isFramed ? Colors.cyan.shade800 : Colors.grey.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(width: 2),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20, color: Colors.grey),
                  tooltip: 'Reset Canvas',
                  onPressed: () {
                    setState(() {
                      _fullScreen = true;
                      _forceSquare = false;
                      _saveCurrentBgLayout();
                      _bgImage = null;
                      _gridImages.clear();
                      _gridGap = 0.0;
                      _bgColor = "#000000";
                      _bgBrightness = 1.0;
                      _bgSaturation = 1.0;
                      _bgBlur = 0.0;
                      _videoX = 0.5;
                      _videoY = 0.5;
                      _videoScale = 1.0;
                      _videoRadius = 0.0;
                      _videoBorderWidth = 0.0;
                      _videoBorderColor = "#FFFFFF";
                      _showVideoShadow = false;
                      _videoShadowColor = "#000000";
                      _videoShadowBlur = 10.0;
                      _videoShadowSpread = 0.0;
                      _videoShadowOffsetX = 0.0;
                      _videoShadowOffsetY = 0.0;
                    });
                    _autoSaveCurrentSettings();
                  },
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: '9:16', label: Text('9:16')),
              ButtonSegment(value: '1:1', label: Text('1:1')),
              ButtonSegment(value: 'original', label: Text('Original')),
            ],
            selected: {
              if (_fullScreen) '9:16'
              else if (_forceSquare) '1:1'
              else 'original'
            },
            onSelectionChanged: (Set<String> newSelection) {
              setState(() {
                final mode = newSelection.first;
                if (mode == '9:16') {
                  _fullScreen = true;
                  _forceSquare = false;
                } else if (mode == '1:1') {
                  _fullScreen = false;
                  _forceSquare = true;
                } else {
                  _fullScreen = false;
                  _forceSquare = false;
                }
              });
              _autoSaveCurrentSettings();
            },
            style: SegmentedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(child: _buildCanvasSubTabBtn(0, 'Background', Icons.wallpaper)),
              Expanded(child: _buildCanvasSubTabBtn(1, 'Video', Icons.video_call)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (_canvasSubTab == 0) ...[
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
                ? IconButton(
                    onPressed: () {
                      setState(() {
                        _saveCurrentBgLayout();
                        _bgImage = null;
                      });
                      _autoSaveCurrentSettings();
                    },
                    icon: const Icon(Icons.close, color: Colors.red),
                  )
                : const Icon(Icons.chevron_right),
            onTap: _pickBgImage,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade300)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _pickAndCreateGridBgImage(1),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.crop_square, size: 28, color: Colors.orange),
                        SizedBox(height: 8),
                        Text('1x1 Grid', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        Text('1 image', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => _pickAndCreateGridBgImage(2),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.grid_view, size: 28, color: Colors.blue),
                        SizedBox(height: 8),
                        Text('2x2 Grid', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        Text('4 images', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => _pickAndCreateGridBgImage(3),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.grid_on, size: 28, color: Colors.purple),
                        SizedBox(height: 8),
                        Text('3x3 Grid', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        Text('9 images', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_gridHistory.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Grid History', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              height: 70,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _gridHistory.length,
                itemBuilder: (context, index) {
                  final path = _gridHistory[index];
                  final isSelected = _bgImage?.path == path;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _saveCurrentBgLayout();
                        _bgImage = File(path);
                        _applyBgLayoutForImage(path);
                      });
                      _autoSaveCurrentSettings();
                    },
                    onLongPress: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Background'),
                          content: const Text('Remove this background image from history?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        try {
                          final f = File(path);
                          if (await f.exists()) await f.delete();
                        } catch (_) {}
                        if (mounted) {
                          setState(() {
                            _bgLayoutConfigs.remove(path);
                            _gridHistory.remove(path);
                            if (_bgImage?.path == path) {
                              _bgImage = null;
                            }
                          });
                          _autoSaveCurrentSettings();
                        }
                      }
                    },
                    child: Container(
                      width: 70,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: isSelected ? Colors.blue : Colors.grey.shade300, width: isSelected ? 2 : 1),
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: FileImage(File(path)),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          if (_gridImages.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Grid Gap', style: TextStyle(fontWeight: FontWeight.bold)),
                Switch(
                  value: _gridGap > 0,
                  onChanged: (v) {
                    setState(() => _gridGap = v ? (_gridGap == 0 ? 5.0 : _gridGap) : 0.0);
                    _generateGridBgImage();
                  },
                ),
              ],
            ),
            if (_gridGap > 0) ...[
              _buildCanvasControlSlider(
                label: 'Gap Width',
                value: _gridGap,
                min: 0.0,
                max: 20.0,
                onChanged: (v) {
                  setState(() => _gridGap = v);
                  _generateGridBgImage();
                },
              ),
              const SizedBox(height: 12),
              const Text('Grid Gap Color', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              _buildPaletteColorPicker(_gridGapColor, (c) {
                setState(() => _gridGapColor = c);
                _generateGridBgImage();
              }),
            ],
          ],
          if (_bgImage == null) ...[
            const SizedBox(height: 20),
            const Text('Background Color', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildPaletteColorPicker(_bgColor, (c) => setState(() => _bgColor = c)),
          ] else ...[
            const SizedBox(height: 16),
            _buildCanvasControlSlider(
              label: 'Brightness',
              value: _bgBrightness,
              min: 0.0,
              max: 2.0,
              onChanged: (v) => setState(() => _bgBrightness = v),
            ),
            _buildCanvasControlSlider(
              label: 'Saturation',
              value: _bgSaturation,
              min: 0.0,
              max: 2.0,
              onChanged: (v) => setState(() => _bgSaturation = v),
            ),
            _buildCanvasControlSlider(
              label: 'Blur',
              value: _bgBlur,
              min: 0.0,
              max: 100.0,
              onChanged: (v) => setState(() => _bgBlur = v),
            ),
          ],
        ],
        if (_canvasSubTab == 1) ...[
          const Text('Video Placement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          _buildCanvasControlSlider(
            label: 'Horizontal Alignment (X)',
            value: _videoX,
            min: 0.0,
            max: 1.0,
            onChanged: (v) => setState(() => _videoX = v),
          ),
          _buildCanvasControlSlider(
            label: 'Vertical Alignment (Y)',
            value: _videoY,
            min: 0.0,
            max: 1.0,
            onChanged: (v) => setState(() => _videoY = v),
          ),
          const SizedBox(height: 16),
          _buildCanvasControlSlider(
            label: 'Video Scale',
            value: _videoScale,
            min: 0.1,
            max: 3.0,
            onChanged: (v) => setState(() => _videoScale = v),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Corner Radius', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Switch(
                value: _videoRadius > 0,
                onChanged: (v) => setState(() => _videoRadius = v ? (_videoRadius == 0 ? 12.0 : _videoRadius) : 0.0),
              ),
            ],
          ),
          if (_videoRadius > 0) ...[
            _buildCanvasControlSlider(
              label: 'Radius Value',
              value: _videoRadius,
              min: 0.0,
              max: 200.0,
              onChanged: (v) => setState(() => _videoRadius = v),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Video Border', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Switch(
                value: _videoBorderWidth > 0,
                onChanged: (v) => setState(() => _videoBorderWidth = v ? (_videoBorderWidth == 0 ? 2.5 : _videoBorderWidth) : 0.0),
              ),
            ],
          ),
          if (_videoBorderWidth > 0) ...[
            _buildCanvasControlSlider(
              label: 'Border Width',
              value: _videoBorderWidth,
              min: 0.0,
              max: 10.0,
              onChanged: (v) => setState(() => _videoBorderWidth = v),
            ),
            const SizedBox(height: 12),
            const Text('Border Color', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            _buildPaletteColorPicker(_videoBorderColor, (c) => setState(() => _videoBorderColor = c)),
          ],
          const SizedBox(height: 16),
          _buildCanvasShadowSection(
            title: 'Video Drop Shadow',
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
        ],
      ],
    );
  }

  Widget _buildColorSubTabButton(int index, String label, IconData icon) {
    final isSelected = _selectedColorSubTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedColorSubTab = index),
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
                  fontSize: 11,
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

  Widget _buildCanvasSubTabBtn(int index, String label, IconData icon) {
    final isActive = _canvasSubTab == index;
    return GestureDetector(
      onTap: () => setState(() => _canvasSubTab = index),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isActive ? [const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))] : [],
        ),
        margin: const EdgeInsets.all(4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isActive ? AppColors.primary : Colors.grey),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? AppColors.primary : Colors.grey,
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildCanvasControlSlider({
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
        _buildCanvasSliderWithButtons(
          value: value,
          min: min,
          max: max,
          onChanged: onChanged,
          step: step,
        ),
      ],
    );
  }

  Widget _buildCanvasSliderWithButtons({
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
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onChanged((value - increment).clamp(min, max)),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: activeColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.remove, size: 16, color: activeColor),
            ),
          ),
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
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onChanged((value + increment).clamp(min, max)),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: activeColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.add, size: 16, color: activeColor),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCanvasShadowSection({
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
          _buildPaletteColorPicker(shadowColor, onColorChanged),
          const SizedBox(height: 16),
          Text('Blur Radius: ${blur.toInt()}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          _buildCanvasSliderWithButtons(value: blur, min: 0, max: 20, onChanged: onBlurChanged),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Text('X', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    Expanded(child: _buildCanvasSliderWithButtons(value: offsetX, min: -20, max: 20, onChanged: onOffsetXChanged)),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    const Text('Y', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    Expanded(child: _buildCanvasSliderWithButtons(value: offsetY, min: -20, max: 20, onChanged: onOffsetYChanged)),
                  ],
                ),
              ),
            ],
          ),
          if (spread != null && onSpreadChanged != null) ...[
            const SizedBox(height: 8),
            Text('Spread Radius: ${spread.toInt()}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            _buildCanvasSliderWithButtons(value: spread, min: -20, max: 20, onChanged: onSpreadChanged),
          ],
        ],
      ],
    );
  }

  Widget _buildPaletteColorPicker(String currentColor, Function(String) onPick) {
    final colors = ['#FFFFFF', '#000000', '#FFD700', '#FF4444', '#00E676', '#2979FF', '#FF4081', '#AA00FF'];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        GestureDetector(
          onTap: () async {
            Color selectedColor = _parseHexColor(currentColor, Colors.black);
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
              color: _parseHexColor(c, Colors.black),
              shape: BoxShape.circle,
              border: Border.all(
                color: currentColor.toUpperCase() == c.toUpperCase() ? AppColors.primary : Colors.grey.shade300,
                width: currentColor.toUpperCase() == c.toUpperCase() ? 3 : 2,
              ),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
          ),
        )),
      ],
    );
  }

  static const List<Map<String, String>> _bookMarkerPresets = [
    {'name': 'Yellow', 'hex': '#FFEE58', 'dot': '#FBC02D'},
    {'name': 'Green', 'hex': '#A7F3D0', 'dot': '#10B981'},
    {'name': 'Blue', 'hex': '#BAE6FD', 'dot': '#0EA5E9'},
    {'name': 'Pink', 'hex': '#FBCFE8', 'dot': '#EC4899'},
    {'name': 'Orange', 'hex': '#FED7AA', 'dot': '#F97316'},
    {'name': 'Purple', 'hex': '#E9D5FF', 'dot': '#A855F7'},
  ];

  Widget _buildMarkerPresetsRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _bookMarkerPresets.map((preset) {
          final hex = preset['hex']!;
          final name = preset['name']!;
          final dotColor = _parseHexColor(preset['dot']!, Colors.amber);
          final markerColor = _parseHexColor(hex, Colors.yellow);
          final isSelected = _selectedWordIndices.isNotEmpty &&
              _selectedWordIndices.every((idx) => _wordBgColors[idx] == hex);

          return Padding(
            padding: const EdgeInsets.only(right: 6.0),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    for (final idx in _selectedWordIndices) {
                      _wordBgColors[idx] = hex;
                    }
                  });
                  _autoSaveCurrentSettings();
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5.5),
                  decoration: BoxDecoration(
                    color: markerColor.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : markerColor,
                      width: isSelected ? 2.0 : 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: dotColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: Colors.black87,
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
    );
  }

  TextSpan _buildWordColoredTextSpan({
    required String text,
    required Map<int, String> wordColors,
    required Map<int, String> wordBgColors,
    required Color defaultColor,
    double textOpacity = 1.0,
    required double fontSize,
    required String? fontFamily,
    required double height,
    required bool showShadow,
    required Color shadowColor,
    required Offset shadowOffset,
    required double shadowBlur,
  }) {
    if (text.isEmpty) return const TextSpan();
    final double safeOpacity = textOpacity.clamp(0.0, 1.0);
    
    final RegExp regex = RegExp(r'(\S+)|(\s+)');
    final matches = regex.allMatches(text).toList();
    
    final List<int> matchWordIndices = List.filled(matches.length, -1);
    int currentWordCount = 0;
    for (int i = 0; i < matches.length; i++) {
      if (matches[i].group(0)!.trim().isNotEmpty) {
        matchWordIndices[i] = currentWordCount++;
      }
    }
    
    final List<TextSpan> children = [];
    
    for (int i = 0; i < matches.length; i++) {
      final str = matches[i].group(0)!;
      final isWord = matchWordIndices[i] != -1;
      
      Color color = defaultColor;
      Color? bgColor;
      
      if (isWord) {
        final wordIdx = matchWordIndices[i];
        if (wordColors.containsKey(wordIdx)) {
          color = _parseHexColor(wordColors[wordIdx]!, defaultColor);
        }
        if (wordBgColors.containsKey(wordIdx)) {
          bgColor = _parseHexColor(wordBgColors[wordIdx]!, Colors.yellow);
          // If no custom text color is set for this word, optimize contrast for authentic book marker look
          if (!wordColors.containsKey(wordIdx)) {
            if (bgColor.computeLuminance() > 0.45 && defaultColor.computeLuminance() > 0.55) {
              color = Colors.black87;
            } else if (bgColor.computeLuminance() <= 0.45 && defaultColor.computeLuminance() <= 0.45) {
              color = Colors.white;
            }
          }
        }
      } else {
        // Match is whitespace.
        // Connect consecutive words sharing the same marker color for a continuous book highlighter stroke!
        if (!str.contains('\n')) {
          int prevWordIdx = -1;
          for (int p = i - 1; p >= 0; p--) {
            if (matchWordIndices[p] != -1) {
              prevWordIdx = matchWordIndices[p];
              break;
            }
          }
          int nextWordIdx = -1;
          for (int n = i + 1; n < matches.length; n++) {
            if (matchWordIndices[n] != -1) {
              nextWordIdx = matchWordIndices[n];
              break;
            }
          }
          if (prevWordIdx != -1 && nextWordIdx != -1) {
            final prevBg = wordBgColors[prevWordIdx];
            final nextBg = wordBgColors[nextWordIdx];
            if (prevBg != null && prevBg == nextBg) {
              bgColor = _parseHexColor(prevBg, Colors.yellow);
            }
          }
        }
      }
      
      final Color effectiveColor = color.withValues(alpha: (color.a * safeOpacity).clamp(0.0, 1.0));
      final Color effectiveShadowColor =
          shadowColor.withValues(alpha: (shadowColor.a * safeOpacity).clamp(0.0, 1.0));

      children.add(
        TextSpan(
          text: str,
          style: TextStyle(
            color: effectiveColor,
            backgroundColor: bgColor,
            fontSize: fontSize,
            fontFamily: fontFamily,
            height: height,
            shadows: (showShadow && bgColor == null) ? [
              Shadow(
                color: effectiveShadowColor,
                offset: shadowOffset,
                blurRadius: shadowBlur,
              )
            ] : null,
          ),
        ),
      );
    }
    
    return TextSpan(children: children);
  }

  Widget _buildColorOption(String title, String hexColor, bool isText) {
    return Row(
      children: [
        Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold))),
        GestureDetector(
          onTap: () => _pickColor(isText: isText),
          child: Container(
            width: 80,
            height: 36,
            decoration: BoxDecoration(
              color: _parseHexColor(hexColor, Colors.grey),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Center(
              child: Text(
                hexColor,
                style: TextStyle(
                  fontSize: 10,
                  color: _parseHexColor(hexColor, Colors.grey).computeLuminance() > 0.5 ? Colors.black : Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWordSelectionChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Select words to highlight:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
            if (_textContent.trim().isNotEmpty)
              Builder(
                builder: (context) {
                  final regex = RegExp(r'(\S+)');
                  final count = regex.allMatches(_textContent).length;
                  final allSelected = count > 0 && _selectedWordIndices.length == count;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (allSelected) {
                          _selectedWordIndices.clear();
                        } else {
                          _selectedWordIndices = List.generate(count, (i) => i).toSet();
                        }
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text(
                        allSelected ? 'Deselect All' : 'Select All',
                        style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
        const SizedBox(height: 8),
        Builder(
          builder: (context) {
            final regex = RegExp(r'(\S+)|(\s+)');
            final matches = regex.allMatches(_textContent).toList();
            int wordIdx = 0;
            final List<Widget> chips = [];
            for (final match in matches) {
              final str = match.group(0)!;
              final isWhitespace = str.trim().isEmpty;
              if (!isWhitespace) {
                final currentIdx = wordIdx;
                final isSelected = _selectedWordIndices.contains(currentIdx);
                final wordColor = _wordColors[currentIdx];
                final wordBgColor = _wordBgColors[currentIdx];
                final hasMarker = wordBgColor != null;

                chips.add(
                  FilterChip(
                    showCheckmark: false,
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
                    backgroundColor: hasMarker
                        ? _parseHexColor(wordBgColor, Colors.yellow).withOpacity(0.3)
                        : null,
                    selectedColor: hasMarker
                        ? _parseHexColor(wordBgColor, Colors.yellow).withOpacity(0.55)
                        : AppColors.primary.withOpacity(0.2),
                    side: BorderSide(
                      color: isSelected
                          ? AppColors.primary
                          : (hasMarker ? _parseHexColor(wordBgColor, Colors.yellow) : Colors.grey.shade300),
                      width: isSelected ? 1.8 : 1.0,
                    ),
                    label: Text(
                      str,
                      style: TextStyle(
                        color: wordColor != null
                            ? _parseHexColor(wordColor, Colors.black)
                            : (hasMarker ? Colors.black87 : null),
                        fontSize: 12,
                        fontWeight: (hasMarker || isSelected) ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (val) {
                      setState(() {
                        if (val) _selectedWordIndices.add(currentIdx);
                        else _selectedWordIndices.remove(currentIdx);
                      });
                    },
                  ),
                );
                wordIdx++;
              }
            }
            return Wrap(spacing: 5, runSpacing: 4, children: chips);
          },
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildProcessingOverlay() {
    final mediaName = _selectedVideo != null
        ? _selectedVideo!.path.split('/').last
        : (_selectedImage != null ? _selectedImage!.path.split('/').last : '');

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
              if (mediaName.isNotEmpty)
                Text(
                  mediaName,
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
                          duration: const Duration(milliseconds: 300),
                          width: constraints.maxWidth * _progress.clamp(0.0, 1.0),
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
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(_progress * 100).toInt()}% Estimated',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF00796B)),
                  ),
                  Expanded(
                    child: Text(
                      _status,
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w500),
                    ),
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

  Future<String?> _generateBoxImage(double width, double height) async {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      
      if (_boxStyle == 'paper_cut') {
        final painter = TornPaperPainter(
          color: _parseHexColor(_boxColor, Colors.white).withOpacity(_boxOpacity),
          isTop: _textBoxPosition == 'top',
          roughness: _paperCutRoughness,
          seed: _paperCutSeed,
          shadowPadding: _paperCutShadowAmount,
          shadowColor: _parseHexColor(_paperCutShadowColor, Colors.black).withOpacity(0.5),
        );
        painter.paint(canvas, Size(width, height));
      } else {
        final paint = Paint()..color = _parseHexColor(_boxColor, Colors.white).withOpacity(_boxOpacity);
        canvas.drawRect(Rect.fromLTWH(0, 0, width, height), paint);
      }
      
      if (_textContent.isNotEmpty) {
        final fontSize = _fontSize * _textScale;
        final span = _buildWordColoredTextSpan(
          text: _textContent,
          wordColors: _wordColors,
          wordBgColors: _wordBgColors,
          defaultColor: _parseHexColor(_textColor, Colors.black),
          textOpacity: _textOpacity,
          fontSize: fontSize,
          fontFamily: _selectedFont?.family,
          height: _lineHeight,
          showShadow: _showTextShadow,
          shadowColor: _parseHexColor(_shadowColor, Colors.black).withOpacity(0.5),
          shadowOffset: Offset(_shadowX, _shadowY),
          shadowBlur: 0.0,
        );
        
        TextAlign textAlign;
        if (_hAlign == 'left') textAlign = TextAlign.left;
        else if (_hAlign == 'right') textAlign = TextAlign.right;
        else textAlign = TextAlign.center;
        
        final textPainter = TextPainter(
          text: span,
          textAlign: textAlign,
          textDirection: ui.TextDirection.ltr,
        );
        
        final maxTextWidth = width - (_horizontalPadding * 2);
        textPainter.layout(maxWidth: maxTextWidth);
        
        final overlapAmount = _boxStyle == 'paper_cut' ? _paperCutRoughness + _paperCutShadowAmount : 0;
        
        double textY = _verticalPadding;
        final availableHeight = height - (_verticalPadding * 2) - overlapAmount;
        if (_vAlign == 'middle') {
          textY = _verticalPadding + (availableHeight - textPainter.height) / 2;
        } else if (_vAlign == 'bottom') {
          textY = height - _verticalPadding - overlapAmount - textPainter.height;
        }
        
        if (_textBoxPosition == 'bottom' && _boxStyle == 'paper_cut') {
           textY += overlapAmount;
        }

        double textX = _horizontalPadding;
        if (_hAlign == 'center') {
          textX = _horizontalPadding + (maxTextWidth - textPainter.width) / 2;
        } else if (_hAlign == 'right') {
          textX = width - _horizontalPadding - textPainter.width;
        }
        
        textPainter.paint(canvas, Offset(textX, textY));
      }
      
      final picture = recorder.endRecording();
      final image = await picture.toImage(width.toInt(), height.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData == null) return null;
      
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/box_image_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      return file.path;
    } catch (e) {
      debugPrint('Error generating box image: $e');
      return null;
    }
  }
  Future<void> _saveHeightPresets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'textbox_height_presets',
        _heightPresets.map((e) => e.toString()).toList(),
      );
    } catch (e) {
      debugPrint('Error saving height presets: $e');
    }
  }

  void _applyHeightPreset(double height) {
    setState(() {
      _userBoxHeight = height;
      _boxHeight = height;
    });
    _autoSaveCurrentSettings();
  }

  void _saveCurrentHeightToPreset(int index) {
    if (index < 0 || index >= _heightPresets.length) return;
    final currentVal = _boxHeight.roundToDouble().clamp(40.0, 400.0);
    setState(() {
      _heightPresets[index] = currentVal;
    });
    _saveHeightPresets();
    _showToast('Preset ${index + 1} set to ${currentVal.toInt()}px');
  }

  void _showEditHeightPresetsDialog() {
    final controllers = List.generate(
      4,
      (i) => TextEditingController(text: _heightPresets[i].toInt().toString()),
    );

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: const [
                Icon(Icons.straighten, color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Text(
                  'Height Presets (Max 4)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Customize up to 4 quick height presets (40px - 400px) for consistent text box sizing across posts.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 14),
                  ...List.generate(4, (i) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'P${i + 1}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: controllers[i],
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: InputDecoration(
                                suffixText: 'px',
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () {
                              setDialogState(() {
                                controllers[i].text = _boxHeight.toInt().toString();
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              'Use ${_boxHeight.toInt()}px',
                              style: const TextStyle(fontSize: 10.5),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                      final defaults = [80.0, 120.0, 160.0, 220.0];
                      for (int i = 0; i < 4; i++) {
                        controllers[i].text = defaults[i].toInt().toString();
                      }
                      setDialogState(() {});
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Defaults', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogCtx).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Cancel', style: TextStyle(color: Colors.black87, fontSize: 13)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          final newPresets = <double>[];
                          for (int i = 0; i < 4; i++) {
                            final val = double.tryParse(controllers[i].text) ?? _heightPresets[i];
                            newPresets.add(val.clamp(40.0, 400.0));
                          }
                          setState(() {
                            _heightPresets = newPresets;
                          });
                          _saveHeightPresets();
                          Navigator.of(dialogCtx).pop();
                          _showToast('Height presets saved');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        child: const Text('Save', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeightPresetsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.straighten, size: 15, color: AppColors.primary),
                const SizedBox(width: 6),
                const Text(
                  'Height Presets',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Max 4',
                    style: TextStyle(fontSize: 9.5, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            InkWell(
              onTap: _showEditHeightPresetsDialog,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.tune, size: 13, color: AppColors.primary),
                    SizedBox(width: 4),
                    Text(
                      'Customize',
                      style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(4, (index) {
            final presetHeight = _heightPresets[index];
            final isSelected = (_boxHeight - presetHeight).abs() < 1.0;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: index == 0 ? 0 : 3.0,
                  right: index == 3 ? 0 : 3.0,
                ),
                child: InkWell(
                  onTap: () => _applyHeightPreset(presetHeight),
                  onLongPress: () => _saveCurrentHeightToPreset(index),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary.withOpacity(0.12) : const Color(0xFFF1F5F9),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : Colors.grey.shade300,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${presetHeight.toInt()}px',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected ? AppColors.primary : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'P${index + 1}',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? AppColors.primary : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Tap to apply • Long-press to save current (${_boxHeight.toInt()}px)',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
            InkWell(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  builder: (sheetCtx) => SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Save Current Height (${_boxHeight.toInt()}px) to Slot',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () => Navigator.of(sheetCtx).pop(),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: List.generate(4, (i) {
                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 3),
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.of(sheetCtx).pop();
                                      _saveCurrentHeightToPreset(i);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: Text('Slot ${i + 1}\n(${_heightPresets[i].toInt()}px)', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
                                  ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                child: Text(
                  'Save to slot...',
                  style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
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
    int divisions = 100,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text(value.toStringAsFixed(1), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: Colors.grey.shade300,
            thumbColor: AppColors.primary,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  String _getFormattedDate(bool includeWeekday) {
    final now = DateTime.now();
    final months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    
    final month = months[now.month - 1];
    final date = now.day;
    final year = now.year;
    
    if (includeWeekday) {
      final weekday = weekdays[now.weekday - 1];
      return '$month $date, $year\n$weekday';
    } else {
      return '$month $date, $year';
    }
  }
}

class TornPaperPainter extends CustomPainter {
  final Color color;
  final bool isTop;
  final double roughness;
  final int seed;
  final double shadowPadding;
  final Color shadowColor;

  TornPaperPainter({
    required this.color,
    required this.isTop,
    required this.roughness,
    required this.seed,
    this.shadowPadding = 0.0,
    this.shadowColor = const Color(0x80000000), // Default semi-transparent black
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final random = math.Random(seed);
    
    if (isTop) {
      // Box is at the top, torn edge is at the bottom
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      
      // Draw torn edge from right to left at the bottom
      final segments = 50;
      final segmentWidth = size.width / segments;
      
      for (int i = segments; i >= 0; i--) {
        final x = i * segmentWidth;
        final y = size.height - shadowPadding - random.nextDouble() * roughness;
        path.lineTo(x, y);
      }
      
      path.lineTo(0, 0);
    } else {
      // Box is at the bottom, torn edge is at the top
      // Draw torn edge from left to right at the top
      final segments = 50;
      final segmentWidth = size.width / segments;
      
      path.moveTo(0, size.height);
      path.lineTo(0, shadowPadding + random.nextDouble() * roughness);
      
      for (int i = 0; i <= segments; i++) {
        final x = i * segmentWidth;
        final y = shadowPadding + random.nextDouble() * roughness;
        path.lineTo(x, y);
      }
      
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
    }
    
    path.close();

    if (shadowPadding > 0) {
      final shadowBlur = shadowPadding * 0.3;
      final shadowPaint = Paint()
        ..color = shadowColor
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadowBlur);
      
      final shadowOffset = isTop ? Offset(0, shadowPadding * 0.2) : Offset(0, -shadowPadding * 0.2);
      canvas.drawPath(path.shift(shadowOffset), shadowPaint);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant TornPaperPainter oldDelegate) {
    return oldDelegate.color != color || 
           oldDelegate.isTop != isTop ||
           oldDelegate.roughness != roughness ||
           oldDelegate.seed != seed;
  }
}
