import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import '../video_creator/widgets/duration_selector_widget.dart';
import '../video_creator/widgets/audio_selector_widget.dart';
import '../../utils/font_selector.dart';

class TextBoxOverlayScreen extends StatefulWidget {
  final List<String>? sharedImagePaths;

  const TextBoxOverlayScreen({Key? key, this.sharedImagePaths}) : super(key: key);

  @override
  State<TextBoxOverlayScreen> createState() => _TextBoxOverlayScreenState();
}

class _TextBoxOverlayScreenState extends State<TextBoxOverlayScreen> {
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
  String _textColor = "#000000"; // default black
  String _boxColor = "#FFFFFF";  // default white
  double _boxOpacity = 1.0;

  bool _showTextShadow = false;
  double _shadowX = 2.0;
  double _shadowY = 2.0;
  String _shadowColor = "#000000";

  String _textBoxPosition = 'top'; // 'top' or 'bottom'
  double _horizontalPadding = 12.0;
  double _verticalPadding = 8.0;
  double _textScale = 1.0;
  double _lineHeight = 1.2;
  String _hAlign = 'center'; // 'left', 'center', 'right'
  String _vAlign = 'middle'; // 'top', 'middle', 'bottom'
  
  // Encoding settings
  String _preset = 'veryfast';
  double _crf = 23.0;
  
  // Controllers
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _textColorController = TextEditingController();
  final TextEditingController _boxColorController = TextEditingController();

  final Map<String, String> _fontFileCache = {};


  
  @override
  void initState() {
    super.initState();
    _selectedFont = FontInfo(family: 'Metrophobic', displayName: 'Metrophobic');
    _textController.text = _textContent;
    _boxHeight = _calculateDynamicBoxHeight(text: _textContent);
    _textColorController.text = _textColor.replaceFirst('#', '');
    _boxColorController.text = _boxColor.replaceFirst('#', '');
    _setupMethodCallHandler();
    _handleSharedImages();
  }

  double _calculateDynamicBoxHeight({required String text}) {
    final normalized = text.replaceAll('\r\n', '\n');
    
    // Create a TextPainter to measure the text with wrapping
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: normalized,
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
    final next = _calculateDynamicBoxHeight(text: _textContent);
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
    _progressTimer?.cancel();
    _textController.dispose();
    _textColorController.dispose();
    _boxColorController.dispose();
    _videoController?.dispose();
    super.dispose();
  }
  
