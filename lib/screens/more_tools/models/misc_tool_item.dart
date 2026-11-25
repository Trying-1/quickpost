import 'package:flutter/material.dart';

/// Categories for organizing miscellaneous tools in the hub.
enum MiscToolCategory {
  quickUtilities('Quick Utilities'),
  librariesAndStudios('Libraries & Studios'),
  creatorLab('Creator Lab');

  final String displayName;
  const MiscToolCategory(this.displayName);
}

/// Domain model representing a tool item inside the More Tools hub.
class MiscToolItem {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color accentColor;
  final MiscToolCategory category;
  final String? badgeText;
  final Color? badgeColor;
  final void Function(BuildContext context) onTap;

  const MiscToolItem({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.category,
    this.badgeText,
    this.badgeColor,
    required this.onTap,
  });
}

