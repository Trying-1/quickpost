import 'package:flutter/material.dart';
import '../../models/template_config.dart';

/// Grid Post Template (1080x1350 with 2x2 image grid)
/// Template with 4 images in a grid layout
const gridTemplate = TemplateConfig(
  id: 'grid_post',
  name: 'Grid Post',
  description: '1080x1350 - 2x2 image grid',
  width: 1080.0,
  height: 1350.0,
  icon: Icons.grid_on,
  color: Colors.deepPurple,
  isGrid: true,
);
