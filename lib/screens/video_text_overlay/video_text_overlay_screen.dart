import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import '../video_creator/widgets/audio_selector_widget.dart';
import '../../services/analytics_service.dart';
import '../../utils/font_selector.dart';

class VideoTextOverlayScreen extends StatefulWidget {
  final List<String>? sharedVideoPaths;

  const VideoTextOverlayScreen({Key? key, this.sharedVideoPaths}) : super(key: key);

  @override
  State<VideoTextOverlayScreen> createState() => _VideoTextOverlayScreenState();
}

class _VideoTextOverlayScreenState extends State<VideoTextOverlayScreen> {
  File? _selectedAudio;
  String? _audioDuration;
  bool _isPlayingAudio = false;

  static const platform = MethodChannel('com.quickpost.app/processor');
  
  File? _selectedVideo;
  VideoPlayerController? _videoController;
  double _videoAspectRatio = 16 / 9;
  int _videoWidth = 1080;
  int _videoHeight = 1920;
  bool _isProcessing = false;
  bool _isMuted = false;
  double _progress = 0.0;
  String? _outputPath;
  Timer? _progressTimer;
  
  double _audioVolume = 1.0;
  bool _loopAudio = true;
  
  int _selectedTabIndex = 0;
  bool _isTabContentExpanded = false;
  
  String _textContent = "Your text here...";
  FontInfo? _selectedFont;
  double _fontSize = 40.0;
  double _boxHeight = 80.0;
  String _textColor = "#FFFFFF";
  String _boxColor = "#FFFFFF";
  double _boxOpacity = 0.0;
  bool _showTextShadow = false;
  double _shadowX = 2.0;
  double _shadowY = 2.0;
  String _shadowColor = "#000000";
  double _textOpacity = 1.0;
  double _textX = 0.5; // Normalized 0.0 to 1.0
  double _textY = 0.5; // Normalized 0.0 to 1.0
  bool _isDragging = false;
  double _horizontalPadding = 12.0;
  double _verticalPadding = 8.0;
  double _textScale = 1.0;
  double _lineHeight = 1.2;
  String _hAlign = 'center';
  String _vAlign = 'middle';
  
  String _preset = 'veryfast';
  double _crf = 23.0;
  
  final TextEditingController _textController = TextEditingController();
  final Map<String, String> _fontFileCache = {};

