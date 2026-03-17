import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';
import '../../widgets/base_template_widget.dart';
import '../../templates/image_post/template_definitions.dart';
import '../../utils/font_selector.dart';
import '../../utils/image_generator.dart';
import '../../services/ad_service.dart';
import '../../services/app_review_service.dart';

class SingleImagePostScreen extends StatefulWidget {
  final String selectedTemplate;
  final TextEditingController textController;
  final TemplateViewController templateController;
  final GlobalKey previewTemplateKey;
  final bool showPlaceholder;

  const SingleImagePostScreen({
    super.key,
    required this.selectedTemplate,
    required this.textController,
    required this.templateController,
    required this.previewTemplateKey,
    required this.showPlaceholder,
  });

  @override
  State<SingleImagePostScreen> createState() => _SingleImagePostScreenState();
}

class _SingleImagePostScreenState extends State<SingleImagePostScreen> {
  File? _selectedImage;
  
  // Text styling state
  late Color _textColor;
  late Color _textBoxColor;
  late bool _enableTextShadow;
  late bool _enableTextGlow;
  late Color _shadowColor;
  late Color _glowColor;
  late double _glowRadius;
  late double _letterSpacing;
  late double _fontSize;
  late FontInfo? _selectedFont;
  late double _shadowOffsetX;
  late double _shadowOffsetY;
  late double _shadowBlur;
  late bool _enableTextStroke;
  late Color _strokeColor;
  late double _strokeWidth;
  late double _textOpacity;

  @override
  void initState() {
    super.initState();
    // Initialize with default values
    _textColor = Colors.black87;
    _textBoxColor = Colors.white;
    _enableTextShadow = false;
    _enableTextGlow = false;
    _shadowColor = Colors.black;
    _glowColor = Colors.white;
    _glowRadius = 10.0;
    _letterSpacing = 0.0;
    _fontSize = 1.0;
    _selectedFont = null;
    _shadowOffsetX = 2.0;
    _shadowOffsetY = 2.0;
    _shadowBlur = 4.0;
    _enableTextStroke = false;
    _strokeColor = Colors.black;
    _strokeWidth = 1.0;
    _textOpacity = 1.0;
  }

