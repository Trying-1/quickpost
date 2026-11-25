import 'package:flutter/material.dart';
import 'package:quickpost/config/app_theme.dart';
import '../models/misc_tool_item.dart';
import 'more_tools_card.dart';

/// Renders a category header followed by a list of tool cards.
class MoreToolsCategorySection extends StatelessWidget {
  final String categoryTitle;
  final List<MiscToolItem> tools;

  const MoreToolsCategorySection({
    super.key,
    required this.categoryTitle,
    required this.tools,
  });

  @override
  Widget build(BuildContext context) {
    if (tools.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 10, left: 4),
          child: Text(
            categoryTitle.toUpperCase(),
            style: const TextStyle(
              fontFamily: AppTextStyles.fontFamily,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: Color(0xFF64748B),
            ),
          ),
        ),
        ...tools.map((tool) => MoreToolsCard(tool: tool)),
      ],
    );
  }
}

