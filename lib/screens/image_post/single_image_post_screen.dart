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
import '../../widgets/advanced_color_picker.dart';
import '../video_creator/video_creator_screen.dart';
import '../audio_extraction/audio_extraction_screen.dart';
import '../audio_library/audio_library_screen_with_folders.dart';
import '../text_box_overlay/text_box_overlay_screen.dart';
import '../../services/app_review_service.dart';
import '../../services/analytics_service.dart';
import '../../services/ad_service.dart';
import 'templates/image_template_section.dart';

class SingleImagePostScreen extends StatefulWidget {
  final List<String>? sharedImagePaths;
  final String? sharedPurpose;

  const SingleImagePostScreen({
    super.key,
    this.sharedImagePaths,
    this.sharedPurpose,
  });

  @override
  State<SingleImagePostScreen> createState() => _SingleImagePostScreenState();
}

class _SingleImagePostScreenState extends State<SingleImagePostScreen> {
  final TextEditingController _textController = TextEditingController();
  final TemplateViewController _templateController = TemplateViewController();
  final GlobalKey _previewTemplateKey = GlobalKey();

  File? _selectedImage;
  FontInfo? _selectedFont;
  bool _isPreviewReady = false;
  bool _showPlaceholder = true;

  Color _textColor = Colors.black87;
  Color _textBoxColor = Colors.white;
  bool _enableTextShadow = false;
  bool _enableTextGlow = false;
  Color _shadowColor = Colors.black;
  Color _glowColor = Colors.white;
  double _glowRadius = 10.0;
  double _shadowOffsetX = 2.0;
  double _shadowOffsetY = 2.0;
  double _shadowBlurRadius = 4.0;
  double _letterSpacing = 0.0;
  double _fontSize = 1.0;

  Timer? _continuousTimer;

  int _selectedTabIndex = 0; // 0: Image, 1: Text, 2: Style

  bool _isTabContentExpanded = false;

  int _selectedStyleTabIndex = 0; // 0: Colors, 1: Effects, 2: Spacing

  // 0: 4:5, 1: 1:1, 2: 9:16, 3: 16:9
  int _selectedAspectIndex = 0;

  double get _currentAspectRatio {
    switch (_selectedAspectIndex) {
      case 1:
        return 1 / 1;
      case 2:
        return 9 / 16;
      case 3:
        return 16 / 9;
      case 0:
      default:
        return 4 / 5;
    }
  }

  Map<String, Map<String, dynamic>> get _templates {
    return TemplateDefinitions.templates.map(
      (key, config) => MapEntry(key, config.toMap()),
    );
  }

  @override
  void initState() {
    super.initState();
    _selectedFont = FontInfo(family: 'Metrophobic', displayName: 'Metrophobic');
    _loadSharedImages();
    _textController.addListener(() {
      setState(() {});
    });
    AnalyticsService().setCurrentScreen(screenName: 'Single Image Post');
  }

