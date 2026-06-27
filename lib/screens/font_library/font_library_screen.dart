import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../config/app_theme.dart';
import '../../utils/font_selector.dart';
import '../../utils/custom_font_manager.dart';

class FontLibraryScreen extends StatefulWidget {
  final bool isActive;
  const FontLibraryScreen({super.key, this.isActive = false});

  @override
  State<FontLibraryScreen> createState() => _FontLibraryScreenState();
}

class _FontLibraryScreenState extends State<FontLibraryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _previewController = TextEditingController(text: 'Abc - The quick brown fox');
  
  List<FontInfo> _allFonts = [];
  List<FontInfo> _filteredFonts = [];
  bool _isImporting = false;
  String _searchQuery = '';

  Color _textColor = Colors.black87;
  Color _bgColor = Colors.white;

  final List<Color> _textColors = [
    Colors.black87,
    Colors.white,
    Colors.grey[600]!,
    Colors.redAccent,
    Colors.orange,
    Colors.amber,
    Colors.green,
    Colors.teal,
    Colors.blue,
    Colors.indigo,
    Colors.purple,
    Colors.pink,
  ];

  final List<Color> _bgColors = [
    Colors.white,
    Colors.grey[100]!,
    Colors.black87,
    Colors.indigo[900]!,
    Colors.teal[900]!,
    Colors.orange[50]!,
    Colors.purple[50]!,
    Colors.green[50]!,
    Colors.blue[50]!,
    Colors.pink[50]!,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _loadFonts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _previewController.dispose();
    super.dispose();
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) return;
    _filterFonts();
  }

  void _loadFonts() {
    setState(() {
      _allFonts = getAllFonts();
      _filterFonts();
    });
  }

  void _filterFonts() {
    List<FontInfo> list = [];
    if (_tabController.index == 0) {
      list = _allFonts;
    } else if (_tabController.index == 1) {
      list = _allFonts.where((f) => f.isCustom).toList();
    } else {
      list = _allFonts.where((f) => !f.isCustom).toList();
    }

    if (_searchQuery.isNotEmpty) {
      list = list.where((f) => f.displayName.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }

    setState(() {
      _filteredFonts = list;
    });
  }

  Future<void> _importCustomFont() async {
    setState(() => _isImporting = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
      );
      if (result != null && result.files.isNotEmpty) {
        bool anyImported = false;
        for (final xFile in result.files) {
          if (xFile.path == null) continue;
          final path = xFile.path!;
          if (!path.toLowerCase().endsWith('.ttf') && !path.toLowerCase().endsWith('.otf')) {
            continue;
          }
          final file = File(path);
          final entry = await CustomFontManager().addFont(file);
          if (entry != null) anyImported = true;
        }

        if (anyImported) {
          _loadFonts();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚡ Fonts imported successfully!'),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to import font: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() => _isImporting = false);
    }
  }

  Future<void> _deleteFont(FontInfo font) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Font'),
        content: Text('Are you sure you want to delete "${font.displayName}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await CustomFontManager().removeFont(font.family);
      _loadFonts();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Deleted font'),
          backgroundColor: Colors.black87,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.primary;
    final totalCount = _allFonts.length;
    final customCount = _allFonts.where((f) => f.isCustom).length;
    final systemCount = totalCount - customCount;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'My Font Library',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 22,
            fontFamily: 'Poppins',
            color: Colors.black87,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: false,
        actions: [
          if (_isImporting)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: ElevatedButton.icon(
                onPressed: _importCustomFont,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Import Font', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // ─── Search & Preview text ───
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val;
                              _filterFonts();
                            });
                          },
                          decoration: const InputDecoration(
                            hintText: 'Search fonts...',
                            hintStyle: TextStyle(fontSize: 14, color: Colors.grey),
                            prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: TextField(
                    controller: _previewController,
                    onChanged: (val) {
                      setState(() {});
                    },
                    decoration: const InputDecoration(
                      hintText: 'Type text to preview fonts...',
                      hintStyle: TextStyle(fontSize: 14, color: Colors.grey),
                      prefixIcon: Icon(Icons.font_download_outlined, size: 20, color: AppColors.primary),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Text Color: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _textColors.map((color) {
                            final isSelected = _textColor == color;
                            return GestureDetector(
                              onTap: () => setState(() => _textColor = color),
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected ? AppColors.primary : Colors.grey[300]!,
                                    width: isSelected ? 2.5 : 1,
                                  ),
                                ),
                                child: isSelected
                                    ? Icon(
                                        Icons.check,
                                        size: 14,
                                        color: color == Colors.white ? Colors.black : Colors.white,
                                      )
                                    : null,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Card BG:     ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _bgColors.map((color) {
                            final isSelected = _bgColor == color;
                            return GestureDetector(
                              onTap: () => setState(() => _bgColor = color),
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected ? AppColors.primary : Colors.grey[300]!,
                                    width: isSelected ? 2.5 : 1,
                                  ),
                                ),
                                child: isSelected
                                    ? Icon(
                                        Icons.check,
                                        size: 14,
                                        color: color == Colors.white || color == Colors.grey[100] || color == Colors.orange[50] || color == Colors.purple[50] || color == Colors.green[50] ? Colors.black : Colors.white,
                                      )
                                    : null,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ─── Stats summary count cards ───
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                _buildStatCard('Total', totalCount, Colors.indigo),
                const SizedBox(width: 8),
                _buildStatCard('Custom', customCount, Colors.purple),
                const SizedBox(width: 8),
                _buildStatCard('Premium', systemCount, Colors.teal),
              ],
            ),
          ),

          // ─── Tab Bar category selectors ───
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              tabs: const [
                Tab(text: 'All Fonts'),
                Tab(text: 'Custom Fonts'),
                Tab(text: 'System Fonts'),
              ],
            ),
          ),

          // ─── Fonts list ───
          Expanded(
            child: _filteredFonts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.font_download_off_outlined, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No fonts found',
                          style: TextStyle(color: Colors.grey[600], fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Import your custom .ttf/.otf fonts to get started.',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredFonts.length,
                    itemBuilder: (context, index) {
                      final font = _filteredFonts[index];
                      final previewText = _previewController.text.isEmpty
                          ? font.displayName
                          : _previewController.text;

                      final isDarkBg = ThemeData.estimateBrightnessForColor(_bgColor) == Brightness.dark;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: _bgColor,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: Border.all(color: isDarkBg ? Colors.white10 : Colors.grey[100]!),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          font.displayName,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: isDarkBg ? Colors.grey[400] : Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: font.isCustom
                                                ? Colors.purple.withOpacity(isDarkBg ? 0.2 : 0.08)
                                                : Colors.teal.withOpacity(isDarkBg ? 0.2 : 0.08),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            font.isCustom ? 'CUSTOM' : 'PREMIUM',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: font.isCustom
                                                  ? (isDarkBg ? Colors.purple[200] : Colors.purple)
                                                  : (isDarkBg ? Colors.teal[200] : Colors.teal),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      previewText,
                                      style: TextStyle(
                                        fontFamily: font.family,
                                        fontSize: 24,
                                        color: _textColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (font.isCustom)
                                Positioned(
                                  top: 12,
                                  right: 12,
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.delete_outline,
                                      color: isDarkBg ? Colors.red[300] : Colors.redAccent,
                                      size: 20,
                                    ),
                                    onPressed: () => _deleteFont(font),
                                    tooltip: 'Delete custom font',
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

  Widget _buildStatCard(String title, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.12), width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color.withOpacity(0.8)),
            ),
            const SizedBox(height: 4),
            Text(
              count.toString(),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
