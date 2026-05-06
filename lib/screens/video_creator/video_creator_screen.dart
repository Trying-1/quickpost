import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:open_file/open_file.dart';
import '../../templates/video/video_template_registry.dart';
import '../../templates/video/video_template_base.dart';
import 'widgets/image_preview_widget.dart';
import 'widgets/multi_image_selector_widget.dart';
import 'widgets/audio_selector_widget.dart';
import 'widgets/template_selector_widget.dart';
import 'widgets/duration_selector_widget.dart';
import 'widgets/create_button_widget.dart';
import '../../services/app_review_service.dart';
import '../../services/analytics_service.dart';

class VideoCreatorScreen extends StatefulWidget {
  final List<String>? sharedImagePaths;
  final String? sharedPurpose;
  final String? initialTemplateId;
  final Map<String, dynamic>? automationSettings;
  final bool autoPopOnSuccess;

  const VideoCreatorScreen({
    Key? key,
    this.sharedImagePaths,
    this.sharedPurpose,
    this.initialTemplateId,
    this.automationSettings,
    this.autoPopOnSuccess = false,
  }) : super(key: key);

  @override
  State<VideoCreatorScreen> createState() => _VideoCreatorScreenState();
}

class _VideoCreatorScreenState extends State<VideoCreatorScreen> {
  static const platform = MethodChannel('com.quickpost.app/processor');
  
  // State
  File? _selectedImage;
  List<File> _selectedImages = []; // For image sequence template
  File? _selectedAudio;
  String? _audioDuration;
  bool _isProcessing = false;
  bool _isPlayingAudio = false;
  double _progress = 0.0;
  String? _outputPath;
  
  // Template state
  String _selectedTemplateId = 'fade_in';
  Map<String, dynamic> _templateSettings = {};
  int _duration = 8;
  
  final _templateRegistry = VideoTemplateRegistry();
  
  @override
  void initState() {
    super.initState();
    if (widget.initialTemplateId != null && widget.initialTemplateId!.isNotEmpty) {
      _selectedTemplateId = widget.initialTemplateId!;
    }

    // Override duration if automation settings provided
    if (widget.automationSettings != null) {
      if (widget.automationSettings!.containsKey('videoDuration')) {
        _duration = widget.automationSettings!['videoDuration'] as int;
      }
    }

    _initializeTemplateSettings();
    _setupMethodCallHandler();
    _loadSharedImages();
    AnalyticsService().setCurrentScreen(screenName: 'Video Creator');
  }

  @override
  void didUpdateWidget(covariant VideoCreatorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldPaths = oldWidget.sharedImagePaths;
    final newPaths = widget.sharedImagePaths;
    final oldPurpose = oldWidget.sharedPurpose;
    final newPurpose = widget.sharedPurpose;

    if (newPaths != null && newPaths.isNotEmpty) {
      final bool wasEmptyBefore = oldPaths == null || oldPaths.isEmpty;
      final bool lengthChanged = oldPaths == null || oldPaths.length != newPaths.length;
      final bool firstChanged = oldPaths == null || oldPaths.isEmpty || oldPaths.first != newPaths.first;
      final bool purposeChanged = oldPurpose != newPurpose;

      if (wasEmptyBefore || lengthChanged || firstChanged || purposeChanged) {
        _loadSharedImages();
      }
    }
  }

  void _loadSharedImages() {
    if (widget.sharedImagePaths != null && widget.sharedImagePaths!.isNotEmpty) {
      final paths = widget.sharedImagePaths!;
      final purpose = widget.sharedPurpose;

      if (paths.length == 1) {
        // Single image - use for fade_in or zoom_in
        _selectedImage = File(paths.first);
        
        // Set template based on purpose
        if (purpose == 'video_zoom_in') {
          _selectedTemplateId = 'zoom_in';
        } else {
          _selectedTemplateId = 'fade_in';
        }
      } else {
        // Multiple images - use for sequence
        _selectedImages = paths.map((p) => File(p)).toList();
        _selectedTemplateId = 'image_sequence';
      }
      
      print('[VideoCreatorScreen] Loaded ${paths.length} shared image(s) for purpose: $purpose');
    }
  }
  