  @override
  void didUpdateWidget(covariant SingleImagePostScreen oldWidget) {
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

      setState(() {
        if (purpose == 'single_image_post' || paths.length == 1) {
          _selectedImage = File(paths.first);
        }
        _isPreviewReady = false;
      });
    }
  }

  Future<void> _pickImage() async {
    try {
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
          _isPreviewReady = false;
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
    AnalyticsService().logSaveAction(feature: 'single_image_post', type: 'image');
    final bool hasText = _textController.text.trim().isNotEmpty;

    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an image'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

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

    await Future.delayed(const Duration(milliseconds: 150));

    if (!hasText) {
      setState(() {
        _showPlaceholder = false;
      });
      await Future.delayed(const Duration(milliseconds: 100));
    }

    try {
      const int baseWidth = 1080;
      final double aspect = _currentAspectRatio;
      final int exportWidth;
      final int exportHeight;

      if (aspect >= 1.0) {
        exportWidth = baseWidth;
        exportHeight = (baseWidth / aspect).round();
      } else {
        exportHeight = baseWidth;
        exportWidth = (baseWidth * aspect).round();
      }

      final String? savedPath = await ImageGenerator.savePostToGallery(
        text: _textController.text,
        imageFile: _selectedImage,
        transform: null,
        selectedFont: _selectedFont,
        templateKey: _previewTemplateKey,
        outputWidth: exportWidth,
        outputHeight: exportHeight,
      );

      Navigator.of(context).pop();

      AppReviewService().incrementExportCount();
      AppReviewService().checkAndRequestReview();

      if (savedPath != null) {
        AdService().showInterstitialAd();
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
                    const Text(
                      'Success!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your post has been saved successfully',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 16),
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
      Navigator.of(context).pop();
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
      appBar: AppBar(
        toolbarHeight: 40,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        titleSpacing: 0,
        title: const Text(
          'Single Image Post',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ),
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildPreviewArea()),
            _buildControlsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewArea() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: _buildAspectRatioSelector(),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: _buildPreviewSection(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAspectRatioSelector() {
    const options = [
      {'label': '4:5', 'index': 0},
      {'label': '1:1', 'index': 1},
      {'label': '9:16', 'index': 2},
      {'label': '16:9', 'index': 3},
    ];

    return Row(
      children: [
        const Text(
          'Size',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: options.map((opt) {
                final idx = opt['index'] as int;
                final isSelected = _selectedAspectIndex == idx;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedAspectIndex = idx;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.black87 : Colors.grey[100],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected ? Colors.black87 : Colors.grey[300]!,
                        ),
                      ),
                      child: Text(
                        opt['label'] as String,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isSelected ? Colors.white : Colors.grey[800],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildControlsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isTabContentExpanded)
            Container(
              height: 180,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: SingleChildScrollView(
                child: _buildActiveTabContent(),
              ),
            ),
          _buildControlTabs(),
        ],
      ),
    );
  }

  Widget _buildActiveTabContent() {
    if (_selectedTabIndex == 0) return _buildImageSection();
    if (_selectedTabIndex == 1) return _buildTextSection();
    if (_selectedTabIndex == 2) return _buildFontSection();
    if (_selectedTabIndex == 3) return _buildStyleColorsSection();
    if (_selectedTabIndex == 4) return _buildStyleEffectsSection();
    return _buildStyleSpacingSection();
  }

  Widget _buildControlTabs() {
    final tabs = [
      {'icon': Icons.photo_library_outlined, 'label': 'Image', 'color': Colors.blue},
      {'icon': Icons.title, 'label': 'Text', 'color': Colors.teal},
      {'icon': Icons.font_download_outlined, 'label': 'Font', 'color': Colors.green},
      {'icon': Icons.format_color_text, 'label': 'Colors', 'color': Colors.deepOrange},
      {'icon': Icons.auto_awesome, 'label': 'Effects', 'color': Colors.purple},
      {'icon': Icons.format_size, 'label': 'Spacing', 'color': Colors.indigo},
    ];

    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 4),
            child: ElevatedButton(
              onPressed: _savePost,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black87,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: const Icon(Icons.download, size: 20),
            ),
          ),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: tabs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 4),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemBuilder: (context, index) {
                final isSelected = _selectedTabIndex == index;
                final tab = tabs[index];
                final Color baseColor = tab['color'] as Color;
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
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected && _isTabContentExpanded
                          ? baseColor.withOpacity(0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          tab['icon'] as IconData,
                          size: 22,
                          color: isSelected && _isTabContentExpanded ? baseColor : Colors.grey[600],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tab['label'] as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSelected && _isTabContentExpanded
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected && _isTabContentExpanded ? baseColor : Colors.grey[700],
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

  Widget _buildImageSection() {
    return Column(
      children: [
        _buildSingleImagePreview(),
      ],
    );
  }

  Widget _buildSingleImagePreview() {
    return Center(
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[300]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: _selectedImage != null
                    ? Image.file(_selectedImage!, fit: BoxFit.cover, width: 120, height: 120)
                    : Container(
                        color: Colors.grey[200],
                        child: Center(
                          child: Icon(Icons.add_photo_alternate, color: Colors.grey[600], size: 40),
                        ),
                      ),
              ),
            ),
            if (_selectedImage != null)
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedImage = null;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 18),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _textController,
          maxLines: 3,
          style: const TextStyle(fontSize: 14),
          decoration: const InputDecoration(
            hintText: 'Enter your post text here...',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.all(10),
            isDense: true,
          ),
        ),
      ],
    );
  }

  Widget _buildFontSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Font',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
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
                      fontSize: 12,
                    ),
                  ),
                  selectedColor: Colors.green[100],
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
    );
  }

  Widget _buildTextStylingSection() {
    return Container(
      padding: const EdgeInsets.all(14),
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
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildStyleTabs(),
          const SizedBox(height: 10),
          if (_selectedStyleTabIndex == 0) ...[
            _buildStyleColorsSection(),
          ] else if (_selectedStyleTabIndex == 1) ...[
            _buildStyleEffectsSection(),
          ] else ...[
            _buildStyleSpacingSection(),
          ],
        ],
      ),
    );
  }

  Widget _buildStyleTabs() {
    final tabs = [
      {'label': 'Colors'},
      {'label': 'Effects'},
      {'label': 'Spacing'},
    ];

    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final isSelected = _selectedStyleTabIndex == index;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedStyleTabIndex = index;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? Colors.orange[50] : Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? Colors.orange : Colors.grey[300]!,
                  width: 1,
                ),
              ),
              child: Text(
                tabs[index]['label'] as String,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.orange[800] : Colors.grey[800],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStyleColorsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Text Color:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => _showColorPicker('text'),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _textColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Text('Box Color:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => _showColorPicker('box'),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _textBoxColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStyleEffectsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title: const Text('Text Shadow', style: TextStyle(fontWeight: FontWeight.w500)),
          value: _enableTextShadow,
          onChanged: (value) {
            setState(() {
              _enableTextShadow = value;
            });
          },
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        if (_enableTextShadow) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Text('Shadow Color:', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => _showColorPicker('shadow'),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _shadowColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('X Offset', style: TextStyle(fontWeight: FontWeight.w500)),
              Expanded(
                child: Slider(
                  value: _shadowOffsetX,
                  min: -20,
                  max: 20,
                  onChanged: (v) => setState(() => _shadowOffsetX = v),
                ),
              ),
              Text(_shadowOffsetX.toStringAsFixed(1), style: const TextStyle(fontSize: 11)),
            ],
          ),
          Row(
            children: [
              const Text('Y Offset', style: TextStyle(fontWeight: FontWeight.w500)),
              Expanded(
                child: Slider(
                  value: _shadowOffsetY,
                  min: -20,
                  max: 20,
                  onChanged: (v) => setState(() => _shadowOffsetY = v),
                ),
              ),
              Text(_shadowOffsetY.toStringAsFixed(1), style: const TextStyle(fontSize: 11)),
            ],
          ),
          Row(
            children: [
              const Text('Blur', style: TextStyle(fontWeight: FontWeight.w500)),
              Expanded(
                child: Slider(
                  value: _shadowBlurRadius,
                  min: 0,
                  max: 20,
                  onChanged: (v) => setState(() => _shadowBlurRadius = v),
                ),
              ),
              Text(_shadowBlurRadius.toStringAsFixed(1), style: const TextStyle(fontSize: 11)),
            ],
          ),
          const SizedBox(height: 10),
        ],
        SwitchListTile(
          title: const Text('Text Glow', style: TextStyle(fontWeight: FontWeight.w500)),
          value: _enableTextGlow,
          onChanged: (value) {
            setState(() {
              _enableTextGlow = value;
            });
          },
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        if (_enableTextGlow) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Text('Glow Color:', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => _showColorPicker('glow'),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _glowColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Glow Radius: ${_glowRadius.toInt()}',
              style: const TextStyle(fontWeight: FontWeight.w500)),
          Slider(
            value: _glowRadius,
            min: 5.0,
            max: 30.0,
            onChanged: (value) {
              setState(() {
                _glowRadius = value;
              });
            },
          ),
        ],
      ],
    );
  }

  Widget _buildStyleSpacingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Letter Spacing: ${_letterSpacing.toStringAsFixed(1)}',
            style: const TextStyle(fontWeight: FontWeight.w500)),
        Slider(
          value: _letterSpacing,
          min: -2.0,
          max: 10.0,
          onChanged: (value) {
            setState(() {
              _letterSpacing = value;
            });
          },
        ),
        const SizedBox(height: 8),
        Text('Font Size: ${(_fontSize * 100).toInt()}%',
            style: const TextStyle(fontWeight: FontWeight.w500)),
        Slider(
          value: _fontSize,
          min: 0.5,
          max: 2.0,
          onChanged: (value) {
            setState(() {
              _fontSize = value;
            });
          },
        ),
      ],
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

    Color selectedColor = currentColor;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                initialColor: currentColor,
                onColorChanged: (color) => selectedColor = color,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      switch (type) {
                        case 'text':
                          _textColor = selectedColor;
                          break;
                        case 'box':
                          _textBoxColor = selectedColor;
                          break;
                        case 'shadow':
                          _shadowColor = selectedColor;
                          break;
                        case 'glow':
                          _glowColor = selectedColor;
                          break;
                      }
                    });
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
  }

  Widget _buildPreviewSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth;
        final double maxPreviewWidth = 600.0;
        final double previewWidth = availableWidth.clamp(180.0, maxPreviewWidth);
        final double previewHeight = previewWidth / _currentAspectRatio;

        return Center(
          child: SizedBox(
            width: previewWidth,
            height: previewHeight,
            child: Stack(
              children: [
                InstagramPostTemplate(
                  key: _previewTemplateKey,
                  text: _textController.text,
                  image: _selectedImage,
                  gridImages: const [null, null, null, null],
                  isGridMode: false,
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
                  shadowOffsetX: _shadowOffsetX,
                  shadowOffsetY: _shadowOffsetY,
                  shadowBlurRadius: _shadowBlurRadius,
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
                if (_selectedImage == null)
                  Positioned.fill(
                    child: Center(
                      child: ElevatedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.add_photo_alternate),
                        label: const Text('Add image'),
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
    if (_selectedImage == null) {
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
          ],
        ),
      ),
    );
  }
}