  Map<String, Map<String, dynamic>> get _templates {
    return TemplateDefinitions.templates.map(
      (key, config) => MapEntry(key, config.toMap()),
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
      case 'stroke':
        currentColor = _strokeColor;
        title = 'Stroke Color';
        break;
      default:
        currentColor = _textColor;
        title = 'Color';
    }
    
    final hexController = TextEditingController(
      text: currentColor.value.toRadixString(16).substring(2).toUpperCase(),
    );
    
    Color previewColor = currentColor;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Select $title'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  children: [
                    for (final color in [
                      Colors.black87, Colors.white, Colors.red, Colors.green,
                      Colors.blue, Colors.yellow, Colors.orange, Colors.purple,
                      Colors.pink, Colors.cyan, Colors.amber, Colors.grey,
                    ])
                      GestureDetector(
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
                              case 'stroke':
                                _strokeColor = color;
                                break;
                            }
                          });
                          Navigator.pop(context);
                        },
                        child: Container(
                          margin: const EdgeInsets.all(8),
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: currentColor == color ? Colors.black : Colors.grey[300]!,
                              width: currentColor == color ? 3 : 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                const Text('Or enter hex code:', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: hexController,
                        decoration: InputDecoration(
                          hintText: 'e.g., FF0000',
                          prefixText: '#',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        maxLength: 6,
                        onChanged: (value) {
                          if (value.isNotEmpty && value.length <= 6) {
                            try {
                              final hexValue = value.toUpperCase().padRight(6, '0');
                              final color = Color(int.parse('FF$hexValue', radix: 16));
                              setDialogState(() {
                                previewColor = color;
                              });
                            } catch (e) {
                              // Invalid hex code
                            }
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: previewColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                    ),
                  ],
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
                setState(() {
                  switch (type) {
                    case 'text':
                      _textColor = previewColor;
                      break;
                    case 'box':
                      _textBoxColor = previewColor;
                      break;
                    case 'shadow':
                      _shadowColor = previewColor;
                      break;
                    case 'glow':
                      _glowColor = previewColor;
                      break;
                    case 'stroke':
                      _strokeColor = previewColor;
                      break;
                  }
                });
                Navigator.pop(context);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
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
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an image'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final bool hasText = widget.textController.text.trim().isNotEmpty;

    // Show loading dialog
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

    try {
      final String? savedPath = await ImageGenerator.savePostToGallery(
        text: widget.textController.text,
        imageFile: _selectedImage,
        transform: null,
        selectedFont: _selectedFont,
        templateKey: widget.previewTemplateKey,
      );

      if (!mounted) return;
      Navigator.of(context).pop();

      AppReviewService().incrementExportCount();
      AppReviewService().checkAndRequestReview();

      if (savedPath != null) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                      child: const Icon(Icons.check, color: Colors.white, size: 48),
                    ),
                    const SizedBox(height: 20),
                    const Text('Success!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 8),
                    const Text('Your post has been saved successfully', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.black54)),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green[200]!)),
                      child: Row(
                        children: [
                          Icon(Icons.folder, color: Colors.green[700], size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text(savedPath, style: TextStyle(fontSize: 11, color: Colors.grey[700]), maxLines: 2, overflow: TextOverflow.ellipsis)),
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
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.grey[700], side: BorderSide(color: Colors.grey[300]!), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
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
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open file')));
                                }
                              }
                            },
                            icon: const Icon(Icons.photo_library, size: 18),
                            label: const Text('Open'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green[600], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save post'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving post: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Preview Section
            Container(
              margin: const EdgeInsets.fromLTRB(0, 0, 0, 8),
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _buildPreviewSection(),
            ),
            
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
                  _buildImageSection(),
                  const SizedBox(height: 12),
                  _buildImageAdjustmentsSection(),
                  const SizedBox(height: 12),
                  _buildTextSection(),
                  const SizedBox(height: 12),
                  _buildTextStylingSection(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewSection() {
    final templateConfig = _templates[widget.selectedTemplate]!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth;
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
                InstagramPostTemplate(
                  key: widget.previewTemplateKey,
                  text: widget.textController.text,
                  image: _selectedImage,
                  gridImages: const [],
                  isGridMode: false,
                  width: previewWidth,
                  height: previewHeight,
                  isPreview: true,
                  controller: widget.templateController,
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
                  textController: widget.textController,
                  showPlaceholder: widget.showPlaceholder,
                  onTextChanged: (value) {
                    setState(() {});
                  },
                  onImageLoaded: () {
                    setState(() {});
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

  Widget _buildImageSection() {
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
              const Text(
                'Image',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _selectedImage != null ? _savePost : null,
                icon: const Icon(Icons.save, size: 18),
                label: const Text('Save'),
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.resolveWith<Color>((states) {
                    if (states.contains(MaterialState.disabled)) {
                      return Colors.grey.shade300;
                    }
                    return Colors.green.shade600;
                  }),
                  foregroundColor: MaterialStateProperty.resolveWith<Color>((states) {
                    if (states.contains(MaterialState.disabled)) {
                      return Colors.grey.shade600;
                    }
                    return Colors.white;
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
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
          ),
        ],
      ),
    );
  }

  Widget _buildImageAdjustmentsSection() {
    if (_selectedImage == null) {
      return const SizedBox.shrink();
    }
    return const SizedBox.shrink(); // Placeholder for now
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
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: widget.textController,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Enter your post text here...',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(16),
            ),
            onChanged: (value) {
              setState(() {});
            },
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
          // Text Shadow Toggle
          Row(
            children: [
              Expanded(
                child: SwitchListTile(
                  title: const Text('Text Shadow', style: TextStyle(fontWeight: FontWeight.w500)),
                  value: _enableTextShadow,
                  onChanged: (value) {
                    setState(() {
                      _enableTextShadow = value;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              if (_enableTextShadow)
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
          // Text Glow Toggle
          Row(
            children: [
              Expanded(
                child: SwitchListTile(
                  title: const Text('Text Glow', style: TextStyle(fontWeight: FontWeight.w500)),
                  value: _enableTextGlow,
                  onChanged: (value) {
                    setState(() {
                      _enableTextGlow = value;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              if (_enableTextGlow)
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
          
          const SizedBox(height: 12),
          
          // Shadow Position X
          Text('Shadow Offset X: ${_shadowOffsetX.toStringAsFixed(1)}', 
            style: const TextStyle(fontWeight: FontWeight.w500)),
          Slider(
            value: _shadowOffsetX,
            min: -10.0,
            max: 10.0,
            divisions: 40,
            label: _shadowOffsetX.toStringAsFixed(1),
            onChanged: (value) {
              setState(() {
                _shadowOffsetX = value;
              });
            },
          ),
          
          // Shadow Position Y
          Text('Shadow Offset Y: ${_shadowOffsetY.toStringAsFixed(1)}', 
            style: const TextStyle(fontWeight: FontWeight.w500)),
          Slider(
            value: _shadowOffsetY,
            min: -10.0,
            max: 10.0,
            divisions: 40,
            label: _shadowOffsetY.toStringAsFixed(1),
            onChanged: (value) {
              setState(() {
                _shadowOffsetY = value;
              });
            },
          ),
          
          // Shadow Blur
          Text('Shadow Blur: ${_shadowBlur.toStringAsFixed(1)}', 
            style: const TextStyle(fontWeight: FontWeight.w500)),
          Slider(
            value: _shadowBlur,
            min: 0.0,
            max: 20.0,
            divisions: 40,
            label: _shadowBlur.toStringAsFixed(1),
            onChanged: (value) {
              setState(() {
                _shadowBlur = value;
              });
            },
          ),
          
          const SizedBox(height: 12),
          
          // Glow Radius
          Text('Glow Radius: ${_glowRadius.toStringAsFixed(1)}', 
            style: const TextStyle(fontWeight: FontWeight.w500)),
          Slider(
            value: _glowRadius,
            min: 0.0,
            max: 50.0,
            divisions: 50,
            label: _glowRadius.toStringAsFixed(1),
            onChanged: (value) {
              setState(() {
                _glowRadius = value;
              });
            },
          ),
          
          const SizedBox(height: 12),
          
          // Text Stroke
          Row(
            children: [
              Expanded(
                child: SwitchListTile(
                  title: const Text('Text Stroke', style: TextStyle(fontWeight: FontWeight.w500)),
                  value: _enableTextStroke,
                  onChanged: (value) {
                    setState(() {
                      _enableTextStroke = value;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              if (_enableTextStroke)
                GestureDetector(
                  onTap: () => _showColorPicker('stroke'),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _strokeColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                  ),
                ),
            ],
          ),
          
          if (_enableTextStroke) ...[
            Text('Stroke Width: ${_strokeWidth.toStringAsFixed(1)}', 
              style: const TextStyle(fontWeight: FontWeight.w500)),
            Slider(
              value: _strokeWidth,
              min: 0.5,
              max: 5.0,
              divisions: 18,
              label: _strokeWidth.toStringAsFixed(1),
              onChanged: (value) {
                setState(() {
                  _strokeWidth = value;
                });
              },
            ),
          ],
          
          const SizedBox(height: 12),
          
          // Text Opacity
          Text('Text Opacity: ${(_textOpacity * 100).toInt()}%', 
            style: const TextStyle(fontWeight: FontWeight.w500)),
          Slider(
            value: _textOpacity,
            min: 0.0,
            max: 1.0,
            divisions: 20,
            label: '${(_textOpacity * 100).toInt()}%',
            onChanged: (value) {
              setState(() {
                _textOpacity = value;
              });
            },
          ),
          
          const SizedBox(height: 12),
          
          // Font Selector
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
}
