import 'package:flutter/material.dart';
import '../../models/template_config.dart';

/// Grid post template configuration
/// 2x2 grid layout with text overlay (1080x1350)
const TemplateConfig gridTemplate = TemplateConfig(
  id: 'grid_post',
  name: 'Grid Post',
  description: '2x2 grid layout with text overlay',
  width: 1080,
  height: 1350,
  icon: Icons.grid_3x3,
  color: Color(0xFF8B5CF6),
  isGrid: true,
);
