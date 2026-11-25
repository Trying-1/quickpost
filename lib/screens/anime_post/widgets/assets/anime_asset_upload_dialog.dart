import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../config/app_theme.dart';
import '../../models/anime_image_asset.dart';
import '../../services/anime_asset_storage_service.dart';
import '../../services/anime_database_service.dart';

/// Dialog/Sheet to upload new images and categorize & tag them under anime titles.
class AnimeAssetUploadDialog extends StatefulWidget {
  final String? initialCategory;
  final List<String>? initialSourceFilePaths;
  final List<String>? suggestedAnimeNames;

  const AnimeAssetUploadDialog({
    super.key,
    this.initialCategory,
    this.initialSourceFilePaths,
    this.suggestedAnimeNames,
  });

  static Future<List<AnimeImageAsset>?> show(
    BuildContext context, {
    String? initialCategory,
    List<String>? initialSourceFilePaths,
    List<String>? suggestedAnimeNames,
  }) {
    return showDialog<List<AnimeImageAsset>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AnimeAssetUploadDialog(
        initialCategory: initialCategory,
        initialSourceFilePaths: initialSourceFilePaths,
        suggestedAnimeNames: suggestedAnimeNames,
      ),
    );
  }

  @override
  State<AnimeAssetUploadDialog> createState() => _AnimeAssetUploadDialogState();
}

class _AnimeAssetUploadDialogState extends State<AnimeAssetUploadDialog> {
  final List<String> _selectedFilePaths = [];
  final TextEditingController _customAnimeController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
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
    _customAnimeController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final list = await AnimeAssetStorageService.instance.getCategories();
    final dbNames = await AnimeDatabaseService.instance.getNames();
    final combinedSet = <String>{...list, ...dbNames};
    final combinedList = combinedSet.toList();
    combinedList.sort((a, b) {
      if (a == 'General') return -1;
      if (b == 'General') return 1;
      return a.toLowerCase().compareTo(b.toLowerCase());
    });

    if (mounted) {
      setState(() {
        _categories = combinedList;
        if (widget.initialCategory != null &&
            widget.initialCategory != 'All' &&
            widget.initialCategory!.trim().isNotEmpty) {
          _selectedCategory = widget.initialCategory!.trim();
          if (!_categories.contains(_selectedCategory)) {
            _categories.add(_selectedCategory);
          }
        } else if (_categories.isNotEmpty) {
          _selectedCategory = _categories.first;
        }
      });
    }
  }

  void _selectAnimeTag(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      if (!_categories.contains(trimmed)) {
        _categories.add(trimmed);
      }
      _selectedCategory = trimmed;
      _customAnimeController.text = trimmed;
    });
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
        const SnackBar(content: Text('Please select at least one image to upload.')),
      );
      return;
    }

    final animeName = _isCreatingNewCategory
        ? _customAnimeController.text.trim()
        : _selectedCategory.trim();

    if (animeName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or specify an anime category name.')),
      );
      return;
    }

    final rawTags = _tagsController.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    setState(() => _isLoading = true);
    try {
      final imported = await AnimeAssetStorageService.instance.importImages(
        animeName: animeName,
        tags: rawTags,
        sourceFilePaths: _selectedFilePaths,
      );
      if (mounted) {
        Navigator.of(context).pop(imported);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to import images: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final suggestions = widget.suggestedAnimeNames
            ?.map((s) => s.trim())
            .where((s) => s.isNotEmpty && s != 'New Anime Recommendation')
            .toSet()
            .toList() ??
        [];

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 440,
          maxHeight: (screenHeight * 0.88).clamp(360.0, 620.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.cloud_upload_rounded, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Upload & Tag Anime Images',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                        ),
                        Text(
                          'Tag images by anime title for auto-filling slides',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Quick Tag Suggestions from Current Slides
              if (suggestions.isNotEmpty) ...[
                const Row(
                  children: [
                    Icon(Icons.label_outline_rounded, size: 13, color: AppColors.primary),
                    SizedBox(width: 4),
                    Text(
                      'Slide Anime Suggestions:',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: suggestions.map((name) {
                      final isSelected = (_isCreatingNewCategory
                              ? _customAnimeController.text.trim().toLowerCase()
                              : _selectedCategory.toLowerCase()) ==
                          name.toLowerCase();
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          visualDensity: VisualDensity.compact,
                          backgroundColor: isSelected ? AppColors.primarySurface : Colors.grey.shade100,
                          side: BorderSide(
                            color: isSelected ? AppColors.primary : Colors.grey.shade300,
                            width: isSelected ? 1.5 : 1.0,
                          ),
                          label: Text(
                            name,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? AppColors.primary : Colors.grey.shade800,
                            ),
                          ),
                          onPressed: () => _selectAnimeTag(name),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // Category Selection
              const Text(
                'Anime Name / Tag',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 5),

              Row(
                children: [
                  Expanded(
                    child: _isCreatingNewCategory
                        ? TextField(
                            controller: _customAnimeController,
                            autofocus: true,
                            decoration: InputDecoration(
                              hintText: 'e.g. Solo Leveling, Bleach...',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: _categories.contains(_selectedCategory)
                                    ? _selectedCategory
                                    : (_categories.isNotEmpty ? _categories.first : 'General'),
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
                    tooltip: _isCreatingNewCategory ? 'Choose existing category' : 'Enter new anime name',
                    icon: Icon(
                      _isCreatingNewCategory ? Icons.list_rounded : Icons.add_circle_outline_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    onPressed: () {
                      setState(() {
                        _isCreatingNewCategory = !_isCreatingNewCategory;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Additional Tags Input (Optional)
              TextField(
                controller: _tagsController,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Additional tags: e.g. Poster, Action, Tanjiro (optional)',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  prefixIcon: const Icon(Icons.tag_rounded, size: 15, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 10),

              // Images Picker & Preview
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Selected Images (${_selectedFilePaths.length})',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  TextButton.icon(
                    onPressed: _isLoading ? null : _pickImages,
                    icon: const Icon(Icons.add_photo_alternate_outlined, size: 15),
                    label: const Text('Add Images', style: TextStyle(fontSize: 11.5)),
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              Expanded(
                child: _selectedFilePaths.isEmpty
                    ? InkWell(
                        onTap: _pickImages,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_rounded, size: 36, color: Colors.grey.shade400),
                              const SizedBox(height: 6),
                              const Text(
                                'Tap to choose images from gallery',
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Select one or multiple images to tag',
                                style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        ),
                      )
                    : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 1,
                        ),
                        itemCount: _selectedFilePaths.length,
                        itemBuilder: (context, index) {
                          final path = _selectedFilePaths[index];
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(path),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: Colors.grey.shade200,
                                    child: const Icon(Icons.broken_image, size: 24, color: Colors.grey),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedFilePaths.removeAt(index);
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, size: 14, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),

              const SizedBox(height: 12),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _isLoading || _selectedFilePaths.isEmpty ? null : _onSave,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_rounded, size: 18),
                    label: Text(_isLoading ? 'Importing...' : 'Upload & Tag'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
}
