import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../config/app_theme.dart';
import '../../models/carousel_image_asset.dart';
import '../../services/carousel_asset_storage_service.dart';

/// Dialog to upload new images and categorize them under a topic/category.
class CarouselAssetUploadDialog extends StatefulWidget {
  final String? initialCategory;
  final List<String>? initialSourceFilePaths;

  const CarouselAssetUploadDialog({
    super.key,
    this.initialCategory,
    this.initialSourceFilePaths,
  });

  static Future<List<CarouselImageAsset>?> show(
    BuildContext context, {
    String? initialCategory,
    List<String>? initialSourceFilePaths,
  }) {
    return showDialog<List<CarouselImageAsset>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CarouselAssetUploadDialog(
        initialCategory: initialCategory,
        initialSourceFilePaths: initialSourceFilePaths,
      ),
    );
  }

  @override
  State<CarouselAssetUploadDialog> createState() => _CarouselAssetUploadDialogState();
}

class _CarouselAssetUploadDialogState extends State<CarouselAssetUploadDialog> {
  final List<String> _selectedFilePaths = [];
  final TextEditingController _customCategoryController = TextEditingController();
  List<String> _categories = [];
  String _selectedCategory = 'General';
  bool _isCreatingNewCategory = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialSourceFilePaths != null) {
      _selectedFilePaths.addAll(widget.initialSourceFilePaths!);
    }
    _loadCategories();
  }

  @override
  void dispose() {
    _customCategoryController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final list = await CarouselAssetStorageService.instance.loadCategories();
    if (mounted) {
      setState(() {
        _categories = list;
        if (widget.initialCategory != null &&
            widget.initialCategory != 'All' &&
            widget.initialCategory!.trim().isNotEmpty) {
          _selectedCategory = widget.initialCategory!;
          if (!_categories.contains(_selectedCategory)) {
            _categories.add(_selectedCategory);
          }
        } else if (_categories.isNotEmpty) {
          _selectedCategory = _categories.first;
        }
      });
    }
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    try {
      final pickedFiles = await picker.pickMultiImage();
      if (pickedFiles.isNotEmpty) {
        setState(() {
          for (final f in pickedFiles) {
            if (!_selectedFilePaths.contains(f.path)) {
              _selectedFilePaths.add(f.path);
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error picking multi-images: $e');
    }
  }

  Future<void> _onSave() async {
    if (_selectedFilePaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one image.')),
      );
      return;
    }

    String categoryToUse = _selectedCategory;
    if (_isCreatingNewCategory) {
      final custom = _customCategoryController.text.trim();
      if (custom.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a category name.')),
        );
        return;
      }
      categoryToUse = custom;
    }

    setState(() => _isLoading = true);

    try {
      final files = _selectedFilePaths.map((p) => File(p)).toList();
      final imported = await CarouselAssetStorageService.instance.importMultipleImages(
        files: files,
        category: categoryToUse,
      );

      if (mounted) {
        Navigator.pop(context, imported);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: AppColors.primarySurface,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.cloud_upload_rounded, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          const Text(
            'Upload Images',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image selection area
              if (_selectedFilePaths.isEmpty)
                InkWell(
                  onTap: _pickImages,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_rounded, size: 36, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        Text(
                          'Tap to select images from gallery',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 80,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _selectedFilePaths.length + 1,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          if (i == _selectedFilePaths.length) {
                            return InkWell(
                              onTap: _pickImages,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 80,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: const Icon(Icons.add_rounded, color: AppColors.primary),
                              ),
                            );
                          }
                          final path = _selectedFilePaths[i];
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(path),
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() => _selectedFilePaths.removeAt(i));
                                  },
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    padding: const EdgeInsets.all(2),
                                    child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_selectedFilePaths.length} image(s) selected',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),

              const SizedBox(height: 16),
              const Text(
                'Category / Topic',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),

              if (!_isCreatingNewCategory)
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _categories.contains(_selectedCategory) ? _selectedCategory : (_categories.isNotEmpty ? _categories.first : null),
                            isExpanded: true,
                            items: _categories.map((c) {
                              return DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedCategory = val);
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'New Category',
                      icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
                      onPressed: () => setState(() => _isCreatingNewCategory = true),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _customCategoryController,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Enter new category name',
                          hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.grey),
                      onPressed: () => setState(() => _isCreatingNewCategory = false),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _onSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: _isLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Save to Library'),
        ),
      ],
    );
  }
}