  void _initializeTemplateSettings() {
    final template = _templateRegistry.getTemplate(_selectedTemplateId);
    if (template != null) {
      _templateSettings = template.getDefaultSettings();
    }
  }
  
  void _setupMethodCallHandler() {
    platform.setMethodCallHandler((call) async {
      if (call.method == 'onProgress') {
        setState(() {
          _progress = call.arguments as double;
        });
      } else if (call.method == 'onAudioComplete') {
        setState(() {
          _isPlayingAudio = false;
        });
      }
    });
  }
  
  void _onTemplateChanged(String templateId) {
    setState(() {
      _selectedTemplateId = templateId;
      final template = _templateRegistry.getTemplate(templateId);
      if (template != null) {
        _templateSettings = template.getDefaultSettings();
        // Sync images with settings for image_sequence template
        if (templateId == 'image_sequence') {
          _templateSettings['images'] = _selectedImages.map((f) => f.path).toList();
        }
      }
    });
  }
  
  void _onTemplateSettingsChanged(Map<String, dynamic> settings) {
    setState(() {
      _templateSettings = settings;
    });
  }
  
  void _onImagesChanged(List<File> images) {
    setState(() {
      _selectedImages = images;
      // Update settings with image paths
      _templateSettings['images'] = images.map((f) => f.path).toList();
    });
  }
  
  void _cancelVideoCreation() {
    setState(() {
      _isProcessing = false;
      _progress = 0.0;
    });
    // Note: Native side cancellation would need to be implemented in VideoProcessor
    _showErrorDialog('Video creation cancelled');
  }
  
