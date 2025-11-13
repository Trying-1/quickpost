import 'package:flutter/material.dart';
import '../../models/template_config.dart';

/// Single Image Post Template (1080x1350)
/// Classic post with single image and text overlay
const singleImageTemplate = TemplateConfig(
  id: 'single_image_post',
  name: 'Single Image',
  description: '1080x1350 - Single image post',
  width: 1080.0,
  height: 1350.0,
  icon: Icons.crop_square,
  color: Colors.purple,
  isGrid: false,
);
