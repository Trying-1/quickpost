import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../services/analytics_service.dart';
import '../../utils/font_selector.dart';
import '../../widgets/base_template_widget.dart';
import 'textbox_image/services/textbox_image_export_service.dart';
import 'textbox_image/widgets/textbox_image_pickers.dart';
import 'textbox_image/widgets/textbox_image_preview.dart';
import 'textbox_image/widgets/textbox_image_style_tabs.dart';

/// Editor screen for Textbox Image posts with live Single Photo and 2x2 Grid modes.
class TextboxImageScreen extends StatefulWidget {
  final bool isGridMode;
  final List<String>? sharedImagePaths;
  final String? sharedPurpose;

  const TextboxImageScreen({
    super.key,
    this.isGridMode = false,
    this.sharedImagePaths,
    this.sharedPurpose,
  });

  @override
  State<TextboxImageScreen> createState() => _TextboxImageScreenState();
}

class _TextboxImageScreenState extends State<TextboxImageScreen> {
  final TextEditingController _textController = TextEditingController();
  final TemplateViewController _templateController = TemplateViewController();
  final GlobalKey _previewTemplateKey = GlobalKey();

  File? _selectedImage;
  List<File?> _gridImages = [null, null, null, null];
  FontInfo? _selectedFont;
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

  int _selectedTabIndex = 0; // 0: Image, 1: Text, 2: Font, 3: Colors, 4: Effects, 5: Spacing
  bool _isTabContentExpanded = false;
  late bool _isGridMode;
  int _selectedAspectIndex = 0; // 0: 4:5, 1: 1:1, 2: 9:16, 3: 16:9

  static const _tabs = <Map<String, Object>>[
    {
      'icon': Icons.photo_library_outlined,
      'label': 'Image',
      'color': Colors.blue,
    },
    {'icon': Icons.title, 'label': 'Text', 'color': Colors.teal},
    {
      'icon': Icons.font_download_outlined,
      'label': 'Font',
      'color': Colors.green,
    },
    {
      'icon': Icons.format_color_text,
      'label': 'Colors',
      'color': Colors.deepOrange,
    },
    {'icon': Icons.auto_awesome, 'label': 'Effects', 'color': Colors.purple},
    {'icon': Icons.format_size, 'label': 'Spacing', 'color': Colors.indigo},
  ];

  bool get _hasImages => _isGridMode
      ? _gridImages.any((img) => img != null)
      : _selectedImage != null;

  @override
  void initState() {
    super.initState();
    _isGridMode = widget.isGridMode;
    _selectedFont = const FontInfo(
      family: 'Metrophobic',
      displayName: 'Metrophobic',
    );
    _loadSharedImages();
    _textController.addListener(() => setState(() {}));
    AnalyticsService().setCurrentScreen(screenName: 'Textbox Image');
  }

