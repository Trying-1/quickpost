import 'package:flutter/material.dart';

class SingleImageTemplateWidget extends StatelessWidget {
  final Widget templateSelector;
  final Widget previewSection;
  final Widget controlsSection;

  const SingleImageTemplateWidget({
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
