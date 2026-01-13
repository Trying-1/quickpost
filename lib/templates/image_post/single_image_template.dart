import 'package:flutter/material.dart';
import '../../models/template_config.dart';

/// Single image post template configuration
/// Instagram-style single image with text overlay (1080x1350)
const TemplateConfig singleImageTemplate = TemplateConfig(
  id: 'single_image_post',
  name: 'Single Image',
  description: 'Instagram-style single image post with text overlay',
  width: 1080,
  height: 1350,
  icon: Icons.image,
  color: Color(0xFF6366F1),
  isGrid: false,
);
