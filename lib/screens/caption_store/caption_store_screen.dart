import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/caption_group.dart';
import '../../services/caption_backup_service.dart';
import '../../services/caption_store_service.dart';
import '../../services/analytics_service.dart';
import '../../config/app_theme.dart';

class CaptionStoreScreen extends StatefulWidget {
  const CaptionStoreScreen({super.key});

  @override
  State<CaptionStoreScreen> createState() => _CaptionStoreScreenState();
}

class _CaptionStoreScreenState extends State<CaptionStoreScreen> {
  List<CaptionGroup> _captions = [];
  List<String> _categories = [];
  String? _selectedCategory;
  String? _selectedVariantName;
  final TextEditingController _searchController = TextEditingController();
  bool _isInit = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    AnalyticsService().setCurrentScreen(screenName: 'Caption Store');
  }

  Future<void> _loadData() async {
    if (!_isInit) {
      await CaptionStoreService.init();
      _isInit = true;
    }
    setState(() {
      _captions = CaptionStoreService.getAllCaptions();
      _categories = CaptionStoreService.getAllCategories();
    });
  }

  List<String> get _variantNames {
    final Set<String> names = {};
    for (var caption in _captions) {
      // If a category is selected, only pull variant names from that category
      if (_selectedCategory == null || caption.category == _selectedCategory) {
        for (var variant in caption.variants) {
          names.add(variant.name);
        }
      }
    }
    final list = names.toList()..sort();
    return list;
  }

  List<CaptionGroup> get _filteredCaptions {
    final query = _searchController.text.toLowerCase();
    return _captions.where((c) {
      final matchesSearch = c.title.toLowerCase().contains(query) ||
          c.category?.toLowerCase().contains(query) == true ||
          c.variants.any((v) => v.content.toLowerCase().contains(query));
      
      final matchesCategory = _selectedCategory == null || c.category == _selectedCategory;
      
      final matchesVariant = _selectedVariantName == null || 
          c.variants.any((v) => v.name == _selectedVariantName);
          
      return matchesSearch && matchesCategory && matchesVariant;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Caption Store', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'export':
                  _exportCaptions();
                  break;
                case 'import':
                  _importCaptions();
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.upload, size: 20),
                    SizedBox(width: 12),
                    Text('Export Captions'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    Icon(Icons.download, size: 20),
                    SizedBox(width: 12),
                    Text('Import Captions'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: _showAddCaptionDialog,
            icon: const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 28),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchBar(),
          Row(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text('Niche / Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              ),
              const Spacer(),
              IconButton(
                onPressed: _showAddCaptionDialog,
                icon: const Icon(Icons.add, size: 18, color: AppColors.primary),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          _buildCategoryFilters(),
          Row(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text('Variant Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              ),
              const Spacer(),
              IconButton(
                onPressed: _showAddCaptionDialog,
                icon: const Icon(Icons.add, size: 18, color: AppColors.primaryLight),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          _buildVariantFilters(),
          const Divider(height: 24),
          Expanded(
            child: _filteredCaptions.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredCaptions.length,
                    itemBuilder: (context, index) => _buildCaptionCard(_filteredCaptions[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Search captions or hashtags...',
          prefixIcon: const Icon(Icons.search, size: 20),
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
      ),
    );
  }

  Widget _buildCategoryFilters() {
    return SizedBox(
      height: 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length + 1,
        itemBuilder: (context, index) {
          final isAll = index == 0;
          final category = isAll ? null : _categories[index - 1];
          final isSelected = _selectedCategory == category;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(isAll ? 'All' : category!),
              selected: isSelected,
              onSelected: (val) => setState(() {
                _selectedCategory = val ? category : null;
                // Reset variant filter if the new category doesn't have it
                if (_selectedVariantName != null) {
                  final availableVariants = _variantNames;
                  if (!availableVariants.contains(_selectedVariantName)) {
                    _selectedVariantName = null;
                  }
                }
              }),
              selectedColor: AppColors.primary.withOpacity(0.2),
              labelStyle: TextStyle(
                color: isSelected ? AppColors.primaryDark : Colors.grey[700],
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              backgroundColor: Colors.grey[100],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              side: BorderSide.none,
              showCheckmark: false,
            ),
          );
        },
      ),
    );
  }

  Widget _buildVariantFilters() {
    final variants = _variantNames;
    return SizedBox(
      height: 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: variants.length + 1,
        itemBuilder: (context, index) {
          final isAll = index == 0;
          final name = isAll ? null : variants[index - 1];
          final isSelected = _selectedVariantName == name;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(isAll ? 'Any' : name!),
              selected: isSelected,
              onSelected: (val) => setState(() => _selectedVariantName = val ? name : null),
              selectedColor: AppColors.primaryLight.withOpacity(0.2),
              labelStyle: TextStyle(
                color: isSelected ? AppColors.primaryDark : Colors.grey[700],
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              backgroundColor: Colors.grey[100],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              side: BorderSide.none,
              showCheckmark: false,
            ),
          );
        },
      ),
    );
  }

  Widget _buildCaptionCard(CaptionGroup group) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...group.variants.map((v) => _buildVariantItem(group, v)).toList(),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: Divider(thickness: 1, height: 1),
        ),
      ],
    );
  }

  Widget _buildVariantItem(CaptionGroup group, CaptionVariant variant) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(group.title, 
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.2)),
                    const SizedBox(width: 8),
                    if (group.category != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(group.category!, 
                          style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w600)),
                      ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(variant.name.toUpperCase(), 
                        style: const TextStyle(
                          fontWeight: FontWeight.bold, 
                          fontSize: 10, 
                          color: AppColors.primaryLight,
                          letterSpacing: 0.5,
                        )),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.content_copy_outlined, size: 18, color: AppColors.primary),
                onPressed: () => _copyToClipboard(variant.content),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(8),
                tooltip: 'Copy Caption',
              ),
              IconButton(
                icon: const Icon(Icons.edit_note_outlined, size: 20, color: Colors.grey),
                onPressed: () => _showEditCaptionDialog(group),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(8),
                tooltip: 'Edit Set',
              ),
            ],
          ),
          const SizedBox(height: 4),
          SelectableText(
            variant.content,
            style: const TextStyle(
              fontSize: 14, 
              height: 1.5, 
              color: Colors.black87,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.description_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No captions found', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _showAddCaptionDialog,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Add Your First Caption'),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    AnalyticsService().logEvent(name: 'caption_copied');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Caption copied to clipboard!'), duration: Duration(seconds: 1)),
    );
  }

  Future<void> _exportCaptions() async {
    AnalyticsService().logEvent(name: 'captions_exported');
    try {
      final filePath = await CaptionBackupService.exportCaptionStore();
      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Export Successful'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your captions have been exported to:'),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  filePath,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.white),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'You can find it in:\nDownloads/Quick Post Backup/',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await Share.shareXFiles(
                  [XFile(filePath)],
                  text: 'Caption Store backup',
                );
              },
              child: const Text('Share'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _importCaptions() async {
    AnalyticsService().logEvent(name: 'captions_imported');
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.isEmpty) return;
      final path = result.files.single.path;
      if (path == null || path.isEmpty) return;
      if (!mounted) return;

      final mode = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import Captions'),
          content: const Text('How should import behave with existing captions?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'merge'),
              child: const Text('Merge'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'replace'),
              child: const Text('Replace'),
            ),
          ],
        ),
      );

      if (mode == null) return;

      final importResult = await CaptionBackupService.importCaptionStoreFromFile(
        path,
        replaceExisting: mode == 'replace',
      );

      await _loadData();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported ${importResult.importedCount} groups (skipped ${importResult.skippedCount})')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showAddCaptionDialog() {
    _showCaptionDialog(null, initialCategory: _selectedCategory, initialVariantName: _selectedVariantName);
  }

  void _showEditCaptionDialog(CaptionGroup group) {
    _showCaptionDialog(group);
  }

  void _showCaptionDialog(CaptionGroup? existingGroup, {String? initialCategory, String? initialVariantName}) {
    final titleController = TextEditingController(text: existingGroup?.title);
    final categoryController = TextEditingController(text: existingGroup?.category ?? initialCategory);
    List<Map<String, TextEditingController>> variantControllers = [];

    if (existingGroup != null) {
      for (var v in existingGroup.variants) {
        variantControllers.add({
          'name': TextEditingController(text: v.name),
          'content': TextEditingController(text: v.content),
        });
      }
    } else {
      variantControllers.add({
        'name': TextEditingController(text: initialVariantName ?? 'Instagram'),
        'content': TextEditingController(),
      });
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(existingGroup == null ? 'New Caption Set' : 'Edit Caption Set', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      if (existingGroup != null)
                        IconButton(
                          onPressed: () => _confirmDelete(existingGroup),
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          tooltip: 'Delete',
                        ),
                      const SizedBox(width: 4),
                      TextButton(
                        onPressed: () async {
                          if (titleController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a title')));
                            return;
                          }
                          final variants = variantControllers
                              .where((v) => v['content']!.text.isNotEmpty)
                              .map((v) => CaptionVariant(
                                  id: DateTime.now().millisecondsSinceEpoch.toString() + v['name']!.text,
                                  name: v['name']!.text,
                                  content: v['content']!.text))
                              .toList();
                          
                          if (variants.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least one variant content')));
                            return;
                          }

                          final group = CaptionGroup(
                            id: existingGroup?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                            title: titleController.text,
                            category: categoryController.text.isEmpty ? null : categoryController.text,
                            createdAt: existingGroup?.createdAt ?? DateTime.now(),
                            variants: variants,
                          );
                          await CaptionStoreService.saveCaptionGroup(group);
                          AnalyticsService().logEvent(
                            name: existingGroup == null ? 'caption_created' : 'caption_updated',
                            parameters: {'category': group.category ?? 'none'}
                          );
                          Navigator.pop(context);
                          _loadData();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          textStyle: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        child: Text(existingGroup == null ? 'CREATE' : 'UPDATE'),
                      ),
                      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final double fieldWidth = (constraints.maxWidth - 8) / 2;
                          return Row(
                            children: [
                              SizedBox(
                                width: fieldWidth,
                                child: _buildFullTextField(titleController, 'Group Title', 'e.g., Viral Reels', fontSize: 13),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: fieldWidth,
                                child: _buildFullTextField(categoryController, 'Niche / Page', 'e.g., Fitness', fontSize: 13),
                              ),
                            ],
                          );
                        }
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('CAPTION VARIANTS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey, letterSpacing: 1.2)),
                          TextButton.icon(
                            onPressed: () => setModalState(() => variantControllers.add({'name': TextEditingController(text: 'Variant ${variantControllers.length + 1}'), 'content': TextEditingController()})),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Type'),
                            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                          ),
                        ],
                      ),
                      const Divider(),
                      ...variantControllers.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final controllers = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildFullTextField(
                                      controllers['name']!,
                                      'Type',
                                      'e.g., Instagram, Twitter, Short',
                                    ),
                                  ),
                                  if (variantControllers.length > 1)
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                      onPressed: () => setModalState(() => variantControllers.removeAt(idx)),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              _buildFullTextField(
                                controllers['content']!,
                                'Content',
                                'Type your caption and hashtags here...',
                                minLines: 10,
                                maxLines: null,
                                keyboardType: TextInputType.multiline,
                                enableInteractiveSelection: true,
                                hideContextMenu: true,
                                collapseSelectionOnTap: true,
                                plain: true,
                              ),
                              if (idx != variantControllers.length - 1)
                                const Padding(
                                  padding: EdgeInsets.only(top: 12),
                                  child: Divider(height: 1),
                                ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFullTextField(
    TextEditingController controller,
    String label,
    String hint, {
    int? minLines,
    int? maxLines = 1,
    double fontSize = 14,
    bool enableInteractiveSelection = true,
    bool hideContextMenu = false,
    TextInputType? keyboardType,
    bool collapseSelectionOnTap = false,
    bool plain = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          minLines: minLines,
          maxLines: maxLines,
          keyboardType: keyboardType,
          enableInteractiveSelection: enableInteractiveSelection,
          contextMenuBuilder: hideContextMenu ? (context, editableTextState) => const SizedBox.shrink() : null,
          onTap: collapseSelectionOnTap
              ? () {
                  // Some Android builds aggressively extend selection when tapping inside
                  // large multi-line fields inside a scrollable bottom sheet.
                  // Collapsing selection on tap keeps this feeling like a plain text editor.
                  final selection = controller.selection;
                  if (selection.isValid && !selection.isCollapsed) {
                    controller.selection = TextSelection.collapsed(offset: selection.extentOffset);
                  }
                }
              : null,
          style: TextStyle(fontSize: fontSize),
          decoration: plain
              ? InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: fontSize),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                )
              : InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: fontSize),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[300]!)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[200]!)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
        ),
      ],
    );
  }

  void _confirmDelete(CaptionGroup group) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Caption?'),
        content: Text('Are you sure you want to delete "${group.title}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await CaptionStoreService.deleteCaptionGroup(group.id);
              Navigator.pop(context); // dialog
              Navigator.pop(context); // bottom sheet
              _loadData();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Caption removed')));
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