  Future<String?> _findFontAssetForFamily(String family) async {
    try {
      final manifestJson = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifest = jsonDecode(manifestJson) as Map<String, dynamic>;

      final lowerFamily = family.toLowerCase();
      String? best;

      for (final key in manifest.keys) {
        if (!key.toLowerCase().startsWith('assets/fonts/')) continue;
        final lowerKey = key.toLowerCase();
        if (!(lowerKey.endsWith('.ttf') || lowerKey.endsWith('.otf'))) continue;

        final fileName = lowerKey.split('/').last;
        final normalized = fileName
            .replaceAll('-', '')
            .replaceAll('_', '')
            .replaceAll(' ', '');
        final normalizedFamily = lowerFamily
            .replaceAll('-', '')
            .replaceAll('_', '')
            .replaceAll(' ', '');

        if (normalized == '${normalizedFamily}.ttf' || normalized == '${normalizedFamily}.otf') {
          return key;
        }

        if (best == null && normalized.contains(normalizedFamily)) {
          best = key;
        }
      }

      return best;
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedFont = FontInfo(family: 'Metrophobic', displayName: 'Metrophobic');
    _textController.text = _textContent;
    _setupMethodCallHandler();
    _handleSharedVideos();
    AnalyticsService().setCurrentScreen(screenName: 'Video Text');
  }

  void _setupMethodCallHandler() {
    platform.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onProgress':
          if (mounted) setState(() => _progress = call.arguments as double);
          break;
        case 'onAudioComplete':
          if (mounted) setState(() => _isPlayingAudio = false);
          break;
      }
    });
  }

  @override
  void didUpdateWidget(covariant VideoTextOverlayScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sharedVideoPaths != oldWidget.sharedVideoPaths) {
      debugPrint('[VideoTextOverlay] sharedVideoPaths updated in didUpdateWidget');
      _handleSharedVideos();
    }
  }

  void _handleSharedVideos() {
    if (widget.sharedVideoPaths != null && widget.sharedVideoPaths!.isNotEmpty) {
      final path = widget.sharedVideoPaths!.first;
      debugPrint('[VideoTextOverlay] Handling shared video: $path');
      
      final file = File(path);
      if (file.existsSync()) {
        if (mounted) {
          setState(() {
            _selectedVideo = file;
            _thumbnailPath = null;
            _outputPath = null;
          });
          debugPrint('[VideoTextOverlay] Shared video state updated: ${file.path}');
          _initializeVideoPlayer(file);
          _fetchVideoMetadata(path);
        }
      } else {
        debugPrint('[VideoTextOverlay] Shared video file does not exist: $path');
      }
    }
  }

  Future<void> _initializeVideoPlayer(File videoFile) async {
    debugPrint('[VideoTextOverlay] Initializing video player for: ${videoFile.path}');
    
    // Dispose previous controller before creating new one
    if (_videoController != null) {
      await _videoController!.pause();
      await _videoController!.dispose();
      _videoController = null;
    }
    
    final controller = VideoPlayerController.file(videoFile);
    _videoController = controller;
    
    try {
      await controller.initialize();
      controller.setLooping(true);
      controller.play();
      controller.addListener(() {
        if (mounted) setState(() {});
      });
      
      if (mounted) {
        setState(() {
          _videoAspectRatio = controller.value.aspectRatio;
          if (_selectedVideo != null)
            Positioned(
              top: 10,
              right: 10,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.swap_horiz, color: Colors.white),
                    onPressed: _selectVideo,
                    tooltip: 'Replace Video',
                    style: IconButton.styleFrom(backgroundColor: Colors.black54),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () {
                      setState(() {
                        _selectedVideo = null;
                        _videoController?.dispose();
                        _videoController = null;
                      });
                    },
                    tooltip: 'Remove Video',
                    style: IconButton.styleFrom(backgroundColor: Colors.black54),
                  ),
                ],
              ),
            );
        });
      }
      debugPrint('[VideoTextOverlay] Video initialized. Aspect ratio: $_videoAspectRatio');
    } catch (e) {
      debugPrint('[VideoTextOverlay] Error initializing video player: $e');
    }
  }

  Future<void> _fetchVideoMetadata(String videoPath) async {
    try {
      final metadata = await platform.invokeMethod<Map>('getVideoMetadata', {'videoPath': videoPath});
      if (metadata != null && mounted) {
        setState(() {
          _videoWidth = metadata['width'] as int? ?? 1080;
          _videoHeight = metadata['height'] as int? ?? 1920;
        });
      }
    } catch (e) {
      debugPrint('Error fetching metadata: $e');
    }
  }

  Future<void> _selectVideo() async {
    debugPrint('[VideoTextOverlay] _selectVideo called');
    try {
      final picker = ImagePicker();
      final XFile? video = await picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 10),
      );
      
      if (video != null) {
        debugPrint('[VideoTextOverlay] Video picked: ${video.path}');
        final file = File(video.path);
        
        // CRITICAL: Ensure we update state immediately and initialize
        if (mounted) {
          setState(() {
            _selectedVideo = file;
            _thumbnailPath = null;
            _outputPath = null;
          });
          debugPrint('[VideoTextOverlay] State updated with video file: ${file.path}');
          
          // Re-verify file exists just in case
          if (await file.exists()) {
            _initializeVideoPlayer(file);
            _fetchVideoMetadata(video.path);
          } else {
            debugPrint('[VideoTextOverlay] ERROR: Picked file does not exist after setState');
          }
        }
      } else {
        debugPrint('[VideoTextOverlay] No video picked (user cancelled)');
      }
    } catch (e) {
      debugPrint('[VideoTextOverlay] Exception during video pick: $e');
      _showErrorDialog('Picker Error', e.toString());
    }
  }

  String? _thumbnailPath;

  @override
  void dispose() {
    _progressTimer?.cancel();
    _textController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<String> _getSelectedFontPath() async {
    if (_selectedFont == null) return '/system/fonts/Roboto-Regular.ttf';
    
    final cached = _fontFileCache[_selectedFont!.family];
    if (cached != null) return cached;

    final path = await FontInfo.getFontFilePath(_selectedFont!);
    _fontFileCache[_selectedFont!.family] = path;
    return path;
  }

  Future<void> _processVideo() async {
    if (_selectedVideo == null) return;
    AnalyticsService().logSaveAction(feature: 'video_text', type: 'video');
    setState(() { _isProcessing = true; _progress = 0.0; });
    
    _progressTimer?.cancel();
    final startTime = DateTime.now();
    const estimatedDuration = Duration(seconds: 20);
    _progressTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!_isProcessing) { timer.cancel(); return; }
      final elapsed = DateTime.now().difference(startTime);
      final ratio = elapsed.inMilliseconds / estimatedDuration.inMilliseconds;
      setState(() { _progress = ratio.clamp(0.0, 0.99); });
    });

    try {
      final outputPath = await platform.invokeMethod<String>('getVideoOutputPath', {
        'filename': 'VideoOverlay_${DateTime.now().millisecondsSinceEpoch}.mp4',
      });
      if (outputPath == null) throw Exception('Failed to get output path');

      final String fontPath = await _getSelectedFontPath();
      final fontFile = File(fontPath);
      final fontExists = await fontFile.exists();
      final fontSizeBytes = fontExists ? await fontFile.length() : -1;
      debugPrint('[VideoTextOverlay] Export selectedFamily=${_selectedFont?.family} fontPath=$fontPath exists=$fontExists size=$fontSizeBytes');

      final previewWidth = _videoWidth; // Use the same base for scaling
      final scaleFactor = _videoWidth / 360.0; // Assume 360 as a base preview width for offset scaling

      final params = {
        'inputPath': _selectedVideo!.path,
        'outputPath': outputPath,
        'text': _textContent,
        'x': (_textX * _videoWidth).toInt(),
        'y': (_textY * _videoHeight).toInt(),
        'fontSize': (_fontSize * _textScale).toInt(),
        'fontColor': _textColor,
        'fontPath': fontPath,
        'preset': _preset,
        'crf': _crf.toInt(),
        'audioPath': _selectedAudio?.path,
        'audioVolume': _audioVolume,
        'loopAudio': _loopAudio,
        'hAlign': _hAlign,
        'vAlign': _vAlign,
        'lineHeight': _lineHeight,
        'showShadow': _showTextShadow,
        'shadowColor': _shadowColor,
        'shadowX': (_shadowX * scaleFactor).toInt(),
        'shadowY': (_shadowY * scaleFactor).toInt(),
        'boxColor': _boxColor,
        'boxOpacity': _boxOpacity,
        'textOpacity': _textOpacity,
      };

      final result = await platform.invokeMethod<String>('addTextToVideoNew', params);
      _progressTimer?.cancel();
      setState(() { _isProcessing = false; _outputPath = result ?? outputPath; _progress = 1.0; });
      _showSuccessDialog();
    } catch (e) {
      _progressTimer?.cancel();
      setState(() { _isProcessing = false; });
      _showErrorDialog('Failed', e.toString());
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Success'),
        content: Text('Video saved successfully'),
        actions: [
          TextButton(onPressed: () { Navigator.pop(context); OpenFile.open(_outputPath!); }, child: const Text('Open')),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(context: context, builder: (context) => AlertDialog(title: Text(title), content: Text(message), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))]));
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
                Expanded(child: _buildPreviewArea()),
                if (_selectedVideo != null) ...[
                  if (_isTabContentExpanded) _buildActiveTabContent(),
                  _buildControlTabs(),
                ],
              ],
            ),
            if (_isProcessing) _buildProcessingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewArea() {
    debugPrint('[VideoTextOverlay] _buildPreviewArea: _selectedVideo is ${_selectedVideo != null ? 'NOT NULL' : 'NULL'}');
    if (_selectedVideo == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.movie_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No video selected', style: TextStyle(fontSize: 18, color: Colors.grey)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _selectVideo,
              icon: const Icon(Icons.video_call),
              label: const Text('Select Video'),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), backgroundColor: Colors.blue, foregroundColor: Colors.white),
            ),
          ],
        ),
      );
    }
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))]),
            clipBehavior: Clip.antiAlias,
            child: AspectRatio(
              aspectRatio: _videoAspectRatio,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        _textX = (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
                        _textY = (details.localPosition.dy / constraints.maxHeight).clamp(0.0, 1.0);
                        _isDragging = true;
                      });
                    },
                    onPanEnd: (_) => setState(() => _isDragging = false),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        VideoPlayer(_videoController!),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.swap_horiz, color: Colors.white, size: 20),
                                  onPressed: _selectVideo,
                                  tooltip: 'Replace Video',
                                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                                  onPressed: () {
                                    setState(() {
                                      _selectedVideo = null;
                                      _videoController?.dispose();
                                      _videoController = null;
                                      _thumbnailPath = null;
                                      _outputPath = null;
                                    });
                                  },
                                  tooltip: 'Remove Video',
                                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildOverlayText(constraints),
                        if (!_isDragging)
                        Positioned(
                          bottom: 10,
                          right: 10,
                          child: IconButton(
                            icon: Icon(_videoController!.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, color: Colors.white, size: 40),
                            onPressed: () => setState(() { _videoController!.value.isPlaying ? _videoController!.pause() : _videoController!.play(); }),
                          ),
                        ),
                      ],
                    ),
                  );
                }
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverlayText(BoxConstraints constraints) {
    final previewWidth = constraints.maxWidth;
    final scaleFactor = previewWidth / _videoWidth;
    final scaledFontSize = _fontSize * scaleFactor;

    return Positioned(
      // Centering the text on the touch point (x, y)
      left: _textX * constraints.maxWidth,
      top: _textY * constraints.maxHeight,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: IgnorePointer(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _parseHexColor(_boxColor, Colors.white).withOpacity(_boxOpacity),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _textContent,
              textAlign: _getTextAlign(),
              style: TextStyle(
                color: _parseHexColor(_textColor, Colors.black).withOpacity(_textOpacity),
                fontSize: scaledFontSize,
                fontFamily: _selectedFont?.family,
                height: _lineHeight,
                shadows: _showTextShadow ? [
                  Shadow(
                    color: _parseHexColor(_shadowColor, Colors.black).withOpacity(0.5),
                    offset: Offset(_shadowX, _shadowY),
                    blurRadius: 0,
                  ),
                ] : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Alignment _getAlignment() {
    if (_hAlign == 'left') return Alignment.centerLeft;
    if (_hAlign == 'right') return Alignment.centerRight;
    return Alignment.center;
  }

  TextAlign _getTextAlign() {
    if (_hAlign == 'left') return TextAlign.left;
    if (_hAlign == 'right') return TextAlign.right;
    return TextAlign.center;
  }

  Color _parseHexColor(String hex, Color fallback) {
    try {
      return Color(int.parse(hex.replaceFirst('#', 'FF'), radix: 16));
    } catch (_) { return fallback; }
  }

  Widget _buildControlTabs() {
    return Container(
      height: 60,
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade200))),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _processVideo,
              child: const Text('Save', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)), elevation: 0),
            ),
          ),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildTabItem(0, Icons.text_fields, 'Text', Colors.teal),
                _buildTabItem(1, Icons.open_with, 'Position', Colors.blue),
                _buildTabItem(2, Icons.palette, 'Color', Colors.deepOrange),
                _buildTabItem(3, Icons.font_download, 'Fonts', Colors.indigo),
                _buildTabItem(4, Icons.auto_fix_high, 'Effects', Colors.amber),
                _buildTabItem(5, Icons.library_music, 'Audio', Colors.pink),
                _buildTabItem(6, Icons.settings, 'Settings', Colors.purple),
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
        width: 70,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? color : Colors.grey[600],
              size: 24,
            ),
            const SizedBox(height: 6),
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
      height: 220,
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(child: _buildTabSpecificContent()),
    );
  }

  Widget _buildTabSpecificContent() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildTextTab();
      case 1:
        return _buildPositionTab();
      case 2:
        return _buildColorTab();
      case 3:
        return _buildFontsTab();
      case 4:
        return _buildEffectsTab();
      case 5:
        return _buildAudioTab();
      case 6:
        return _buildSettingsTab();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTextTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Text Content', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: _textController,
          decoration: const InputDecoration(
            hintText: 'Enter text to overlay',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          onChanged: (v) => setState(() => _textContent = v),
        ),
        const SizedBox(height: 16),
        Text('Font Size: ${_fontSize.toInt()}px'),
        Slider(
          value: _fontSize,
          min: 20,
          max: 200,
          onChanged: (v) => setState(() => _fontSize = v),
        ),
      ],
    );
  }

  Widget _buildPositionTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Manual Position Control', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Drag text on video or use sliders below.', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 16),
        Row(
          children: [
            const SizedBox(width: 40, child: Text('X:', style: TextStyle(fontWeight: FontWeight.bold))),
            Expanded(
              child: Slider(
                value: _textX,
                min: 0.0,
                max: 1.0,
                onChanged: (v) => setState(() => _textX = v),
              ),
            ),
            SizedBox(width: 40, child: Text('${(_textX * 100).toInt()}%')),
          ],
        ),
        Row(
          children: [
            const SizedBox(width: 40, child: Text('Y:', style: TextStyle(fontWeight: FontWeight.bold))),
            Expanded(
              child: Slider(
                value: _textY,
                min: 0.0,
                max: 1.0,
                onChanged: (v) => setState(() => _textY = v),
              ),
            ),
            SizedBox(width: 40, child: Text('${(_textY * 100).toInt()}%')),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Alignment', style: TextStyle(fontWeight: FontWeight.bold)),
        Row(children: [
          _buildAlignIconButton('left', Icons.align_horizontal_left),
          _buildAlignIconButton('center', Icons.align_horizontal_center),
          _buildAlignIconButton('right', Icons.align_horizontal_right),
        ]),
      ],
    );
  }

  Widget _buildColorTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Text Color', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildColorList((color) => setState(() => _textColor = color)),
        const SizedBox(height: 16),
        const Text('Background Color', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildColorList((color) => setState(() => _boxColor = color)),
        const SizedBox(height: 16),
        Text('Background Opacity: ${(_boxOpacity * 100).toInt()}%'),
        Slider(value: _boxOpacity, min: 0.0, max: 1.0, onChanged: (v) => setState(() => _boxOpacity = v)),
      ],
    );
  }

  Widget _buildFontsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Font Family', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SizedBox(
          height: 150,
          child: ListView.separated(
            itemCount: getAllFonts().length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final font = getAllFonts()[index];
              final isSelected = _selectedFont == font;
              return Material(
                color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                child: ListTile(
                  dense: true,
                  title: Text(
                    font.displayName, 
                    style: TextStyle(
                      fontFamily: font.family, 
                      color: isSelected ? Colors.blue : Colors.black,
                      fontSize: 16,
                    ),
                  ),
                  trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.blue, size: 20) : null,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  onTap: () => setState(() => _selectedFont = font),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEffectsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title: const Text('Text Shadow', style: TextStyle(fontWeight: FontWeight.bold)),
          value: _showTextShadow,
          onChanged: (v) => setState(() => _showTextShadow = v),
        ),
        if (_showTextShadow) ...[
          const Text('Shadow Color', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildColorList((color) => setState(() => _shadowColor = color)),
          const SizedBox(height: 8),
          Text('Shadow X Offset: ${_shadowX.toInt()}'),
          Slider(value: _shadowX, min: -20, max: 20, onChanged: (v) => setState(() => _shadowX = v)),
          const SizedBox(height: 8),
          Text('Shadow Y Offset: ${_shadowY.toInt()}'),
          Slider(value: _shadowY, min: -20, max: 20, onChanged: (v) => setState(() => _shadowY = v)),
        ],
        const SizedBox(height: 8),
        Text('Text Opacity: ${(_textOpacity * 100).toInt()}%'),
        Slider(value: _textOpacity, min: 0.1, max: 1.0, onChanged: (v) => setState(() => _textOpacity = v)),
      ],
    );
  }

  Widget _buildColorList(Function(String) onColorSelected) {
    final colors = [
      '#FFFFFF', '#000000', '#FF0000', '#00FF00', '#0000FF', 
      '#FFFF00', '#FF00FF', '#00FFFF', '#FF9800', '#795548'
    ];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: colors.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final color = colors[index];
          return GestureDetector(
            onTap: () => onColorSelected(color),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _parseHexColor(color, Colors.grey),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAlignIconButton(String value, IconData icon) {
    final isSelected = _hAlign == value;
    return Expanded(
      child: IconButton(
        icon: Icon(icon, color: isSelected ? Colors.blue : Colors.grey),
        onPressed: () => setState(() => _hAlign = value),
      ),
    );
  }

  Widget _buildAudioTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Background Music', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        AudioSelectorWidget(
          selectedAudio: _selectedAudio,
          audioDuration: _audioDuration,
          isPlayingAudio: _isPlayingAudio,
          onAudioSelected: (audio, duration) => setState(() { _selectedAudio = audio; _audioDuration = duration; }),
          onAudioRemoved: () => setState(() { _selectedAudio = null; _audioDuration = null; }),
          onPlaybackToggle: (playing) => setState(() => _isPlayingAudio = playing),
          isProcessing: _isProcessing,
        ),
        if (_selectedAudio != null) ...[
          const SizedBox(height: 16),
          Row(children: [const Icon(Icons.volume_up, size: 20), const SizedBox(width: 12), Expanded(child: Slider(value: _audioVolume, min: 0.0, max: 2.0, onChanged: (v) => setState(() => _audioVolume = v))), Text('${(_audioVolume * 100).toInt()}%')]),
          SwitchListTile(title: const Text('Loop Audio'), value: _loopAudio, onChanged: (v) => setState(() => _loopAudio = v)),
        ],
      ],
    );
  }

  Widget _buildSettingsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Export Quality', style: TextStyle(fontWeight: FontWeight.bold)),
        DropdownButtonFormField<String>(value: _preset, items: ['ultrafast', 'veryfast', 'fast', 'medium'].map((p) => DropdownMenuItem(value: p, child: Text(p.toUpperCase()))).toList(), onChanged: (v) => setState(() => _preset = v!)),
        const SizedBox(height: 16),
        Text('Quality (CRF): ${_crf.toInt()}'),
        Slider(value: _crf, min: 18, max: 32, onChanged: (v) => setState(() => _crf = v)),
      ],
    );
  }

  Widget _buildProcessingOverlay() {
    return Container(
      color: Colors.black38,
      child: Center(
        child: Material(
          color: Colors.white, borderRadius: BorderRadius.circular(16), elevation: 10,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                Text('Processing Video... ${(_progress * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                SizedBox(width: 200, child: LinearProgressIndicator(value: _progress)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
