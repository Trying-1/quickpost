import 'package:flutter/material.dart';
import 'package:quickpost/config/app_theme.dart';
import 'package:quickpost/services/analytics_service.dart';
import 'models/misc_tool_item.dart';
import 'services/more_tools_registry_service.dart';
import 'widgets/more_tools_search_bar.dart';
import 'widgets/more_tools_category_section.dart';

/// Lightweight orchestrator screen for the More Tools hub.
/// Connects decoupled search, categories, and tool cards.
class MoreToolsScreen extends StatefulWidget {
  const MoreToolsScreen({super.key});

  @override
  State<MoreToolsScreen> createState() => _MoreToolsScreenState();
}

class _MoreToolsScreenState extends State<MoreToolsScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final MoreToolsRegistryService _registryService = MoreToolsRegistryService();

  @override
  void initState() {
    super.initState();
    AnalyticsService().setCurrentScreen(screenName: 'More Tools');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredTools = _registryService.searchTools(_searchQuery);

    // Extract unique active categories based on filtered results
    final activeCategories = MiscToolCategory.values.where((cat) {
      return filteredTools.any((t) => t.category == cat);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'More Tools',
              style: TextStyle(
                fontFamily: AppTextStyles.fontFamily,
                fontWeight: FontWeight.w800,
                fontSize: 19,
                color: Color(0xFF0F172A),
              ),
            ),
            Text(
              'Utilities & creative helpers for your content',
              style: TextStyle(
                fontFamily: AppTextStyles.fontFamily,
                fontSize: 11,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Search & Filter Bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: MoreToolsSearchBar(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                onClear: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              ),
            ),
          ),

          // Tools grouped by category
          if (filteredTools.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.search_off_rounded, size: 54, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text(
                      'No tools matching "$_searchQuery"',
                      style: TextStyle(
                        fontFamily: AppTextStyles.fontFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final category = activeCategories[index];
                    final catTools = filteredTools.where((t) => t.category == category).toList();

                    return MoreToolsCategorySection(
                      categoryTitle: category.displayName,
                      tools: catTools,
                    );
                  },
                  childCount: activeCategories.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
