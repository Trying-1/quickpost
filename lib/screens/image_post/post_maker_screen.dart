import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:async';
import 'package:open_file/open_file.dart';
import '../../widgets/base_template_widget.dart';
import '../../templates/image_post/template_definitions.dart';
import '../../utils/image_generator.dart';
import '../../utils/font_selector.dart';
import '../image_cropper/image_cropper_screen.dart';
import '../video_creator/video_creator_screen.dart';
import '../audio_extraction/audio_extraction_screen.dart';
import '../audio_library/audio_library_screen_with_folders.dart';
import '../../widgets/ad_banner_widget.dart';
import '../../services/ad_service.dart';
import '../../services/app_review_service.dart';

class PostMakerScreen extends StatefulWidget {
  const PostMakerScreen({super.key});

  @override
  State<PostMakerScreen> createState() => _PostMakerScreenState();
}

class _PostMakerScreenState extends State<PostMakerScreen> {
  final TextEditingController _textController = TextEditingController();
  final TemplateViewController _templateController = TemplateViewController();
  final GlobalKey _previewTemplateKey = GlobalKey();
  final GlobalKey _exportTemplateKey = GlobalKey();
  
  File? _selectedImage;
  List<File?> _gridImages = [null, null, null, null]; // For 2x2 grid template
  FontInfo? _selectedFont;
  String _selectedTemplate = 'single_image_post';
  bool _isLoading = false;
  int _currentBottomNavIndex = 0;
  bool _isPreviewReady = false; // Track if preview is fully loaded
  bool _showPlaceholder = true; // Control placeholder visibility during save
  
  // Text styling options
  Color _textColor = Colors.black87;
  Color _textBoxColor = Colors.white;
  bool _enableTextShadow = false;
  bool _enableTextGlow = false;
  Color _shadowColor = Colors.black;
  Color _glowColor = Colors.white;
  double _glowRadius = 10.0;
  double _letterSpacing = 0.0;
  double _fontSize = 1.0; // Multiplier for base font size
  
  // Continuous adjustment timers
  Timer? _continuousTimer;
  String? _continuousAdjustmentType;
  
  // Template dropdown state
  bool _isTemplateExpanded = false;

  // Get templates from centralized definitions
  Map<String, Map<String, dynamic>> get _templates {
    return TemplateDefinitions.templates.map(
      (key, config) => MapEntry(key, config.toMap()),
    );
  }

  @override
  void initState() {
    super.initState();
    // Do not request permissions on startup; ask just-in-time when needed
    
    // Set default font to Metrophobic
    _selectedFont = FontInfo(family: 'Metrophobic', displayName: 'Metrophobic');
  }

  Future<void> _requestPermissions() async {
    try {
      if (Platform.isAndroid) {
        // Request a safe set; unsupported ones are ignored by permission_handler
        await [
          Permission.photos, // Android 13+ (READ_MEDIA_IMAGES) and iOS
          Permission.storage, // Android <= 12
          Permission.camera,
        ].request();
      }
    } catch (_) {
      // Swallow errors; permissions can also be requested at save time
    }
  }

