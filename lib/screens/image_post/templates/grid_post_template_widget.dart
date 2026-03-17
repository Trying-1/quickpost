import 'package:flutter/material.dart';

class GridPostTemplateWidget extends StatelessWidget {
  final Widget templateSelector;
  final Widget previewSection;
  final Widget controlsSection;

  const GridPostTemplateWidget({
    super.key,
    required this.templateSelector,
    required this.previewSection,
    required this.controlsSection,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          templateSelector,
          previewSection,
          controlsSection,
        ],
      ),
    );
  }
}