  Future<void> _createVideo() async {
    AnalyticsService().logSaveAction(feature: 'video_creator', type: 'video');
    // Validate based on template type
    if (_selectedTemplateId == 'image_sequence') {
      if (_selectedImages.isEmpty) {
        _showErrorDialog('Please select at least one image');
        return;
      }
    } else {
      if (_selectedImage == null) {
        _showErrorDialog('Please select an image');
        return;
      }
    }
    
    final template = _templateRegistry.getTemplate(_selectedTemplateId);
    if (template == null || !template.validateSettings(_templateSettings)) {
      _showErrorDialog('Invalid template settings');
      return;
    }
    
    setState(() {
      _isProcessing = true;
      _progress = 0.0;
    });
    
    try {
      final nativeSettings = template.getNativeSettings(
        _templateSettings,
        automationSettings: widget.automationSettings,
      );
      
      // Prepare parameters based on template type
      final params = <String, dynamic>{
        'duration': _duration,
        'template': _selectedTemplateId,
        'fadeInDuration': nativeSettings['fadeInDuration'],
        'zoomScale': nativeSettings['zoomScale'],
        'zoomDuration': nativeSettings['zoomDuration'],
        'audioPath': _selectedAudio?.path,
        'automationSettings': widget.automationSettings,
      };
      
      // Add image(s) based on template
      if (_selectedTemplateId == 'image_sequence') {
        params['imagePaths'] = _selectedImages.map((f) => f.path).toList();
        
        // Validate and cap durationPerImage
        double durationPerImage = nativeSettings['durationPerImage'] ?? 0.2;
        // Cap at video duration to ensure at least one image is shown
        durationPerImage = durationPerImage.clamp(0.01, _duration.toDouble());
        
        params['durationPerImage'] = durationPerImage;
        params['sequenceMode'] = nativeSettings['sequenceMode'];
        params['allowRepeat'] = nativeSettings['allowRepeat'];
      } else {
        params['imagePath'] = _selectedImage?.path ?? '';
      }
      
      final result = await platform.invokeMethod('createVideo', params);
      
      setState(() {
        _outputPath = result as String?;
        _isProcessing = false;
      });
      
      if (_outputPath != null) {
        // Show snackbar immediately
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Video saved to: $_outputPath'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OPEN',
              onPressed: () {
                OpenFile.open(_outputPath!);
              },
            ),
          ),
        );
        _showSuccessDialog();
      } else {
        _showErrorDialog('Video was created but path is null');
      }
    } on PlatformException catch (e) {
      setState(() {
        _isProcessing = false;
      });
      _showErrorDialog('Failed to create video: ${e.message}');
    }
  }
  
  void _showSuccessDialog() {
    // Increment export count and check for review request
    AppReviewService().incrementExportCount();
    AppReviewService().checkAndRequestReview();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green[600], size: 28),
            const SizedBox(width: 12),
            const Text('Success!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Video created successfully!'),
            const SizedBox(height: 8),
            if (_outputPath != null) ...[
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Saved to:',
                style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                _outputPath!,
                style: TextStyle(fontSize: 11, color: Colors.grey[700]),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (widget.autoPopOnSuccess) {
                Navigator.of(this.context).pop();
              }
            },
            child: const Text('OK'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              if (widget.autoPopOnSuccess) {
                Navigator.of(this.context).pop();
              }
              if (_outputPath != null) {
                OpenFile.open(_outputPath!);
              }
            },
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('OPEN'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
  
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final template = _templateRegistry.getTemplate(_selectedTemplateId);
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Template Selector Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
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
                child: TemplateSelectorWidget(
                  selectedTemplateId: _selectedTemplateId,
                  onTemplateChanged: _onTemplateChanged,
                  isProcessing: _isProcessing,
                ),
              ),
              
              // Image & Audio Section
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.fromLTRB(8, 0, 8, 4),
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
                    // Image selector - single or multiple based on template
                    if (_selectedTemplateId == 'image_sequence')
                      MultiImageSelectorWidget(
                        selectedImages: _selectedImages,
                        onImagesChanged: _onImagesChanged,
                        isProcessing: _isProcessing,
                      )
                    else
                      ImagePreviewWidget(
                        selectedImage: _selectedImage,
                        onImageSelected: (image) => setState(() => _selectedImage = image),
                        isProcessing: _isProcessing,
                      ),
                    const SizedBox(height: 12),
                  
                  // Audio Selector
                  AudioSelectorWidget(
                    selectedAudio: _selectedAudio,
                    audioDuration: _audioDuration,
                    isPlayingAudio: _isPlayingAudio,
                    onAudioSelected: (audio, duration) {
                      setState(() {
                        _selectedAudio = audio;
                        _audioDuration = duration;
                      });
                    },
                    onAudioRemoved: () {
                      setState(() {
                        _selectedAudio = null;
                        _audioDuration = null;
                        _isPlayingAudio = false;
                      });
                    },
                    onPlaybackToggle: (isPlaying) {
                      setState(() => _isPlayingAudio = isPlaying);
                    },
                    isProcessing: _isProcessing,
                  ),
                ],
              ),
            ),
            
            // Settings Section
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.fromLTRB(8, 0, 8, 4),
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
                  // Duration Selector
                  DurationSelectorWidget(
                    duration: _duration,
                    onDurationChanged: (value) => setState(() => _duration = value),
                    isProcessing: _isProcessing,
                  ),
                  const SizedBox(height: 16),
                  
                  // Template-specific settings
                  if (template != null)
                    template.buildSettingsUI(
                      context: context,
                      settings: _templateSettings,
                      onSettingsChanged: _onTemplateSettingsChanged,
                      isProcessing: _isProcessing,
                    ),
                ],
              ),
            ),
            
            // Create Button
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
              child: CreateButtonWidget(
                isProcessing: _isProcessing,
                progress: _progress,
                onPressed: _createVideo,
                onCancel: _cancelVideoCreation,
                enabled: _selectedTemplateId == 'image_sequence' 
                    ? _selectedImages.isNotEmpty 
                    : _selectedImage != null,
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}
