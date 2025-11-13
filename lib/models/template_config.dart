import 'package:flutter/material.dart';

/// Template configuration model
/// Defines the properties of each social media template
class TemplateConfig {
  final String id;
  final String name;
  final String description;
  final double width;
  final double height;
  final IconData icon;
  final Color color;
  final bool isGrid;

  const TemplateConfig({
    required this.id,
    required this.name,
    required this.description,
    required this.width,
    required this.height,
    required this.icon,
    required this.color,
    this.isGrid = false,
  });

  /// Convert to map for backward compatibility
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'width': width,
      'height': height,
      'icon': icon,
      'color': color,
      'isGrid': isGrid,
    };
  }
}