  void _setupMethodCallHandler() {
    platform.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onProgress':
          setState(() {
            _progress = call.arguments as double;
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
      final String? thumb = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: (await getTemporaryDirectory()).path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 1280,
        quality: 75,
      );
      
      if (thumb != null) {
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
  
  Future<void> _processVideo() async {
    if (_selectedVideo == null && _selectedImage == null) {
      _showErrorDialog('No Media Selected', 'Please select a video or image first.');
      return;
    }
    
    setState(() {
      _isProcessing = true;
      _progress = 0.0;
    });
    
    try {
      debugPrint('[TextBoxOverlay] Starting processing. isImageInput=$_isImageInput');

      final dynamicBoxHeight = _calculateDynamicBoxHeight(text: _textContent);
      if ((dynamicBoxHeight - _boxHeight).abs() >= 0.1) {
        setState(() {
          _boxHeight = dynamicBoxHeight;
        });
      }

      // Manually wrap the text for FFmpeg since native drawtext wrapping is failing
      final TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: _textContent.replaceAll('\r\n', '\n'),
          style: TextStyle(
            fontSize: _fontSize * _textScale,
            height: _lineHeight,
            fontFamily: _selectedFont?.family,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: _hAlign == 'left' ? TextAlign.left : (_hAlign == 'right' ? TextAlign.right : TextAlign.center),
      );

      final double horizontalPaddingTotal = (_horizontalPadding + 12) * 2;
      final double availableWidth = (_videoWidth.toDouble() - horizontalPaddingTotal).clamp(100.0, 2000.0);
      textPainter.layout(maxWidth: availableWidth);

      final List<LineMetrics> lines = textPainter.computeLineMetrics();
      String wrappedText = "";
      final String fullText = _textContent.replaceAll('\r\n', '\n');

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        
        // Find the vertical center of this specific line
        double verticalOffset = 0;
        for (int j = 0; j < i; j++) {
          verticalOffset += lines[j].height;
        }
        final double midY = verticalOffset + (line.height * 0.5);
        
        // Use getPositionForOffset at x=0 and a very large width to find the character range for this line
        final int startIdx = textPainter.getPositionForOffset(Offset(0, midY)).offset;
        final int endIdx = textPainter.getPositionForOffset(Offset(availableWidth + 1000, midY)).offset;
        
        if (startIdx < fullText.length) {
          int end = endIdx;
          if (end > fullText.length) end = fullText.length;
          
          if (end > startIdx) {
            String lineText = fullText.substring(startIdx, end).trim();
            if (lineText.isNotEmpty) {
              // Only add if not a duplicate of the previous line (getPositionForOffset can overlap)
              final List<String> currentLines = wrappedText.split('\n');
              if (wrappedText.isEmpty || currentLines.last != lineText) {
                if (wrappedText.isNotEmpty) wrappedText += "\n";
                wrappedText += lineText;
              }
            }
          }
        }
      }

      // Safety fallback: if manual wrapping lost too much text, use original (might overflow but better than missing text)
      if (wrappedText.length < fullText.length * 0.8) {
        wrappedText = _textContent;
      }

      _progressTimer?.cancel();
      final startTime = DateTime.now();
      const estimatedDuration = Duration(seconds: 20);
      _progressTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
        if (!_isProcessing) {
          timer.cancel();
          return;
        }
        final elapsed = DateTime.now().difference(startTime);
        final ratio = elapsed.inMilliseconds / estimatedDuration.inMilliseconds;
        setState(() {
          _progress = ratio.clamp(0.0, 0.99);
        });
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

      if (_isImageInput) {
        inputPath = _selectedImage!.path;
        method = 'addTextToImageVideo';
        params = {
          'inputPath': inputPath,
          'outputPath': outputPath,
          'text': wrappedText,
          'fontSize': (_fontSize * _textScale).toInt(),
          'fontColor': _textColor,
          'boxColor': _boxColor,
          'boxHeight': dynamicBoxHeight.toInt(),
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
        };
      } else {
        inputPath = _selectedVideo!.path;
        method = 'addTextToVideo';
        params = {
          'inputPath': inputPath,
          'outputPath': outputPath,
          'text': wrappedText,
          'x': 0,
          'y': 0,
          'fontSize': (_fontSize * _textScale).toInt(),
          'fontColor': _textColor,
          'boxColor': _boxColor,
          'boxHeight': dynamicBoxHeight.toInt(),
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
          'audioPath': _selectedAudio?.path,
          'audioVolume': _audioVolume,
          'loopAudio': _loopAudio,
        };
      }

      debugPrint('[TextBoxOverlay] Calling $method with params: $params');

      final result = await platform.invokeMethod<String>(method, params);
      
      setState(() {
        _isProcessing = false;
        _outputPath = result ?? outputPath;
        _progress = 1.0;
      });
      
      _progressTimer?.cancel();
      
      debugPrint('[TextBoxOverlay] Processing completed, output=$_outputPath');
      _showSuccessDialog();
      
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      
      _progressTimer?.cancel();
      
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

  Future<void> _pickColor({required bool isText, bool isShadow = false}) async {
    final initial = _parseHexColor(
      isShadow ? _shadowColor : (isText ? _textColor : _boxColor),
      isText ? Colors.black : Colors.white,
    );

    final String originalTextColor = _textColor;
    final String originalBoxColor = _boxColor;
    final String originalShadowColor = _shadowColor;

    HSVColor hsv = HSVColor.fromColor(initial);
    Color tempColor = hsv.toColor();

    final TextEditingController hexController = TextEditingController(
      text: _colorToHex(tempColor).replaceFirst('#', ''),
    );

    String? errorText;

    void applyTempToPreview() {
      final hex = _colorToHex(tempColor);
      setState(() {
        if (isShadow) {
          _shadowColor = hex;
        } else if (isText) {
          _textColor = hex;
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
                                if (isShadow) {
                                  _shadowColor = hex;
                                } else if (isText) {
                                  _textColor = hex;
                                  final digits = hex.replaceFirst('#', '');
                                  _textColorController.value = TextEditingValue(
                                    text: digits,
                                    selection: TextSelection.collapsed(offset: digits.length),
                                  );
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('✅ Success!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Text box overlay added successfully!'),
            if (_outputPath != null) ...[
              const SizedBox(height: 8),
              Text(
                'Saved to: ${_outputPath!.split('/').last}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
        actions: [
          if (_outputPath != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                OpenFile.open(_outputPath!);
              },
              child: const Text('Open Video'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
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
            Row(
              children: [
                const Icon(Icons.volume_up, size: 20),
                const SizedBox(width: 12),
                const Text('Volume'),
                Expanded(
                  child: Slider(
                    value: _audioVolume,
                    min: 0.0,
                    max: 2.0,
                    divisions: 20,
                    label: '${(_audioVolume * 100).toInt()}%',
                    onChanged: (value) {
                      setState(() {
                        _audioVolume = value;
                      });
                    },
                  ),
                ),
                Text('${(_audioVolume * 100).toInt()}%'),
              ],
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      width: double.infinity,
      child: LayoutBuilder(
              builder: (context, constraints) {
                // Get dimensions from metadata or image
                final previewWidth = constraints.maxWidth;
                final previewAspectRatio = _videoAspectRatio;
                final videoHeight = previewWidth / previewAspectRatio;
                
                // Calculate scale factor: ACTUAL width / preview width
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

                final mediaWidget = SizedBox(
                  width: previewWidth,
                  height: videoHeight,
                  child: Stack(
                    children: [
                      _isImageInput && _selectedImage != null
                          ? Image.file(
                              _selectedImage!,
                              width: previewWidth,
                              height: videoHeight,
                              fit: BoxFit.contain,
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
                                      width: previewWidth,
                                      height: videoHeight,
                                      fit: BoxFit.contain,
                                    )
                                  : const Center(child: CircularProgressIndicator()))),
                      
                      // Video Controls Overlay (only for video)
                      if (!_isImageInput && _videoController != null && _videoController!.value.isInitialized && _showControls)
                        Positioned.fill(
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
                        ),
                    ],
                  ),
                );

                final boxWidget = Container(
                  width: previewWidth,
                  height: boxHeight,
                  color: _parseHexColor(_boxColor, Colors.white),
                  alignment: textAlignment,
                  padding: EdgeInsets.symmetric(
                    horizontal: previewHorizontalPadding + (12 / scaleFactor),
                    vertical: previewVerticalPadding,
                  ),
                  child: Text(
                    _textContent,
                    textAlign: textAlign,
                    softWrap: true,
                    overflow: TextOverflow.visible,
                    style: TextStyle(
                      color: _parseHexColor(_textColor, Colors.black),
                      fontSize: previewFontSize,
                      fontFamily: _selectedFont?.family,
                      height: _lineHeight,
                      shadows: _showTextShadow
                          ? [
                              Shadow(
                                color: _parseHexColor(_shadowColor, Colors.black).withOpacity(0.5),
                                offset: Offset(_shadowX, _shadowY),
                                blurRadius: 0,
                              ),
                            ]
                          : null,
                    ),
                  ),
                );

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _textBoxPosition == 'top'
                      ? [
                          boxWidget,
                          mediaWidget,
                        ]
                      : [
                          mediaWidget,
                          boxWidget,
                        ],
                );
              },
            ),
    );
  }

  Widget _buildControlTabs() {
    return Container(
      height: 60,
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
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              children: [
                _buildTabItem(0, Icons.format_quote, 'Text', Colors.teal),
                const SizedBox(width: 8),
                _buildTabItem(1, Icons.font_download_outlined, 'Font', Colors.green),
                const SizedBox(width: 8),
                _buildTabItem(2, Icons.palette_outlined, 'Colors', Colors.deepOrange),
                const SizedBox(width: 8),
                _buildTabItem(3, Icons.vertical_align_center, 'Position', Colors.blue),
                const SizedBox(width: 8),
                _buildTabItem(4, Icons.settings_outlined, 'Settings', Colors.purple),
                const SizedBox(width: 8),
                _buildTabItem(5, Icons.movie_outlined, 'Video', Colors.indigo),
                if (_isImageInput) ...[
                  const SizedBox(width: 8),
                  _buildTabItem(6, Icons.image_outlined, 'Image Opts', Colors.orange),
                ],
                const SizedBox(width: 8),
                _buildTabItem(7, Icons.library_music, 'Audio', Colors.pink),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, IconData icon, String label, Color color) {
    final isSelected = _selectedTabIndex == index;
    return Center(
      child: InkWell(
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? color : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? color : Colors.grey[600],
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? color : Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveTabContent() {
    return Container(
      height: 220,
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: _buildTabSpecificContent(),
      ),
    );
  }

  Widget _buildTabSpecificContent() {
    switch (_selectedTabIndex) {
      case 0: // Text
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Text Content', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _textController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter overlay text...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: (v) {
                setState(() {
                  _textContent = v;
                  _boxHeight = _calculateDynamicBoxHeight(text: v);
                });
              },
            ),
            const SizedBox(height: 16),
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
          ],
        );
      case 1: // Font
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Font Settings', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('Size: ${_fontSize.toInt()}px'),
            Slider(
              value: _fontSize,
              min: 20, max: 100,
              onChanged: (v) {
                setState(() {
                  _fontSize = v;
                  _boxHeight = _calculateDynamicBoxHeight(text: _textContent);
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
                          _boxHeight = _calculateDynamicBoxHeight(text: _textContent);
                        });
                      }
                    },
                  );
                },
              ),
            ),
          ],
        );
      case 2: // Colors
        return Column(
          children: [
            _buildColorOption('Text Color', _textColor, true),
            const SizedBox(height: 16),
            _buildColorOption('Box Color', _boxColor, false),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Text Shadow', style: TextStyle(fontWeight: FontWeight.bold)),
              value: _showTextShadow,
              onChanged: (v) => setState(() => _showTextShadow = v),
            ),
            if (_showTextShadow) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Expanded(
                    child: Text('Shadow Color', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  GestureDetector(
                    onTap: () => _pickColor(isText: true, isShadow: true),
                    child: Container(
                      width: 80,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _parseHexColor(_shadowColor, Colors.black),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Center(
                        child: Text(
                          _shadowColor,
                          style: TextStyle(
                            fontSize: 10,
                            color: _parseHexColor(_shadowColor, Colors.black).computeLuminance() > 0.5
                                ? Colors.black
                                : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Shadow X Offset: ${_shadowX.toInt()}'),
              Slider(
                value: _shadowX,
                min: -20,
                max: 20,
                onChanged: (v) => setState(() => _shadowX = v),
              ),
              const SizedBox(height: 8),
              Text('Shadow Y Offset: ${_shadowY.toInt()}'),
              Slider(
                value: _shadowY,
                min: -20,
                max: 20,
                onChanged: (v) => setState(() => _shadowY = v),
              ),
            ],
          ],
        );
      case 3: // Layout
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Box Layout', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('Box Height: ${_boxHeight.toInt()}px'),
            Slider(
              value: _boxHeight,
              min: 40, max: 400,
              onChanged: (v) => setState(() => _boxHeight = v),
            ),
            const SizedBox(height: 8),
            Text('Text Scale: ${(_textScale * 100).toInt()}%'),
            Slider(
              value: _textScale,
              min: 0.5, max: 2.0,
              onChanged: (v) {
                setState(() {
                  _textScale = v;
                  _boxHeight = _calculateDynamicBoxHeight(text: _textContent);
                });
              },
            ),
            const SizedBox(height: 8),
            Text('Line Height: ${_lineHeight.toStringAsFixed(1)}'),
            Slider(
              value: _lineHeight,
              min: 0.8, max: 2.5,
              onChanged: (v) {
                setState(() {
                  _lineHeight = v;
                  _boxHeight = _calculateDynamicBoxHeight(text: _textContent);
                });
              },
            ),
            const SizedBox(height: 8),
            Text('Horizontal Padding: ${_horizontalPadding.toInt()}px'),
            Slider(
              value: _horizontalPadding,
              min: 0, max: 100,
              onChanged: (v) => setState(() => _horizontalPadding = v),
            ),
            const SizedBox(height: 8),
            Text('Vertical Padding: ${_verticalPadding.toInt()}px'),
            Slider(
              value: _verticalPadding,
              min: 0, max: 100,
              onChanged: (v) {
                setState(() {
                  _verticalPadding = v;
                  _boxHeight = _calculateDynamicBoxHeight(text: _textContent);
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
            Text('Quality (CRF): ${_crf.toInt()} (Lower is better)'),
            Slider(
              value: _crf,
              min: 18, max: 32,
              onChanged: (v) => setState(() => _crf = v),
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
      default:
        return const SizedBox.shrink();
    }
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

  Widget _buildProcessingOverlay() {
    return Container(
      color: Colors.black38,
      child: Center(
        child: Material(
          color: Colors.white,
          elevation: 10,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                Text(
                  'Processing Video... ${(_progress * 100).toInt()}%',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please wait, this might take a minute.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(value: _progress),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