  Future<void> _pickImage() async {
    try {
      // Request only what's needed for picking
      await [Permission.photos, Permission.storage].request();
      if (!(await Permission.photos.isGranted) && !(await Permission.storage.isGranted)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permission needed to pick images')),
          );
        }
        return;
      }

      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        if (!mounted) return;
        setState(() {
          _selectedImage = File(image.path);
          _isPreviewReady = false; // Reset ready state when new image is loaded
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<void> _savePost() async {
    final isGridMode = _templates[_selectedTemplate]?['isGrid'] == true;
    final bool hasText = _textController.text.trim().isNotEmpty;
    
    // Validation - only image is required, text is optional
    if (isGridMode) {
      if (_gridImages.every((img) => img == null)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least one image'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    } else {
      if (_selectedImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select an image'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    // Show loading dialog immediately
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false,
          child: Dialog(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    hasText ? 'Saving, please wait...' : 'Saving without text...',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    
    // Small delay to let dialog render
    await Future.delayed(const Duration(milliseconds: 150));
    
    // If no text, hide placeholder to avoid capturing it
    if (!hasText) {
      setState(() {
        _showPlaceholder = false;
      });
      // Wait for UI to update
      await Future.delayed(const Duration(milliseconds: 100));
    }

    try {
      final String? savedPath = await ImageGenerator.savePostToGallery(
        text: _textController.text,
        imageFile: isGridMode ? null : _selectedImage,
        transform: null, // Not needed when capturing widget
        selectedFont: _selectedFont,
        templateKey: _previewTemplateKey, // Use the PREVIEW widget!
      );
      
      // Close loading dialog
      Navigator.of(context).pop();
      
      // Show interstitial ad after export
      AdService().showInterstitialAfterExport();
      
      // Increment export count and check for review request
      AppReviewService().incrementExportCount();
      AppReviewService().checkAndRequestReview();

      if (savedPath != null) {
        // Show success dialog
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
                    // Success icon with animation effect
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
                    
                    // Title
                    const Text(
                      'Success!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Message
                    const Text(
                      'Your post has been saved successfully',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // File path
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.folder, color: Colors.green[700], size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              savedPath,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[700],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Buttons
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
      } else {
        // Show error dialog
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: const [
                  Icon(Icons.error, color: Colors.red, size: 28),
                  SizedBox(width: 12),
                  Text('Error'),
                ],
              ),
              content: const Text('Failed to save post. Please try again.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      // Close loading dialog
      Navigator.of(context).pop();
      
      // Show error dialog
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: const [
                Icon(Icons.error, color: Colors.red, size: 28),
                SizedBox(width: 12),
                Text('Error'),
              ],
            ),
            content: Text('Error: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } finally {
      // Restore placeholder if it was hidden
      if (!hasText) {
        setState(() {
          _showPlaceholder = true;
        });
      }
    }
  }

  void _startContinuousZoom(int direction) {
    _continuousTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        _templateController.scale = (_templateController.scale + direction * 0.01).clamp(0.5, 1.5);
      });
    });
  }

  void _startContinuousPosition(String axis, int direction) {
    _continuousTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      setState(() {
        if (axis == 'x') {
          _templateController.offsetX = (_templateController.offsetX + direction * 10).clamp(-300.0, 300.0);
        } else {
          _templateController.offsetY = (_templateController.offsetY + direction * 10).clamp(-300.0, 300.0);
        }
      });
    });
  }

  void _stopContinuousZoom() {
    _continuousTimer?.cancel();
    _continuousTimer = null;
  }

  @override
  void dispose() {
    _textController.dispose();
    _continuousTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _currentBottomNavIndex == 0
          ? _buildPostMakerBody()
          : _currentBottomNavIndex == 1
              ? const ImageCropperScreen()
              : _currentBottomNavIndex == 2
                  ? const VideoCreatorScreen()
                  : const AudioLibraryScreenWithFolders(),
      floatingActionButton: _currentBottomNavIndex == 3
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AudioExtractionScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Extract New'),
              backgroundColor: Colors.purple,
            )
          : null,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Banner Ad
          AdBannerWidget(screenName: 'post_maker'),
          // Navigation Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildNavItem(0, Icons.create, 'Post Maker'),
                  _buildNavItem(1, Icons.crop, 'Image Cropper'),
                  _buildNavItem(2, Icons.video_call, 'Image to Video'),
                  _buildNavItem(3, Icons.library_music, 'My Audios'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostMakerBody() {
    final templateConfig = _templates[_selectedTemplate]!;
    
    return SafeArea(
      child: Column(
        children: [
          // ===== TEMPLATE SELECTOR AT TOP =====
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
            child: _buildTemplateSection(),
          ),
          
          // ===== STICKY PREVIEW IMAGE =====
          Container(
            margin: const EdgeInsets.fromLTRB(8, 0, 8, 4),
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _buildPreviewSection(templateConfig),
          ),
          
          // ===== SCROLLABLE SECTION: All Controls =====
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    
                    // Controls Container
                    Container(
                      padding: const EdgeInsets.all(12),
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
                          // Image Upload Section
                          _buildImageSection(),
                          const SizedBox(height: 12),
                          
                          // Image Adjustments (Scale, Position)
                          _buildImageAdjustmentsSection(),
                          const SizedBox(height: 12),
                          
                          // Text Input Section
                          _buildTextSection(),
                          const SizedBox(height: 12),
                          
                          // Text Styling Section
                          _buildTextStylingSection(),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateSection() {
    final currentTemplate = _templates[_selectedTemplate]!;
    
    return Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isTemplateExpanded = !_isTemplateExpanded;
              });
            },
            child: Row(
              children: [
                Icon(Icons.grid_view, color: Colors.purple[600], size: 20),
                const SizedBox(width: 12),
                const Text(
                  'Template:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          currentTemplate['icon'],
                          size: 18,
                          color: currentTemplate['color'],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          currentTemplate['name'],
                          style: const TextStyle(fontSize: 14),
                        ),
                        const Spacer(),
                        Icon(
                          _isTemplateExpanded ? Icons.expand_less : Icons.expand_more,
                          color: Colors.grey[600],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isTemplateExpanded) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 130,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _templates.length,
                itemBuilder: (context, index) {
                  final templateKey = _templates.keys.elementAt(index);
                  final template = _templates[templateKey]!;
                  final isSelected = _selectedTemplate == templateKey;
                  
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedTemplate = templateKey;
                        _isTemplateExpanded = false; // Close after selection
                      });
                    },
                    child: Container(
                      width: 100,
                      height: 120,
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected ? template['color'].withOpacity(0.1) : Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? template['color'] : Colors.grey[200]!,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            template['icon'],
                            size: 24,
                            color: isSelected ? template['color'] : Colors.grey[600],
                          ),
                          const SizedBox(height: 8),
                          Flexible(
                            child: Text(
                              template['name'],
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? template['color'] : Colors.grey[700],
                              ),
                              textAlign: TextAlign.center,
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
        ],
    );
  }

  Widget _buildTabletLayout(Map<String, dynamic> templateConfig) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Panel - Controls
        Expanded(
          flex: 1,
          child: Column(
            children: [
              _buildImageSection(),
              const SizedBox(height: 20),
              _buildTextSection(),
              const SizedBox(height: 20),
              _buildQuickActionsSection(),
            ],
          ),
        ),
        
        const SizedBox(width: 20),
        
        // Right Panel - Preview
        Expanded(
          flex: 1,
          child: _buildPreviewSection(templateConfig),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(Map<String, dynamic> templateConfig) {
    return Column(
      children: [
        // Preview first on mobile
        _buildPreviewSection(templateConfig),
        const SizedBox(height: 20),
        
        // Controls below
        _buildImageSection(),
        const SizedBox(height: 20),
        _buildTextSection(),
        const SizedBox(height: 20),
        _buildTextStylingSection(),
        const SizedBox(height: 20),
        _buildQuickActionsSection(),
      ],
    );
  }

  Widget _buildImageSection() {
    final isGridMode = _templates[_selectedTemplate]?['isGrid'] == true;
    
    return Container(
      padding: const EdgeInsets.all(20),
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
              Icon(Icons.image, color: Colors.blue[600], size: 24),
              const SizedBox(width: 12),
              Text(
                isGridMode ? '2x2 Grid' : 'Image',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              // Save button - only enabled when preview is fully loaded
              ElevatedButton.icon(
                onPressed: (_selectedImage != null || _gridImages.any((img) => img != null)) && _isPreviewReady
                    ? _savePost
                    : null,
                icon: const Icon(Icons.save, size: 18),
                label: Text(_isPreviewReady ? 'Save' : 'Loading...'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Grid action buttons (only for grid mode)
          if (isGridMode) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickAllGridImages,
                    icon: const Icon(Icons.add_photo_alternate, size: 18),
                    label: const Text('Import All (4)'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue[700],
                      side: BorderSide(color: Colors.blue[300]!),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _gridImages.any((img) => img != null) ? _clearAllGridImages : null,
                    icon: const Icon(Icons.clear_all, size: 18),
                    label: const Text('Clear All'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red[700],
                      side: BorderSide(color: Colors.red[300]!),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          
          // Image Preview
          isGridMode ? _buildGridPreview() : _buildSingleImagePreview(),
        ],
      ),
    );
  }

  Widget _buildSingleImagePreview() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          // Square image preview
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(7),
                  bottomLeft: Radius.circular(7),
                ),
              ),
              child: _selectedImage != null
                  ? ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(7),
                        bottomLeft: Radius.circular(7),
                      ),
                      child: Image.file(_selectedImage!, fit: BoxFit.cover),
                    )
                  : Icon(Icons.add_photo_alternate, color: Colors.grey[600], size: 28),
            ),
          ),
          // Label
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'IMG_1',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[800],
                ),
              ),
            ),
          ),
          // Action buttons on right
          if (_selectedImage != null) ...[
            InkWell(
              onTap: _pickImage,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.refresh, color: Colors.blue[700], size: 20),
                    const SizedBox(height: 2),
                    Text(
                      'Replace',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: () {
                setState(() {
                  _selectedImage = null;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.close, color: Colors.red[700], size: 20),
                    const SizedBox(height: 2),
                    Text(
                      'Remove',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.red[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildGridPreview() {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) {
            newIndex -= 1;
          }
          final item = _gridImages.removeAt(oldIndex);
          _gridImages.insert(newIndex, item);
        });
      },
      itemBuilder: (context, index) {
          final image = _gridImages[index];
          return Container(
            key: ValueKey('grid_image_$index'),
            margin: const EdgeInsets.only(bottom: 12),
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                // Drag handle
                Container(
                  width: 40,
                  child: Icon(Icons.drag_handle, color: Colors.grey[600]),
                ),
                // Square image preview
                GestureDetector(
                  onTap: () => _pickGridImage(index),
                  child: Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey[200],
                    child: image != null
                        ? Image.file(image, fit: BoxFit.cover)
                        : Icon(Icons.add_photo_alternate, color: Colors.grey[600], size: 32),
                  ),
                ),
                // Label
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'IMG_${index + 1}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                ),
                // Action buttons on right
                if (image != null) ...[
                  IconButton(
                    icon: Icon(Icons.refresh, color: Colors.blue[700]),
                    onPressed: () => _pickGridImage(index),
                    tooltip: 'Replace',
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.red[700]),
                    onPressed: () {
                      setState(() {
                        _gridImages[index] = null;
                      });
                    },
                    tooltip: 'Remove',
                  ),
                ],
              ],
            ),
          );
        },
    );
  }

  Widget _buildSingleImageButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.photo_library),
            label: const Text('Gallery'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () async {
              final ImagePicker picker = ImagePicker();
              final XFile? image = await picker.pickImage(source: ImageSource.camera);
              if (image != null) {
                setState(() {
                  _selectedImage = File(image.path);
                });
              }
            },
            icon: const Icon(Icons.camera_alt),
            label: const Text('Camera'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGridButtons() {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: _pickAllGridImages,
          icon: const Icon(Icons.photo_library),
          label: const Text('Pick All Images'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            minimumSize: const Size(double.infinity, 44),
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _clearAllGridImages,
          icon: const Icon(Icons.clear_all),
          label: const Text('Clear All'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            minimumSize: const Size(double.infinity, 44),
          ),
        ),
      ],
    );
  }

  Future<void> _pickGridImage(int index) async {
    try {
      await [Permission.photos, Permission.storage].request();
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _gridImages[index] = File(image.path);
          _isPreviewReady = false; // Reset ready state to trigger reload
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<void> _pickAllGridImages() async {
    try {
      await [Permission.photos, Permission.storage].request();
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage();
      if (images.isNotEmpty) {
        setState(() {
          for (int i = 0; i < images.length && i < 4; i++) {
            _gridImages[i] = File(images[i].path);
          }
          _isPreviewReady = false; // Reset ready state to trigger reload
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking images: $e')),
      );
    }
  }

  void _clearAllGridImages() {
    setState(() {
      _gridImages = [null, null, null, null];
    });
  }

  Widget _buildTextSection() {
    return Container(
      padding: const EdgeInsets.all(20),
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
              Icon(Icons.text_fields, color: Colors.purple[600], size: 24),
              const SizedBox(width: 12),
              const Text(
                'Text',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              // Selected font display on the right
              if (_selectedFont != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Text(
                    _selectedFont!.displayName,
                    style: TextStyle(
                      fontFamily: _selectedFont!.family,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          
          TextField(
            controller: _textController,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Enter your post text here...',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(16),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Horizontal scrollable font selector
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Font',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 44,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: getAllFonts().length,
                  itemBuilder: (context, index) {
                    final font = getAllFonts()[index];
                    final isSelected = _selectedFont == font;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        selected: isSelected,
                        label: Text(
                          font.displayName,
                          style: TextStyle(
                            fontFamily: font.family,
                            fontWeight: font.weight ?? FontWeight.w400,
                            fontStyle: font.style ?? FontStyle.normal,
                            fontSize: 13,
                          ),
                        ),
                        selectedColor: Colors.blue[100],
                        backgroundColor: Colors.grey[100],
                        onSelected: (_) {
                          setState(() {
                            _selectedFont = font;
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextStylingSection() {
    return Container(
      padding: const EdgeInsets.all(20),
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
              Icon(Icons.palette, color: Colors.orange[600], size: 24),
              const SizedBox(width: 12),
              const Text(
                'Text Styling',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Text Color
          Row(
            children: [
              const Text('Text Color:', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => _showColorPicker('text'),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _textColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Text Box Color
          Row(
            children: [
              const Text('Box Color:', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => _showColorPicker('box'),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _textBoxColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Text Shadow Toggle
          SwitchListTile(
            title: const Text('Text Shadow', style: TextStyle(fontWeight: FontWeight.w500)),
            value: _enableTextShadow,
            onChanged: (value) {
              setState(() {
                _enableTextShadow = value;
              });
            },
            contentPadding: EdgeInsets.zero,
          ),
          
          // Shadow Color (only show when shadow is enabled)
          if (_enableTextShadow) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Shadow Color:', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => _showColorPicker('shadow'),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _shadowColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          
          // Text Glow Toggle
          SwitchListTile(
            title: const Text('Text Glow', style: TextStyle(fontWeight: FontWeight.w500)),
            value: _enableTextGlow,
            onChanged: (value) {
              setState(() {
                _enableTextGlow = value;
              });
            },
            contentPadding: EdgeInsets.zero,
          ),
          
          // Glow Color and Radius (only show when glow is enabled)
          if (_enableTextGlow) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Glow Color:', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => _showColorPicker('glow'),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _glowColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Glow Radius: ${_glowRadius.toInt()}', 
              style: const TextStyle(fontWeight: FontWeight.w500)),
            Slider(
              value: _glowRadius,
              min: 5.0,
              max: 30.0,
              divisions: 25,
              label: _glowRadius.toInt().toString(),
              onChanged: (value) {
                setState(() {
                  _glowRadius = value;
                });
              },
            ),
          ],
          
          const SizedBox(height: 12),
          
          // Letter Spacing Slider
          Text('Letter Spacing: ${_letterSpacing.toStringAsFixed(1)}', 
            style: const TextStyle(fontWeight: FontWeight.w500)),
          Slider(
            value: _letterSpacing,
            min: -2.0,
            max: 10.0,
            divisions: 60,
            label: _letterSpacing.toStringAsFixed(1),
            onChanged: (value) {
              setState(() {
                _letterSpacing = value;
              });
            },
          ),
          
          const SizedBox(height: 12),
          
          // Font Size Slider
          Text('Font Size: ${(_fontSize * 100).toInt()}%', 
            style: const TextStyle(fontWeight: FontWeight.w500)),
          Slider(
            value: _fontSize,
            min: 0.5,
            max: 2.0,
            divisions: 30,
            label: '${(_fontSize * 100).toInt()}%',
            onChanged: (value) {
              setState(() {
                _fontSize = value;
              });
            },
          ),
        ],
      ),
    );
  }

  void _showColorPicker(String type) {
    Color currentColor;
    String title;
    
    switch (type) {
      case 'text':
        currentColor = _textColor;
        title = 'Text Color';
        break;
      case 'box':
        currentColor = _textBoxColor;
        title = 'Box Color';
        break;
      case 'shadow':
        currentColor = _shadowColor;
        title = 'Shadow Color';
        break;
      case 'glow':
        currentColor = _glowColor;
        title = 'Glow Color';
        break;
      default:
        currentColor = _textColor;
        title = 'Color';
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select $title'),
        content: SingleChildScrollView(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Colors.black87,
              Colors.black,
              Colors.white,
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
            ].map((color) {
              return GestureDetector(
                onTap: () {
                  setState(() {
                    switch (type) {
                      case 'text':
                        _textColor = color;
                        break;
                      case 'box':
                        _textBoxColor = color;
                        break;
                      case 'shadow':
                        _shadowColor = color;
                        break;
                      case 'glow':
                        _glowColor = color;
                        break;
                    }
                  });
                  Navigator.pop(context);
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: color == currentColor ? Colors.blue : Colors.grey[300]!,
                      width: color == currentColor ? 3 : 1,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
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
              Icon(Icons.flash_on, color: Colors.orange[600], size: 24),
              const SizedBox(width: 12),
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          LayoutBuilder(
            builder: (context, constraints) {
              return Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _textController.text = '✨ Amazing day! #blessed #grateful';
                  },
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Sample Text'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedFont = null;
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset Font'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewSection(Map<String, dynamic> templateConfig) {
    return LayoutBuilder(
              builder: (context, constraints) {
                final double availableWidth = constraints.maxWidth;
                // Keep a pleasant max preview size on large screens
                final double maxPreviewWidth = 600.0;
                final double previewWidth = availableWidth.clamp(180.0, maxPreviewWidth);
                final double aspect = (templateConfig['height'] as double) / (templateConfig['width'] as double);
                final double previewHeight = previewWidth * aspect;

                return Center(
            child: SizedBox(
                    width: previewWidth,
                    height: previewHeight,
              child: Stack(
                      children: [
                        // The live template preview
                        InstagramPostTemplate(
                          key: _previewTemplateKey,
                  text: _textController.text,
                  image: _selectedImage,
                          gridImages: _gridImages,
                          isGridMode: templateConfig['isGrid'] == true,
                          width: previewWidth,
                          height: previewHeight,
                  isPreview: true,
                  controller: _templateController,
                  selectedFont: _selectedFont,
                          textColor: _textColor,
                          textBoxColor: _textBoxColor,
                          enableTextShadow: _enableTextShadow,
                          enableTextGlow: _enableTextGlow,
                          shadowColor: _shadowColor,
                          glowColor: _glowColor,
                          glowRadius: _glowRadius,
                          letterSpacing: _letterSpacing,
                          fontSizeMultiplier: _fontSize,
                          textController: _textController,
                          showPlaceholder: _showPlaceholder,
                          onTextChanged: (value) {
                            setState(() {});
                          },
                          onImageLoaded: () {
                            setState(() {
                              _isPreviewReady = true;
                            });
                          },
                        ),

                        // Add image inline button when no image
                        if ((templateConfig['isGrid'] == true && _gridImages.every((img) => img == null)) ||
                            (templateConfig['isGrid'] != true && _selectedImage == null))
                          Positioned.fill(
                            child: Center(
                              child: ElevatedButton.icon(
                                onPressed: templateConfig['isGrid'] == true ? _pickAllGridImages : _pickImage,
                                icon: const Icon(Icons.add_photo_alternate),
                                label: Text(templateConfig['isGrid'] == true ? 'Add images' : 'Add image'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.purple,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
  }

  Widget _buildImageAdjustmentsSection() {
    if (_selectedImage == null || _templates[_selectedTemplate]?['isGrid'] == true) {
      return const SizedBox.shrink();
    }
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: Icon(Icons.tune, color: Colors.blue[700], size: 18),
          title: Text(
            'Image Adjustments',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.blue[700],
            ),
          ),
          children: [
          
          // Scale Slider (Zoom)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Scale: ${_templateController.scale.toStringAsFixed(2)}x',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
              Slider(
                value: _templateController.scale,
                min: 0.5,
                max: 1.5,
                divisions: 100,
                onChanged: (value) {
                  setState(() {
                    _templateController.scale = value;
                  });
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _templateController.scale = (_templateController.scale - 0.1).clamp(0.5, 1.5);
                      });
                    },
                    onLongPress: () {
                      _startContinuousZoom(-1);
                    },
                    onLongPressEnd: (_) {
                      _stopContinuousZoom();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: const Icon(Icons.remove, size: 18),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 60,
                    height: 32,
                    child: TextField(
                      controller: TextEditingController(
                        text: _templateController.scale.toStringAsFixed(2),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        isDense: true,
                      ),
                      onSubmitted: (value) {
                        final scale = double.tryParse(value) ?? 1.0;
                        setState(() {
                          _templateController.scale = scale.clamp(0.5, 1.5);
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _templateController.scale = (_templateController.scale + 0.1).clamp(0.5, 1.5);
                      });
                    },
                    onLongPress: () {
                      _startContinuousZoom(1);
                    },
                    onLongPressEnd: (_) {
                      _stopContinuousZoom();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: const Icon(Icons.add, size: 18),
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // X Position Slider
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('X: ${_templateController.offsetX.toInt()}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
              Slider(
                value: _templateController.offsetX,
                min: -300,
                max: 300,
                onChanged: (value) {
                  setState(() {
                    _templateController.offsetX = value;
                  });
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _templateController.offsetX = (_templateController.offsetX - 10).clamp(-300.0, 300.0);
                      });
                    },
                    onLongPress: () {
                      _startContinuousPosition('x', -1);
                    },
                    onLongPressEnd: (_) {
                      _stopContinuousZoom();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: const Icon(Icons.arrow_back, size: 18),
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _templateController.offsetX = (_templateController.offsetX + 10).clamp(-300.0, 300.0);
                      });
                    },
                    onLongPress: () {
                      _startContinuousPosition('x', 1);
                    },
                    onLongPressEnd: (_) {
                      _stopContinuousZoom();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: const Icon(Icons.arrow_forward, size: 18),
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Y Position Slider
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Y: ${_templateController.offsetY.toInt()}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
              Slider(
                value: _templateController.offsetY,
                min: -300,
                max: 300,
                onChanged: (value) {
                  setState(() {
                    _templateController.offsetY = value;
                  });
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _templateController.offsetY = (_templateController.offsetY - 10).clamp(-300.0, 300.0);
                      });
                    },
                    onLongPress: () {
                      _startContinuousPosition('y', -1);
                    },
                    onLongPressEnd: (_) {
                      _stopContinuousZoom();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: const Icon(Icons.arrow_upward, size: 18),
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _templateController.offsetY = (_templateController.offsetY + 10).clamp(-300.0, 300.0);
                      });
                    },
                    onLongPress: () {
                      _startContinuousPosition('y', 1);
                    },
                    onLongPressEnd: (_) {
                      _stopContinuousZoom();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: const Icon(Icons.arrow_downward, size: 18),
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Reset All Button
          Center(
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _templateController.resetToInitial();
                });
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Reset All', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveSection() {
    final isGridMode = _templates[_selectedTemplate]?['isGrid'] == true;
    final bool isReady = isGridMode
        ? _gridImages.any((img) => img != null) && _textController.text.trim().isNotEmpty
        : _selectedImage != null && _textController.text.trim().isNotEmpty;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isReady ? Colors.green[50] : Colors.orange[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isReady ? Colors.green[200]! : Colors.orange[200]!,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                isReady ? Icons.check_circle : Icons.info,
                color: isReady ? Colors.green[600] : Colors.orange[600],
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isReady ? 'Ready to save!' : 'Add an image and text to continue',
                  style: TextStyle(
                    color: isReady ? Colors.green[700] : Colors.orange[700],
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          
          if (isReady) ...[
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                return SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _savePost,
                icon: const Icon(Icons.save),
                label: const Text('Save Post'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  void _showMenuDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Menu'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.help_outline),
                title: const Text('Help'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showHelpDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Settings'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showSettingsDialog();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How to Use'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📱 Post Maker Features:'),
            Text('• Choose from multiple templates'),
            Text('• Add your own images'),
            Text('• Customize text and fonts'),
            Text('• Drag and zoom images'),
            Text('• Save to gallery'),
            SizedBox(height: 16),
            Text('✂️ Image Cropper Features:'),
            Text('• Select multiple images'),
            Text('• Crop each image individually'),
            Text('• Navigate with Previous/Next'),
            Text('• Export all cropped images'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settings'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('⚙️ Settings coming soon!'),
            SizedBox(height: 8),
            Text('Future features:'),
            Text('• Export quality settings'),
            Text('• Default font preferences'),
            Text('• Auto-save options'),
            Text('• Theme customization'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showPreviewEditDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Preview'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Text editing section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.text_fields, color: Colors.purple[600], size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Edit Text',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _textController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Enter your post text here...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Horizontal scrollable font selector
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Font',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 44,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: getAllFonts().length,
                            itemBuilder: (context, index) {
                              final font = getAllFonts()[index];
                              final isSelected = _selectedFont == font;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  selected: isSelected,
                                  label: Text(
                                    font.displayName,
                                    style: TextStyle(
                                      fontFamily: font.family,
                                      fontWeight: font.weight ?? FontWeight.w400,
                                      fontStyle: font.style ?? FontStyle.normal,
                                      fontSize: 13,
                                    ),
                                  ),
                                  selectedColor: Colors.blue[100],
                                  backgroundColor: Colors.grey[100],
                                  onSelected: (_) {
                                    setState(() {
                                      _selectedFont = font;
                                    });
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Image editing section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.image, color: Colors.blue[600], size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Edit Image',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Image preview
                    Container(
                      width: double.infinity,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: _selectedImage != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                _selectedImage!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate,
                                  size: 32,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No image selected',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Image action buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _pickImage,
                            icon: const Icon(Icons.photo_library, size: 18),
                            label: const Text('Gallery'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final ImagePicker picker = ImagePicker();
                              final XFile? image = await picker.pickImage(source: ImageSource.camera);
                              if (image != null) {
                                setState(() {
                                  _selectedImage = File(image.path);
                                });
                              }
                            },
                            icon: const Icon(Icons.camera_alt, size: 18),
                            label: const Text('Camera'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    if (_selectedImage != null) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _selectedImage = null;
                            });
                          },
                          icon: const Icon(Icons.delete, size: 18),
                          label: const Text('Remove Image'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {}); // Refresh the preview
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  double _calculatePreviewFontSize(String text, double width) {
    if (text.isEmpty) return width * 0.05;
    double baseSize = width * 0.05;
    if (text.length > 50) baseSize *= 0.7;
    else if (text.length > 30) baseSize *= 0.8;
    else if (text.length > 20) baseSize *= 0.9;
    return baseSize.clamp(12.0, 24.0);
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.grey[600], size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentBottomNavIndex == index;
    return InkWell(
      onTap: () {
        setState(() {
          _currentBottomNavIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.purple : Colors.grey[600],
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.purple : Colors.grey[600],
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