  @override
  void didUpdateWidget(covariant TextboxImageScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldPaths = oldWidget.sharedImagePaths;
    final newPaths = widget.sharedImagePaths;
    final oldPurpose = oldWidget.sharedPurpose;
    final newPurpose = widget.sharedPurpose;

    if (newPaths != null && newPaths.isNotEmpty) {
      final wasEmptyBefore = oldPaths == null || oldPaths.isEmpty;
      final lengthChanged =
          oldPaths == null || oldPaths.length != newPaths.length;
      final firstChanged = oldPaths == null ||
          oldPaths.isEmpty ||
          oldPaths.first != newPaths.first;
      final purposeChanged = oldPurpose != newPurpose;

      if (wasEmptyBefore || lengthChanged || firstChanged || purposeChanged) {
        _loadSharedImages();
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _loadSharedImages() {
    final paths = widget.sharedImagePaths;
    if (paths == null || paths.isEmpty) return;

    final purpose = widget.sharedPurpose;
    setState(() {
      if (purpose == 'grid_post' || (purpose == null && paths.length > 1)) {
        _isGridMode = true;
        for (int i = 0; i < paths.length && i < 4; i++) {
          _gridImages[i] = File(paths[i]);
        }
      } else if (_isGridMode) {
        for (int i = 0; i < paths.length && i < 4; i++) {
          _gridImages[i] = File(paths[i]);
        }
      } else if (purpose == 'single_image_post' || paths.length == 1) {
        _isGridMode = false;
        _selectedImage = File(paths.first);
      }
    });
  }

  void _setGridMode(bool gridMode) {
    if (_isGridMode == gridMode) return;
    setState(() {
      _isGridMode = gridMode;
      if (gridMode) {
        if (_selectedImage != null && _gridImages.every((f) => f == null)) {
          _gridImages[0] = _selectedImage;
        }
      } else {
        _selectedImage ??= _gridImages.firstWhere(
          (f) => f != null,
          orElse: () => null,
        );
      }
    });
  }

  Future<void> _pickSingleImage() async {
    try {
      await [Permission.photos, Permission.storage].request();
      if (!(await Permission.photos.isGranted) &&
          !(await Permission.storage.isGranted)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permission needed to pick images')),
          );
        }
        return;
      }

      final XFile? image =
          await ImagePicker().pickImage(source: ImageSource.gallery);
      if (image != null && mounted) {
        setState(() => _selectedImage = File(image.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _pickGridImage(int index) async {
    try {
      await [Permission.photos, Permission.storage].request();
      final XFile? image =
          await ImagePicker().pickImage(source: ImageSource.gallery);
      if (image != null && mounted) {
        setState(() => _gridImages[index] = File(image.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _pickAllGridImages() async {
    try {
      await [Permission.photos, Permission.storage].request();
      final List<XFile> images = await ImagePicker().pickMultiImage();
      if (images.isNotEmpty && mounted) {
        setState(() {
          for (int i = 0; i < images.length && i < 4; i++) {
            _gridImages[i] = File(images[i].path);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking images: $e')),
        );
      }
    }
  }

  Future<void> _savePost() {
    return TextboxImageExportService.savePost(
      context: context,
      analyticsFeature: _isGridMode ? 'grid_post' : 'single_image_post',
      hasImages: _hasImages,
      missingImageMessage: _isGridMode
          ? 'Please select at least one image'
          : 'Please select an image',
      text: _textController.text,
      singleImage: _isGridMode ? null : _selectedImage,
      selectedFont: _selectedFont,
      previewTemplateKey: _previewTemplateKey,
      aspectRatio: textboxImageAspectRatio(_selectedAspectIndex),
      onShowPlaceholderChanged: (show) {
        if (mounted) setState(() => _showPlaceholder = show);
      },
    );
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
          'Textbox Image',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ),
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: TextboxImagePreviewArea(
                selectedAspectIndex: _selectedAspectIndex,
                onAspectChanged: (idx) =>
                    setState(() => _selectedAspectIndex = idx),
                previewTemplateKey: _previewTemplateKey,
                templateController: _templateController,
                textController: _textController,
                singleImage: _isGridMode ? null : _selectedImage,
                gridImages: _isGridMode
                    ? _gridImages
                    : const [null, null, null, null],
                isGridMode: _isGridMode,
                hasImages: _hasImages,
                emptyCtaLabel: _isGridMode ? 'Add images' : 'Add image',
                onEmptyPickPressed:
                    _isGridMode ? _pickAllGridImages : _pickSingleImage,
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
                fontSize: _fontSize,
                showPlaceholder: _showPlaceholder,
                onTextChanged: () => setState(() {}),
                onImageLoaded: () {
                  if (mounted) setState(() {});
                },
              ),
            ),
            _buildControlsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
              child: SingleChildScrollView(child: _buildActiveTabContent()),
            ),
          _buildControlTabs(),
        ],
      ),
    );
  }

  Widget _buildControlTabs() {
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: const Icon(Icons.download, size: 20),
            ),
          ),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _tabs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 4),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemBuilder: (_, index) {
                final isSelected = _selectedTabIndex == index;
                final tab = _tabs[index];
                final baseColor = tab['color']! as Color;
                final highlighted = isSelected && _isTabContentExpanded;
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
                      color: highlighted
                          ? baseColor.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          tab['icon']! as IconData,
                          size: 22,
                          color: highlighted ? baseColor : Colors.grey[600],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tab['label']! as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: highlighted
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: highlighted ? baseColor : Colors.grey[700],
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

  Widget _buildActiveTabContent() {
    switch (_selectedTabIndex) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Layout Mode',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(
                      value: false,
                      label: Text('Single', style: TextStyle(fontSize: 11)),
                    ),
                    ButtonSegment<bool>(
                      value: true,
                      label: Text('2×2 Grid', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                  selected: {_isGridMode},
                  onSelectionChanged: (selection) =>
                      _setGridMode(selection.first),
                  style: const ButtonStyle(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_isGridMode)
              GridTextboxImagesPickerTab(
                gridImages: _gridImages,
                onPickGridImage: _pickGridImage,
                onClearGridSlot: (idx) =>
                    setState(() => _gridImages[idx] = null),
                onPickAllGridImages: _pickAllGridImages,
                onClearAllGridImages: () =>
                    setState(() => _gridImages = [null, null, null, null]),
              )
            else
              SingleTextboxImagePickerTab(
                selectedImage: _selectedImage,
                onPickImage: _pickSingleImage,
                onClearImage: () => setState(() => _selectedImage = null),
              ),
          ],
        );
      case 1:
        return TextboxImageTextTab(textController: _textController);
      case 2:
        return TextboxImageFontTab(
          selectedFont: _selectedFont,
          onFontSelected: (font) => setState(() => _selectedFont = font),
        );
      case 3:
        return TextboxImageColorsTab(
          textColor: _textColor,
          textBoxColor: _textBoxColor,
          onTextColorChanged: (c) => setState(() => _textColor = c),
          onBoxColorChanged: (c) => setState(() => _textBoxColor = c),
        );
      case 4:
        return TextboxImageEffectsTab(
          enableTextShadow: _enableTextShadow,
          shadowColor: _shadowColor,
          shadowOffsetX: _shadowOffsetX,
          shadowOffsetY: _shadowOffsetY,
          shadowBlurRadius: _shadowBlurRadius,
          enableTextGlow: _enableTextGlow,
          glowColor: _glowColor,
          glowRadius: _glowRadius,
          onEnableShadowChanged: (v) =>
              setState(() => _enableTextShadow = v),
          onShadowColorChanged: (c) => setState(() => _shadowColor = c),
          onShadowOffsetXChanged: (v) => setState(() => _shadowOffsetX = v),
          onShadowOffsetYChanged: (v) => setState(() => _shadowOffsetY = v),
          onShadowBlurRadiusChanged: (v) =>
              setState(() => _shadowBlurRadius = v),
          onEnableGlowChanged: (v) => setState(() => _enableTextGlow = v),
          onGlowColorChanged: (c) => setState(() => _glowColor = c),
          onGlowRadiusChanged: (v) => setState(() => _glowRadius = v),
        );
      default:
        return TextboxImageSpacingTab(
          letterSpacing: _letterSpacing,
          fontSize: _fontSize,
          onLetterSpacingChanged: (v) => setState(() => _letterSpacing = v),
          onFontSizeChanged: (v) => setState(() => _fontSize = v),
        );
    }
  }
}

